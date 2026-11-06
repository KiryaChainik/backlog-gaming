//
//  PersistenceTests.swift
//  Backlog_GamingTests
//
//  Чтение/запись данных и защита от их потери.
//

import Foundation
import Testing
@testable import Backlog_Gaming

@MainActor
struct PersistenceDecodingTests {
    private func decode(_ json: String) -> GameBacklogDecodeResult {
        GameBacklogPersistence.decodeEntries(from: Data(json.utf8))
    }

    @Test func roundTripKeepsGamesAndTasks() throws {
        let entries = GameEntry.previewSamples()
        let data = try #require(GameBacklogPersistence.encodeEntries(entries))
        let result = GameBacklogPersistence.decodeEntries(from: data)
        #expect(!result.hasIssues)
        #expect(result.entries.map(\.id) == entries.map(\.id))
        #expect(result.entries.flatMap(\.tasks).map(\.id) == entries.flatMap(\.tasks).map(\.id))
    }

    @Test func readsLegacyV1Array() {
        let id = UUID()
        let result = decode(#"[{"id":"\#(id.uuidString)","title":"Old","isCompleted":true}]"#)
        #expect(!result.hasIssues)
        #expect(result.entries.map(\.id) == [id])
        #expect(result.entries.first?.status == .completed)
    }

    @Test func brokenGameIsSkippedOthersKept() {
        let good = UUID()
        let result = decode(#"{"version":4,"entries":[{"id":"\#(good.uuidString)","title":"Good","status":"playing"},{"title":"No id"}]}"#)
        #expect(result.entries.map(\.id) == [good])
        #expect(result.hasIssues)
    }

    @Test func unknownStatusFallsBackToQueuedAndIsReported() {
        let result = decode(#"{"version":4,"entries":[{"id":"\#(UUID().uuidString)","title":"G","status":"archived"}]}"#)
        #expect(result.entries.first?.status == .queued)
        #expect(result.hasIssues)
    }

    @Test func brokenTaskIsSkippedGameKept() {
        let taskId = UUID()
        let json = #"{"version":4,"entries":[{"id":"\#(UUID().uuidString)","title":"G","status":"queued","tasks":[{"id":"\#(taskId.uuidString)","title":"T","kind":"todo","isDone":false},{"id":"not-a-uuid"}]}]}"#
        let result = decode(json)
        #expect(result.entries.count == 1)
        #expect(result.entries.first?.tasks.map(\.id) == [taskId])
        #expect(result.hasIssues)
    }

    @Test func garbageIsReportedNotSilentlyEmpty() {
        let result = decode("definitely not json")
        #expect(result.entries.isEmpty)
        #expect(result.hasIssues)
    }

    @Test func newerEnvelopeVersionIsReported() {
        let result = decode(#"{"version":99,"entries":[{"id":"\#(UUID().uuidString)","title":"G"}]}"#)
        #expect(result.entries.count == 1)
        #expect(result.hasIssues)
    }
}

@MainActor
struct StoreDataSafetyTests {
    @Test func corruptDataIsBackedUpAndReported() {
        let raw = Data("garbage".utf8)
        let storage = InMemoryBacklogStorage(data: raw)
        let store = GameBacklogStore(storage: storage)
        #expect(store.entries.isEmpty)
        #expect(store.storageIssue != nil)
        #expect(storage.backups.contains { $0.kind == .recovery && $0.data == raw })
    }

    @Test func savingIsBlockedWhenBackupFails() {
        let raw = Data("garbage".utf8)
        let storage = InMemoryBacklogStorage(data: raw, failsBackups: true)
        let store = GameBacklogStore(storage: storage)
        store.addEntry(title: "New game")
        // Единственный экземпляр данных не перезаписан.
        #expect(storage.data == raw)
        #expect(store.storageIssue != nil)
    }

    @Test func cleanDataSavesAndReloads() {
        let storage = InMemoryBacklogStorage(entries: [])
        let store = GameBacklogStore(storage: storage)
        #expect(store.storageIssue == nil)
        store.addEntry(title: "Hades")
        let reloaded = GameBacklogStore(storage: storage)
        #expect(reloaded.entries.map(\.title) == ["Hades"])
        #expect(storage.backups.allSatisfy { $0.kind == .launch })
    }
}
