//
//  GameBacklogStorage.swift
//  Backlog_Gaming
//

import Foundation

/// Где `GameBacklogStore` хранит сырые данные. Протокол — чтобы превью и тесты не трогали настоящие данные.
protocol GameBacklogStorage {
    func loadData() -> Data?
    func saveData(_ data: Data)
    /// Резервная копия сырых данных. `nil` — записать копию не удалось.
    func writeBackup(_ data: Data, kind: GameBacklogBackupKind) -> URL?
}

/// Боевое хранилище: `UserDefaults` + бэкапы в `Documents/Backups`.
struct UserDefaultsBacklogStorage: GameBacklogStorage {
    var defaults: UserDefaults = .standard
    var key: String = GameBacklogPersistence.storageKey

    func loadData() -> Data? {
        defaults.data(forKey: key)
    }

    func saveData(_ data: Data) {
        defaults.set(data, forKey: key)
    }

    func writeBackup(_ data: Data, kind: GameBacklogBackupKind) -> URL? {
        GameBacklogPersistence.writeBackup(data, kind: kind)
    }
}

/// Хранилище в памяти — для превью и тестов. Ничего не пишет на диск.
final class InMemoryBacklogStorage: GameBacklogStorage {
    var data: Data?
    private(set) var backups: [(kind: GameBacklogBackupKind, data: Data)] = []
    /// Имитация сбоя записи бэкапа (для тестов защиты данных).
    var failsBackups: Bool

    init(data: Data? = nil, failsBackups: Bool = false) {
        self.data = data
        self.failsBackups = failsBackups
    }

    convenience init(entries: [GameEntry]) {
        self.init(data: GameBacklogPersistence.encodeEntries(entries))
    }

    func loadData() -> Data? { data }

    func saveData(_ data: Data) { self.data = data }

    func writeBackup(_ data: Data, kind: GameBacklogBackupKind) -> URL? {
        guard !failsBackups else { return nil }
        backups.append((kind: kind, data: data))
        return URL(fileURLWithPath: "/dev/null/backlog-\(kind.rawValue)-\(backups.count).json")
    }
}

// MARK: - Демо-данные

extension GameBacklogStore {
    /// Store с демо-данными в памяти — для `#Preview`. Настоящие данные не читаются и не перезаписываются.
    static func preview() -> GameBacklogStore {
        GameBacklogStore(storage: InMemoryBacklogStorage(entries: GameEntry.previewSamples()))
    }
}

extension GameEntry {
    /// Небольшой набор игр во всех статусах; даты — относительно «сейчас», чтобы «Поток» был не пустым.
    static func previewSamples(now: Date = Date()) -> [GameEntry] {
        let cal = Calendar.current
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: now) ?? now }
        return [
            GameEntry(
                title: "Outer Wilds", status: .playing, platform: .pc,
                symbolName: "sparkles", accentIndex: 0,
                tasks: [
                    GameTask(title: "Добраться до Пепельного близнеца", kind: .milestone, dueDate: day(-1), accentIndex: 0),
                    GameTask(title: "Прочитать записи номаи", dueDate: day(0), accentIndex: 1),
                    GameTask(title: "Найти Тёмный кустарник", dueDate: day(5), accentIndex: 2),
                    GameTask(title: "Пройти DLC", accentIndex: 3),
                ]
            ),
            GameEntry(
                title: "Hades II", status: .queued, platform: .nintendoSwitch, wishlist: true,
                symbolName: "flame.fill", accentIndex: 2
            ),
            GameEntry(
                title: "Baldur's Gate 3", status: .queued, platform: .playStation,
                symbolName: "shield.fill", accentIndex: 5
            ),
            GameEntry(
                title: "Celeste", status: .completed, platform: .pc, completedAt: day(-20),
                symbolName: "star.fill", accentIndex: 6,
                tasks: [GameTask(title: "Собрать все клубники", isDone: true, dueDate: day(-21), accentIndex: 6)]
            ),
            GameEntry(
                title: "Starfield", status: .dropped, platform: .xbox,
                symbolName: "airplane", accentIndex: 7
            ),
        ]
    }
}
