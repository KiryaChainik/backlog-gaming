//
//  FlowTimelineViews.swift
//  Backlog_Gaming
//

import SwiftUI

/// Как показывать дату в строке потока (зависит от блока и масштаба периода).
enum FlowRowDateStyle {
    /// Дата понятна из заголовка (режим «День») или её нет.
    case hidden
    /// «понедельник, 3 ноя» — для недели.
    case weekdayDayMonth
    /// «3 ноя» (с годом, если не текущий) — для месяца, просроченных и будущих дел.
    case dayMonth
}

struct FlowTimelineList: View {
    let pairs: [(game: GameEntry, task: GameTask)]
    let dateStyle: FlowRowDateStyle
    let orderingScope: FlowOrderingScope
    var emphasizeUndated: Bool = false
    var onSelect: (UUID, UUID) -> Void

    @Environment(GameBacklogStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(pairs.enumerated()), id: \.element.task.id) { index, pair in
                FlowTimelineRow(
                    pair: pair,
                    dateStyle: dateStyle,
                    emphasizeUndated: emphasizeUndated,
                    // Ручной порядок — только внутри одного дня (порядок дней задаёт дата).
                    canMoveUp: index > 0
                        && GameBacklogStore.sameFlowDay(pairs[index - 1].task, pair.task),
                    canMoveDown: index < pairs.count - 1
                        && GameBacklogStore.sameFlowDay(pair.task, pairs[index + 1].task),
                    orderingScope: orderingScope,
                    isLast: index == pairs.count - 1,
                    onSelect: { onSelect(pair.game.id, pair.task.id) },
                    onToggle: {
                        withAnimation(.snappy) {
                            store.toggleTaskDone(gameId: pair.game.id, taskId: pair.task.id)
                        }
                    }
                )
            }
        }
        // Strictly uniform top inset for any section size (1 or many items).
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FlowTimelineRow: View {
    @Environment(GameBacklogStore.self) private var store

    let pair: (game: GameEntry, task: GameTask)
    let dateStyle: FlowRowDateStyle
    var emphasizeUndated: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let orderingScope: FlowOrderingScope
    let isLast: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void

    private var taskColor: Color {
        GameTaskVisual.accentColor(at: pair.task.accentIndex)
    }

    var body: some View {
        // Same leading layout as `gameTaskRow` in GamesTabView: timeline column first, no extra time gutter.
        HStack(alignment: .top, spacing: 10) {
            TaskTimelineNode(
                symbolName: pair.task.displaySymbolName,
                color: taskColor,
                isDone: pair.task.isDone,
                isLast: isLast
            )

            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pair.task.title)
                        .font(.body)
                        .foregroundStyle(pair.task.isDone ? .secondary : .primary)
                        .strikethrough(pair.task.isDone, color: .secondary)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 4) {
                        Text(pair.game.title)
                            .foregroundStyle(.secondary)
                        if pair.task.includesTime, let d = pair.task.dueDate {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(AppDateFormatting.timeOnly(d))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if let sub = subtitleDate {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(sub)
                                .foregroundStyle(.secondary)
                        }
                        if pair.task.dueDate == nil && emphasizeUndated {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text("без даты")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .font(.caption)
                    .lineLimit(1)

                    if !pair.task.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        TaskNoteFormatting.text(from: pair.task.note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(5)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button(action: onToggle) {
                Image(systemName: pair.task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(pair.task.isDone ? taskColor : .secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(pair.task.isDone ? "Отметить невыполненным" : "Отметить выполненным")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Full-row hit target so long-press isn’t ambiguous; must stay per-row (not one List cell for all tasks).
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onSelect()
            } label: {
                Label("Редактировать", systemImage: "pencil")
            }
            if canMoveUp {
                Button {
                    store.flowMoveTaskUp(gameId: pair.game.id, taskId: pair.task.id, scope: orderingScope)
                } label: {
                    Label("Вверх", systemImage: "arrow.up")
                }
            }
            if canMoveDown {
                Button {
                    store.flowMoveTaskDown(gameId: pair.game.id, taskId: pair.task.id, scope: orderingScope)
                } label: {
                    Label("Вниз", systemImage: "arrow.down")
                }
            }
            Button {
                onToggle()
            } label: {
                Label(pair.task.isDone ? "Открыть снова" : "Выполнено", systemImage: "checkmark.circle")
            }
            Button(role: .destructive) {
                store.deleteTask(gameId: pair.game.id, taskId: pair.task.id)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }

    private var subtitleDate: String? {
        guard let d = pair.task.dueDate else { return nil }
        switch dateStyle {
        case .hidden:
            return nil
        case .weekdayDayMonth:
            return AppDateFormatting.weekdayDayMonth(d)
        case .dayMonth:
            return Calendar.current.isDate(d, equalTo: Date(), toGranularity: .year)
                ? AppDateFormatting.dayMonth(d)
                : AppDateFormatting.abbreviated(d)
        }
    }
}
