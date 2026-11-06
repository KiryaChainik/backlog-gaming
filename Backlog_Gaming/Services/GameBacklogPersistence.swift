//
//  GameBacklogPersistence.swift
//  Backlog_Gaming
//

import Foundation
import os

// MARK: - Сбор проблем декодирования

/// Собирает проблемы, встреченные при декодировании (битые записи, неизвестные значения enum).
/// Передаётся через `JSONDecoder.userInfo`, чтобы вложенные `init(from:)` могли сообщить о потере данных
/// и Store успел сделать резервную копию **до** первой перезаписи хранилища.
nonisolated final class GameBacklogDecodeIssues: @unchecked Sendable {
    static let userInfoKey = CodingUserInfoKey(rawValue: "gameBacklog.decodeIssues")!

    private let lock = NSLock()
    private var storage: [String] = []

    init() {}

    func report(_ message: String) {
        lock.lock()
        storage.append(message)
        lock.unlock()
    }

    var messages: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

extension Decoder {
    nonisolated func reportBacklogDecodeIssue(_ message: @autoclosure () -> String) {
        (userInfo[GameBacklogDecodeIssues.userInfoKey] as? GameBacklogDecodeIssues)?.report(message())
    }
}

extension KeyedDecodingContainer {
    /// Как `decodeIfPresent`, но ошибка (неверный тип, неизвестный raw value) не роняет всю запись:
    /// возвращается `nil`, а проблема регистрируется.
    nonisolated func decodeTolerant<T: Decodable>(_ type: T.Type, forKey key: Key, decoder: any Decoder) -> T? {
        do {
            return try decodeIfPresent(type, forKey: key)
        } catch {
            decoder.reportBacklogDecodeIssue("\(key.stringValue): \(error)")
            return nil
        }
    }
}

/// Декодирует массив поэлементно: битый элемент пропускается и регистрируется, остальные сохраняются.
nonisolated struct LossyDecodableArray<Element: Decodable>: Decodable {
    var elements: [Element]

    nonisolated init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var result: [Element] = []
        while !container.isAtEnd {
            let index = container.currentIndex
            do {
                result.append(try container.decode(Element.self))
            } catch {
                decoder.reportBacklogDecodeIssue("\(Element.self)[\(index)] skipped: \(error)")
                // Неудачный decode не сдвигает курсор unkeyed-контейнера — пропускаем элемент вручную.
                if (try? container.decode(SkippedDecodable.self)) == nil { break }
            }
        }
        elements = result
    }
}

nonisolated private struct SkippedDecodable: Decodable {
    nonisolated init(from decoder: any Decoder) throws {}
}

// MARK: - Формат файла

/// File-scoped envelope avoids Swift 6 treating nested `Codable` conformance as actor-isolated.
private struct GameBacklogFileEnvelope: Codable, Sendable {
    var version: Int
    var entries: [GameEntry]

    private enum CodingKeys: String, CodingKey {
        case version, entries
    }

    nonisolated init(version: Int, entries: [GameEntry]) {
        self.version = version
        self.entries = entries
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.decodeTolerant(Int.self, forKey: .version, decoder: decoder) ?? 0
        entries = try c.decode(LossyDecodableArray<GameEntry>.self, forKey: .entries).elements
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(entries, forKey: .entries)
    }
}

nonisolated struct GameBacklogDecodeResult: Sendable {
    var entries: [GameEntry]
    /// Непустой — часть данных прочитать не удалось (или формат неизвестен). Нужна резервная копия.
    var issues: [String]

    var hasIssues: Bool { !issues.isEmpty }
}

nonisolated enum GameBacklogBackupKind: String, Sendable {
    /// Снимок при запуске; хранятся последние `launchBackupsToKeep`.
    case launch
    /// Копия данных, которые не удалось прочитать полностью; не удаляется автоматически.
    case recovery
}

// MARK: - Persistence

enum GameBacklogPersistence: Sendable {
    nonisolated static let storageKey = "gameBacklog.entries.v1"
    nonisolated private static let envelopeVersion = 4
    nonisolated private static let launchBackupsToKeep = 5
    nonisolated private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BacklogGaming",
        category: "Persistence"
    )

    nonisolated static func decodeEntries(from data: Data) -> GameBacklogDecodeResult {
        // 1. Текущий формат: конверт { version, entries }.
        let envelopeAttempt = attemptDecode(GameBacklogFileEnvelope.self, from: data)
        if let env = envelopeAttempt.value {
            var issues = envelopeAttempt.issues
            if env.version > envelopeVersion {
                issues.append("envelope version \(env.version) is newer than supported \(envelopeVersion)")
            }
            return GameBacklogDecodeResult(entries: env.entries.map(Self.repairInvariants), issues: issues)
        }

        // 2. Старые форматы: плоский массив. v1 (`id, title, isCompleted`) читается тем же `GameEntry.init(from:)`.
        let flatAttempt = attemptDecode(LossyDecodableArray<GameEntry>.self, from: data)
        if let flat = flatAttempt.value {
            return GameBacklogDecodeResult(entries: flat.elements.map(Self.repairInvariants), issues: flatAttempt.issues)
        }

        return GameBacklogDecodeResult(entries: [], issues: ["storage blob (\(data.count) bytes) is not readable as any known format"])
    }

    nonisolated static func encodeEntries(_ entries: [GameEntry]) -> Data? {
        let payload = GameBacklogFileEnvelope(version: envelopeVersion, entries: entries.map(Self.repairInvariants))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            return try encoder.encode(payload)
        } catch {
            logger.error("Encoding backlog failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    // MARK: Backups

    /// `Documents/Backups` — видна в приложении «Файлы» (UIFileSharingEnabled).
    nonisolated static func backupsDirectory() throws -> URL {
        let fm = FileManager.default
        let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = docs.appendingPathComponent("Backups", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Пишет сырые данные хранилища в файл. Возвращает URL или `nil`, если запись не удалась.
    @discardableResult
    nonisolated static func writeBackup(_ data: Data, kind: GameBacklogBackupKind, now: Date = Date()) -> URL? {
        do {
            let dir = try backupsDirectory()
            if kind == .launch, let latest = backupFiles(kind: .launch, in: dir).last,
               let latestData = try? Data(contentsOf: latest), latestData == data {
                return latest // данные не менялись с прошлого снимка
            }
            let url = dir.appendingPathComponent("backlog-\(kind.rawValue)-\(timestamp(now)).json")
            try data.write(to: url, options: .atomic)
            if kind == .launch {
                pruneBackups(kind: .launch, keep: launchBackupsToKeep, in: dir)
            }
            return url
        } catch {
            logger.error("Backup (\(kind.rawValue, privacy: .public)) failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    // MARK: Private

    nonisolated private static func attemptDecode<T: Decodable>(_ type: T.Type, from data: Data) -> (value: T?, issues: [String]) {
        let collector = GameBacklogDecodeIssues()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.userInfo[GameBacklogDecodeIssues.userInfoKey] = collector
        let value = try? decoder.decode(type, from: data)
        return (value, collector.messages)
    }

    /// Файлы бэкапов данного типа, от старых к новым (имя содержит сортируемую метку времени).
    nonisolated private static func backupFiles(kind: GameBacklogBackupKind, in dir: URL) -> [URL] {
        let prefix = "backlog-\(kind.rawValue)-"
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    nonisolated private static func pruneBackups(kind: GameBacklogBackupKind, keep: Int, in dir: URL) {
        let files = backupFiles(kind: kind, in: dir)
        guard files.count > keep else { return }
        for url in files.prefix(files.count - keep) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    nonisolated private static func timestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: date)
    }

    nonisolated private static func repairInvariants(_ entry: GameEntry) -> GameEntry {
        var e = entry
        if e.status != .queued { e.wishlist = false }
        if e.status != .completed { e.completedAt = nil }
        return e
    }
}
