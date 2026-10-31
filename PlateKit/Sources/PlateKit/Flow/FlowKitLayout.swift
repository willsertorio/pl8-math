import Foundation

/// Where each plate of the kit lies on the floor (HANDOFF 2.7, prototype flKitLayout): one line per size,
/// heaviest first, each plate flat on its own spot so the kit can be counted at a glance; smaller sizes share a
/// line when they fit (2.2 m wide). Metres, on the floor, centred on x = 0 and z = 0.35.
public enum FlowKitLayout {
    public struct Spot: Hashable, Sendable {
        public let size: Double
        public let plate: Plate
        public let x: Float
        public let z: Float
        /// Its turn about the vertical, so the printed numbers don't all line up.
        public let yaw: Float
    }

    static let gapInside: Float = 0.05, gapBetween: Float = 0.24, maxWidth: Float = 2.2, rowGap: Float = 0.16

    /// - Parameter kit: (size, count) heaviest first, counts for both sides together.
    public static func spots(kit: [(Double, Int)], unit: WeightUnit) -> [Spot] {
        struct Group { let plate: Plate; let count: Int; let width: Float }
        let groups: [Group] = kit.compactMap { size, count in
            guard count > 0, let plate = Plate.find(size, unit) else { return nil }
            let d = Float(plate.diameter)
            return Group(plate: plate, count: count, width: Float(count) * d + Float(count - 1) * gapInside)
        }
        var rows: [[Group]] = [[]]
        var width: Float = 0
        for group in groups {
            let add = (rows[rows.count - 1].isEmpty ? 0 : gapBetween) + group.width
            if width + add > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                width = 0
            }
            rows[rows.count - 1].append(group)
            width += (rows[rows.count - 1].count > 1 ? gapBetween : 0) + group.width
        }
        rows = rows.filter { !$0.isEmpty }
        let depths = rows.map { row in row.map { Float($0.plate.diameter) }.max() ?? 0 }
        let total = depths.reduce(0, +) + rowGap * Float(max(0, rows.count - 1))
        var z = 0.35 - total / 2
        var out: [Spot] = []
        var n = 0
        for (index, row) in rows.enumerated() {
            let rowWidth = row.map(\.width).reduce(0, +) + gapBetween * Float(row.count - 1)
            var x = -rowWidth / 2
            let centre = z + depths[index] / 2
            for group in row {
                let d = Float(group.plate.diameter)
                for j in 0..<group.count {
                    let yaw = (Float(n) * 1.37).truncatingRemainder(dividingBy: 6.28)
                    out.append(Spot(size: group.plate.size, plate: group.plate, x: x + d / 2 + Float(j) * (d + gapInside), z: centre, yaw: yaw))
                    n += 1
                }
                x += group.width + gapBetween
            }
            z += depths[index] + rowGap
        }
        return out
    }
}
