//
//  PeriodFlowView.swift
//  Backlog_Gaming
//

import SwiftUI

struct PeriodFlowView: View {
    @Environment(GameBacklogStore.self) private var store
    @State private var grain: FlowPeriodGrain = .day
    @State private var taskSheet: TaskSheetPayload?

    private var interval: DateInterval? {
        GameFlowCalendar.interval(for: grain, containing: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if store.entries.isEmpty {
                        ContentUnavailableView(
                            "Нет игр",
                            systemImage: "tray",
                            description: Text("Добавь игру на вкладке «Игры», затем назначь дела.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                    } else if let interval {
                        periodBlock(interval: interval)
                        overdueBlock
                        undatedBlock
                    } else {
                        ContentUnavailableView(
                            "Период недоступен",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("Не удалось вычислить интервал для выбранной даты.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.secondarySystemGroupedBackground))
            .navigationTitle("Поток")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Период", selection: $grain) {
                        ForEach(FlowPeriodGrain.allCases) { g in
                            Text(g.title).tag(g)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }
            }
            .sheet(item: $taskSheet) { payload in
                GameTaskEditorSheet(payload: payload)
                    .environment(store)
            }
        }
    }

    // MARK: - Blocks (ScrollView: each task row is outside UITableViewCell — context menu targets one task)

    @ViewBuilder
    private func periodBlock(interval: DateInterval) -> some View {
        let dated = store.openTasks(withDueDateIn: interval)
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(periodHeaderText(interval: interval))
                .padding(.horizontal, 16)
            sectionCard {
                if dated.isEmpty {
                    Text("Нет открытых дел в этот период.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    FlowTimelineList(
                        pairs: dated,
                        grain: grain,
                        orderingScope: .dated(interval),
                        onSelect: { gameId, taskId in
                            taskSheet = TaskSheetPayload(gameId: gameId, taskId: taskId)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var overdueBlock: some View {
        let overdue = store.openOverdueTasks()
        if !overdue.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Просрочено", color: .orange)
                    .padding(.horizontal, 16)
                sectionCard(accent: .orange) {
                    FlowTimelineList(
                        pairs: overdue,
                        grain: grain,
                        orderingScope: .overdue,
                        onSelect: { gameId, taskId in
                            taskSheet = TaskSheetPayload(gameId: gameId, taskId: taskId)
                        }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var undatedBlock: some View {
        let undated = store.openUndatedTasks()
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Без даты")
                .padding(.horizontal, 16)
            sectionCard {
                if undated.isEmpty {
                    Text("Все открытые дела с датой или их нет.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    FlowTimelineList(
                        pairs: undated,
                        grain: grain,
                        orderingScope: .undated,
                        emphasizeUndated: true,
                        onSelect: { gameId, taskId in
                            taskSheet = TaskSheetPayload(gameId: gameId, taskId: taskId)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
    }

    private func sectionCard<Content: View>(accent: Color = .secondary, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(accent.opacity(0.22), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sectionHeader(_ title: String, color: Color = .secondary) -> some View {
        Text(title)
            .textCase(nil)
            .font(.title3.weight(.semibold))
            .foregroundStyle(color)
            .padding(.top, 14)
            .padding(.bottom, 2)
    }

    // MARK: - Header formatting

    private func periodHeaderText(interval: DateInterval) -> String {
        let cal = Calendar.current
        switch grain {
        case .day:
            if cal.isDateInToday(interval.start) {
                return "Сегодня, \(AppDateFormatting.dayMonth(interval.start))"
            }
            return AppDateFormatting.weekdayDayMonth(interval.start)
        case .week:
            let startStr = AppDateFormatting.dayMonth(interval.start)
            let endDate = cal.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
            let endStr = AppDateFormatting.dayMonth(endDate)
            return "Эта неделя, \(startStr) – \(endStr)"
        case .month:
            return AppDateFormatting.monthYear(interval.start)
        }
    }
}

#Preview {
    PeriodFlowView()
        .environment(GameBacklogStore())
}
