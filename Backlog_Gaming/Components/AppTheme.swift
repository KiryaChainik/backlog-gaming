//
//  AppTheme.swift
//  Backlog_Gaming
//
//  Единые UI-токены и цвета (см. `.cursor/rules/ui-tokens.mdc`).
//

import SwiftUI

enum UITokens {
    // Таймлайн дел (канбан и «Поток»)
    static let nodeSize: CGFloat = 26
    static let stemWidth: CGFloat = 3
    static let timelineLaneWidth: CGFloat = 32

    // Карточки и колонки
    static let cardCornerRadius: CGFloat = 10
    static let columnCornerRadius: CGFloat = 14
}

enum AppTheme {
    /// Акцент приложения (tint, кнопка «+») — цвет колонки «Играю».
    static var accent: Color { GameKanbanColumn.playing.accent }
    /// Цвет вишлиста — одинаковый в карточках и статистике.
    static let wishlist: Color = .orange

    /// Подложка под белую иконку. В режиме «Повышенный контраст» пастель затемняется, чтобы глиф читался.
    static func iconFill(_ color: Color, contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? color.mix(with: .black, by: 0.35) : color
    }
}

extension GameKanbanColumn {
    var accent: Color {
        switch self {
        case .playing: Color(red: 0.38, green: 0.66, blue: 0.84)
        case .backlog: Color(red: 0.72, green: 0.52, blue: 0.78)
        case .completed: Color(red: 0.47, green: 0.73, blue: 0.53)
        case .dropped: Color(red: 0.63, green: 0.65, blue: 0.70)
        }
    }

    var symbolName: String {
        switch self {
        case .playing: "play.circle.fill"
        case .backlog: "clock.circle.fill"
        case .completed: "checkmark.circle.fill"
        case .dropped: "xmark.circle.fill"
        }
    }
}
