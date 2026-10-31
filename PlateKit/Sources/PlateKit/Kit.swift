/// The plates to take from the rack for a whole session, plus the bar (SPEC 3.5).
public struct Kit: Hashable, Sendable {
    public struct Item: Hashable, Sendable {
        public let size: Double
        /// Total plates of this size, both sides together.
        public let count: Int
    }

    public let bar: Double
    /// Heaviest first.
    public let plates: [Item]

    /// For each plate size: the most of it any single set needs on one side, × 2.
    /// Pass every set of the session, warm-up included.
    public init(bar: Double, loads: [Load]) {
        var mostPerSide: [Double: Int] = [:]
        for load in loads {
            var counts: [Double: Int] = [:]
            for plate in load.perSide { counts[plate, default: 0] += 1 }
            for (size, count) in counts { mostPerSide[size] = max(mostPerSide[size] ?? 0, count) }
        }
        self.bar = bar
        self.plates = mostPerSide
            .map { Item(size: $0.key, count: $0.value * 2) }
            .sorted { $0.size > $1.size }
    }
}

/// What to change on each side between two consecutive sets on the same bar (SPEC 3.5).
public struct SetChange: Hashable, Sendable {
    /// In the order they come off: outermost first.
    public let takeOff: [Double]
    /// In the order they go on: innermost first.
    public let add: [Double]

    /// Keeps the longest common inner part of the two per-side lists (both heaviest/innermost first).
    public init(from previous: [Double], to next: [Double]) {
        let kept = zip(previous, next).prefix { $0 == $1 }.count
        self.takeOff = Array(previous.dropFirst(kept).reversed())
        self.add = Array(next.dropFirst(kept))
    }

    public var isSame: Bool { takeOff.isEmpty && add.isEmpty }

    /// "Take off A + B, then add C each side", "Add C each side", "Take off A each side" or "Same plates as the last set".
    public var text: String {
        let off = takeOff.map(WeightUnit.trimmed).joined(separator: " + ")
        let on = add.map(WeightUnit.trimmed).joined(separator: " + ")
        switch (takeOff.isEmpty, add.isEmpty) {
        case (true, true): return "Same plates as the last set"
        case (true, false): return "Add \(on) each side"
        case (false, true): return "Take off \(off) each side"
        case (false, false): return "Take off \(off), then add \(on) each side"
        }
    }
}
