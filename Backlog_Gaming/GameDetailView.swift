//
//  GameDetailView.swift
//  Backlog_Gaming
//

import SwiftUI

struct GameDetailView: View {
    @Environment(GameBacklogStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GameEntry
    @State private var original: GameEntry
    @State private var taskSheet: TaskSheetPayload?
    private let entryId: UUID

    init(entry: GameEntry) {
        entryId = entry.id
        _draft = State(initialValue: entry)
        _original = State(initialValue: entry)
    }

    private var hasChanges: Bool {
        draft.title != original.title
            || draft.status != original.status
            || draft.platform != original.platform
            || draft.wishlist != original.wishlist
            || draft.symbolName != original.symbolName
            || draft.accentIndex != original.accentIndex
            || draft.note != original.note
    }

    var body: some View {
        Form {
            Section("Название") {
                TextField("Название", text: $draft.title)
                    .textInputAutocapitalization(.sentences)
            }

            Section("Статус") {
                Picker("Статус", selection: $draft.status) {
                    ForEach(GameStatus.allCases, id: \.self) { s in
                        Text(s.shortTitle).tag(s)
                    }
                }
            }

            Section("Платформа") {
                Picker("Платформа", selection: $draft.platform) {
                    ForEach(GamePlatform.allCases, id: \.self) { p in
                        Text(p.shortTitle).tag(p)
                    }
                }
            }

            Section {
                Toggle("Вишлист", isOn: $draft.wishlist)
                    .disabled(draft.status != .queued)
            } footer: {
                if draft.status != .queued {
                    Text("Вишлист только для игр в очереди.")
                }
            }

            Section("Иконка и цвет") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                    ForEach(GameTaskVisual.editorGameSymbols, id: \.self) { sym in
                        Button {
                            draft.symbolName = sym
                        } label: {
                            Image(systemName: sym)
                                .font(.title3)
                                .foregroundStyle(sym == draft.displaySymbolName ? Color.white : Color.primary)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(sym == draft.displaySymbolName
                                            ? GameTaskVisual.accentColor(at: draft.accentIndex)
                                            : Color.secondary.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0 ..< GameTaskVisual.accentCount, id: \.self) { i in
                            Button {
                                draft.accentIndex = i
                            } label: {
                                Circle()
                                    .fill(GameTaskVisual.accentColor(at: i))
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if draft.accentIndex == i {
                                            Circle().strokeBorder(Color.primary, lineWidth: 2)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
            }

            Section("Заметка") {
                TextEditor(text: $draft.note)
                    .frame(minHeight: 120)
            }

            tasksSection

            if draft.status == .completed {
                Section("Завершение") {
                    if let at = draft.completedAt {
                        Text(AppDateFormatting.abbreviated(at))
                    } else {
                        Text("Дата неизвестна (импорт или старая запись)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Игра")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") {
                    saveDraft()
                    dismiss()
                }
                .bold()
                .disabled(!hasChanges)
            }
            ToolbarItem(placement: .cancellationAction) {
                if hasChanges {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let latest = store.entry(id: entryId) {
                draft = latest
                original = latest
            }
        }
        .sheet(item: $taskSheet) { payload in
            GameTaskEditorSheet(payload: payload)
                .environment(store)
        }
    }

    // MARK: - Tasks section

    @ViewBuilder
    private var tasksSection: some View {
        Section("Дела в игре") {
            if draft.tasks.isEmpty {
                Text("Пока нет дел. Добавь на вкладке «Бэклог».")
                    .foregroundStyle(.secondary)
            } else {
                let tasks = store.entry(id: entryId)?.tasks ?? draft.tasks
                let open = tasks.filter { !$0.isDone }.count
                Text("Всего: \(tasks.count), открыто: \(open)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(tasks) { t in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(GameTaskVisual.accentColor(at: t.accentIndex).opacity(t.isDone ? 0.45 : 0.92))
                            .frame(width: 22, height: 22)
                            .overlay {
                                Image(systemName: t.displaySymbolName)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(t.title)
                                .strikethrough(t.isDone, color: .secondary)
                                .foregroundStyle(t.isDone ? .secondary : .primary)
                            if !t.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                TaskNoteFormatting.text(from: t.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }

                        Spacer(minLength: 0)

                        Button {
                            store.toggleTaskDone(gameId: entryId, taskId: t.id)
                        } label: {
                            Image(systemName: t.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(t.isDone ? .green : .secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .contextMenu {
                        Button {
                            taskSheet = TaskSheetPayload(gameId: entryId, taskId: t.id)
                        } label: {
                            Label("Редактировать", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            store.deleteTask(gameId: entryId, taskId: t.id)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func saveDraft() {
        var toSave = draft
        if let latestTasks = store.entry(id: entryId)?.tasks {
            toSave.tasks = latestTasks
        }
        store.updateEntry(toSave)
    }
}

#Preview {
    NavigationStack {
        GameDetailView(
            entry: GameEntry(title: "Outer Wilds", status: .playing, platform: .pc)
        )
        .environment(GameBacklogStore())
    }
}
