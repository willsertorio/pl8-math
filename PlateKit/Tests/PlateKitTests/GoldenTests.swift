import Testing
@testable import PlateKit

/// Every golden case in Fixtures/README.md, planned end to end.
@Suite("Golden loads (Fixtures/README.md)")
struct GoldenTests {
    static let lbGym = GymSetup(unit: .lb)
    static let kgGym = GymSetup(unit: .kg)

    static func sets(_ reps: Int, _ targets: [Target]) -> [LiftInput.WorkSet] {
        targets.map { LiftInput.WorkSet(reps: reps, target: $0) }
    }

    static let backSquat0110 = LiftInput(name: "Back Squat", pr: 100, prUnit: .kg, sets: sets(3, [
        .range(75, 78), .range(75, 78), .range(78, 80), .range(78, 80), .plus(80),
    ]))
    static let session0210 = [
        LiftInput(name: "Snatch Balance", pr: 100, prUnit: .kg, sets: sets(1, [68, 68, 73, 73, 75, 75].map { .single($0) })),
        LiftInput(name: "Snatch Pull + Snatch", pr: 85, prUnit: .kg, sets: sets(1, [68, 68, 70, 73, 75, 75, 78, 78].map { .single($0) })),
    ]
    static let session0510 = [
        LiftInput(name: "Snatch", pr: 85, prUnit: .kg, sets: sets(1, [
            .range(75, 80), .range(75, 80), .range(75, 80), .range(80, 83), .range(80, 83), .range(80, 83),
        ])),
        LiftInput(name: "Back Squat", pr: 140, prUnit: .kg, sets: sets(2, Array(repeating: .range(83, 85), count: 5))),
    ]

    // MARK: - Summaries in the README's format

    static func text(_ load: Load, _ reps: Int) -> String {
        "\(reps)@\(WeightUnit.trimmed(load.total)) [\(load.perSide.map(WeightUnit.trimmed).joined(separator: "+"))]"
    }
    static func warmUp(_ plan: SessionPlan) -> [String] { plan.warmUp.map { text($0.load, $0.reps) } }
    static func lift(_ plan: SessionPlan, _ index: Int) -> [String] { plan.lifts[index].sets.map { text($0.load, $0.reps) } }
    static func kit(_ plan: SessionPlan) -> [String] { plan.kit.plates.map { "\($0.count)×\(WeightUnit.trimmed($0.size))" } }

    // MARK: - Cases
    // Totals are the box-tested golden values. Since 2026-10-16 the plates per side are chosen for the smallest
    // kit with the fewest plates per set (KitOptimizer), so some arrangements differ from the web prototype's.

    @Test func backSquat0110PoundGym() {
        let plan = SessionPlan(gym: Self.lbGym, lifts: [Self.backSquat0110])
        #expect(Self.warmUp(plan) == ["5@85 [15+5]", "3@120 [35+2.5]", "3@145 [35+15]"])
        #expect(Self.lift(plan, 0) == ["3@170 [55+5+2.5]", "3@170 [55+5+2.5]", "3@175 [55+10]", "3@175 [55+10]", "3@180 [55+10+2.5]"])
        #expect(Self.kit(plan) == ["2×55", "2×35", "2×15", "2×10", "2×5", "2×2.5"])   // no 45s: 35+15 for 145
        #expect(plan.kit.bar == 45)
        // Display: set 1 shows 77.1 kg (PR unit), plates in lb
        #expect(plan.displayTotal(plan.lifts[0].sets[0]) == "77.1 kg")
    }

    @Test func backSquat0110KilogramGym() {
        let plan = SessionPlan(gym: Self.kgGym, lifts: [Self.backSquat0110])
        #expect(Self.warmUp(plan) == ["5@39 [5+2.5+2]", "3@55 [15+2.5]", "3@66 [20+2.5+0.5]"])
        #expect(Self.lift(plan, 0) == ["3@78 [25+2.5+1.5]", "3@78 [25+2.5+1.5]", "3@80 [25+5]", "3@80 [25+5]", "3@80 [25+5]"])
        #expect(Self.kit(plan) == ["2×25", "2×20", "2×15", "2×5", "2×2.5", "2×2", "2×1.5", "2×0.5"])
        #expect(plan.displayTotal(plan.lifts[0].sets[0]) == "78 kg")
    }

    @Test func snatch0210PoundGym() {
        let plan = SessionPlan(gym: Self.lbGym, lifts: Self.session0210)
        #expect(Self.warmUp(plan) == ["5@75 [15]", "3@105 [25+5]", "1@125 [25+15]"])
        #expect(Self.lift(plan, 0) == ["1@150 [45+5+2.5]", "1@150 [45+5+2.5]", "1@160 [55+2.5]", "1@160 [55+2.5]", "1@165 [55+5]", "1@165 [55+5]"])
        #expect(Self.lift(plan, 1) == ["1@125 [25+15]", "1@125 [25+15]", "1@130 [25+15+2.5]", "1@135 [45]", "1@140 [45+2.5]", "1@140 [45+2.5]", "1@145 [45+5]", "1@145 [45+5]"])
        #expect(Self.kit(plan) == ["2×55", "2×45", "2×25", "2×15", "2×5", "2×2.5"])   // no 35s
    }

    @Test func snatch0510PoundGym() {
        let plan = SessionPlan(gym: Self.lbGym, lifts: Self.session0510)
        #expect(Self.warmUp(plan) == ["5@70 [10+2.5]", "3@100 [25+2.5]", "1@125 [25+15]"])
        #expect(Self.lift(plan, 0) == ["1@145 [25+25]", "1@145 [25+25]", "1@145 [25+25]", "1@155 [55]", "1@155 [55]", "1@155 [55]"])
        #expect(Self.lift(plan, 1) == Array(repeating: "2@260 [55+25+25+2.5]", count: 5))
        #expect(Self.kit(plan) == ["2×55", "4×25", "2×15", "2×10", "2×2.5"])   // 12 plates instead of 14
        // Change text, Snatch set 3 → 4
        #expect(plan.lifts[0].sets[3].change.text == "Take off 25 + 25, then add 55 each side")
    }

    @Test func snatch0510KilogramGym() {
        let plan = SessionPlan(gym: Self.kgGym, lifts: Self.session0510)
        #expect(Self.warmUp(plan) == ["5@34 [5+2]", "3@48 [10+2.5+1.5]", "1@58 [15+2.5+1.5]"])
        #expect(Self.lift(plan, 0) == ["1@68 [20+2.5+1.5]", "1@68 [20+2.5+1.5]", "1@68 [20+2.5+1.5]", "1@70 [25]", "1@70 [25]", "1@70 [25]"])
        #expect(Self.lift(plan, 1) == Array(repeating: "2@119 [25+20+2.5+2]", count: 5))
        #expect(Self.kit(plan) == ["2×25", "2×20", "2×15", "2×10", "2×5", "2×2.5", "2×2", "2×1.5"])
    }

    @Test func targetLighterThanTheBar() {
        let snatch = LiftInput(name: "Snatch", pr: 60, prUnit: .kg, sets: Self.sets(3, [.single(20)]))
        let plan = SessionPlan(gym: Self.kgGym, lifts: [snatch])
        #expect(Self.warmUp(plan) == ["5@20 []"])
        #expect(Self.lift(plan, 0) == ["3@20 []"])
        #expect(plan.lifts[0].sets[0].load.isLighterThanBar)
        #expect(plan.kit.plates.isEmpty)
        #expect(plan.kit.bar == 20)
    }

    @Test func missingSmallPlates() {
        let gym = GymSetup(unit: .lb, plateSizes: [45, 35, 25, 15, 10])
        let squat = LiftInput(name: "Back Squat", pr: 100, prUnit: .kg, sets: Self.sets(5, [.range(75, 78)]))
        let plan = SessionPlan(gym: gym, lifts: [squat])
        #expect(Self.warmUp(plan) == ["5@85 [10+10]", "5@115 [35]", "5@145 [35+15]"])
        #expect(Self.lift(plan, 0) == ["5@165 [35+25]"])
        #expect(Self.kit(plan) == ["2×35", "2×25", "2×15", "4×10"])
    }
}

@Suite("Session plan")
struct SessionPlanTests {
    @Test func everySetSaysWhatChangesFromTheOneBefore() {
        let plan = SessionPlan(gym: GymSetup(unit: .lb), lifts: [GoldenTests.backSquat0110])
        #expect(plan.warmUp[0].change.text == "Add 15 + 5 each side")      // from the empty bar
        #expect(plan.lifts[0].sets[0].change.text == "Take off 15 + 35, then add 55 + 5 + 2.5 each side")
        #expect(plan.lifts[0].sets[1].change.isSame)
    }

    @Test func noLiftsMeansNoWarmUp() {
        let plan = SessionPlan(gym: GymSetup(unit: .kg), lifts: [])
        #expect(plan.warmUp.isEmpty)
        #expect(plan.kit.plates.isEmpty)
    }
}

@Suite("Set records for history (SPEC Part 4 SetLog)")
struct SetRecordTests {
    @Test func warmUpThenEveryWorkingSetInOrder() {
        let plan = SessionPlan(gym: GymSetup(unit: .lb), lifts: GoldenTests.session0510)
        let records = plan.setRecords
        #expect(records.count == 3 + 6 + 5)

        let first = records[0]
        #expect(first.isWarmUp)
        #expect(first.blockIndex == 0)
        #expect(first.setIndex == 0)
        #expect(first.reps == 5)
        #expect(first.pctText == "≈37% 1RM")                       // 70 lb of 187.4 lb
        #expect(first.plannedTotal == 70)
        #expect(first.unit == .lb)
        #expect(first.perSide == [10, 2.5])

        let squat = records[9]
        #expect(!squat.isWarmUp)
        #expect(squat.blockIndex == 1)
        #expect(squat.setIndex == 0)
        #expect(squat.reps == 2)
        #expect(squat.pctText == "83–85%")
        #expect(squat.plannedTotal == 260)
        #expect(squat.perSide == [55, 25, 25, 2.5])

        #expect(records.last?.setIndex == 4)
    }

    @Test func heaviestSet() {
        let plan = SessionPlan(gym: GymSetup(unit: .lb), lifts: GoldenTests.session0510)
        #expect(plan.heaviestSet?.plannedTotal == 260)
        #expect(SessionPlan(gym: GymSetup(unit: .kg), lifts: []).heaviestSet == nil)
    }
}
