//
//  Array+BacklogMove.swift
//  Backlog_Gaming
//
//  Тот же контракт, что у `List.onMove` и `Array.move(fromOffsets:to:)` в стандартной библиотеке,
//  но без зависимости от модулей, где `move` может быть недоступен.
//

import Foundation

extension Array {
    mutating func backlogMove(fromOffsets source: IndexSet, to destination: Int) {
        guard !source.isEmpty else { return }
        var result = self
        var extracted: [Element] = []
        for index in source.sorted(by: >) {
            extracted.insert(result.remove(at: index), at: 0)
        }
        let dest = destination - source.filter { $0 < destination }.count
        for (offset, item) in extracted.enumerated() {
            let insertIndex = Swift.min(dest + offset, result.count)
            result.insert(item, at: insertIndex)
        }
        self = result
    }
}

#if DEBUG
enum BacklogMoveSelfTest {
    static func run() {
        var a = ["A", "B", "C", "D"]
        a.backlogMove(fromOffsets: IndexSet(integer: 1), to: 0)
        assert(a == ["B", "A", "C", "D"], "single move up")

        var b = ["A", "B", "C", "D"]
        b.backlogMove(fromOffsets: IndexSet([0, 1]), to: 4)
        assert(b == ["C", "D", "A", "B"], "two to end")

        var c = [1, 2, 3]
        c.backlogMove(fromOffsets: IndexSet(integer: 0), to: 3)
        assert(c == [2, 3, 1], "move first to end")
    }
}
#endif
