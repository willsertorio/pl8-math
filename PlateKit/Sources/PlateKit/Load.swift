/// A set's target as a percentage of 1RM: `75–78%`, `80%+` or `80%` (SPEC 3.3).
public struct Target: Hashable, Codable, Sendable {
    public let low: Double
    public let high: Double?
    public let plus: Bool

    public init(low: Double, high: Double? = nil, plus: Bool = false) {
        self.low = low
        self.high = high
        self.plus = plus
    }

    /// `75–78%`
    public static func range(_ low: Double, _ high: Double) -> Target { Target(low: low, high: high) }
    /// `80%+`
    public static func plus(_ low: Double) -> Target { Target(low: low, plus: true) }
    /// `80%`
    public static func single(_ percent: Double) -> Target { Target(low: percent) }

    /// "75–78%", "80%+" or "80%".
    public var text: String {
        let low = WeightUnit.trimmed(self.low)
        if plus { return "\(low)%+" }
        if let high, high != self.low { return "\(low)–\(WeightUnit.trimmed(high))%" }
        return "\(low)%"
    }
}

/// What goes on the bar: the total (bar included) and the plates on one side, heaviest (innermost) first.
public struct Load: Hashable, Sendable {
    public let total: Double
    public let perSide: [Double]
    /// The target was lighter than the empty bar, so this is just the bar.
    public let isLighterThanBar: Bool

    public init(total: Double, perSide: [Double], isLighterThanBar: Bool = false) {
        self.total = total
        self.perSide = perSide
        self.isLighterThanBar = isLighterThanBar
    }
}

/// Turns targets into loads a gym's plates can make (SPEC 3.3). Plates per side are unlimited.
public struct PlateSolver: Sendable {
    public let gym: GymSetup

    public init(gym: GymSetup) {
        self.gym = gym
    }

    /// The load for `target`, with the PR converted to the gym's unit.
    public func load(for target: Target, pr: Double, prUnit: WeightUnit) -> Load {
        let max = prUnit.convert(pr, to: gym.unit)
        let low = max * target.low / 100
        let high = target.high.map { max * $0 / 100 }
        if (high ?? low) < gym.barWeight - tolerance {
            return Load(total: gym.barWeight, perSide: [], isLighterThanBar: true)
        }
        let candidates = loadable(upTo: high ?? low)
        if target.plus {
            return candidates.first { $0.total >= low - tolerance } ?? candidates[candidates.count - 1]
        }
        if let high {
            let inside = candidates.filter { $0.total >= low - tolerance && $0.total <= high + tolerance }
            return inside.last ?? nearest(in: candidates, to: (low + high) / 2)
        }
        return nearest(in: candidates, to: low)
    }

    /// The loadable total nearest to `total` (in the gym's unit); ties go to the lighter one.
    public func nearestLoad(to total: Double) -> Load {
        nearest(in: loadable(upTo: total), to: total)
    }

    /// Plates for one side: fewest plates, ties go to larger plates, heaviest first. Nil if the plates can't make it.
    public func perSide(_ weight: Double) -> [Double]? {
        let amount = units(weight)
        guard amount >= 0, Double(amount) * quarter == weight else { return nil }
        return PlateTable(plates: plateUnits, upTo: amount).plates(for: amount).map { $0.map(asWeight) }
    }

    // MARK: - Private

    /// Weights are counted in quarters so 0.5, 1.5 and 2.5 stay exact.
    private let quarter = 0.25
    private let tolerance = 1e-9

    private var plateUnits: [Int] { gym.plateSizes.map(units) }

    private func units(_ weight: Double) -> Int { Int((weight / quarter).rounded()) }
    private func asWeight(_ units: Int) -> Double { Double(units) * quarter }

    /// Every loadable total from the empty bar up to the first one at or above `total`, lightest first.
    private func loadable(upTo total: Double) -> [Load] {
        let largest = plateUnits.max() ?? 0
        let sideLimit = max(0, units((total - gym.barWeight) / 2)) + largest
        let table = PlateTable(plates: plateUnits, upTo: sideLimit)
        return (0...sideLimit).compactMap { side in
            table.plates(for: side).map { plates in
                Load(total: gym.barWeight + 2 * asWeight(side), perSide: plates.map(asWeight))
            }
        }
    }

    private func nearest(in candidates: [Load], to total: Double) -> Load {
        // Candidates are lightest first, so `<` keeps the lighter one on a tie.
        candidates.dropFirst().reduce(candidates[0]) { best, next in
            abs(next.total - total) < abs(best.total - total) - tolerance ? next : best
        }
    }
}

/// Fewest-plate counts for every per-side amount up to a limit (unlimited plates of each size).
private struct PlateTable {
    let plates: [Int]       // heaviest first
    let fewest: [Int?]      // fewest[n] = fewest plates making n, nil if impossible

    init(plates: [Int], upTo limit: Int) {
        self.plates = plates.sorted(by: >)
        var fewest = [Int?](repeating: nil, count: limit + 1)
        fewest[0] = 0
        if limit > 0 {
            for amount in 1...limit {
                for plate in plates where plate <= amount {
                    if let count = fewest[amount - plate], count + 1 < (fewest[amount] ?? .max) {
                        fewest[amount] = count + 1
                    }
                }
            }
        }
        self.fewest = fewest
    }

    /// Takes the largest plate that still allows the fewest total, so ties go to larger plates.
    func plates(for amount: Int) -> [Int]? {
        guard amount < fewest.count, var left = fewest[amount] else { return nil }
        var remaining = amount
        var result: [Int] = []
        while left > 0 {
            guard let plate = plates.first(where: { $0 <= remaining && fewest[remaining - $0] == left - 1 }) else { return nil }
            result.append(plate)
            remaining -= plate
            left -= 1
        }
        return result
    }
}
