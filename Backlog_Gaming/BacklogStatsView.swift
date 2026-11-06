//
//  BacklogStatsView.swift
//  Backlog_Gaming
//

import SwiftUI

struct BacklogStatsView: View {
    @Environment(GameBacklogStore.self) private var store

    var body: some View {
        let s = store.counts()
        List {
            Section("По статусам") {
                // Те же значки и цвета, что у колонок канбана; вишлист — как бейдж на карточке.
                statRow(title: GameListSection.playing.header, value: s.playing, symbol: GameKanbanColumn.playing.symbolName, color: GameKanbanColumn.playing.accent)
                statRow(title: GameListSection.wishlist.header, value: s.wishlist, symbol: "star.fill", color: AppTheme.wishlist)
                statRow(title: GameListSection.queue.header, value: s.queue, symbol: GameKanbanColumn.backlog.symbolName, color: GameKanbanColumn.backlog.accent)
                statRow(title: GameListSection.completed.header, value: s.completed, symbol: GameKanbanColumn.completed.symbolName, color: GameKanbanColumn.completed.accent)
                statRow(title: GameListSection.dropped.header, value: s.dropped, symbol: GameKanbanColumn.dropped.symbolName, color: GameKanbanColumn.dropped.accent)
            }
            Section("Всего записей") {
                LabeledContent("Игр в списке", value: "\(s.total)")
            }
        }
        .navigationTitle("Статистика")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statRow(title: String, value: Int, symbol: String, color: Color) -> some View {
        LabeledContent {
            Text("\(value)")
                .monospacedDigit()
                .fontWeight(.medium)
        } label: {
            Label(title, systemImage: symbol)
                .foregroundStyle(color)
        }
    }
}

#Preview {
    NavigationStack {
        BacklogStatsView()
            .environment(GameBacklogStore.preview())
    }
}
