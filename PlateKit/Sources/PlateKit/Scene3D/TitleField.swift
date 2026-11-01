import Foundation

/// The opening title's plates (prototype AnimLayer makePlates, step and placeFree): 24 plates in lanes on both
/// sides of the title, at depths 0.75–2.4, rising slowly and tumbling; one that leaves the top comes back from
/// below. Screen units: u and v from −1 to 1 across and down the screen at depth 1 (v up is negative).
public struct TitleField: Sendable {
    public struct Item: Sendable {
        public var u: Float, v: Float, z: Float
        /// Radius on screen at depth 1, in points (the prototype's r0 × size 2).
        public var radius: Float
        public var rotation: SIMD3<Float>
        let spin: SIMD3<Float>
    }

    public private(set) var plates: [Item] = []
    private var random: Seeded
    /// The prototype's drift (points per second at depth 1), spin and the half screen height it was tuned on.
    static let drift: Float = 42, spin: Float = 0.08, halfHeight: Float = 422, lane: Float = 0.4

    public init(count: Int, seed: UInt32) {
        random = Seeded(seed: seed)
        for _ in 0..<count {
            var item = Item(u: 0, v: random.next(-1.15...1.15), z: random.next(0.75...2.4), radius: random.next(38...92) * 2,
                            rotation: [random.next(0...6.28), random.next(0...6.28), random.next(0...6.28)],
                            spin: [random.next(-1...1), random.next(-1...1), random.next(0.4...1) * (random.next(0...1) < 0.5 ? -1 : 1)])
            item.u = laneU()
            placeFree(&item)
            plates.append(item)
        }
        // The field starts just below the screen with a quarter of it filled each way, so plates rise in at once.
        let top = plates.map { $0.v - $0.radius / (Self.halfHeight * $0.z) }.min() ?? 0
        let shift = 1 - top - 2 * 0.25
        for i in plates.indices { plates[i].v += shift }
    }

    /// Straight up, farther ones slower; turning slowly.
    public mutating func step(_ dt: Float) {
        for i in plates.indices {
            var p = plates[i]
            p.v -= Self.drift * dt / (Self.halfHeight * p.z)
            let margin = 1 + p.radius * 1.3 / (Self.halfHeight * p.z)
            if p.v < -margin { p.v = margin; p.u = laneU() }
            p.rotation += p.spin * Self.spin * dt
            plates[i] = p
        }
    }

    private mutating func laneU() -> Float {
        (random.next(0...1) < 0.5 ? -1 : 1) * random.next(Self.lane...1.15)
    }

    /// Of 40 tries, where it's farthest from the others.
    private mutating func placeFree(_ item: inout Item) {
        var best = (u: item.u, v: item.v, z: item.z), bestScore: Float = -1
        for _ in 0..<40 {
            let c = (u: laneU(), v: random.next(-1.15...1.15), z: random.next(0.75...2.4))
            var score: Float = 1e9
            for q in plates {
                let dx = (c.u - q.u) * 195 * c.z, dy = (c.v - q.v) * Self.halfHeight * c.z, dz = (c.z - q.z) * 760
                score = min(score, (dx * dx + dy * dy + dz * dz).squareRoot() / (item.radius + q.radius))
            }
            if score > bestScore { bestScore = score; best = c }
            if score > 1.3 { break }
        }
        item.u = best.u; item.v = best.v; item.z = best.z
    }
}
