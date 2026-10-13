/// One lift of today's workout, as the planner needs it: its PR and its working sets.
public struct LiftInput: Hashable, Sendable {
    public struct WorkSet: Hashable, Sendable {
        public let reps: Int
        public let target: Target

        public init(reps: Int, target: Target) {
            self.reps = reps
            self.target = target
        }
    }

    public let name: String
    public let pr: Double
    public let prUnit: WeightUnit
    public let sets: [WorkSet]

    public init(name: String, pr: Double, prUnit: WeightUnit, sets: [WorkSet]) {
        self.name = name
        self.pr = pr
        self.prUnit = prUnit
        self.sets = sets
    }
}

/// A whole session in a gym: warm-up, every working set, what changes before each set, and the plate kit (SPEC 3.3–3.5).
public struct SessionPlan: Hashable, Sendable {
    public struct WarmUpSet: Hashable, Sendable {
        public let round: WarmUpRound
        /// From the set before (the empty bar for the very first).
        public let change: SetChange

        public var reps: Int { round.reps }
        public var load: Load { round.load }
    }

    public struct WorkingSet: Hashable, Sendable {
        /// 1, 2, 3… within its lift.
        public let number: Int
        public let reps: Int
        public let target: Target
        public let load: Load
        /// The unit the lift's PR is in; totals are shown in it.
        public let prUnit: WeightUnit
        /// From the set before, across lifts too (same bar).
        public let change: SetChange
    }

    public struct Lift: Hashable, Sendable {
        public let name: String
        public let prUnit: WeightUnit
        public let sets: [WorkingSet]
    }

    public let gym: GymSetup
    /// Before the first lift only.
    public let warmUp: [WarmUpSet]
    public let lifts: [Lift]
    public let kit: Kit

    public init(gym: GymSetup, lifts inputs: [LiftInput]) {
        let solver = PlateSolver(gym: gym)
        var previous: [Double] = []
        func change(to load: Load) -> SetChange {
            defer { previous = load.perSide }
            return SetChange(from: previous, to: load.perSide)
        }

        // Working loads first: the warm-up climbs to the first one.
        let loads = inputs.map { lift in
            lift.sets.map { solver.load(for: $0.target, pr: lift.pr, prUnit: lift.prUnit) }
        }

        var warmUp: [WarmUpSet] = []
        if let first = inputs.first, let firstSet = first.sets.first {
            let rounds = solver.warmUp(before: loads[0][0], reps: firstSet.reps, pr: first.pr, prUnit: first.prUnit)
            warmUp = rounds.map { WarmUpSet(round: $0, change: change(to: $0.load)) }
        }

        var lifts: [Lift] = []
        for (input, liftLoads) in zip(inputs, loads) {
            var sets: [WorkingSet] = []
            for (index, (workSet, load)) in zip(input.sets, liftLoads).enumerated() {
                sets.append(WorkingSet(number: index + 1, reps: workSet.reps, target: workSet.target, load: load, prUnit: input.prUnit, change: change(to: load)))
            }
            lifts.append(Lift(name: input.name, prUnit: input.prUnit, sets: sets))
        }

        self.gym = gym
        self.warmUp = warmUp
        self.lifts = lifts
        self.kit = Kit(bar: gym.barWeight, loads: warmUp.map(\.load) + loads.flatMap { $0 })
    }

    /// A set's total in its PR's unit, e.g. "77.1 kg" for 170 lb (SPEC 3.2).
    public func displayTotal(_ set: WorkingSet) -> String {
        gym.unit.display(set.load.total, in: set.prUnit)
    }
}
