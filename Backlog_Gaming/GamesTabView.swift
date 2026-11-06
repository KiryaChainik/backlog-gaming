//
//  GamesTabView.swift
//  Backlog_Gaming
//

import SwiftUI
import UIKit

struct GamesTabView: View {
    @Environment(GameBacklogStore.self) private var store
    @Binding var path: NavigationPath
    @Binding var showAddSheet: Bool

    @State private var expandedGameIDs: Set<UUID> = []
    @State private var dropTargetColumn: GameKanbanColumn?

    @State private var newTitle = ""
    @State private var newPlatform: GamePlatform = .unspecified
    @State private var newWishlist = false
    @State private var newSymbolName = GameEntry.defaultSymbol
    @State private var newAccentIndex = 0
    @State private var searchText = ""
    @State private var platformFilter: GamePlatform?
    @State private var taskSheet: TaskSheetPayload?
    @State private var quickAddByGame: [UUID: String] = [:]
    @State private var gameToDelete: GameEntry?
    @FocusState private var addFieldFocused: Bool

    private func filteredEntries(for column: GameKanbanColumn) -> [GameEntry] {
        let base = store.entries(forKanban: column, search: searchText)
        guard let pf = platformFilter else { return base }
        return base.filter { $0.platform == pf }
    }

    private var searchShowsNoResults: Bool {
        !store.entries.isEmpty
            && GameKanbanColumn.allCases.allSatisfy { filteredEntries(for: $0).isEmpty }
    }

    var body: some View {
        listContent
            .overlay(alignment: .bottomTrailing) {
                // Кнопка живёт на корневом экране стека: при переходе в игру/статистику она уходит вместе с ним.
                addButton
            }
            .navigationTitle("Бэклог")
            .searchable(text: $searchText, prompt: "Поиск")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(value: BacklogRoute.stats) {
                        Image(systemName: "chart.bar")
                            .font(.title3.weight(.medium))
                    }
                    .accessibilityLabel("Статистика")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            platformFilter = nil
                        } label: {
                            if platformFilter == nil {
                                Label("Все платформы", systemImage: "checkmark")
                            } else {
                                Text("Все платформы")
                            }
                        }
                        Divider()
                        ForEach(GamePlatform.allCases.filter { $0 != .unspecified }, id: \.self) { p in
                            Button {
                                platformFilter = p
                            } label: {
                                if platformFilter == p {
                                    Label(p.shortTitle, systemImage: "checkmark")
                                } else {
                                    Text(p.shortTitle)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: platformFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                            .font(.title3.weight(.medium))
                    }
                    .accessibilityLabel("Фильтр платформы")
                }
            }
            .onChange(of: showAddSheet) { _, show in
                if show {
                    newTitle = ""
                    newPlatform = .unspecified
                    newWishlist = false
                    newSymbolName = GameEntry.defaultSymbol
                    newAccentIndex = 0
                }
            }
            .sheet(isPresented: $showAddSheet, onDismiss: { addFieldFocused = false }) {
                addGameSheet
            }
            .sheet(item: $taskSheet) { payload in
                GameTaskEditorSheet(payload: payload)
                    .environment(store)
            }
            .navigationDestination(for: BacklogRoute.self) { route in
                switch route {
                case .stats: BacklogStatsView()
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let entry = store.entry(id: id) {
                    GameDetailView(entry: entry)
                } else {
                    ContentUnavailableView("Запись удалена", systemImage: "trash")
                }
            }
            .confirmationDialog(
                "Удалить «\(gameToDelete?.title ?? "")» и все дела?",
                isPresented: Binding(
                    get: { gameToDelete != nil },
                    set: { if !$0 { gameToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    if let game = gameToDelete {
                        withAnimation { store.deleteEntry(id: game.id) }
                    }
                    gameToDelete = nil
                }
                Button("Отмена", role: .cancel) {
                    gameToDelete = nil
                }
            }
    }

    // MARK: - List content

    @ViewBuilder
    private var listContent: some View {
        if store.entries.isEmpty {
            ContentUnavailableView(
                "Пустой бэклог",
                systemImage: "tray",
                description: Text("Нажми «+», чтобы занести первую игру.")
            )
        } else if searchShowsNoResults {
            ContentUnavailableView(
                "Ничего не найдено",
                systemImage: "magnifyingglass",
                description: Text("Попробуй другой запрос.")
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(GameKanbanColumn.allCases) { column in
                        kanbanColumnView(column)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .contentMargins(.bottom, 80, for: .scrollContent)
        }
    }

    private var addButton: some View {
        Button {
            showAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Circle().fill(AppTheme.accent))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        }
        .accessibilityLabel("Добавить игру")
        .padding(.trailing, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Kanban column

    @ViewBuilder
    private func kanbanColumnView(_ column: GameKanbanColumn) -> some View {
        let items = filteredEntries(for: column)
        let highlighted = dropTargetColumn == column

        VStack(alignment: .leading, spacing: 8) {
            kanbanColumnHeader(column: column, count: items.count)

            VStack(spacing: 6) {
                if items.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "tray")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                } else {
                    ForEach(items) { entry in
                        kanbanCard(entry)
                            .draggable(entry.id.uuidString) {
                                Text(entry.title)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(2)
                                    .padding(12)
                                    .frame(maxWidth: 260)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial))
                            }
                            .contextMenu {
                                Button {
                                    path.append(entry.id)
                                } label: {
                                    Label("Редактировать", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    gameToDelete = entry
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        highlighted ? column.accent : column.accent.opacity(0.15),
                        lineWidth: highlighted ? 2.5 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .dropDestination(for: String.self) { items, _ in
                guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
                let ok = store.moveEntryToKanban(id: id, column: column)
                if !ok {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
                return ok
            } isTargeted: { over in
                dropTargetColumn = over ? column : (dropTargetColumn == column ? nil : dropTargetColumn)
            }
            .animation(.easeInOut(duration: 0.15), value: highlighted)
        }
    }

    private func kanbanColumnHeader(column: GameKanbanColumn, count: Int) -> some View {
        HStack {
            Image(systemName: column.symbolName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(column.accent.opacity(0.82))
                .frame(width: 22)
            Text(column.title)
                .font(.title2.weight(.bold))
            Spacer(minLength: 8)
            if column == .playing {
                Text("\(count)/\(GameBacklogStore.maxPlayingGames)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(count >= GameBacklogStore.maxPlayingGames ? .orange : .secondary)
            } else {
                Text("\(count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Kanban card

    @ViewBuilder
    private func kanbanCard(_ entry: GameEntry) -> some View {
        let expanded = expandedGameIDs.contains(entry.id)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        if expanded { expandedGameIDs.remove(entry.id) }
                        else { expandedGameIDs.insert(entry.id) }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(GameTaskVisual.accentColor(at: entry.accentIndex).opacity(0.92))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: entry.displaySymbolName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(entry.title)
                                    .font(.body)
                                    .foregroundStyle(entry.status == .completed ? .secondary : .primary)
                                    .strikethrough(entry.status == .completed || entry.status == .dropped, color: .secondary)
                                    .lineLimit(expanded ? nil : 2)
                                if !entry.note.isEmpty {
                                    Image(systemName: "doc.text")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            let isWishlist = entry.wishlist && entry.status == .queued
                            if entry.platform != .unspecified || isWishlist {
                                HStack(spacing: 6) {
                                    if entry.platform != .unspecified {
                                        Text(entry.platform.shortTitle)
                                    }
                                    if isWishlist {
                                        // Тот же значок и цвет, что у «Вишлиста» в статистике.
                                        Label("Вишлист", systemImage: "star.fill")
                                            .foregroundStyle(AppTheme.wishlist)
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            if !entry.tasks.isEmpty {
                                let open = entry.tasks.filter { !$0.isDone }.count
                                Text(open == 0 ? "Все дела закрыты" : "Открытых дел: \(open)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        Spacer(minLength: 4)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                            .animation(.snappy(duration: 0.2), value: expanded)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if expanded {
                Divider()

                if entry.tasks.isEmpty {
                    Text("Нет дел — добавь первое.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(entry.tasks.enumerated()), id: \.element.id) { idx, task in
                        gameTaskRow(
                            game: entry,
                            task: task,
                            isLast: idx == entry.tasks.count - 1
                        )
                    }
                }

                gameQuickAddRow(entry: entry)

                if !entry.tasks.isEmpty
                    && entry.tasks.allSatisfy(\.isDone)
                    && entry.status != .completed {
                    Button {
                        var updated = entry
                        updated.status = .completed
                        store.updateEntry(updated)
                    } label: {
                        Label("Все дела закрыты — в Пройдено?", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(GameTaskVisual.accentColor(at: entry.accentIndex).opacity(0.35))
                .frame(width: 3)
                .padding(.vertical, 8)
        }
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    // MARK: - Task rows

    private func gameQuickAddRow(entry: GameEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "text.badge.plus")
                    .font(.body)
                    .foregroundStyle(GameTaskVisual.accentColor(at: entry.tasks.count))
                    .frame(width: 32)
                TextField("Новое дело…", text: quickAddBinding(for: entry.id))
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .onSubmit { commitQuickAdd(gameId: entry.id) }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func gameTaskRow(game: GameEntry, task: GameTask, isLast: Bool) -> some View {
        let color = GameTaskVisual.accentColor(at: task.accentIndex)
        let taskIndex = game.tasks.firstIndex(where: { $0.id == task.id })

        HStack(alignment: .top, spacing: 10) {
            TaskTimelineNode(
                symbolName: task.displaySymbolName,
                color: color,
                isDone: task.isDone,
                isLast: isLast
            )

            Button {
                taskSheet = TaskSheetPayload(gameId: game.id, taskId: task.id)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.body)
                        .strikethrough(task.isDone, color: .secondary)
                        .foregroundStyle(task.isDone ? .secondary : .primary)
                    if let d = task.dueDate {
                        Text(AppDateFormatting.abbreviated(d, includesTime: task.includesTime))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !task.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        TaskNoteFormatting.text(from: task.note)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            if !task.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Image(systemName: "note.text")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Есть заметка")
            }

            Button {
                store.toggleTaskDone(gameId: game.id, taskId: task.id)
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isDone ? color : .secondary)
            }
            .buttonStyle(.borderless)
        }
        .contextMenu {
            Button {
                taskSheet = TaskSheetPayload(gameId: game.id, taskId: task.id)
            } label: {
                Label("Редактировать", systemImage: "pencil")
            }
            if let idx = taskIndex, idx > 0 {
                Button {
                    store.moveTaskUp(gameId: game.id, taskId: task.id)
                } label: {
                    Label("Вверх", systemImage: "arrow.up")
                }
            }
            if let idx = taskIndex, idx < game.tasks.count - 1 {
                Button {
                    store.moveTaskDown(gameId: game.id, taskId: task.id)
                } label: {
                    Label("Вниз", systemImage: "arrow.down")
                }
            }
            Button(role: .destructive) {
                store.deleteTask(gameId: game.id, taskId: task.id)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    private func quickAddBinding(for gameId: UUID) -> Binding<String> {
        Binding(
            get: { quickAddByGame[gameId] ?? "" },
            set: { quickAddByGame[gameId] = $0 }
        )
    }

    private func commitQuickAdd(gameId: UUID) {
        let raw = (quickAddByGame[gameId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let entry = store.entry(id: gameId) else { return }
        let preset = GameTaskVisual.quickPreset(taskIndex: entry.tasks.count, kind: .todo)
        let task = GameTask(
            title: raw,
            kind: .todo,
            symbolName: preset.symbolName,
            accentIndex: preset.accentIndex
        )
        store.addTask(gameId: gameId, task: task)
        quickAddByGame[gameId] = ""
    }

    // MARK: - Add game sheet

    private var addGameSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название игры", text: $newTitle)
                        .focused($addFieldFocused)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .onSubmit { confirmAddGame() }
                    Picker("Платформа", selection: $newPlatform) {
                        ForEach(GamePlatform.allCases, id: \.self) { p in
                            Text(p.shortTitle).tag(p)
                        }
                    }
                    Toggle("Вишлист (ещё нет в коллекции)", isOn: $newWishlist)
                }

                Section("Иконка и цвет") {
                    SymbolColorPicker(symbols: GameTaskVisual.editorGameSymbols, symbol: $newSymbolName, accentIndex: $newAccentIndex)
                }
            }
            .navigationTitle("Новая игра")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { showAddSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") { confirmAddGame() }
                        .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { addFieldFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func confirmAddGame() {
        store.addEntry(title: newTitle, platform: newPlatform, wishlist: newWishlist, symbolName: newSymbolName, accentIndex: newAccentIndex)
        showAddSheet = false
    }
}

/// Маршруты стека «Бэклог», кроме экрана игры (он открывается по `UUID`).
enum BacklogRoute: Hashable {
    case stats
}

#Preview {
    @Previewable @State var path = NavigationPath()
    @Previewable @State var showAdd = false
    NavigationStack(path: $path) {
        GamesTabView(path: $path, showAddSheet: $showAdd)
            .environment(GameBacklogStore.preview())
    }
}
