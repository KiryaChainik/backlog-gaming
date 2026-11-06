//
//  StoreLogicTests.swift
//  Backlog_GamingTests
//
//  Лимит «Играю» и выборки «Потока».
//

import Foundation
import Testing
@testable import Backlog_Gaming

@MainActor
struct PlayingLimitTests {
    @Test func sixthGameCannotStartPlaying() throws {
        let store = GameBacklogStore(storage: InMemoryBacklogStorage())
        for i in 0 ..< GameBacklogStore.maxPlayingGames + 1 { store.addEntry(title: "Game \(i)") }
        let ids = store.entries.map(\.id)

        for id in ids.prefix(GameBacklogStore.maxPlayingGames) {
            #expect(store.moveEntryToKanban(id: id, column: .playing))
        }
        let extra = ids[GameBacklogStore.maxPlayingGames]
        #expect(!store.moveEntryToKanban(id: extra, column: .playing))

        // Обход через экран игры (updateEntry) тоже закрыт.
        var edited = try #require(store.entry(id: extra))
        edited.status = .playing
        #expect(!store.updateEntry(edited))
        #expect(store.entry(id: extra)?.status == .queued)

        // Уже играющую игру можно сохранять со статусом «Играю».
        #expect(store.canMoveToPlaying(id: ids[0]))
    }
}

@MainActor
struct FlowTests {
    private let cal = Calendar.current
    /// Пятница, 6 ноября 2026, 12:00 — середина недели и месяца.
    private let now: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 11; c.day = 6; c.hour = 12
        return Calendar.current.date(from: c)!
    }()

    private func day(_ offset: Int, hour: Int = 10) -> Date {
        let start = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now))!
        return cal.date(byAdding: .hour, value: hour, to: start)!
    }

    private func store(_ tasks: [GameTask]) -> GameBacklogStore {
        GameBacklogStore(storage: InMemoryBacklogStorage(entries: [GameEntry(title: "G", status: .playing, tasks: tasks)]))
    }

    private func titles(_ pairs: [(game: GameEntry, task: GameTask)]) -> [String] {
        pairs.map(\.task.title)
    }

    @Test func overdueShowsOnlyOpenTasks() {
        let s = store([
            GameTask(title: "open-yesterday", dueDate: day(-1)),
            GameTask(title: "done-yesterday", isDone: true, dueDate: day(-1)),
            GameTask(title: "today", dueDate: day(0)),
        ])
        #expect(titles(s.overdueTasks(now: now)) == ["open-yesterday"])
    }

    @Test func periodDoesNotDuplicateOpenOverdue() throws {
        let s = store([
            GameTask(title: "open-yesterday", dueDate: day(-1)),
            GameTask(title: "done-yesterday", isDone: true, dueDate: day(-1)),
            GameTask(title: "today", dueDate: day(0)),
        ])
        let week = try #require(GameFlowCalendar.interval(for: .week, containing: now))
        let inWeek = titles(s.flowTasks(in: week, now: now))
        #expect(!inWeek.contains("open-yesterday"))
        #expect(inWeek.contains("done-yesterday"))
        #expect(inWeek.contains("today"))
    }

    @Test func upcomingShowsFutureOpenTasks() throws {
        let s = store([
            GameTask(title: "future", dueDate: day(10)),
            GameTask(title: "future-done", isDone: true, dueDate: day(10)),
            GameTask(title: "today", dueDate: day(0)),
        ])
        let today = try #require(GameFlowCalendar.interval(for: .day, containing: now))
        #expect(titles(s.upcomingTasks(after: today.end)) == ["future"])
    }

    @Test func undatedShowsOnlyOpenTasks() {
        let s = store([
            GameTask(title: "undated"),
            GameTask(title: "undated-done", isDone: true),
        ])
        #expect(titles(s.undatedOpenTasks()) == ["undated"])
    }

    @Test func periodIntervalIsHalfOpen() throws {
        let today = try #require(GameFlowCalendar.interval(for: .day, containing: now))
        let s = store([GameTask(title: "midnight", dueDate: today.end)])
        #expect(s.flowTasks(in: today, now: now).isEmpty)
        let tomorrow = try #require(GameFlowCalendar.interval(for: .day, offset: 1, from: now))
        #expect(titles(s.flowTasks(in: tomorrow, now: now)) == ["midnight"])
    }

    @Test func reorderWorksWithinOneDayOnly() throws {
        let a = GameTask(title: "A", dueDate: day(0, hour: 10))
        let b = GameTask(title: "B", dueDate: day(0, hour: 11))
        let c = GameTask(title: "C", dueDate: day(1, hour: 9))
        let s = store([a, b, c])
        let gameId = try #require(s.entries.first?.id)
        let week = try #require(GameFlowCalendar.interval(for: .week, containing: now))
        let scope = FlowOrderingScope.dated(week, now: now)

        #expect(titles(s.flowTasks(in: week, now: now)) == ["A", "B", "C"])
        s.flowMoveTaskDown(gameId: gameId, taskId: a.id, scope: scope)
        #expect(titles(s.flowTasks(in: week, now: now)) == ["B", "A", "C"])
        // «A» — последнее дело своего дня: дальше вниз (на другой день) не двигается.
        s.flowMoveTaskDown(gameId: gameId, taskId: a.id, scope: scope)
        #expect(titles(s.flowTasks(in: week, now: now)) == ["B", "A", "C"])
    }

    @Test func nextPeriodStartsWhereCurrentEnds() throws {
        for grain in FlowPeriodGrain.allCases {
            let current = try #require(GameFlowCalendar.interval(for: grain, offset: 0, from: now))
            let next = try #require(GameFlowCalendar.interval(for: grain, offset: 1, from: now))
            #expect(next.start == current.end, "\(grain)")
        }
    }
}
