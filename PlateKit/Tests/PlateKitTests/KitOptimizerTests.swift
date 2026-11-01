import Testing
@testable import PlateKit

@Suite("Fewest plates in the kit (SPEC 3.5, from Will's first real class)")
struct KitOptimizerTests {
    let kg = GymSetup(unit: .kg)

    func kitPlates(_ loads: [Load]) -> Int {
        Kit(bar: 20, loads: loads).plates.map(\.count).reduce(0, +)
    }

    @Test func picksCombinationsThatShareTheSamePlates() {
        // Per side 35, 40, 45 kg. Larger-plates-first gives 25+10, 25+15, 25+20: four sizes, a kit of 8.
        // 20+15, 25+15, 25+20 are just as short and need only 25, 20 and 15: a kit of 6.
        let solver = PlateSolver(gym: kg)
        let loads = [90.0, 100, 110].map { total in Load(total: total, perSide: solver.perSide((total - 20) / 2)!) }
        #expect(kitPlates(loads) == 8)
        let optimized = KitOptimizer.arrange(loads, plates: kg.plateSizes)
        #expect(kitPlates(optimized) == 6)
        #expect(optimized.map(\.total) == [90, 100, 110])                     // the loads stay the same
        for (load, before) in zip(optimized, loads) {
            #expect(20 + 2 * load.perSide.reduce(0, +) == load.total)
            #expect(load.perSide.count == before.perSide.count)              // no more plates on the bar
            #expect(load.perSide == load.perSide.sorted(by: >))              // heaviest inside
        }
    }

    @Test func canTradeAPlateOnTheBarForASmallerKitWhenAsked() {
        let solver = PlateSolver(gym: kg)
        let loads = [80.0, 90, 100].map { total in Load(total: total, perSide: solver.perSide((total - 20) / 2)!) }
        #expect(kitPlates(KitOptimizer.arrange(loads, plates: kg.plateSizes)) == 8)
        #expect(kitPlates(KitOptimizer.arrange(loads, plates: kg.plateSizes, extraPlates: 1)) == 6)   // 25+10+5 for 100
    }

    @Test func neverMoreThanFewestPerSet() {
        let solver = PlateSolver(gym: kg)
        let totals: [Double] = [40, 60, 70, 75, 85, 95, 105, 110]
        let loads = totals.map { Load(total: $0, perSide: solver.perSide(($0 - 20) / 2)!) }
        let optimized = KitOptimizer.arrange(loads, plates: kg.plateSizes)
        #expect(kitPlates(optimized) <= kitPlates(loads))
        #expect(optimized.map(\.total) == totals)
    }

    @Test func amongEqualKitsFewerChangesWin() {
        // 35 then 40 a side: 20+15 → 20+20 or 25+10 → 25+15 keep the inner plate on (2 changes);
        // 20+15 → 25+15 would take both off.
        let loads = [Load(total: 90, perSide: [25, 10]), Load(total: 100, perSide: [25, 15])]
        let optimized = KitOptimizer.arrange(loads, plates: kg.plateSizes)
        #expect(optimized[0].perSide[0] == optimized[1].perSide[0])
        #expect(kitPlates(optimized) == 6)
    }

    @Test func emptyBarAndLighterThanBarStayAsTheyAre() {
        let loads = [Load(total: 20, perSide: []), Load(total: 20, perSide: [], isLighterThanBar: true)]
        #expect(KitOptimizer.arrange(loads, plates: kg.plateSizes) == loads)
    }

    @Test func sessionPlanUsesTheSmallerKit() {
        let lift = LiftInput(name: "Back Squat", pr: 100, prUnit: .kg, sets: [
            LiftInput.WorkSet(reps: 3, target: Target(low: 80)),
            LiftInput.WorkSet(reps: 3, target: Target(low: 90)),
            LiftInput.WorkSet(reps: 3, target: Target(low: 100)),
        ])
        let plan = SessionPlan(gym: kg, lifts: [lift])
        #expect(plan.lifts[0].sets.map(\.load.total) == [80, 90, 100])
        let solver = PlateSolver(gym: kg)
        let fewestEach = plan.setRecords.map { Load(total: $0.plannedTotal, perSide: solver.perSide(($0.plannedTotal - 20) / 2)!) }
        #expect(plan.kit.plates.map(\.count).reduce(0, +) < kitPlates(fewestEach))
    }
}
