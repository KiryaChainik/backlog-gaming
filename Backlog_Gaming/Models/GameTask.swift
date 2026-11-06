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
        // `id` и `title` обязательны; остальное — терпимо, с дефолтами (проблемы регистрируются).
        if let k = c.decodeTolerant(GameTaskKind.self, forKey: .kind, decoder: decoder) {
            kind = k
        } else {
            decoder.reportBacklogDecodeIssue("GameTask.kind missing, defaulted to todo")
            kind = .todo
        }
        isDone = c.decodeTolerant(Bool.self, forKey: .isDone, decoder: decoder) ?? false
        dueDate = c.decodeTolerant(Date.self, forKey: .dueDate, decoder: decoder)
        includesTime = c.decodeTolerant(Bool.self, forKey: .includesTime, decoder: decoder) ?? false
        if let s = c.decodeTolerant(String.self, forKey: .symbolName, decoder: decoder), !s.isEmpty {
            symbolName = s
        } else {
            symbolName = Self.defaultSymbol(for: kind)
        }
        accentIndex = c.decodeTolerant(Int.self, forKey: .accentIndex, decoder: decoder) ?? 0
        flowSortKey = c.decodeTolerant(Int.self, forKey: .flowSortKey, decoder: decoder) ?? 0
        note = c.decodeTolerant(String.self, forKey: .note, decoder: decoder) ?? ""
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
