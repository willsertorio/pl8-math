import Foundation
import Testing
@testable import PlateKit

/// The whiteboard formats the rules must read (docs/DATA-AND-SERVICES.md §2.3). Anything unclear is a failure,
/// never a guess.
@Suite("Reading rules: whiteboard formats (DATA-AND-SERVICES §2.3)")
struct BoardFormatsTests {
    func only(_ text: String) -> StrengthBlock? {
        let blocks = WorkoutParser.parse(text)
        return blocks.count == 1 ? blocks[0] : nil
    }

    func sets(_ count: Int, of reps: Int, at percent: Double?) -> [ParsedSet] {
        Array(repeating: ParsedSet(reps: reps, target: percent.map { .single($0) }), count: count)
    }

    @Test func liftThenSetsTimesReps() {
        let block = only("Back squat 5x5 @ 75%")
        #expect(block?.prLift == "Back Squat")
        #expect(block?.sets == sets(5, of: 5, at: 75))
    }

    @Test func theLiftOnTheLineAbove() {
        let block = only("Back squat\n5 × 5 @ 75%")
        #expect(block?.prLift == "Back Squat")
        #expect(block?.sets == sets(5, of: 5, at: 75))
    }

    @Test func repsWithDashes() {
        let block = only("Deadlift 3-3-3 @80%")
        #expect(block?.prLift == "Deadlift")
        #expect(block?.sets == sets(3, of: 3, at: 80))
    }

    @Test func emomWithRepsBeforeTheLift() {
        let block = only("EMOM 10: 3 cleans @ 70%")
        #expect(block?.prLift == "Clean")
        #expect(block?.format == "EMOM")
        #expect(block?.sets == sets(10, of: 3, at: 70))
    }

    @Test func fiveThreeOneHasNoPercent() {
        let block = only("Bench 5/3/1")
        #expect(block?.prLift == "Bench Press")
        #expect(block?.sets.map(\.reps) == [5, 3, 1])
        #expect(block?.pctMissing == true)
    }

    @Test func aFixedWeightIsReadButNotPlanned() {
        // SPEC 3.6 rule 3: loads without a % are not planned (yet); the result keeps them.
        #expect(WorkoutParser.parse("Strict press 4x6 @ 40kg").isEmpty)
        let result = BoardFormats.read("Strict press 4x6 @ 40kg")
        #expect(result?.blocks?.first?.lift == "Strict Press")
        #expect(result?.blocks?.first?.sets == Array(repeating: ReadResult.Set(reps: 6, percent: nil, weight: 40), count: 4))
        #expect(result?.unit == .kg)
    }

    @Test func aSectionHeaderNamesTheLift() {
        let block = only("A. BACK SQUAT\n5x5 @ 75%")
        #expect(block?.letter == "A")
        #expect(block?.prLift == "Back Squat")
        #expect(block?.sets == sets(5, of: 5, at: 75))
    }

    @Test func spellingsAreNormalised() {
        for text in ["Back squat 5X5@75 %", "back squat 5 x 5 @ 75%", "BACK SQUAT 5 × 5 @75%", "BS 5x5 @ 75%", "Back squats 5x5 @ 75%"] {
            #expect(only(text)?.prLift == "Back Squat", "\(text)")
            #expect(only(text)?.sets == sets(5, of: 5, at: 75), "\(text)")
        }
        #expect(BoardFormats.read("Deadlift 5x3 @ 225#")?.blocks?.first?.sets.first?.weight == 225)
        #expect(BoardFormats.read("Deadlift 5x3 @ 225#")?.unit == .lb)
    }

    @Test func unclearIsAFailure() {
        #expect(WorkoutParser.parse("5x5 @ 75%").isEmpty)                 // no lift
        #expect(WorkoutParser.parse("Back squat @ 75%").isEmpty)          // no reps
        #expect(WorkoutParser.parse("Back squat 5x5 @ 175%").isEmpty)     // fails validation
        #expect(WorkoutParser.parse("Strength\n21-15-9\nThrusters").isEmpty)
        #expect(BoardFormats.read("Order completed! 45.90") == nil)
    }

    @Test func severalLiftsGetLetters() {
        let blocks = WorkoutParser.parse("Back squat 5x5 @ 75%\nDeadlift 3-3-3 @80%")
        #expect(blocks.map(\.letter) == ["A", "B"])
        #expect(blocks.map(\.prLift) == ["Back Squat", "Deadlift"])
    }

    @Test func theBoxAppStillComesFirst() throws {
        // The box app's format is unchanged (Fixtures 01/10).
        let blocks = WorkoutParser.parse("""
        A.
        5 Minute EMOM
        3 Back Squat @75-78% 1RM Back Squat
        """)
        #expect(blocks.first?.prLift == "Back Squat")
        #expect(blocks.first?.sets.count == 5)
    }
}

/// The result every reading stage gives (rules, the on-device model, the cloud), and its checks (§2.4).
@Suite("Reading result and its validation (DATA-AND-SERVICES §2.4)")
struct ReadResultTests {
    @Test func decodesTheWorkoutSchema() throws {
        let json = """
        {"kind": "workout", "unit": "kg", "blocks": [{"label": "A", "lift": "Back squat",
          "sets": [{"reps": 5, "percent": 75, "weight": null}], "note": "EMOM 10"}]}
        """
        let result = try JSONDecoder().decode(ReadResult.self, from: Data(json.utf8))
        #expect(result.kind == .workout)
        #expect(result.unit == .kg)
        #expect(result.blocks?.first?.sets == [ReadResult.Set(reps: 5, percent: 75, weight: nil)])
        #expect(result.blocks?.first?.note == "EMOM 10")
    }

    @Test func decodesThePRSchema() throws {
        let json = #"{ "kind": "prs", "unit": null, "prs": [ { "lift": "Deadlift", "weight": 180 } ] }"#
        let result = try JSONDecoder().decode(ReadResult.self, from: Data(json.utf8))
        #expect(result.kind == .prs)
        #expect(result.unit == nil)
        #expect(result.prs == [ReadResult.PR(lift: "Deadlift", weight: 180)])
    }

    func workout(_ sets: [ReadResult.Set], unit: WeightUnit? = .kg) -> ReadResult {
        ReadResult(kind: .workout, unit: unit, blocks: [.init(label: "A", lift: "Back squat", sets: sets, note: nil)])
    }

    @Test func repsPercentAndWeightMustBeLikely() {
        #expect(workout([.init(reps: 5, percent: 75, weight: nil)]).validated() != nil)
        #expect(workout([.init(reps: 0, percent: 75, weight: nil)]).validated() == nil)
        #expect(workout([.init(reps: 51, percent: 75, weight: nil)]).validated() == nil)
        #expect(workout([.init(reps: 50, percent: 30, weight: nil)]).validated() != nil)
        #expect(workout([.init(reps: 5, percent: 29, weight: nil)]).validated() == nil)
        #expect(workout([.init(reps: 5, percent: 111, weight: nil)]).validated() == nil)
        #expect(workout([.init(reps: 5, percent: nil, weight: 500)]).validated() != nil)
        #expect(workout([.init(reps: 5, percent: nil, weight: 501)]).validated() == nil)
        #expect(workout([.init(reps: 5, percent: nil, weight: 1100)], unit: .lb).validated() != nil)
        #expect(workout([.init(reps: 5, percent: nil, weight: 1101)], unit: .lb).validated() == nil)
        #expect(workout([.init(reps: 5, percent: nil, weight: 0.5)]).validated() == nil)
    }

    @Test func atLeastOneBlockOrPR() {
        #expect(ReadResult(kind: .workout, unit: nil, blocks: []).validated() == nil)
        #expect(ReadResult(kind: .prs, unit: .kg, prs: []).validated() == nil)
        #expect(ReadResult(kind: .prs, unit: .kg, prs: [.init(lift: "Deadlift", weight: 180)]).validated() != nil)
        #expect(ReadResult(kind: .prs, unit: .kg, prs: [.init(lift: "Deadlift", weight: 600)]).validated() == nil)
    }

    @Test func liftNamesMatchTheirSynonyms() {
        let names = ["bs", "dl", "cj", "c&j", "BENCH", "cleans", "Zercher squat"].map { name in
            ReadResult(kind: .prs, unit: .kg, prs: [.init(lift: name, weight: 100)]).validated()?.prs?.first?.lift
        }
        // Unknown lifts are kept as written.
        #expect(names == ["Back Squat", "Deadlift", "Clean & Jerk", "Clean & Jerk", "Bench Press", "Clean", "Zercher squat"])
    }

    @Test func aReceiptIsNotAPR() {
        #expect(ReadResult(kind: .prs, unit: .kg, prs: [.init(lift: "Order completed", weight: 45.9)]).validated() == nil)
    }

    @Test func becomesTheBlocksThePlannerUses() {
        let result = ReadResult(kind: .workout, unit: .kg, blocks: [
            .init(label: "A", lift: "back squat", sets: [.init(reps: 5, percent: 75, weight: nil), .init(reps: 3, percent: nil, weight: nil)], note: "EMOM 10"),
            .init(label: nil, lift: "Strict press", sets: [.init(reps: 6, percent: nil, weight: 40)], note: nil),
            .init(label: nil, lift: "Deadlift", sets: [.init(reps: 3, percent: 80, weight: nil)], note: nil),
        ])
        let blocks = result.strengthBlocks()
        // The fixed weight isn't planned (SPEC 3.6 rule 3); letters carry on from the labelled block.
        #expect(blocks.map(\.letter) == ["A", "B"])
        #expect(blocks.map(\.prLift) == ["Back Squat", "Deadlift"])
        #expect(blocks[0].sets == [ParsedSet(reps: 5, target: .single(75)), ParsedSet(reps: 3, target: nil)])
        #expect(blocks[0].note == "EMOM 10")
    }

    @Test func becomesPREntries() {
        let result = ReadResult(kind: .prs, unit: .lb, prs: [.init(lift: "Deadlift", weight: 405)])
        #expect(result.prEntries() == [PREntry(lift: "Deadlift", value: 405, unit: .lb)])
        let unknownUnit = ReadResult(kind: .prs, unit: nil, prs: [.init(lift: "Snatch", weight: 85)])
        #expect(unknownUnit.prEntries() == [PREntry(lift: "Snatch", value: 85, unit: nil)])
    }
}

/// The rules' own output is checked with the same limits, item by item: one odd line doesn't throw away the rest.
@Suite("The rules' output is checked too (DATA-AND-SERVICES §2.4)")
struct LikelyOutputTests {
    @Test func aBlockIsLikelyWithinTheLimits() {
        func block(_ sets: [ParsedSet]) -> StrengthBlock { .typed(letter: "A", lift: "Back Squat", sets: 1, reps: 1, target: .single(80)).replacingSets(sets) }
        #expect(block([ParsedSet(reps: 5, target: .range(75, 78))]).isLikely)
        #expect(block([ParsedSet(reps: 3, target: nil)]).isLikely)                 // a % to ask for is fine
        #expect(block([ParsedSet(reps: 5, target: .plus(80))]).isLikely)
        #expect(!block([ParsedSet(reps: 0, target: .single(80))]).isLikely)
        #expect(!block([ParsedSet(reps: 60, target: .single(80))]).isLikely)
        #expect(!block([ParsedSet(reps: 5, target: .single(20))]).isLikely)
        #expect(!block([ParsedSet(reps: 5, target: .range(100, 120))]).isLikely)
        #expect(!block([]).isLikely)
    }

    @Test func aPRIsLikelyWithinTheLimits() {
        #expect(PREntry(lift: "Deadlift", value: 180, unit: .kg).isLikely)
        #expect(PREntry(lift: "Deadlift", value: 1000, unit: .lb).isLikely)
        #expect(!PREntry(lift: "Deadlift", value: 600, unit: .kg).isLikely)
        #expect(PREntry(lift: "Deadlift", value: 600, unit: nil).isLikely)          // its unit is asked later
        #expect(!PREntry(lift: "Deadlift", value: 0.5, unit: .kg).isLikely)
        #expect(!PREntry(lift: "Order completed", value: 45, unit: .kg).isLikely)
    }
}
