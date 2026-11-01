import Testing
@testable import PlateKit

@Suite("Warm-up (SPEC 3.4)")
struct WarmUpTests {
    let lbGym = PlateSolver(gym: GymSetup(unit: .lb))
    let kgGym = PlateSolver(gym: GymSetup(unit: .kg))

    /// "reps@total [plates]" for each round, like Fixtures/README.md.
    func summary(_ rounds: [WarmUpRound]) -> [String] {
        rounds.map { round in
            let plates = round.load.perSide.map { WeightUnit.trimmed($0) }.joined(separator: "+")
            return "\(round.reps)@\(WeightUnit.trimmed(round.load.total)) [\(plates)]"
        }
    }

    // Fixtures 01/10 · Back Squat PR 100 kg · first working set 3@170 lb
    @Test func backSquatInPounds() {
        let rounds = lbGym.warmUp(before: Load(total: 170, perSide: [55, 5, 2.5]), reps: 3, pr: 100, prUnit: .kg)
        #expect(summary(rounds) == ["5@85 [15+5]", "3@120 [35+2.5]", "3@145 [45+5]"])
    }

    // Fixtures 01/10 · kg gym · first working set 3@78 kg
    @Test func backSquatInKilograms() {
        let rounds = kgGym.warmUp(before: Load(total: 78, perSide: [25, 2.5, 1.5]), reps: 3, pr: 100, prUnit: .kg)
        #expect(summary(rounds) == ["5@39 [5+2.5+2]", "3@55 [15+2.5]", "3@66 [20+2.5+0.5]"])
    }

    // Fixtures 02/10 · Snatch Balance PR 100 kg · first working set 1@150 lb
    @Test func singlesGetFiveThreeOne() {
        let rounds = lbGym.warmUp(before: Load(total: 150, perSide: [45, 5, 2.5]), reps: 1, pr: 100, prUnit: .kg)
        #expect(summary(rounds) == ["5@75 [15]", "3@105 [25+5]", "1@125 [35+5]"])
    }

    // Fixtures 05/10 · Snatch PR 85 kg · first working set 1@145 lb
    @Test func snatchInPounds() {
        let rounds = lbGym.warmUp(before: Load(total: 145, perSide: [45, 5]), reps: 1, pr: 85, prUnit: .kg)
        #expect(summary(rounds) == ["5@70 [10+2.5]", "3@100 [25+2.5]", "1@125 [35+5]"])
    }

    // Fixtures 05/10 · kg gym · first working set 1@68 kg
    @Test func snatchInKilograms() {
        let rounds = kgGym.warmUp(before: Load(total: 68, perSide: [20, 2.5, 1.5]), reps: 1, pr: 85, prUnit: .kg)
        #expect(summary(rounds) == ["5@34 [5+2]", "3@48 [10+2.5+1.5]", "1@58 [15+2.5+1.5]"])
    }

    // Fixtures edge: missing small plates · first working set 5@165 lb
    @Test func fiveRepSetsKeepFiveRepsEveryRound() {
        let gym = PlateSolver(gym: GymSetup(unit: .lb, plateSizes: [45, 35, 25, 15, 10]))
        let rounds = gym.warmUp(before: Load(total: 165, perSide: [45, 15]), reps: 5, pr: 100, prUnit: .kg)
        #expect(summary(rounds) == ["5@85 [10+10]", "5@115 [35]", "5@145 [35+15]"])
    }

    // Fixtures edge: first working set is the empty bar
    @Test func noRoundSurvivesSoOneRoundOfFiveWithTheEmptyBar() {
        let first = Load(total: 20, perSide: [], isLighterThanBar: true)
        let rounds = kgGym.warmUp(before: first, reps: 3, pr: 60, prUnit: .kg)
        #expect(summary(rounds) == ["5@20 []"])
    }

    @Test func roundsThatDoNotClimbAreDropped() {
        // Only 45s: 50% of 225 → 135; 70% → 135 again (dropped); 85% → 225, not lighter than the set (dropped).
        let gym = PlateSolver(gym: GymSetup(unit: .lb, plateSizes: [45]))
        let rounds = gym.warmUp(before: Load(total: 225, perSide: [45, 45]), reps: 3, pr: 300, prUnit: .lb)
        #expect(summary(rounds) == ["5@135 [45]"])
    }

    @Test func roundsAreNumberedWithPercentOfMax() {
        let rounds = kgGym.warmUp(before: Load(total: 78, perSide: [25, 2.5, 1.5]), reps: 3, pr: 100, prUnit: .kg)
        #expect(rounds.map(\.label) == ["Round 1", "Round 2", "Round 3"])
        #expect(rounds.map(\.percentText) == ["≈39% 1RM", "≈55% 1RM", "≈66% 1RM"])
    }

    @Test func percentOfMaxUsesThePRInTheGymUnit() {
        // 145 lb of a 100 kg (220.5 lb) PR is 65.8% → ≈66%
        let rounds = lbGym.warmUp(before: Load(total: 170, perSide: [55, 5, 2.5]), reps: 3, pr: 100, prUnit: .kg)
        #expect(rounds.last?.percentText == "≈66% 1RM")
    }

    @Test func zeroPRDoesNotCrash() {
        let rounds = kgGym.warmUp(before: Load(total: 78, perSide: [25, 2.5, 1.5]), reps: 3, pr: 0, prUnit: .kg)
        #expect(rounds.map(\.percentOfMax) == [0, 0, 0])
    }
}
