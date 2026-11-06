//
//  Backlog_GamingApp.swift
//  Backlog_Gaming
//
//  Created by Кирилл Пантюхов on 31.03.2026.
//

import SwiftUI

@main
struct Backlog_GamingApp: App {
    @State private var backlogStore = GameBacklogStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(backlogStore)
        }
    }
}

#Preview("Backlog Gaming") {
    MainTabView()
        .environment(GameBacklogStore.preview())
}
