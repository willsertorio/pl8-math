import Foundation
import Testing
@testable import PlateKit

/// Fixed weights (`Strict press 4x6 @ 40kg`) are planned too (SPEC 3.6 rule 10, DECISIONS 2026-11-01): the weight
/// is the load, so no PR is needed.
struct FixedWeightTests {
    let kgGym = GymSetup(unit: .kg)
    let lbGym = GymSetup(unit: .lb)

    @Test func aWhiteboardFixedWeightIsPlanned() {
        let blocks = WorkoutParser.parse(screenshots: ["Strict press 4x6 @ 40kg"])
        #expect(blocks.count == 1)
        #expect(blocks.first?.prLift == "Strict Press")
        #expect(blocks.first?.sets == Array(repeating: ParsedSet(reps: 6, target: .weight(40, unit: .kg)), count: 4))
        #expect(blocks.first?.pctMissing == false)
    }

    @Test func theBoxAppsWODLoadsStayIgnored() {
        // Rule 3 is unchanged for the box app: a block with no % lines is a WOD, even with loads like (50/35).
        #expect(WorkoutParser.parse("A. WOD\n21 Thrusters (43/29)\n15 Pull-ups").isEmpty)
    }

    @Test func itsTextIsTheWeight() {
        #expect(Target.weight(40, unit: .kg).text == "40 kg")
        #expect(Target.weight(102.5, unit: .lb).text == "102.5 lb")
        #expect(Target.weight(40, unit: nil).text == "40")
        #expect(Target.weight(40, unit: .kg).isFixed)
        #expect(!Target.single(75).isFixed)
    }

    @Test func theWeightIsTheLoadWithoutAPR() {
        let load = PlateSolver(gym: kgGym).load(for: .weight(40, unit: .kg), pr: 0, prUnit: .kg)
        #expect(load.total == 40)
        #expect(load.perSide == [10])
        #expect(!load.isLighterThanBar)
    }

    @Test func aPRDoesNotChangeIt() {
        let load = PlateSolver(gym: kgGym).load(for: .weight(60, unit: .kg), pr: 150, prUnit: .kg)
        #expect(load.total == 60)
    }

    @Test func otherUnitsAreConvertedToTheNearestLoad() {
        // 40 kg = 88.2 lb → 90 lb on a 45 lb bar.
        #expect(PlateSolver(gym: lbGym).load(for: .weight(40, unit: .kg), pr: 0, prUnit: .kg).total == 90)
        // No unit written: the gym's.
        #expect(PlateSolver(gym: lbGym).load(for: .weight(95, unit: nil), pr: 0, prUnit: .kg).total == 95)
    }

    @Test func lighterThanTheBarIsTheBar() {
        let load = PlateSolver(gym: kgGym).load(for: .weight(15, unit: .kg), pr: 0, prUnit: .kg)
        #expect(load.total == 20)
        #expect(load.isLighterThanBar)
    }

    @Test func theWarmUpWithoutAPRSaysWarmUp() {
        let lift = LiftInput(name: "Strict Press", pr: 0, prUnit: .kg, sets: Array(repeating: .init(reps: 6, target: .weight(60, unit: .kg)), count: 4))
        let plan = SessionPlan(gym: kgGym, lifts: [lift])
        #expect(!plan.warmUp.isEmpty)
        #expect(plan.warmUp.allSatisfy { $0.round.percentText == "Warm-up" })
        #expect(plan.lifts[0].sets.map(\.load.total) == [60, 60, 60, 60])
        #expect(plan.setRecords.last?.pctText == "60 kg")
    }

    @Test func savedTargetsStillDecode() throws {
        let old = try JSONDecoder().decode(Target.self, from: Data(#"{"low":75,"plus":false}"#.utf8))
        #expect(old == .single(75))
        let fixed = Target.weight(40, unit: .kg)
        #expect(try JSONDecoder().decode(Target.self, from: JSONEncoder().encode(fixed)) == fixed)
    }
}
