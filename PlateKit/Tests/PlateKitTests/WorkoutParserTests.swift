import Foundation
import Testing
@testable import PlateKit

/// Reads a file from the repo's Fixtures/workouts folder.
func fixture(_ name: String) throws -> String {
    let repo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // PlateKitTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // PlateKit
        .deletingLastPathComponent()   // repo
    return try String(contentsOf: repo.appendingPathComponent("Fixtures/workouts/\(name)"), encoding: .utf8)
}

func targets(_ block: StrengthBlock) -> [Target?] { block.sets.map(\.target) }

@Suite("Workout parser · fixtures (Fixtures/README.md)")
struct WorkoutFixtureTests {
    @Test func workout0110() throws {
        let blocks = WorkoutParser.parse(try fixture("2026-10-01.ocr.txt"))
        #expect(blocks.count == 1)                                   // B (run + 115/80) ignored
        let a = try #require(blocks.first)
        #expect(a.letter == "A")
        #expect(a.name == "Back Squat")
        #expect(a.prLift == "Back Squat")
        #expect(a.format == "EMOM")
        #expect(a.sets.map(\.reps) == [3, 3, 3, 3, 3])
        #expect(targets(a) == [.range(75, 78), .range(75, 78), .range(78, 80), .range(78, 80), .plus(80)])
        #expect(!a.pctMissing)
    }

    @Test func workout0210() throws {
        let blocks = WorkoutParser.parse(try fixture("2026-10-02.ocr.txt"))
        #expect(blocks.map(\.letter) == ["A", "B"])                  // C (For Time) ignored

        let a = blocks[0]
        #expect(a.name == "Snatch Balance")
        #expect(a.prLift == "Snatch Balance")
        #expect(a.format == "EMOM")
        #expect(a.sets.map(\.reps) == Array(repeating: 1, count: 6))
        #expect(targets(a) == [68, 68, 73, 73, 75, 75].map { .single($0) })

        let b = blocks[1]
        #expect(b.name == "Snatch Pull + Snatch")
        #expect(b.prLift == "Snatch")
        #expect(b.format == nil)
        #expect(b.sets.map(\.reps) == Array(repeating: 1, count: 8))
        #expect(targets(b) == [68, 68, 70, 73, 75, 75, 78, 78].map { .single($0) })
        #expect(b.note == "Rest 2 minutes between sets")
    }

    @Test func workout0510() throws {
        let blocks = WorkoutParser.parse(try fixture("2026-10-05.ocr.txt"))
        #expect(blocks.map(\.letter) == ["B", "D"])                  // A (complex, no %) and C (dumbbells) ignored

        let b = blocks[0]
        #expect(b.name == "Snatch")
        #expect(b.prLift == "Snatch")
        #expect(b.format == "EMOM")
        #expect(targets(b) == [.range(75, 80), .range(75, 80), .range(75, 80), .range(80, 83), .range(80, 83), .range(80, 83)])

        // The % is hidden under the app's Check-In button: OCR reads "2 Back Squat K checn J Squat".
        let d = blocks[1]
        #expect(d.label == "After Party")
        #expect(d.name == "Back Squat")
        #expect(d.prLift == "Back Squat")
        #expect(d.format == "EMOM")
        #expect(d.sets.map(\.reps) == [2, 2, 2, 2, 2])
        #expect(d.pctMissing)

        // The user then enters 83-85.
        let filled = d.fillingMissingPercent(with: try #require(Target(parsing: "83-85")))
        #expect(!filled.pctMissing)
        #expect(targets(filled) == Array(repeating: .range(83, 85), count: 5))
    }
}

@Suite("Workout parser · real use")
struct WorkoutRealUseTests {
    // Vision on the iPhone read "A." with a Cyrillic А, so block A was missed.
    @Test func workout1310ReadByVision() throws {
        let blocks = WorkoutParser.parse(try fixture("2026-10-13.vision.txt"))
        #expect(blocks.map(\.letter) == ["A"])                      // B (run) and C (planks) ignored
        let a = try #require(blocks.first)
        #expect(a.name == "Split Jerk")
        #expect(a.prLift == "Split Jerk")
        #expect(a.format == "EMOM")
        #expect(a.sets.map(\.reps) == Array(repeating: 1, count: 6))
        #expect(targets(a) == [.single(83), .single(83), .single(85), .single(85), .range(85, 88), .range(85, 88)])
    }

    @Test func workout0110ReadByVision() throws {
        let blocks = WorkoutParser.parse(try fixture("2026-10-01.vision.txt"))
        #expect(blocks.count == 1)
        let a = try #require(blocks.first)
        #expect(a.letter == "A")
        #expect(a.name == "Back Squat")
        #expect(a.format == "EMOM")
        #expect(targets(a) == [.range(75, 78), .range(75, 78), .range(78, 80), .range(78, 80), .plus(80)])
    }

    @Test func workout0210ReadByVision() throws {
        let blocks = WorkoutParser.parse(try fixture("2026-10-02.vision.txt"))
        #expect(blocks.map(\.letter) == ["A", "B"])
        #expect(blocks.map(\.prLift) == ["Snatch Balance", "Snatch"])
        #expect(blocks.map(\.sets.count) == [6, 8])
        #expect(blocks.last?.note == "Rest 2 minutes between sets")
    }

    @Test func workout0510ReadByVision() throws {
        let blocks = WorkoutParser.parse(try fixture("2026-10-05.vision.txt"))
        #expect(blocks.map(\.letter) == ["B", "D"])
        #expect(blocks.first.map(targets) == [.range(75, 80), .range(75, 80), .range(75, 80), .range(80, 83), .range(80, 83), .range(80, 83)])
        let d = try #require(blocks.last)
        #expect(d.label == "After Party")
        #expect(d.name == "Back Squat")
        #expect(!d.pctMissing)                                       // Vision read the % through the button
        #expect(d.sets.map(\.reps) == [2, 2, 2, 2, 2])
        #expect(targets(d) == Array(repeating: .range(83, 85), count: 5))
    }

    @Test func workout0210AppVersionReadByVision() throws {
        let blocks = WorkoutParser.parse(try fixture("2026-10-02-app.vision.txt"))
        #expect(blocks.map(\.name) == ["Snatch Balance"])          // B "10 Back Squats (225/155)" has no %
        #expect(blocks.first.map(targets) == [68, 68, 73, 73, 75, 75].map { .single($0) })
    }

    @Test func lookalikeLettersInsideWordsAreReadAsLatin() {
        // "Back" with a Cyrillic а and с.
        let blocks = WorkoutParser.parse("A.\n3 B\u{0430}\u{0441}k Squat @80% 1RM B\u{0430}\u{0441}k Squat")
        #expect(blocks.first?.name == "Back Squat")
        #expect(blocks.first?.prLift == "Back Squat")
    }
}

@Suite("Workout parser · rules (SPEC 3.6)")
struct WorkoutRuleTests {
    @Test func blocksStartAtALetterAndADot() {
        let blocks = WorkoutParser.parse("""
        WOD 07/10/2026
        3 Back Squat @80% 1RM Back Squat
        A.
        3 Deadlift @70% 1RM Deadlift
        """)
        #expect(blocks.map(\.name) == ["Deadlift"])                  // lines before the first block are ignored
    }

    // 02/10 app version: "C. After a Party" on one line.
    @Test func blockLetterCanHaveItsLabelOnTheSameLine() {
        let blocks = WorkoutParser.parse("""
        A.
        For Time:
        100 Double Unders
        C. After a Party
        3 Back Squat @80% 1RM Back Squat
        """)
        #expect(blocks.map(\.letter) == ["C"])
        #expect(blocks.first?.label == "After a Party")
    }

    @Test func anyPercentLineIsStrengthWhateverTheBlockIsCalled() {
        let blocks = WorkoutParser.parse("""
        A.
        For Time:
        21 Thrusters (95/65)
        B.
        Compete
        3 Front Squat @80% 1RM Front Squat
        """)
        #expect(blocks.map(\.letter) == ["B"])
        #expect(blocks.first?.label == "Compete")
    }

    @Test func plusIsReadEitherWay() {
        let blocks = WorkoutParser.parse("""
        A.
        2 Clean @80%+ 1RM Clean
        2 Clean @80-80+% 1RM Clean
        """)
        #expect(blocks.first.map(targets) == [.plus(80), .plus(80)])
    }

    @Test func enDashRangeAndDecimals() {
        let blocks = WorkoutParser.parse("""
        A.
        3 Deadlift @72.5–75% 1RM Deadlift
        """)
        #expect(blocks.first.map(targets) == [.range(72.5, 75)])
    }

    @Test func prLiftDefaultsToTheMovement() {
        let blocks = WorkoutParser.parse("""
        A.
        3 Back Squat @80%
        """)
        #expect(blocks.first?.prLift == "Back Squat")
    }

    @Test func liftNamesUseAliasesAndIgnoreCase() {
        let blocks = WorkoutParser.parse("""
        A.
        3 back squat @80% 1RM BS
        """)
        #expect(blocks.first?.name == "Back Squat")
        #expect(blocks.first?.prLift == "Back Squat")
    }

    @Test func differentMovementsInOneBlockAreSeparateLifts() {
        let blocks = WorkoutParser.parse("""
        A.
        3 Back Squat @75% 1RM Back Squat
        3 Back Squat @80% 1RM Back Squat
        2 Front Squat @70% 1RM Front Squat
        """)
        #expect(blocks.map(\.name) == ["Back Squat", "Front Squat"])
        #expect(blocks.map(\.letter) == ["A", "A"])
        #expect(blocks.map(\.sets.count) == [2, 1])
    }

    @Test func complexWithNumbersInsideIsOneMovement() {
        let blocks = WorkoutParser.parse("""
        A.
        1 Snatch Pull + 1 Floating Snatch @70% 1RM Snatch
        """)
        #expect(blocks.first?.name == "Snatch Pull + 1 Floating Snatch")
        #expect(blocks.first?.prLift == "Snatch")
        #expect(blocks.first.map(targets) == [.single(70)])
    }

    @Test func minuteEMOMWithOneLineRepeatsIt() {
        let blocks = WorkoutParser.parse("""
        A.
        8 Minute EMOM
        2 Power Clean @70% 1RM Clean
        """)
        #expect(blocks.first?.sets.count == 8)
        #expect(blocks.first?.format == "EMOM")
        #expect(blocks.first?.prLift == "Clean")
    }

    @Test func e2momHalvesTheMinutes() {
        let blocks = WorkoutParser.parse("""
        A.
        E2MOM 10 min
        3 Front Squat @75% 1RM Front Squat
        """)
        #expect(blocks.first?.sets.count == 5)
        #expect(blocks.first?.format == "E2MOM")
    }

    @Test func nSetsWithOneLineRepeatsIt() {
        let blocks = WorkoutParser.parse("""
        A.
        6 Sets
        2 Deadlift @85% 1RM Deadlift
        """)
        #expect(blocks.first?.sets.count == 6)
        #expect(blocks.first?.format == nil)
    }

    @Test func setsByReps() {
        let blocks = WorkoutParser.parse("""
        A.
        5x3 Back Squat @80%
        B.
        4x2 @75% 1RM Snatch
        """)
        #expect(blocks.map(\.name) == ["Back Squat", "Snatch"])
        #expect(blocks.map { $0.sets.count } == [5, 4])
        #expect(blocks.map { $0.sets.first?.reps } == [3, 2])
    }

    @Test func hiddenPercentNeedsAFormatHeaderAndLeftoverFragments() {
        let blocks = WorkoutParser.parse("""
        A.
        5 Sets
        3 Front Squat @8
        B.
        3 Back Squat K checn J Squat
        C.
        5 Minute EMOM
        3 Back Squat
        """)
        #expect(blocks.map(\.letter) == ["A"])                       // B has no header; C has no fragments
        #expect(blocks.first?.pctMissing == true)
        #expect(blocks.first?.sets.count == 5)
    }

    @Test func complexWithoutPercentIsTechniqueNotHiddenPercent() {
        let blocks = WorkoutParser.parse("""
        A.
        4 Sets
        1 Snatch Deadlift to Mid Thigh + 1 Floating Snatch
        """)
        #expect(blocks.isEmpty)
    }

    @Test func screenshotsAreReadInOrderAndJoined() {
        let blocks = WorkoutParser.parse(screenshots: [
            "A.\n5 Minute EMOM",
            "3 Back Squat @75% 1RM Back Squat",
        ])
        #expect(blocks.first?.sets.count == 5)
    }
}

@Suite("Answering a hidden %")
struct TargetParsingTests {
    @Test func acceptedForms() {
        #expect(Target(parsing: "83-85") == .range(83, 85))
        #expect(Target(parsing: " 83 – 85 % ") == .range(83, 85))
        #expect(Target(parsing: "80") == .single(80))
        #expect(Target(parsing: "80%") == .single(80))
        #expect(Target(parsing: "80+") == .plus(80))
        #expect(Target(parsing: "80%+") == .plus(80))
        #expect(Target(parsing: "82,5") == .single(82.5))
    }

    @Test func rejectsNonsense() {
        #expect(Target(parsing: "") == nil)
        #expect(Target(parsing: "abc") == nil)
        #expect(Target(parsing: "85-83") == nil)                     // high below low
    }
}

@Suite("Lift names (SPEC 3.6 rule 7)")
struct LiftNameTests {
    @Test func canonicalNames() {
        #expect(LiftNames.canonical("  back   squat ") == "Back Squat")
        #expect(LiftNames.canonical("BS") == "Back Squat")
        #expect(LiftNames.canonical("Snatch") == "Snatch")
        #expect(LiftNames.canonical("Zercher Squat") == "Zercher Squat")  // unknown lifts are kept
    }
}
