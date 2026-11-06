//
//  GameTaskVisual.swift
//  Backlog_Gaming
//

import SwiftUI

enum GameTaskVisual {
    nonisolated static let accentCount = 20

    static var accentPalette: [Color] {
        [
            Color(red: 0.45, green: 0.74, blue: 0.78),
            Color(red: 0.57, green: 0.81, blue: 0.63),
            Color(red: 0.95, green: 0.71, blue: 0.46),
            Color(red: 0.63, green: 0.73, blue: 0.55),
            Color(red: 0.80, green: 0.56, blue: 0.62),
            Color(red: 0.64, green: 0.62, blue: 0.85),
            Color(red: 0.86, green: 0.66, blue: 0.82),
            Color(red: 0.73, green: 0.77, blue: 0.91),
            Color(red: 0.62, green: 0.84, blue: 0.84),
            Color(red: 0.78, green: 0.85, blue: 0.62),
            Color(red: 0.95, green: 0.77, blue: 0.62),
            Color(red: 0.90, green: 0.68, blue: 0.52),
            Color(red: 0.76, green: 0.66, blue: 0.56),
            Color(red: 0.71, green: 0.78, blue: 0.70),
            Color(red: 0.70, green: 0.68, blue: 0.88),
            Color(red: 0.89, green: 0.76, blue: 0.90),
            Color(red: 0.70, green: 0.78, blue: 0.84),
            Color(red: 0.83, green: 0.72, blue: 0.62),
            Color(red: 0.86, green: 0.82, blue: 0.68),
            Color(red: 0.67, green: 0.74, blue: 0.76),
        ]
    }

    static func accentColor(at index: Int) -> Color {
        let palette = accentPalette
        guard !palette.isEmpty else { return .accentColor }
        let i = ((index % palette.count) + palette.count) % palette.count
        return palette[i]
    }

    nonisolated static let quickSymbolRotation: [String] = [
        "checkmark.circle", "gamecontroller.fill", "flag.fill", "star.fill",
        "bolt.fill", "map.fill", "bookmark.fill", "target",
    ]

    nonisolated static func quickPreset(taskIndex: Int, kind: GameTaskKind) -> (symbolName: String, accentIndex: Int) {
        let sym = kind == .milestone
            ? GameTask.defaultSymbol(for: .milestone)
            : quickSymbolRotation[taskIndex % quickSymbolRotation.count]
        let ai = taskIndex % accentCount
        return (sym, ai)
    }

    static let editorSymbols: [String] = [
        "checkmark.circle", "circle.fill", "flag.fill", "star.fill", "bolt.fill",
        "target", "clock.fill", "alarm.fill", "calendar", "calendar.badge.clock",
        "bookmark.fill", "tag.fill", "list.bullet.clipboard", "checklist", "note.text",
        "pencil", "square.and.pencil", "sparkles", "exclamationmark.triangle.fill", "bell.fill",
        "gamecontroller.fill", "dpad.fill", "dice.fill", "puzzlepiece.fill", "map.fill",
        "location.fill", "figure.run", "trophy.fill", "rosette", "crown.fill",
        "flame.fill", "flag.2.crossed.fill", "shield.fill", "medal.fill", "hourglass",
    ]

    static let editorGameSymbols: [String] = [
        "gamecontroller.fill", "dpad.fill", "playstation.logo", "xbox.logo", "pc",
        "trophy.fill", "rosette", "crown.fill", "medal.fill", "star.fill",
        "flag.fill", "target", "scope", "map.fill", "location.fill",
        "puzzlepiece.fill", "dice.fill", "car.fill", "airplane", "sailboat.fill",
        "shield.fill", "flag.2.crossed.fill", "flame.fill", "bolt.fill", "sparkles",
        "checkmark.seal.fill", "clock.fill", "hourglass", "bookmark.fill", "tag.fill",
        "book.fill", "books.vertical.fill", "headphones", "cpu.fill", "antenna.radiowaves.left.and.right",
    ]
}

extension GameTask {
    var displaySymbolName: String {
        symbolName.isEmpty ? Self.defaultSymbol(for: kind) : symbolName
    }
}
