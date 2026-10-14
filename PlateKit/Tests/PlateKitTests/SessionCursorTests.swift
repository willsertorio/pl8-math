import Testing
@testable import PlateKit

@Suite("Session progress (SPEC 2.3 set by set)")
struct SessionCursorTests {
    /// Warm-up (3 rounds) before lift 0 (5 sets), then lift 1 (3 sets).
    func items(done: Int) -> [SessionCursor.Item] {
        let shape: [(Int, Bool)] = Array(repeating: (0, true), count: 3)
            + Array(repeating: (0, false), count: 5)
            + Array(repeating: (1, false), count: 3)
        return shape.enumerated().map { index, item in
            SessionCursor.Item(blockIndex: item.0, isWarmUp: item.1, isDone: index < done)
        }
    }

    @Test func currentIsTheFirstSetNotDone() {
        #expect(SessionCursor(items: items(done: 0)).current == 0)
        #expect(SessionCursor(items: items(done: 4)).current == 4)
        #expect(SessionCursor(items: items(done: 11)).current == nil)
    }

    @Test func doneOutOfOrderStillPicksTheFirstOpenOne() {
        var list = items(done: 0)
        list[1] = SessionCursor.Item(blockIndex: 0, isWarmUp: true, isDone: true)
        #expect(SessionCursor(items: list).current == 0)
    }

    @Test func setNumberIsCountedWithinItsGroup() {
        let cursor = SessionCursor(items: items(done: 0))
        #expect(cursor.position(of: 0) == SessionCursor.Position(number: 1, count: 3))   // warm-up round 1 of 3
        #expect(cursor.position(of: 4) == SessionCursor.Position(number: 2, count: 5))   // lift 0, set 2 of 5
        #expect(cursor.position(of: 10) == SessionCursor.Position(number: 3, count: 3))  // lift 1, set 3 of 3
    }

    @Test func groupHoldsTheProgressDots() {
        let cursor = SessionCursor(items: items(done: 0))
        #expect(cursor.group(of: 1) == [0, 1, 2])
        #expect(cursor.group(of: 3) == [3, 4, 5, 6, 7])      // warm-up isn't part of the lift's dots
        #expect(cursor.group(of: 9) == [8, 9, 10])
    }

    @Test func lastSetOfEachLift() {
        let cursor = SessionCursor(items: items(done: 0))
        #expect(cursor.isLastOfLift(7))
        #expect(cursor.isLastOfLift(10))
        #expect(!cursor.isLastOfLift(2))                       // end of the warm-up isn't a lift
        #expect(!cursor.isLastOfLift(6))
    }

    @Test func finishedWhenEverySetIsDone() {
        #expect(!SessionCursor(items: items(done: 10)).isFinished)
        #expect(SessionCursor(items: items(done: 11)).isFinished)
        #expect(!SessionCursor(items: []).isFinished)
    }
}
