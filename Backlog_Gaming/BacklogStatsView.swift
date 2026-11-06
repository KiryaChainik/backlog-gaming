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
                statRow(title: GameListSection.playing.header, value: s.playing, symbol: "gamecontroller.fill", color: .blue)
                statRow(title: GameListSection.wishlist.header, value: s.wishlist, symbol: "star.fill", color: .orange)
                statRow(title: GameListSection.queue.header, value: s.queue, symbol: "tray.full.fill", color: .purple)
                statRow(title: GameListSection.completed.header, value: s.completed, symbol: "checkmark.circle.fill", color: .green)
                statRow(title: GameListSection.dropped.header, value: s.dropped, symbol: "xmark.circle.fill", color: .secondary)
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
            .environment(GameBacklogStore())
    }
}
