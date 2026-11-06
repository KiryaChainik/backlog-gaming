//
//  GameBacklogPersistence.swift
//  Backlog_Gaming
//

import Foundation

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
        version = try c.decode(Int.self, forKey: .version)
        entries = try c.decode([GameEntry].self, forKey: .entries)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(entries, forKey: .entries)
    }
}

enum GameBacklogPersistence: Sendable {
    nonisolated static let storageKey = "gameBacklog.entries.v1"
    nonisolated private static let envelopeVersion = 4
    nonisolated private static let minReadableEnvelopeVersion = 2

    private struct LegacyV1Entry: Codable, Sendable {
        var id: UUID
        var title: String
        var isCompleted: Bool
    }

    nonisolated static func decodeEntries(from data: Data) -> [GameEntry] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let env = try? decoder.decode(GameBacklogFileEnvelope.self, from: data), env.version >= minReadableEnvelopeVersion {
            return env.entries.map(Self.repairInvariants)
        }

        if let legacy = try? decoder.decode([LegacyV1Entry].self, from: data) {
            return legacy.map {
                GameEntry(
                    id: $0.id,
                    title: $0.title,
                    status: $0.isCompleted ? .completed : .queued
                )
            }
        }

        if let flat = try? decoder.decode([GameEntry].self, from: data) {
            return flat.map(Self.repairInvariants)
        }

        return []
    }

    nonisolated static func encodeEntries(_ entries: [GameEntry]) -> Data? {
        let payload = GameBacklogFileEnvelope(version: envelopeVersion, entries: entries.map(Self.repairInvariants))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(payload)
    }

    nonisolated private static func repairInvariants(_ entry: GameEntry) -> GameEntry {
        var e = entry
        if e.status != .queued { e.wishlist = false }
        if e.status != .completed { e.completedAt = nil }
        return e
    }
}
