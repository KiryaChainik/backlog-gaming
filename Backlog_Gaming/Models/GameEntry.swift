//
//  GameEntry.swift
//  Backlog_Gaming
//

import Foundation

enum GameStatus: String, Codable, CaseIterable, Sendable {
    case queued
    case playing
    case completed
    case dropped

    var shortTitle: String {
        switch self {
        case .queued: "В очереди"
        case .playing: "Играю"
        case .completed: "Пройдено"
        case .dropped: "Брошено"
        }
    }
}

enum GamePlatform: String, Codable, CaseIterable, Sendable {
    case unspecified
    case pc
    case playStation
    case xbox
    case nintendoSwitch
    case steamDeck
    case ios
    case mac
    case other

    var shortTitle: String {
        switch self {
        case .unspecified: "Не указана"
        case .pc: "PC"
        case .playStation: "PlayStation"
        case .xbox: "Xbox"
        case .nintendoSwitch: "Switch"
        case .steamDeck: "Steam Deck"
        case .ios: "iOS / iPadOS"
        case .mac: "Mac"
        case .other: "Другое"
        }
    }
}

/// Колонки канбана на вкладке «Игры» (бэклог = вишлист + очередь, `status == .queued`).
enum GameKanbanColumn: String, CaseIterable, Identifiable, Sendable {
    case playing
    case backlog
    case completed
    case dropped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .playing: "Играю"
        case .backlog: "Бэклог"
        case .completed: "Пройдено"
        case .dropped: "Брошено"
        }
    }
}

enum GameListSection: Hashable, Sendable {
    case playing
    case wishlist
    case queue
    case completed
    case dropped

    var header: String {
        switch self {
        case .playing: "Играю"
        case .wishlist: "Вишлист"
        case .queue: "В очереди"
        case .completed: "Пройдено"
        case .dropped: "Брошено"
        }
    }
}

struct GameEntry: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var status: GameStatus
    var note: String
    var platform: GamePlatform
    var wishlist: Bool
    var completedAt: Date?
    /// SF Symbol для карточки игры в канбане и на таймлайне.
    var symbolName: String
    /// Индекс в палитре `GameTaskVisual.accentPalette`.
    var accentIndex: Int
    /// Поток дел внутри игры; порядок в массиве — порядок «сверху вниз».
    var tasks: [GameTask]

    nonisolated static let defaultSymbol = "gamecontroller.fill"

    var displaySymbolName: String {
        symbolName.isEmpty ? Self.defaultSymbol : symbolName
    }

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        status: GameStatus = .queued,
        note: String = "",
        platform: GamePlatform = .unspecified,
        wishlist: Bool = false,
        completedAt: Date? = nil,
        symbolName: String = GameEntry.defaultSymbol,
        accentIndex: Int = 0,
        tasks: [GameTask] = []
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.note = note
        self.platform = platform
        self.wishlist = wishlist
        self.completedAt = completedAt
        self.symbolName = symbolName
        self.accentIndex = accentIndex
        self.tasks = tasks
    }

    enum CodingKeys: String, CodingKey {
        case id, title, status, note, platform, wishlist, completedAt, symbolName, accentIndex, tasks
        case isCompleted
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)

        if let st = try c.decodeIfPresent(GameStatus.self, forKey: .status) {
            status = st
        } else if let legacy = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) {
            status = legacy ? .completed : .queued
        } else {
            status = .queued
        }

        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        platform = try c.decodeIfPresent(GamePlatform.self, forKey: .platform) ?? .unspecified
        wishlist = try c.decodeIfPresent(Bool.self, forKey: .wishlist) ?? false
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        if let s = try c.decodeIfPresent(String.self, forKey: .symbolName), !s.isEmpty {
            symbolName = s
        } else {
            symbolName = Self.defaultSymbol
        }
        accentIndex = try c.decodeIfPresent(Int.self, forKey: .accentIndex) ?? 0
        tasks = try c.decodeIfPresent([GameTask].self, forKey: .tasks) ?? []

        if status != .queued { wishlist = false }
        if status != .completed { completedAt = nil }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(status, forKey: .status)
        try c.encode(note, forKey: .note)
        try c.encode(platform, forKey: .platform)
        try c.encode(wishlist, forKey: .wishlist)
        try c.encodeIfPresent(completedAt, forKey: .completedAt)
        try c.encode(symbolName, forKey: .symbolName)
        try c.encode(accentIndex, forKey: .accentIndex)
        try c.encode(tasks, forKey: .tasks)
    }
}
