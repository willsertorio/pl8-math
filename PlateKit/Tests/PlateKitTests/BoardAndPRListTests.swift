import Foundation
import Testing
@testable import PlateKit

/// From Will's phone test, 2026-11-10: a long workout crammed the board, and the PR notebook had a lift twice and
/// no order.
@Suite("Board and PR list (2026-11-10)")
struct BoardAndPRListTests {
    let line = { (i: Int) in FlowBoardLine(title: "\(i)", format: "", load: "") }

    @Test func theBoardShowsThreeLiftsThenMore() {
        let four = (1...4).map(line)
        #expect(FlowBoard.shown(four).lines.map(\.title) == ["1", "2", "3"])
        #expect(FlowBoard.shown(four).more)
        #expect(!FlowBoard.shown(Array(four.prefix(3))).more)
        #expect(FlowBoard.shown(Array(four.prefix(3))).lines.count == 3)
    }

    @Test func aClimbIsShownAsItsRange() {
        // "Progressão: 60–80%" (Fixtures 07/11): the board says where the sets go, not just the first.
        #expect(FlowBoard.percentText([60, 64, 68, 72, 76, 80].map { Target.single($0) }) == "60–80%")
        #expect(FlowBoard.percentText(Array(repeating: .range(75, 80), count: 5)) == "75–80%")
        #expect(FlowBoard.percentText([.single(75)]) == "75%")
        // Mixed targets (Fixtures 01/10) keep the first set's, as before.
        #expect(FlowBoard.percentText([.range(75, 78), .range(78, 80), .plus(80)]) == "75–78%")
        #expect(FlowBoard.percentText([.weight(40, unit: .kg)]) == "40 kg")
        #expect(FlowBoard.percentText([]) == "")
    }

    @Test func plusAndAmpersandAreTheSameLift() {
        // The marker font draws "&" like "+": both spellings come in from screenshots.
        #expect(LiftNames.key("Clean + Jerk") == LiftNames.key("Clean & Jerk"))
        #expect(LiftNames.key("Clean and Jerk") == LiftNames.key("Clean & Jerk"))
    }

    @Test func thePRPageIsAlphabetical() {
        let rows = ["Snatch balance  10 kg", "bench press  80 kg", "Clean pull  132 lb", "Clean  95 kg", "Clean & jerk  125 lb"]
        #expect(NotebookPages.ordered(rows) == ["bench press  80 kg", "Clean  95 kg", "Clean & jerk  125 lb", "Clean pull  132 lb", "Snatch balance  10 kg"])
    }

    @Test func oneRecordStaysPerLift() {
        let old = Date(timeIntervalSince1970: 0), new = Date(timeIntervalSince1970: 100)
        // The one with a value wins; among those, the newest.
        #expect(PRMerge.keeper(of: [(value: nil, updated: new), (value: 100, updated: old)]) == 1)
        #expect(PRMerge.keeper(of: [(value: 90, updated: old), (value: 100, updated: new)]) == 1)
        #expect(PRMerge.keeper(of: [(value: nil, updated: old), (value: nil, updated: new)]) == 1)
    }
}
