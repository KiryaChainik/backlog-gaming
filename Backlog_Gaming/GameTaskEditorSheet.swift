//
//  GameTaskEditorSheet.swift
//  Backlog_Gaming
//

import SwiftUI

struct TaskSheetPayload: Identifiable, Hashable {
    let id: UUID
    let gameId: UUID
    let taskId: UUID?
    /// Только для нового дела (`taskId == nil`): подставить текст из быстрого ввода.
    var prefillTitle: String?

    init(gameId: UUID, taskId: UUID?, prefillTitle: String? = nil) {
        self.gameId = gameId
        self.taskId = taskId
        self.prefillTitle = prefillTitle
        self.id = taskId ?? UUID()
    }
}

struct GameTaskEditorSheet: View {
    @Environment(GameBacklogStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let payload: TaskSheetPayload

    @State private var draft = GameTask(title: "")
    @State private var hasDueDate = false

    private var isEditing: Bool { payload.taskId != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Дело") {
                    TextField("Название", text: $draft.title)
                        .textInputAutocapitalization(.sentences)

                    Picker("Тип", selection: $draft.kind) {
                        ForEach(GameTaskKind.allCases, id: \.self) { k in
                            Text(k.shortTitle).tag(k)
                        }
                    }
                }

                Section {
                    TextEditor(text: $draft.note)
                        .frame(minHeight: 120)
                } header: {
                    Text("Заметка")
                } footer: {
                    Text("Markdown: **жирный**, *курсив*, маркированные списки (`-` или `*`), нумерация, [ссылка](https://…)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Вид в потоке") {
                    SymbolColorPicker(
                        symbols: GameTaskVisual.editorSymbols,
                        symbol: Binding(get: { draft.displaySymbolName }, set: { draft.symbolName = $0 }),
                        accentIndex: $draft.accentIndex
                    )
                }

                Section("Срок") {
                    Toggle("Указать дату", isOn: $hasDueDate)
                        .onChange(of: hasDueDate) { _, on in
                            if on && draft.dueDate == nil {
                                draft.dueDate = .now
                            }
                        }
                    if hasDueDate {
                        DatePicker(
                            "Дата",
                            selection: Binding(
                                get: { draft.dueDate ?? .now },
                                set: { draft.dueDate = $0 }
                            ),
                            displayedComponents: draft.includesTime ? [.date, .hourAndMinute] : [.date]
                        )
                        Toggle("Со временем", isOn: $draft.includesTime)
                    }
                }

                Section {
                    Toggle("Выполнено", isOn: $draft.isDone)
                }
            }
            .navigationTitle(isEditing ? "Дело" : "Новое дело")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        if let tid = payload.taskId,
           let g = store.entry(id: payload.gameId),
           let t = g.tasks.first(where: { $0.id == tid }) {
            draft = t
            hasDueDate = t.dueDate != nil
        } else {
            let initial = (payload.prefillTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            draft = GameTask(title: initial, kind: .todo)
            hasDueDate = false
        }
    }

    private func save() {
        if !hasDueDate {
            draft.dueDate = nil
            draft.includesTime = false
        }
        if payload.taskId != nil {
            store.updateTask(gameId: payload.gameId, task: draft)
        } else {
            store.addTask(gameId: payload.gameId, task: draft)
        }
        dismiss()
    }
}

#Preview {
    GameTaskEditorSheet(payload: TaskSheetPayload(gameId: UUID(), taskId: nil))
        .environment(GameBacklogStore.preview())
}
