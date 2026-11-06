//
//  MainTabView.swift
//  Backlog_Gaming
//

import SwiftUI

struct MainTabView: View {
    @Environment(GameBacklogStore.self) private var store
    @State private var gamesPath = NavigationPath()
    @State private var isAddingGame = false
    @State private var selectedTab = 0
    private let playingAccent = Color(red: 0.38, green: 0.66, blue: 0.84)

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $gamesPath) {
                GamesTabView(path: $gamesPath, showAddSheet: $isAddingGame)
            }
            .environment(store)
            .tabItem {
                Label("Бэклог", systemImage: "tray.full.fill")
            }
            .tag(0)

            PeriodFlowView()
                .environment(store)
                .tabItem {
                    Label("Поток", systemImage: "calendar.day.timeline.left")
                }
                .tag(1)

            NavigationStack {
                SettingsPlaceholderView()
            }
            .tabItem {
                Label("Настройки", systemImage: "gearshape.fill")
            }
            .tag(2)
        }
        .tint(playingAccent)
        .overlay(alignment: .bottomTrailing) {
            if selectedTab == 0 {
                addButton
            }
        }
        .alert(
            "Проблема с данными",
            isPresented: Binding(
                get: { store.storageIssue != nil },
                set: { if !$0 { store.dismissStorageIssue() } }
            ),
            presenting: store.storageIssue
        ) { _ in
            Button("Понятно", role: .cancel) { store.dismissStorageIssue() }
        } message: { issue in
            Text(issue.message)
        }
    }

    private var addButton: some View {
        Button {
            isAddingGame = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Circle().fill(playingAccent))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 64)
    }
}

struct SettingsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Настройки",
            systemImage: "gearshape",
            description: Text("Здесь будут настройки приложения.")
        )
        .navigationTitle("Настройки")
    }
}

#Preview {
    MainTabView()
        .environment(GameBacklogStore())
}
