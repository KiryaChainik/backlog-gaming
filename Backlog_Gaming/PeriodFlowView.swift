//
//  PeriodFlowView.swift
//  Backlog_Gaming
//

import Combine
import SwiftUI
import UIKit

struct PeriodFlowView: View {
    @Environment(GameBacklogStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var grain: FlowPeriodGrain = .day
    /// Сдвиг от текущего периода: 0 — сегодня / эта неделя / этот месяц, −1 — предыдущий, +1 — следующий.
    @State private var periodOffset = 0
    /// «Сейчас» для потока. Обновляется после полуночи и при возврате в приложение, чтобы «Сегодня» не залипало.
    @State private var now = Date()
    @State private var taskSheet: TaskSheetPayload?

    private var interval: DateInterval? {
        GameFlowCalendar.interval(for: grain, offset: periodOffset, from: now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if store.entries.isEmpty {
                        ContentUnavailableView(
                            "Нет игр",
                            systemImage: "tray",
                            description: Text("Добавь игру на вкладке «Бэклог», затем назначь дела.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                    } else if let interval {
                        periodBlock(interval: interval)
                        overdueBlock
                        // «Скоро» — то, что идёт после выбранного периода; для прошедших периодов не нужно.
                        if interval.end > now {
                            upcomingBlock(after: interval.end)
                        }
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
            .onChange(of: grain) { _, _ in
                periodOffset = 0
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { now = Date() }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                now = Date()
            }
        }
    }

    // MARK: - Blocks (ScrollView: each task row is outside UITableViewCell — context menu targets one task)

    @ViewBuilder
    private func periodBlock(interval: DateInterval) -> some View {
        let dated = store.flowTasks(in: interval, now: now)
        VStack(alignment: .leading, spacing: 0) {
            periodHeader(interval: interval)
                .padding(.horizontal, 16)
            sectionCard {
                if dated.isEmpty {
                    Text("Нет дел в этот период.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    FlowTimelineList(
                        pairs: dated,
                        dateStyle: periodDateStyle,
                        orderingScope: .dated(interval, now: now),
                        onSelect: selectTask
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
        let overdue = store.overdueTasks(now: now)
        if !overdue.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Просрочено", color: .orange)
                    .padding(.horizontal, 16)
                sectionCard(accent: .orange) {
                    FlowTimelineList(
                        pairs: overdue,
                        dateStyle: .dayMonth,
                        orderingScope: .overdue(now: now),
                        onSelect: selectTask
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private func upcomingBlock(after date: Date) -> some View {
        let upcoming = store.upcomingTasks(after: date)
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Скоро")
                    .padding(.horizontal, 16)
                sectionCard {
                    FlowTimelineList(
                        pairs: upcoming,
                        dateStyle: .dayMonth,
                        orderingScope: .upcoming(after: date),
                        onSelect: selectTask
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
        let undated = store.undatedOpenTasks()
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Без даты")
                .padding(.horizontal, 16)
            sectionCard {
                if undated.isEmpty {
                    Text("Нет открытых дел без даты.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    FlowTimelineList(
                        pairs: undated,
                        dateStyle: .hidden,
                        orderingScope: .undated,
                        emphasizeUndated: true,
                        onSelect: selectTask
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
    }

    private func selectTask(gameId: UUID, taskId: UUID) {
        taskSheet = TaskSheetPayload(gameId: gameId, taskId: taskId)
    }

    private var periodDateStyle: FlowRowDateStyle {
        switch grain {
        case .day: .hidden
        case .week: .weekdayDayMonth
        case .month: .dayMonth
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

    /// Заголовок периода с листанием: «‹ ›» — соседние периоды, «Сегодня» — вернуться к текущему.
    private func periodHeader(interval: DateInterval) -> some View {
        HStack(spacing: 4) {
            Text(periodHeaderText(interval: interval))
                .textCase(nil)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 8)

            if periodOffset != 0 {
                Button("Сегодня") {
                    withAnimation(.snappy) { periodOffset = 0 }
                }
                .font(.subheadline.weight(.medium))
                .padding(.trailing, 4)
            }

            Button {
                withAnimation(.snappy) { periodOffset -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Предыдущий период")

            Button {
                withAnimation(.snappy) { periodOffset += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Следующий период")
        }
        .buttonStyle(.borderless)
        .padding(.top, 14)
        .padding(.bottom, 2)
    }

    // MARK: - Header formatting

    private func periodHeaderText(interval: DateInterval) -> String {
        let cal = Calendar.current
        switch grain {
        case .day:
            let day = interval.start
            let dm = AppDateFormatting.dayMonth(day)
            if cal.isDateInToday(day) { return "Сегодня, \(dm)" }
            if cal.isDateInTomorrow(day) { return "Завтра, \(dm)" }
            if cal.isDateInYesterday(day) { return "Вчера, \(dm)" }
            return capitalizedFirst(AppDateFormatting.weekdayDayMonth(day))
        case .week:
            let endDate = cal.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
            let range = compactRange(from: interval.start, to: endDate)
            switch periodOffset {
            case 0: return "Эта неделя, \(range)"
            case 1: return "Следующая, \(range)"
            case -1: return "Прошлая, \(range)"
            default: return range
            }
        case .month:
            return capitalizedFirst(AppDateFormatting.monthYear(interval.start))
        }
    }

    /// «2–8 ноя» в пределах месяца, иначе «30 ноя – 6 дек» — чтобы заголовок помещался рядом со стрелками.
    private func compactRange(from start: Date, to end: Date) -> String {
        let cal = Calendar.current
        if cal.isDate(start, equalTo: end, toGranularity: .month) {
            return "\(cal.component(.day, from: start))–\(AppDateFormatting.dayMonth(end))"
        }
        return "\(AppDateFormatting.dayMonth(start)) – \(AppDateFormatting.dayMonth(end))"
    }

    private func capitalizedFirst(_ s: String) -> String {
        s.prefix(1).uppercased() + s.dropFirst()
    }
}

#Preview {
    PeriodFlowView()
        .environment(GameBacklogStore.preview())
}
