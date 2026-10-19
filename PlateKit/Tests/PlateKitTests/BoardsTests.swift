import Testing
@testable import PlateKit

@Suite("PR board and whiteboard (M6 step 4)")
struct BoardsTests {
    @Test func prBoardCarriesThePRs() {
        let rows = [BoardRow(left: "Back Squat", right: "100 kg"), BoardRow(left: "Snatch", right: "60 kg")]
        let parts = PropModels.parts(for: .prBoard, plates: [], boards: Boards(prs: rows, workout: []))
        #expect(parts.contains { $0.tone == .picture(.prTable(rows)) })
        // No PRs yet: the empty table.
        #expect(PropModels.parts(for: .prBoard, plates: []).contains { $0.tone == .picture(.prTable([])) })
    }

    @Test func whiteboardShowsTodaysWorkoutOnItsFace() {
        let lines = [BoardLine(name: "Back Squat", format: "5 × 3", load: "80 kg")]
        let parts = PropModels.parts(for: .board, plates: [], boards: Boards(prs: [], workout: lines))
        let face = parts.first { $0.tone == .picture(.whiteboard(lines)) }
        #expect(face != nil)
        #expect(face?.mesh.uvs.count == face?.mesh.positions.count)
        // In front of the writing surface (z 0.04) and the size of the prototype's 1.33 × 0.89 plane.
        let zs = face?.mesh.positions.map(\.z) ?? []
        #expect(zs.allSatisfy { abs($0 - 0.042) < 0.001 })
        let xs = face?.mesh.positions.map(\.x) ?? []
        #expect(abs((xs.max() ?? 0) - (xs.min() ?? 0) - 1.33) < 0.001)
    }

    @Test func boardLinesFromAPlan() {
        let lift = LiftInput(name: "Back Squat", pr: 100, prUnit: .kg, sets: [
            LiftInput.WorkSet(reps: 3, target: Target(low: 80)), LiftInput.WorkSet(reps: 3, target: Target(low: 80)),
        ])
        let plan = SessionPlan(gym: GymSetup(unit: .kg), lifts: [lift])
        #expect(BoardLine.lines(for: plan) == [BoardLine(name: "Back Squat", format: "2 × 3", load: "80 kg")])
    }
}
