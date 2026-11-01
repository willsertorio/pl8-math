import Testing
@testable import PlateKit

@Suite("Plates per side (SPEC 3.3 rule 2)")
struct PerSideTests {
    let lbGym = PlateSolver(gym: GymSetup(unit: .lb))
    let kgGym = PlateSolver(gym: GymSetup(unit: .kg))

    @Test func emptySideNeedsNoPlates() {
        #expect(lbGym.perSide(0) == [])
    }

    @Test func fewestPlatesThenLargerPlatesHeaviestFirst() {
        #expect(lbGym.perSide(62.5) == [55, 5, 2.5])       // not 45 + 15 + 2.5
        #expect(lbGym.perSide(107.5) == [55, 45, 5, 2.5])
        #expect(kgGym.perSide(29) == [25, 2.5, 1.5])        // not 25 + 2 + 2
        #expect(kgGym.perSide(49.5) == [25, 20, 2.5, 2])
    }

    @Test func fewestPlatesBeatsGrabbingTheBiggestFirst() {
        let gym = PlateSolver(gym: GymSetup(unit: .kg, plateSizes: [20, 15, 5]))
        #expect(gym.perSide(30) == [15, 15])                // 2 plates, not 20 + 5 + 5
    }

    @Test func impossibleSideIsNil() {
        #expect(lbGym.perSide(1) == nil)
        let noSmallPlates = PlateSolver(gym: GymSetup(unit: .lb, plateSizes: [45, 35, 25, 15, 10]))
        #expect(noSmallPlates.perSide(62.5) == nil)
    }
}

@Suite("One load (SPEC 3.3)")
struct LoadTests {
    let lbGym = PlateSolver(gym: GymSetup(unit: .lb))
    let kgGym = PlateSolver(gym: GymSetup(unit: .kg))

    // Fixtures 01/10 · Back Squat PR 100 kg · lb gym, 45 lb bar
    @Test func rangePicksHeaviestLoadInside() {
        let load = lbGym.load(for: .range(75, 78), pr: 100, prUnit: .kg)
        #expect(load == Load(total: 170, perSide: [55, 5, 2.5]))
        #expect(lbGym.load(for: .range(78, 80), pr: 100, prUnit: .kg) == Load(total: 175, perSide: [55, 10]))
    }

    @Test func plusPicksLightestLoadAtOrAbove() {
        #expect(lbGym.load(for: .plus(80), pr: 100, prUnit: .kg) == Load(total: 180, perSide: [55, 10, 2.5]))
        // 80% of 100 kg is exactly loadable in a kg gym.
        #expect(kgGym.load(for: .plus(80), pr: 100, prUnit: .kg) == Load(total: 80, perSide: [25, 5]))
    }

    // Fixtures 01/10 · same PR · kg gym
    @Test func rangeInKilograms() {
        #expect(kgGym.load(for: .range(75, 78), pr: 100, prUnit: .kg) == Load(total: 78, perSide: [25, 2.5, 1.5]))
        #expect(kgGym.load(for: .range(78, 80), pr: 100, prUnit: .kg) == Load(total: 80, perSide: [25, 5]))
    }

    // Fixtures edge: lb gym with only 45, 35, 25, 15, 10 → nothing loadable in 165.3–172.0
    @Test func rangeWithNothingInsidePicksNearestToTheMiddle() {
        let gym = PlateSolver(gym: GymSetup(unit: .lb, plateSizes: [45, 35, 25, 15, 10]))
        #expect(gym.load(for: .range(75, 78), pr: 100, prUnit: .kg) == Load(total: 165, perSide: [45, 15]))
    }

    @Test func rangeTieAtTheMiddlePicksLighter() {
        // Only 45s: loadable 45, 135, 225. 89–91% of 200 lb has middle 180, 45 from both.
        let gym = PlateSolver(gym: GymSetup(unit: .lb, plateSizes: [45]))
        #expect(gym.load(for: .range(89, 91), pr: 200, prUnit: .lb).total == 135)
    }

    // Fixtures 02/10 · Snatch PR 85 kg · lb gym: 68% = 127.4 lb, 73% = 136.8 lb
    @Test func singlePicksNearest() {
        #expect(lbGym.load(for: .single(68), pr: 85, prUnit: .kg) == Load(total: 125, perSide: [35, 5]))
        #expect(lbGym.load(for: .single(73), pr: 85, prUnit: .kg) == Load(total: 135, perSide: [45]))
    }

    // Fixtures 05/10 warm-up: 72.5 lb is halfway between 70 and 75
    @Test func nearestTiePicksLighter() {
        #expect(lbGym.nearestLoad(to: 72.5) == Load(total: 70, perSide: [10, 2.5]))
    }

    // Fixtures edge: Snatch PR 60 kg @20% = 12 kg, 20 kg bar
    @Test func targetLighterThanTheBarLoadsTheEmptyBarAndFlagsIt() {
        let load = kgGym.load(for: .single(20), pr: 60, prUnit: .kg)
        #expect(load == Load(total: 20, perSide: [], isLighterThanBar: true))
    }

    @Test func normalLoadIsNotFlagged() {
        #expect(kgGym.load(for: .single(50), pr: 60, prUnit: .kg).isLighterThanBar == false)
    }

    @Test func prInPoundsLoadedInAKilogramGym() {
        // 225 lb PR @ 80% = 180 lb = 81.6 kg → nearest loadable 82 kg (31 a side)
        #expect(kgGym.load(for: .single(80), pr: 225, prUnit: .lb) == Load(total: 82, perSide: [25, 5, 1]))
    }
}

@Suite("Target text")
struct TargetTextTests {
    @Test func rangePlusAndSingle() {
        #expect(Target.range(75, 78).text == "75–78%")
        #expect(Target.plus(80).text == "80%+")
        #expect(Target.single(68).text == "68%")
        #expect(Target.single(82.5).text == "82.5%")
    }
}
