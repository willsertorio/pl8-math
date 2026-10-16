/// One thing the phone draws: a mesh in room space, one flat paint, shown while its walls are.
public struct BakedPiece: Sendable {
    public enum Paint: Hashable, Sendable {
        /// An exact colour.
        case colour(RGB)
        /// A printed picture, multiplied by `tint` (how much light that face gets).
        case picture(Picture, tint: RGB)
    }

    public let mesh: LowPolyMesh
    public let paint: Paint
    /// Shown only while all of these walls are (a wall's own pieces, the props on it, shadows across it).
    public let walls: Set<RoomLayout.Wall>

    public func isVisible(from camera: SIMD3<Float>) -> Bool {
        walls.allSatisfy { $0.isVisible(from: camera) }
    }

    /// The same piece moved, e.g. to sit around a pivot the app scales it from.
    public func translated(by offset: SIMD3<Float>) -> BakedPiece {
        BakedPiece(mesh: mesh.translated(by: offset), paint: paint, walls: walls)
    }
}

/// The whole diorama baked into flat-coloured pieces, the way the prototype renders it (reference/
/// prototype-app-logic.js): three.js Lambert light from `Look`, the sun's shadows from `Sunlight`, thin ink lines
/// on every inked part's hard edges, and the rough sketch line round the box. The app turns each piece into an
/// unlit RealityKit model, so what's drawn is exactly these colours.
public enum SceneBake {
    /// The ink lines' width in metres (the prototype's are one pixel).
    public static let inkWidth: Float = 0.007

    /// - Parameter except: props the caller bakes on its own (the ones the gym setup changes).
    public static func pieces(plates: [Plate], gymName: String, except: Set<RoomLayout.Object> = []) -> [BakedPiece] {
        // Everything in room space, grouped by the wall it shows with.
        var groups: [(wall: RoomLayout.Wall?, parts: [PropPart])] = [(nil, PropModels.floor() + PropModels.border(nil))]
        for wall in RoomLayout.Wall.allCases { groups.append((wall, PropModels.wall(wall) + PropModels.border(wall))) }
        for object in RoomLayout.Object.allCases where !except.contains(object) {
            let placement = PropModels.placement(for: object)
            let parts = PropModels.parts(for: object, plates: plates, gymName: gymName).map {
                PropPart(mesh: $0.mesh.placed(placement), tone: $0.tone, inked: $0.inked, casts: $0.casts)
            }
            if !parts.isEmpty { groups.append((object.wall, parts)) }
        }

        return bake(groups)
    }

    /// One prop's parts (in its own space) placed in the room and baked with their ink and shadows; `wall` is
    /// the wall it shows with. For the parts of the room that change as the gym is set up.
    public static func bake(_ parts: [PropPart], placement: RoomLayout.Placement, wall: RoomLayout.Wall?) -> [BakedPiece] {
        bake([(wall, parts.map { PropPart(mesh: $0.mesh.placed(placement), tone: $0.tone, inked: $0.inked, casts: $0.casts) })])
    }

    static func bake(_ groups: [(wall: RoomLayout.Wall?, parts: [PropPart])]) -> [BakedPiece] {
        var buckets: [Key: LowPolyMesh] = [:]
        var order: [Key] = []
        func add(_ mesh: LowPolyMesh, _ paint: BakedPiece.Paint, _ walls: Set<RoomLayout.Wall>) {
            guard mesh.triangleCount > 0 else { return }
            let key = Key(paint: paint, walls: walls)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: LowPolyMesh()].append(mesh)
        }

        let receivers = Sunlight.receivers
        for group in groups {
            let walls: Set<RoomLayout.Wall> = group.wall.map { [$0] } ?? []
            var casters = LowPolyMesh()
            for part in group.parts {
                for (paint, mesh) in shaded(part) { add(mesh, paint, walls) }
                if part.inked { add(part.mesh.inkLines(width: inkWidth), .colour(Look.ink), walls) }
                if part.casts { casters.append(part.mesh) }
            }
            for receiver in receivers {
                let shadow = Sunlight.shadow(of: casters, on: receiver)
                let shadowWalls = walls.union(receiver.wall.map { [$0] } ?? [])
                add(shadow, .colour(Look.lit(albedo(receiver.tone), sun: 0)), shadowWalls)
            }
        }
        return order.map { BakedPiece(mesh: buckets[$0]!, paint: $0.paint, walls: $0.walls) }
    }

    /// A part's faces split by how much sun each gets, each with its paint.
    static func shaded(_ part: PropPart) -> [(BakedPiece.Paint, LowPolyMesh)] {
        if case .flat(let colour) = part.tone { return [(.colour(colour), part.mesh)] }
        if case .metal(let colour) = part.tone {
            // Measured off the prototype's bar: ×0.97 on top, ×0.70 on the sides, ×0.40 underneath (sRGB).
            var steps: [Int: LowPolyMesh] = [:]
            for triangle in 0..<part.mesh.triangleCount {
                steps[Int((part.mesh.faceNormal(triangle).y * 4).rounded()), default: LowPolyMesh()].append(part.mesh.face(triangle))
            }
            return steps.sorted { $0.key < $1.key }.map { step, mesh in
                let f = 0.70 + 0.29 * Float(step) / 4
                return (.colour(RGB(colour.r * f, colour.g * f, colour.b * f)), mesh)
            }
        }
        var steps: [Int: LowPolyMesh] = [:]
        for triangle in 0..<part.mesh.triangleCount {
            steps[Look.sunStep(normal: part.mesh.faceNormal(triangle)), default: LowPolyMesh()].append(part.mesh.face(triangle))
        }
        return steps.sorted { $0.key < $1.key }.map { step, mesh in
            let sun = Look.sun(step: step)
            if case .picture(let picture) = part.tone {
                let light = min(1, (Look.ambient + Look.sunIntensity * sun) / Float.pi)
                return (.picture(picture, tint: RGB(linear: SIMD3(repeating: light))), mesh)
            }
            return (.colour(Look.lit(albedo(part.tone), sun: sun)), mesh)
        }
    }

    static func albedo(_ tone: PropPart.Tone) -> RGB {
        switch tone {
        case .dark: Look.boxDark
        case .light: Look.boxLight
        case .paint(let colour), .metal(let colour), .flat(let colour): colour
        case .picture: RGB(1, 1, 1)
        }
    }

    struct Key: Hashable {
        let paint: BakedPiece.Paint
        let walls: Set<RoomLayout.Wall>
    }
}
