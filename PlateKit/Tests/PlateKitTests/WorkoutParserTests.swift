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

    // The B sets wrap over 3 lines each on the phone.
    @Test func workout1410WrappedLines() throws {
        let blocks = WorkoutParser.parse(try fixture("2026-10-14.screen.txt"))
        #expect(blocks.map(\.letter) == ["A", "B", "C"])             // D is cut off

        // A is RPE-based: % missing, RPE 5 remembered, 50% suggested.
        let a = blocks[0]
        #expect(a.name == "Muscle Clean + 3 Hang Power Clean to Parallel Catch + 3 Tall Cleans")
        #expect(a.prLift == "Clean")
        #expect(a.sets.map(\.reps) == [3, 3, 3])
        #expect(a.pctMissing)
        #expect(a.rpe == 5)
        #expect(a.suggestedTarget == .single(50))
        #expect(a.note == "Rest 90 seconds between sets")

        let b = blocks[1]
        #expect(b.name == "Clean Pull + 1 Hang Power Clean + 1 Floating Power Clean + 1 Power Clean")
        #expect(b.prLift == "Power Clean")
        #expect(b.sets.map(\.reps) == [1, 1, 1])
        #expect(targets(b) == [.range(68, 70), .range(73, 75), .range(75, 78)])
        #expect(b.note == "Rest as needed between sets")

        let c = blocks[2]
        #expect(c.name == "Power Clean")
        #expect(c.format == "EMOM")
        #expect(c.sets.map(\.reps) == [2, 2, 2, 1, 1])
        #expect(targets(c) == [.single(80), .single(83), .single(85), .plus(85), .plus(85)])
    }

    // Two overlapping screenshots, picked in either order.
    @Test(arguments: [false, true])
    func workout1410TwoScreenshots(bottomFirst: Bool) throws {
        let top = try fixture("2026-10-14-top.vision.txt")
        let bottom = try fixture("2026-10-14-bottom.vision.txt")
        let blocks = WorkoutParser.parse(screenshots: bottomFirst ? [bottom, top] : [top, bottom])
        #expect(blocks.map(\.letter) == ["A", "B", "C", "E"])        // in letter order; D has fixed loads only

        #expect(blocks[2].name == "Power Clean")
        #expect(blocks[2].sets.count == 5)                            // the overlap isn't counted twice

        let e = blocks[3]
        #expect(e.label == "After Party")
        #expect(e.name == "Deadlift")
        #expect(e.prLift == "Deadlift")                               // not ")"
        #expect(e.sets.map(\.reps) == [10, 5])
        #expect(targets(e) == [.single(60), .single(65)])
        #expect(e.note?.hasPrefix("1000m Bike Erg OR 24/19 cal Echo Bike between sets") == true)
        #expect(e.note?.contains("Check-In") == false)                // app buttons aren't notes
    }

    @Test func percentWrappedOnItsOwnLine() {
        let blocks = WorkoutParser.parse("A.\n1 Clean Pull + 1 Power Clean\n@68-70%\n1RM Power Clean")
        #expect(blocks.first?.prLift == "Power Clean")
        #expect(blocks.first.map(targets) == [.range(68, 70)])
    }

    @Test func fixedLoadsAndOrAreNotPartOfTheName() {
        let blocks = WorkoutParser.parse("A.\n5 Front Squat (185/125) or 70% 1RM Front Squat")
        #expect(blocks.first?.name == "Front Squat")
        #expect(blocks.first?.prLift == "Front Squat")
    }

    @Test func liftAfter1RMOnTheNextLine() {
        let blocks = WorkoutParser.parse("A.\n3 Front Squat @80%\n1RM Front Squat\n3 Front Squat @82%\n1RM Front Squat")
        #expect(blocks.first?.sets.count == 2)
        #expect(blocks.first?.prLift == "Front Squat")
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

@Suite("Typed workout (SPEC 2.2 'Type it in', simple form)")
struct TypedBlockTests {
    @Test func oneLiftWithSetsRepsAndOnePercent() {
        let block = StrengthBlock.typed(letter: "A", lift: " back squat ", sets: 5, reps: 3, target: .range(75, 78))
        #expect(block.letter == "A")
        #expect(block.name == "Back Squat")
        #expect(block.prLift == "Back Squat")
        #expect(block.format == nil)
        #expect(block.sets == Array(repeating: ParsedSet(reps: 3, target: .range(75, 78)), count: 5))
        #expect(!block.pctMissing)
    }

    @Test func atLeastOneSetAndOneRep() {
        let block = StrengthBlock.typed(letter: "B", lift: "Snatch", sets: 0, reps: 0, target: .single(70))
        #expect(block.sets == [ParsedSet(reps: 1, target: .single(70))])
    }
}

@Suite("Editing a block's %")
struct SettingPercentTests {
    @Test func everySetGetsTheNewPercent() {
        let block = StrengthBlock.typed(letter: "A", lift: "Snatch", sets: 3, reps: 1, target: .single(70))
        let edited = block.settingPercent(.range(75, 80))
        #expect(edited.sets == Array(repeating: ParsedSet(reps: 1, target: .range(75, 80)), count: 3))
        #expect(edited.name == "Snatch")
    }
}

@Suite("RPE (suggested % = RPE × 10)")
struct RPETests {
    @Test func rpeForms() {
        let blocks = WorkoutParser.parse("""
        A.
        3 Front Squat @ RPE 8
        B.
        2 Deadlift @7.5/10 RPE
        C.
        1 Snatch @9 RPE
        """)
        #expect(blocks.map(\.rpe) == [8, 7.5, 9])
        #expect(blocks.map(\.suggestedTarget) == [.single(80), .single(75), .single(90)])
        #expect(blocks.allSatisfy { $0.pctMissing })
        #expect(blocks.map(\.prLift) == ["Front Squat", "Deadlift", "Snatch"])
    }

    @Test func needsTheAtSignAndAValidRPE() {
        let blocks = WorkoutParser.parse("""
        A.
        5 Sets
        10 Back Squats (225/155) (RPE 8)
        B.
        3 Front Squat @ RPE 12
        """)
        #expect(blocks.isEmpty)
    }

    @Test func answeringKeepsTheRPE() {
        let block = WorkoutParser.parse("A.\n3 Front Squat @ RPE 8")[0]
        let filled = block.fillingMissingPercent(with: .single(78))
        #expect(!filled.pctMissing)
        #expect(filled.rpe == 8)
    }

    @Test func changingThePRLift() {
        let block = WorkoutParser.parse("A.\n3 Muscle Clean + 3 Tall Cleans @ 5/10 RPE")[0]
        #expect(block.prLift == "Clean")
        #expect(block.settingPRLift("power clean").prLift == "Power Clean")
    }
}

@Suite("First known lift in a line")
struct FirstKnownLiftTests {
    @Test func earliestWholeWordMatch() {
        #expect(LiftNames.firstKnown(in: "Muscle Clean + 3 Hang Power Clean") == "Clean")
        #expect(LiftNames.firstKnown(in: "Tall Cleans + Snatch Balance") == "Snatch Balance")
        #expect(LiftNames.firstKnown(in: "Wall Walks") == nil)
    }
}

@Suite("Repairing saved blocks")
struct RepairTests {
    // Workouts saved before the 14/10 fix have prLift ")" and the brackets in the name.
    @Test func prLiftWithoutLettersFallsBackToTheMovement() {
        let old = StrengthBlock.typed(letter: "E", lift: "Deadlift (315/225) (OR", sets: 1, reps: 10, target: .single(60))
            .settingPRLift(")")
        #expect(old.prLift == ")")
        #expect(old.repaired().prLift == "Deadlift")
    }

    @Test func goodBlocksAreUnchanged() {
        let block = StrengthBlock.typed(letter: "A", lift: "Snatch", sets: 3, reps: 1, target: .single(70))
        #expect(block.repaired() == block)
    }
}
