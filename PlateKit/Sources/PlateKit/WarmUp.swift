/// One warm-up round before the first lift (SPEC 3.4).
public struct WarmUpRound: Hashable, Sendable {
    /// 1, 2, 3…
    public let number: Int
    public let reps: Int
    public let load: Load
    /// The load as a whole-number percentage of the PR, for "≈N% 1RM".
    public let percentOfMax: Int

    public var label: String { "Round \(number)" }
    public var percentText: String { "≈\(percentOfMax)% 1RM" }
}

extension PlateSolver {
    /// Three rounds aimed at 50%, 70% and 85% of the first working set, each the nearest loadable total.
    /// A round is dropped if it isn't heavier than the round before or isn't lighter than the working set.
    /// If none survive, one round of 5 with the empty bar.
    /// - Parameters:
    ///   - first: the first working set of the first lift.
    ///   - reps: reps of that set.
    ///   - pr, prUnit: that lift's PR, for the "≈N% 1RM" label.
    public func warmUp(before first: Load, reps: Int, pr: Double, prUnit: WeightUnit) -> [WarmUpRound] {
        let plan: [(fraction: Double, reps: Int)] = [(0.50, max(5, reps)), (0.70, max(3, reps)), (0.85, reps)]
        var loads: [(reps: Int, load: Load)] = []
        for step in plan {
            let load = nearestLoad(to: first.total * step.fraction)
            let previous = loads.last?.load.total ?? -Double.infinity
            if load.total > previous && load.total < first.total {
                loads.append((step.reps, load))
            }
        }
        if loads.isEmpty {
            loads = [(5, Load(total: gym.barWeight, perSide: []))]
        }

        let max = prUnit.convert(pr, to: gym.unit)
        return loads.enumerated().map { index, round in
            WarmUpRound(
                number: index + 1,
                reps: round.reps,
                load: round.load,
                percentOfMax: max > 0 ? Int((round.load.total / max * 100).rounded()) : 0
            )
        }
    }
}
