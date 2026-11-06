//
//  GameBacklogStore.swift
//  Backlog_Gaming
//

import Foundation
import Observation

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
}

/// Секция потока для ручного порядка строк (`flowSortKey` задаётся только задачам из этой секции).
enum FlowOrderingScope: Sendable {
    case dated(DateInterval)
    case overdue
    case undated
}

@Observable
@MainActor
final class GameBacklogStore {
    /// Лимит слотов в колонке «Играю».
    static let maxPlayingGames = 5

    private(set) var entries: [GameEntry] = []

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
            if previous.status != .playing {
                let playingCount = entries.filter { $0.status == .playing }.count
                if playingCount >= Self.maxPlayingGames { return false }
            }
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
        updateEntry(e)
        return true
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

    func updateEntry(_ entry: GameEntry) {
        guard let i = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        let previous = entries[i]
        var e = entry
        e.title = e.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !e.title.isEmpty else { return }
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
    func flowMoveTaskUp(gameId: GameEntry.ID, taskId: GameTask.ID, scope: FlowOrderingScope) {
        var pairs = flowPairs(for: scope)
        guard let i = pairs.firstIndex(where: { $0.game.id == gameId && $0.task.id == taskId }),
              i > 0 else { return }
        pairs.swapAt(i, i - 1)
        applyFlowOrdering(pairs)
        save()
    }

    func flowMoveTaskDown(gameId: GameEntry.ID, taskId: GameTask.ID, scope: FlowOrderingScope) {
        var pairs = flowPairs(for: scope)
        guard let i = pairs.firstIndex(where: { $0.game.id == gameId && $0.task.id == taskId }),
              i < pairs.count - 1 else { return }
        pairs.swapAt(i, i + 1)
        applyFlowOrdering(pairs)
        save()
    }

    private func flowPairs(for scope: FlowOrderingScope) -> [(game: GameEntry, task: GameTask)] {
        switch scope {
        case .dated(let interval):
            openTasks(withDueDateIn: interval)
        case .overdue:
            openOverdueTasks()
        case .undated:
            openUndatedTasks()
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

    /// Дела с датой в интервале (по моменту `dueDate`), включая выполненные.
    func openTasks(withDueDateIn interval: DateInterval) -> [(game: GameEntry, task: GameTask)] {
        var out: [(game: GameEntry, task: GameTask)] = []
        for g in entries {
            for t in g.tasks {
                if let d = t.dueDate, interval.contains(d) {
                    out.append((game: g, task: t))
                }
            }
        }
        let cal = Calendar.current
        out.sort { a, b in
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
        return out
    }

    /// Просроченные дела (dueDate < начало сегодняшнего дня), включая выполненные.
    func openOverdueTasks() -> [(game: GameEntry, task: GameTask)] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        var out: [(game: GameEntry, task: GameTask)] = []
        for g in entries {
            for t in g.tasks {
                if let d = t.dueDate, d < todayStart {
                    out.append((game: g, task: t))
                }
            }
        }
        let cal = Calendar.current
        out.sort { a, b in
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
        return out
    }

    /// Дела без даты (включая выполненные) — для блока «без даты» на вкладке потока.
    func openUndatedTasks() -> [(game: GameEntry, task: GameTask)] {
        entries.flatMap { g in
            g.tasks.filter { $0.dueDate == nil }.map { (game: g, task: $0) }
        }
        .sorted { a, b in
            if a.task.flowSortKey != b.task.flowSortKey {
                return a.task.flowSortKey < b.task.flowSortKey
            }
            let c = a.game.title.localizedCaseInsensitiveCompare(b.game.title)
            if c != .orderedSame { return c == .orderedAscending }
            guard let ia = a.game.tasks.firstIndex(where: { $0.id == a.task.id }),
                  let ib = b.game.tasks.firstIndex(where: { $0.id == b.task.id }) else { return false }
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

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: GameBacklogPersistence.storageKey) else {
            entries = []
            return
        }
        entries = GameBacklogPersistence.decodeEntries(from: data)
        normalizeOrder()
    }

    private func save() {
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
