//
//  GameTask.swift
//  Backlog_Gaming
//

import Foundation

enum GameTaskKind: String, Codable, CaseIterable, Sendable {
    /// Крупная единица: глава, крупная веха.
    case milestone
    /// Обычное дело внутри игры.
    case todo

    var shortTitle: String {
        switch self {
        case .milestone: "Веха / глава"
        case .todo: "Дело"
        }
    }
}

struct GameTask: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var kind: GameTaskKind
    var isDone: Bool
    /// Необязательный срок / дата в потоке; `nil` — только порядок в списке игры.
    var dueDate: Date?
    /// Если `true`, при отображении учитывается время, иначе только календарный день.
    var includesTime: Bool
    /// Имя SF Symbol для узла на таймлайне и в списке.
    var symbolName: String
    /// Индекс в палитре `GameTaskVisual.accentPalette`.
    var accentIndex: Int
    /// Порядок строки внутри секции «Поток» (одна нумерация на секцию: дата / просрочено / без даты). 0 — как раньше, сравнение по названию игры.
    var flowSortKey: Int
    /// Заметка (Markdown: **жирный**, *курсив*, списки, ссылки).
    var note: String

    enum CodingKeys: String, CodingKey {
        case id, title, kind, isDone, dueDate, includesTime, symbolName, accentIndex, flowSortKey, note
    }

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        kind: GameTaskKind = .todo,
        isDone: Bool = false,
        dueDate: Date? = nil,
        includesTime: Bool = false,
        symbolName: String? = nil,
        accentIndex: Int = 0,
        flowSortKey: Int = 0,
        note: String = ""
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.isDone = isDone
        self.dueDate = dueDate
        self.includesTime = includesTime
        self.symbolName = symbolName ?? Self.defaultSymbol(for: kind)
        self.accentIndex = accentIndex
        self.flowSortKey = flowSortKey
        self.note = note
    }

    nonisolated static func defaultSymbol(for kind: GameTaskKind) -> String {
        kind == .milestone ? "flag.fill" : "checkmark.circle"
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        kind = try c.decode(GameTaskKind.self, forKey: .kind)
        isDone = try c.decode(Bool.self, forKey: .isDone)
        dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
        includesTime = try c.decodeIfPresent(Bool.self, forKey: .includesTime) ?? false
        if let s = try c.decodeIfPresent(String.self, forKey: .symbolName), !s.isEmpty {
            symbolName = s
        } else {
            symbolName = Self.defaultSymbol(for: kind)
        }
        accentIndex = try c.decodeIfPresent(Int.self, forKey: .accentIndex) ?? 0
        flowSortKey = try c.decodeIfPresent(Int.self, forKey: .flowSortKey) ?? 0
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(kind, forKey: .kind)
        try c.encode(isDone, forKey: .isDone)
        try c.encodeIfPresent(dueDate, forKey: .dueDate)
        try c.encode(includesTime, forKey: .includesTime)
        try c.encode(symbolName, forKey: .symbolName)
        try c.encode(accentIndex, forKey: .accentIndex)
        try c.encode(flowSortKey, forKey: .flowSortKey)
        try c.encode(note, forKey: .note)
    }
}
