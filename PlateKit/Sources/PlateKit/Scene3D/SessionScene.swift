/// Where the session's plates are in the room (prototype buildKit and showSet): the kit laid out on the kit
/// floor, and the current set's plates on the bar on the rack.
public enum SessionScene {
    public struct PlacedPlate: Hashable, Sendable {
        public let plate: Plate
        /// Its middle, in room space.
        public let centre: SIMD3<Float>
        /// The way its hole points: `.y` lying on the floor, `.x` on the bar.
        public let axis: LowPolyMesh.Axis
        /// How far it's turned round its hole (where its printing ends up), radians.
        public let turn: Float
    }

    /// The kit on the floor, as the prototype lays it out: one group per plate size, lightest first, side by side
    /// in rows up to 2.05 m wide, in the view from the kit shot (rows run away from you, plates left to right),
    /// round the layout's kit spot.
    public static func kitFloor(_ kit: Kit, unit: WeightUnit) -> [PlacedPlate] {
        let shelfWidth: Float = 2.05, gap: Float = 0.08, lead: Float = 0.02
        struct Group { let plate: Plate; let count: Int; var pitch: Float { Float(plate.diameter) + 0.06 }
            var length: Float { Float(count) * pitch - 0.06 }; var width: Float { max(length, 0.36) }; var start: Float = 0 }
        let groups = kit.plates.compactMap { item in Plate.find(item.size, unit).map { Group(plate: $0, count: item.count) } }
            .sorted { $0.plate.size < $1.plate.size }
        var shelves: [(width: Float, depth: Float, groups: [Group])] = []
        for var group in groups {
            if shelves.isEmpty || (shelves[shelves.count - 1].width + gap + group.width > shelfWidth && !shelves[shelves.count - 1].groups.isEmpty) {
                shelves.append((-gap, 0, []))
            }
            group.start = shelves[shelves.count - 1].width + gap
            shelves[shelves.count - 1].width += gap + group.width
            shelves[shelves.count - 1].depth = max(shelves[shelves.count - 1].depth, Float(group.plate.diameter))
            shelves[shelves.count - 1].groups.append(group)
        }
        let depth = shelves.reduce(-0.12) { $0 + lead + 0.05 + $1.depth + 0.12 }

        // The athlete's frame: f away from them (from the kit shot), u to their right.
        let shot = RoomLayout.shots[.kit]!
        let flat = SIMD2(shot.target.x - shot.position.x, shot.target.z - shot.position.z)
        let f = flat / flat.length
        let spot = RoomLayout.objects[.kitPlates]!.position
        func at(_ u: Float, _ v: Float) -> SIMD2<Float> { SIMD2(spot.x - f.y * u + f.x * v, spot.z + f.x * u + f.y * v) }

        var placed: [PlacedPlate] = []
        var v = -depth / 2
        for shelf in shelves {
            v += lead + 0.05
            let middle = v + shelf.depth / 2
            for group in shelf.groups {
                let first = -shelf.width / 2 + group.start + (group.width - group.length) / 2
                for i in 0..<group.count {
                    let xz = at(first + Float(i) * group.pitch + Float(group.plate.diameter) / 2, middle)
                    placed.append(PlacedPlate(plate: group.plate, centre: SIMD3(xz.x, Float(group.plate.thickness) / 2, xz.y),
                                              axis: .y, turn: turn(group.plate, i)))
                }
            }
            v += shelf.depth + 0.12
        }
        return placed
    }

    /// The set's plates on both sleeves of the bar on the rack, innermost first, from just outside the collar
    /// (the same on every bar, clear of the J-hooks), 2 mm apart.
    public static func barPlates(perSide: [Double], unit: WeightUnit, barWeight: Double) -> [PlacedPlate] {
        let bar = RoomLayout.barOnRack
        var placed: [PlacedPlate] = []
        var along: Float = 0
        for (k, size) in perSide.enumerated() {
            guard let plate = Plate.find(size, unit) else { continue }
            let t = Float(plate.thickness)
            let x = PropModels.collarEnd + 0.004 + along + t / 2
            along += t + 0.002
            for side: Float in [-1, 1] {
                placed.append(PlacedPlate(plate: plate, centre: bar + SIMD3(side * x, 0, 0), axis: .x, turn: turn(plate, k * 2 + (side > 0 ? 1 : 0))))
            }
        }
        return placed
    }

    /// The plate's parts, turned to lie the way it does, around its middle.
    public static func parts(_ placed: PlacedPlate) -> [PropPart] {
        PropModels.plateParts(placed.plate, turn: placed.turn).map { part in
            let mesh = placed.axis == .y ? part.mesh.rotatedZ(Float.pi / 2) : part.mesh
            return PropPart(mesh: mesh, tone: part.tone, inked: part.inked, casts: part.casts)
        }
    }

    private static func turn(_ plate: Plate, _ i: Int) -> Float {
        let seed = UInt32(plate.size * 4) &* 2_246_822_519 &+ UInt32(i) &* 3_266_489_917
        return Float(seed % 10_000) / 10_000 * 2 * Float.pi
    }
}

extension SIMD2 where Scalar == Float {
    public var length: Float { (x * x + y * y).squareRoot() }
}
