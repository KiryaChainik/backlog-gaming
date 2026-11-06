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

    /// Колонка канбана, в которой сейчас стоит игра.
    var kanbanColumn: GameKanbanColumn {
        switch status {
        case .playing: .playing
        case .queued: .backlog
        case .completed: .completed
        case .dropped: .dropped
        }
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

        // `id` и `title` обязательны: без них запись пропускается целиком (см. `LossyDecodableArray`).
        // Остальные поля читаются терпимо — битое значение заменяется дефолтом и регистрируется.
        if let st = c.decodeTolerant(GameStatus.self, forKey: .status, decoder: decoder) {
            status = st
        } else if let legacy = c.decodeTolerant(Bool.self, forKey: .isCompleted, decoder: decoder) {
            status = legacy ? .completed : .queued
        } else {
            status = .queued
        }

        note = c.decodeTolerant(String.self, forKey: .note, decoder: decoder) ?? ""
        platform = c.decodeTolerant(GamePlatform.self, forKey: .platform, decoder: decoder) ?? .unspecified
        wishlist = c.decodeTolerant(Bool.self, forKey: .wishlist, decoder: decoder) ?? false
        completedAt = c.decodeTolerant(Date.self, forKey: .completedAt, decoder: decoder)
        if let s = c.decodeTolerant(String.self, forKey: .symbolName, decoder: decoder), !s.isEmpty {
            symbolName = s
        } else {
            symbolName = Self.defaultSymbol
        }
        accentIndex = c.decodeTolerant(Int.self, forKey: .accentIndex, decoder: decoder) ?? 0
        tasks = c.decodeTolerant(LossyDecodableArray<GameTask>.self, forKey: .tasks, decoder: decoder)?.elements ?? []

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
