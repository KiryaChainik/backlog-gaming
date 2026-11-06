//
//  TaskNoteFormatting.swift
//  Backlog_Gaming
//

import SwiftUI

enum TaskNoteFormatting {
    /// Отображение заметки дела с поддержкой базового Markdown (жирный, курсив, списки, ссылки, абзацы).
    static func text(from source: String) -> Text {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return Text("") }

        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .full

        if let attributed = try? AttributedString(markdown: source, options: options) {
            return Text(attributed)
        }
        return Text(source)
    }
}
