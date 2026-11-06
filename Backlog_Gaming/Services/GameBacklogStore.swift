//
//  GameBacklogStore.swift
//  Backlog_Gaming
//

import Foundation
import Observation
import os

// MARK: - Поток дел

enum FlowPeriodGrain: String, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: "День"
        case .week: "Неделя"
        case .month: "Месяц"
        }
    }
}

enum GameFlowCalendar {
    nonisolated static func interval(
        for grain: FlowPeriodGrain,
        containing date: Date,
        calendar: Calendar = .current
    ) -> DateInterval? {
        switch grain {
        case .day: calendar.dateInterval(of: .day, for: date)
        case .week: calendar.dateInterval(of: .weekOfYear, for: date)
        case .month: calendar.dateInterval(of: .month, for: date)
        }
    }

    /// Интервал периода, сдвинутого на `offset` шагов от периода, содержащего `date` (0 — текущий).
    nonisolated static func interval(
        for grain: FlowPeriodGrain,
        offset: Int,
        from date: Date,
        calendar: Calendar = .current
    ) -> DateInterval? {
        let component: Calendar.Component = switch grain {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
        guard let anchor = calendar.date(byAdding: component, value: offset, to: date) else { return nil }
        return interval(for: grain, containing: anchor, calendar: calendar)
    }
}

/// Проблема с хранилищем, о которой нужно сообщить пользователю (показывается алертом в `MainTabView`).
struct GameBacklogStorageIssue: Identifiable, Equatable, Sendable {
    let id = UUID()
    let message: String
}

/// Секция потока для ручного порядка строк (`flowSortKey` задаётся только задачам из этой секции).
/// `now` фиксирует «сегодня», с которым секция была построена, чтобы перестановка работала с тем же списком.
enum FlowOrderingScope: Sendable {
    case dated(DateInterval, now: Date)
    case overdue(now: Date)
    case upcoming(after: Date)
    case undated
}

@Observable
@MainActor
final class GameBacklogStore {
    /// Лимит слотов в колонке «Играю».
    static let maxPlayingGames = 5

    private(set) var entries: [GameEntry] = []

    /// Не `nil` — при загрузке что-то пошло не так; UI показывает сообщение один раз.
    private(set) var storageIssue: GameBacklogStorageIssue?

    /// `false`, если данные прочитаны с потерями и резервную копию сделать не удалось:
    /// тогда не перезаписываем хранилище, чтобы не уничтожить единственный экземпляр.
    private var isStorageWritable = true

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BacklogGaming",
        category: "Store"
    )

    init() {
        load()
    }

    func entry(id: GameEntry.ID) -> GameEntry? {
        entries.first { $0.id == id }
    }

    func entries(for section: GameListSection, search: String) -> [GameEntry] {
        let base: [GameEntry] = entries.filter { entry in
            switch section {
            case .playing: entry.status == .playing
            case .wishlist: entry.status == .queued && entry.wishlist
            case .queue: entry.status == .queued && !entry.wishlist
            case .completed: entry.status == .completed
            case .dropped: entry.status == .dropped
            }
        }
        return filterBySearch(base, search: search)
    }

    func entries(forKanban column: GameKanbanColumn, search: String) -> [GameEntry] {
        let base: [GameEntry] = entries.filter { entry in
            switch column {
            case .playing: entry.status == .playing
            case .backlog: entry.status == .queued
            case .completed: entry.status == .completed
            case .dropped: entry.status == .dropped
            }
        }
        return filterBySearch(base, search: search)
    }

    private func filterBySearch(_ list: [GameEntry], search: String) -> [GameEntry] {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return list }
        return list.filter { entry in
            entry.title.localizedCaseInsensitiveContains(needle)
                || entry.platform.shortTitle.localizedCaseInsensitiveContains(needle)
                || entry.note.localizedCaseInsensitiveContains(needle)
                || entry.tasks.contains {
                    $0.title.localizedCaseInsensitiveContains(needle)
                        || $0.note.localizedCaseInsensitiveContains(needle)
                }
        }
    }

    /// Перенос карточки в колонку канбана. Для «Играю» соблюдается лимит `maxPlayingGames`.
    @discardableResult
    func moveEntryToKanban(id: UUID, column: GameKanbanColumn) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return false }
        let previous = entries[index]
        var e = previous

        switch column {
        case .playing:
            guard canMoveToPlaying(id: id) else { return false }
            e.status = .playing
            e.wishlist = false
        case .backlog:
            e.status = .queued
            if previous.status != .queued { e.wishlist = false }
        case .completed:
            e.status = .completed
            e.wishlist = false
        case .dropped:
            e.status = .dropped
            e.wishlist = false
        }

        if e == previous { return true }
        return updateEntry(e)
    }

    /// Можно ли перевести игру в «Играю», не превысив `maxPlayingGames` (уже играющая — всегда можно).
    func canMoveToPlaying(id: GameEntry.ID) -> Bool {
        if entry(id: id)?.status == .playing { return true }
        return entries.filter { $0.status == .playing }.count < Self.maxPlayingGames
    }

    var nonEmptySections: [GameListSection] {
        GameListSection.allCases.filter { !entries(for: $0, search: "").isEmpty }
    }

    func counts() -> GameBacklogStats {
        GameBacklogStats(
            playing: entries.filter { $0.status == .playing }.count,
            wishlist: entries.filter { $0.status == .queued && $0.wishlist }.count,
            queue: entries.filter { $0.status == .queued && !$0.wishlist }.count,
            completed: entries.filter { $0.status == .completed }.count,
            dropped: entries.filter { $0.status == .dropped }.count,
            total: entries.count
        )
    }

    func addEntry(title raw: String, platform: GamePlatform = .unspecified, wishlist: Bool = false, symbolName: String = GameEntry.defaultSymbol, accentIndex: Int = 0) {
        let title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let entry = GameEntry(title: title, platform: platform, wishlist: wishlist, symbolName: symbolName, accentIndex: accentIndex)
        entries.append(entry)
        normalizeOrder()
        save()
    }

    /// Сохраняет игру. `false` — изменение отклонено (нет записи, пустое название или занят лимит «Играю»).
    @discardableResult
    func updateEntry(_ entry: GameEntry) -> Bool {
        guard let i = entries.firstIndex(where: { $0.id == entry.id }) else { return false }
        let previous = entries[i]
        if entry.status == .playing, previous.status != .playing, !canMoveToPlaying(id: entry.id) {
            return false
        }
        var e = entry
        e.title = e.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !e.title.isEmpty else { return false }
        if e.status != .queued { e.wishlist = false }
        if e.status == .completed {
            if previous.status != .completed {
                e.completedAt = Date()
            }
        } else {
            e.completedAt = nil
        }
        entries[i] = e
        normalizeOrder()
        save()
        return true
    }

    func deleteEntry(id: GameEntry.ID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func delete(at offsets: IndexSet, section: GameListSection, search: String) {
        let group = entries(for: section, search: search)
        let ids = offsets.compactMap { group[$0].id }
        entries.removeAll { ids.contains($0.id) }
        normalizeOrder()
        save()
    }

    // MARK: Задачи внутри игры

    func moveTasks(gameId: GameEntry.ID, from source: IndexSet, to destination: Int) {
        guard let gi = entries.firstIndex(where: { $0.id == gameId }) else { return }
        var entry = entries[gi]
        entry.tasks.backlogMove(fromOffsets: source, to: destination)
        entries[gi] = entry
        save()
    }

    func addTask(gameId: GameEntry.ID, task: GameTask) {
        guard let gi = entries.firstIndex(where: { $0.id == gameId }) else { return }
        var t = task
        t.title = t.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.title.isEmpty else { return }
        var entry = entries[gi]
        entry.tasks.append(t)
        entries[gi] = entry
        save()
    }

    func updateTask(gameId: GameEntry.ID, task: GameTask) {
        guard let gi = entries.firstIndex(where: { $0.id == gameId }),
              let ti = entries[gi].tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var t = task
        t.title = t.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.title.isEmpty else { return }
        var entry = entries[gi]
        entry.tasks[ti] = t
        entries[gi] = entry
        save()
    }

    func moveTaskUp(gameId: GameEntry.ID, taskId: GameTask.ID) {
        guard let gi = entries.firstIndex(where: { $0.id == gameId }),
              let ti = entries[gi].tasks.firstIndex(where: { $0.id == taskId }),
              ti > 0 else { return }
        entries[gi].tasks.swapAt(ti, ti - 1)
        save()
    }

    func moveTaskDown(gameId: GameEntry.ID, taskId: GameTask.ID) {
        guard let gi = entries.firstIndex(where: { $0.id == gameId }),
              let ti = entries[gi].tasks.firstIndex(where: { $0.id == taskId }),
              ti < entries[gi].tasks.count - 1 else { return }
        entries[gi].tasks.swapAt(ti, ti + 1)
        save()
    }

    /// Вверх/вниз в списке текущей секции потока (между играми), а не только внутри `tasks` одной игры.
    /// Двигаем только в пределах одного календарного дня: порядок дней задаётся датой, а не ручной сортировкой.
    func flowMoveTaskUp(gameId: GameEntry.ID, taskId: GameTask.ID, scope: FlowOrderingScope) {
        flowMoveTask(gameId: gameId, taskId: taskId, scope: scope, by: -1)
    }

    func flowMoveTaskDown(gameId: GameEntry.ID, taskId: GameTask.ID, scope: FlowOrderingScope) {
        flowMoveTask(gameId: gameId, taskId: taskId, scope: scope, by: 1)
    }

    /// Строки потока стоят в одном «дне» (оба без даты или даты в один календарный день) — их можно менять местами.
    static func sameFlowDay(_ a: GameTask, _ b: GameTask, calendar: Calendar = .current) -> Bool {
        switch (a.dueDate, b.dueDate) {
        case (nil, nil): true
        case let (da?, db?): calendar.isDate(da, inSameDayAs: db)
        default: false
        }
    }

    private func flowMoveTask(gameId: GameEntry.ID, taskId: GameTask.ID, scope: FlowOrderingScope, by step: Int) {
        var pairs = flowPairs(for: scope)
        guard let i = pairs.firstIndex(where: { $0.game.id == gameId && $0.task.id == taskId }) else { return }
        let j = i + step
        guard pairs.indices.contains(j), Self.sameFlowDay(pairs[i].task, pairs[j].task) else { return }
        pairs.swapAt(i, j)
        applyFlowOrdering(pairs)
        save()
    }

    private func flowPairs(for scope: FlowOrderingScope) -> [(game: GameEntry, task: GameTask)] {
        switch scope {
        case let .dated(interval, now):
            flowTasks(in: interval, now: now)
        case let .overdue(now):
            overdueTasks(now: now)
        case let .upcoming(after):
            upcomingTasks(after: after)
        case .undated:
            undatedOpenTasks()
        }
    }

    private func applyFlowOrdering(_ pairs: [(game: GameEntry, task: GameTask)]) {
        for (rank, pair) in pairs.enumerated() {
            guard let gi = entries.firstIndex(where: { $0.id == pair.game.id }),
                  let ti = entries[gi].tasks.firstIndex(where: { $0.id == pair.task.id }) else { continue }
            var entry = entries[gi]
            entry.tasks[ti].flowSortKey = rank
            entries[gi] = entry
        }
    }

    func deleteTask(gameId: GameEntry.ID, taskId: GameTask.ID) {
        guard let gi = entries.firstIndex(where: { $0.id == gameId }) else { return }
        var entry = entries[gi]
        entry.tasks.removeAll { $0.id == taskId }
        entries[gi] = entry
        save()
    }

    func toggleTaskDone(gameId: GameEntry.ID, taskId: GameTask.ID) {
        guard let gi = entries.firstIndex(where: { $0.id == gameId }),
              let ti = entries[gi].tasks.firstIndex(where: { $0.id == taskId }) else { return }
        var entry = entries[gi]
        entry.tasks[ti].isDone.toggle()
        entries[gi] = entry
        save()
    }

    // MARK: Поток — выборки

    /// Дела периода `[start, end)`, включая выполненные (как журнал периода).
    /// Открытые дела за прошедшие дни сюда не попадают — они в «Просрочено», чтобы не дублироваться.
    func flowTasks(in interval: DateInterval, now: Date = Date()) -> [(game: GameEntry, task: GameTask)] {
        let todayStart = Calendar.current.startOfDay(for: now)
        return flowPairs { t in
            guard let d = t.dueDate, d >= interval.start, d < interval.end else { return false }
            return t.isDone || d >= todayStart
        }
    }

    /// Открытые дела со сроком раньше сегодняшнего дня.
    func overdueTasks(now: Date = Date()) -> [(game: GameEntry, task: GameTask)] {
        let todayStart = Calendar.current.startOfDay(for: now)
        return flowPairs { t in
            guard !t.isDone, let d = t.dueDate else { return false }
            return d < todayStart
        }
    }

    /// Открытые дела со сроком не раньше `date` (обычно — конец текущего периода): блок «Скоро».
    func upcomingTasks(after date: Date) -> [(game: GameEntry, task: GameTask)] {
        flowPairs { t in
            guard !t.isDone, let d = t.dueDate else { return false }
            return d >= date
        }
    }

    /// Открытые дела без даты.
    func undatedOpenTasks() -> [(game: GameEntry, task: GameTask)] {
        flowPairs { !$0.isDone && $0.dueDate == nil }
    }

    /// Все пары (игра, дело) под условием, в едином порядке потока:
    /// календарный день → ручной `flowSortKey` → время → название игры → порядок дела в игре.
    private func flowPairs(where include: (GameTask) -> Bool) -> [(game: GameEntry, task: GameTask)] {
        let cal = Calendar.current
        let pairs = entries.flatMap { g in
            g.tasks.filter(include).map { (game: g, task: $0) }
        }
        return pairs.sorted { a, b in
            // Same calendar day → respect manual flow order; raw Date would block reorder for «сегодня» without time.
            let dayA = a.task.dueDate.map { cal.startOfDay(for: $0) } ?? Date.distantFuture
            let dayB = b.task.dueDate.map { cal.startOfDay(for: $0) } ?? Date.distantFuture
            if dayA != dayB { return dayA < dayB }
            if a.task.flowSortKey != b.task.flowSortKey {
                return a.task.flowSortKey < b.task.flowSortKey
            }
            let da = a.task.dueDate ?? Date.distantFuture
            let db = b.task.dueDate ?? Date.distantFuture
            if da != db { return da < db }
            let titleOrder = a.game.title.localizedCaseInsensitiveCompare(b.game.title)
            if titleOrder != .orderedSame {
                return titleOrder == .orderedAscending
            }
            guard let ia = a.game.tasks.firstIndex(where: { $0.id == a.task.id }),
                  let ib = b.game.tasks.firstIndex(where: { $0.id == b.task.id }) else {
                return false
            }
            return ia < ib
        }
    }

    private func normalizeOrder() {
        let playing = entries.filter { $0.status == .playing }.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        let wish = entries.filter { $0.status == .queued && $0.wishlist }.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        let queue = entries.filter { $0.status == .queued && !$0.wishlist }.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        let done = entries.filter { $0.status == .completed }.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        let dropped = entries.filter { $0.status == .dropped }.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        entries = playing + wish + queue + done + dropped
    }

    func dismissStorageIssue() {
        storageIssue = nil
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: GameBacklogPersistence.storageKey) else {
            entries = []
            return
        }

        // Снимок при каждом запуске (если данные изменились) — точка восстановления на любой случай.
        GameBacklogPersistence.writeBackup(data, kind: .launch)

        let result = GameBacklogPersistence.decodeEntries(from: data)
        entries = result.entries
        normalizeOrder()

        guard result.hasIssues else { return }

        for issue in result.issues {
            Self.logger.error("Decode issue: \(issue, privacy: .public)")
        }

        if let backupURL = GameBacklogPersistence.writeBackup(data, kind: .recovery) {
            storageIssue = GameBacklogStorageIssue(
                message: "Часть сохранённых данных не удалось прочитать. Исходная копия сохранена в приложении «Файлы» → папка этого приложения → Backups → \(backupURL.lastPathComponent)."
            )
        } else {
            isStorageWritable = false
            storageIssue = GameBacklogStorageIssue(
                message: "Не удалось полностью прочитать сохранённые данные и сделать их резервную копию. Чтобы ничего не потерять, изменения в этом запуске сохраняться не будут."
            )
        }
    }

    private func save() {
        guard isStorageWritable else {
            Self.logger.warning("Save skipped: storage is read-only after a failed load + backup")
            return
        }
        guard let data = GameBacklogPersistence.encodeEntries(entries) else { return }
        UserDefaults.standard.set(data, forKey: GameBacklogPersistence.storageKey)
    }
}

struct GameBacklogStats: Equatable {
    var playing: Int
    var wishlist: Int
    var queue: Int
    var completed: Int
    var dropped: Int
    var total: Int
}

extension GameListSection: CaseIterable {
    static var allCases: [GameListSection] {
        [.playing, .wishlist, .queue, .completed, .dropped]
    }
}
