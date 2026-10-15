/// The prototype's light, baked (reference/prototype-app-logic.js initScene): a bright, even sky (hemisphere 2.7)
/// and one sun from (−8, 20, 12) at 1.5, with no tone mapping. White in full sun reads near-white; faces turned
/// away from the sun and the shadows read the same soft lavender. Baking it into flat colours gives the exact look
/// on every device, where RealityKit's own lights and tone mapping greyed it out.
public enum Sunlight {
    /// Unit vector towards the sun.
    public static let towardsSun = SIMD3<Float>(-8, 20, 12).normalized
    /// Shade steps: 0 = in shade (or shadow) … `levels − 1` = full sun, like the floor.
    public static let levels = 4
    /// How far shadows sit above the floor (under the 2 mm tile seams, so the seams still show) and off the walls.
    public static let floorLift: Float = 0.0015
    public static let wallLift: Float = 0.003

    /// The shade step for a face. The floor gets full sun; the left wall, facing away, none.
    public static func level(normal: SIMD3<Float>) -> Int {
        let lit = max(0, normal.dot(towardsSun)) / towardsSun.y
        return min(levels - 1, Int((lit * Float(levels - 1)).rounded()))
    }

    /// 0 (shade) … 1 (full sun) for a step.
    public static func brightness(level: Int) -> Float {
        Float(level) / Float(levels - 1)
    }

    /// The mesh's faces split by shade step, so each step can get its own flat colour.
    public static func bands(_ mesh: LowPolyMesh) -> [Int: LowPolyMesh] {
        var bands: [Int: LowPolyMesh] = [:]
        for triangle in 0..<mesh.triangleCount {
            let level = level(normal: mesh.faceNormal(triangle))
            let corners = (0..<3).map { mesh.positions[Int(mesh.indices[triangle * 3 + $0])] }
            bands[level, default: LowPolyMesh()].append(corners[0], corners[1], corners[2])
        }
        return bands
    }

    /// The shadow `mesh` (in room space) casts on the floor, the back wall and the right wall — the surfaces the
    /// sun shines on. Each face is pushed along the sun's rays onto each surface and cut to it; in a box room a
    /// ray lands inside exactly one of them, so the pieces meet without overlapping walls. Props don't shadow
    /// each other; at this size nobody notices.
    public static func shadow(of mesh: LowPolyMesh, in room: RoomLayout.Room) -> LowPolyMesh {
        let ray = -towardsSun
        let receivers = [
            Receiver(axis: 1, plane: 0, lift: floorLift, normal: [0, 1, 0],
                     u: 0, uRange: room.minX...room.maxX, v: 2, vRange: room.minZ...room.maxZ),
            Receiver(axis: 2, plane: room.minZ, lift: wallLift, normal: [0, 0, 1],
                     u: 0, uRange: room.minX...room.maxX, v: 1, vRange: 0...room.wallHeight),
            Receiver(axis: 0, plane: room.maxX, lift: -wallLift, normal: [-1, 0, 0],
                     u: 2, uRange: room.minZ...room.maxZ, v: 1, vRange: 0...room.wallHeight),
        ]
        var shadow = LowPolyMesh()
        for triangle in 0..<mesh.triangleCount {
            let corners = (0..<3).map { mesh.positions[Int(mesh.indices[triangle * 3 + $0])] }
            for receiver in receivers {
                let projected = corners.map { corner -> SIMD3<Float> in
                    let t = (receiver.plane - corner[receiver.axis]) / ray[receiver.axis]
                    var point = corner + ray * t
                    point[receiver.axis] = receiver.plane + receiver.lift
                    return point
                }
                let piece = receiver.clip(projected)
                guard piece.count >= 3 else { continue }
                for i in 1..<(piece.count - 1) {
                    var (a, b, c) = (piece[0], piece[i], piece[i + 1])
                    let normal = (b - a).cross(c - a)
                    guard normal.length > 1e-7 else { continue }
                    if normal.dot(receiver.normal) < 0 { swap(&b, &c) }                // face into the room
                    shadow.append(a, b, c)
                }
            }
        }
        return shadow
    }

    /// A surface that takes shadows: the plane `position[axis] == plane`, bounded in two other axes.
    private struct Receiver {
        let axis: Int, plane: Float, lift: Float, normal: SIMD3<Float>
        let u: Int, uRange: ClosedRange<Float>
        let v: Int, vRange: ClosedRange<Float>

        /// Sutherland–Hodgman: cuts the polygon to the surface's rectangle.
        func clip(_ polygon: [SIMD3<Float>]) -> [SIMD3<Float>] {
            var points = polygon
            for (index, bound, keepAbove) in [(u, uRange.lowerBound, true), (u, uRange.upperBound, false),
                                              (v, vRange.lowerBound, true), (v, vRange.upperBound, false)] {
                guard !points.isEmpty else { break }
                let inside = { (p: SIMD3<Float>) in keepAbove ? p[index] >= bound : p[index] <= bound }
                var kept: [SIMD3<Float>] = []
                for i in points.indices {
                    let current = points[i], next = points[(i + 1) % points.count]
                    if inside(current) { kept.append(current) }
                    if inside(current) != inside(next) {
                        let t = (bound - current[index]) / (next[index] - current[index])
                        kept.append(current + (next - current) * t)
                    }
                }
                points = kept
            }
            return points
        }
    }
}

extension LowPolyMesh {
    /// Length of one piece of a rough edge.
    public static let roughStep: Float = 0.035

    /// A hand-drawn, grainy line along an axis-aligned edge, like the prototype's sketch border around the box:
    /// small pieces that wobble slowly off the line, change thickness, and now and then drop out. `width` is
    /// about the line's thickness in metres. The same seed gives the same line every launch.
    public static func roughEdge(from start: SIMD3<Float>, to end: SIMD3<Float>, width: Float, seed: UInt32) -> LowPolyMesh {
        let delta = end - start, length = delta.length
        guard length > 0 else { return LowPolyMesh() }
        let along = [abs(delta.x), abs(delta.y), abs(delta.z)].enumerated().max { $0.element < $1.element }!.offset
        let across = [0, 1, 2].filter { $0 != along }
        let count = Int(length / roughStep)
        var mesh = LowPolyMesh()
        for i in 0..<count {
            let s = Float(i) * roughStep
            if hash(UInt32(i), seed &+ 7) < 0.2 { continue }                           // grain: a gap
            var centre = start + delta * ((s + roughStep / 2) / length)
            centre[across[0]] += (smoothNoise(s / 0.5, seed: seed) - 0.5) * width * 1.6   // slow wobble
            centre[across[1]] += (smoothNoise(s / 0.5, seed: seed &+ 31) - 0.5) * width * 1.6
            let thickness = width * (0.45 + 0.9 * hash(UInt32(i), seed &+ 13))
            var size = SIMD3<Float>(repeating: thickness)
            size[along] = roughStep * 1.1
            let piece = box(size: size).translated(by: centre), shift = UInt32(mesh.positions.count)
            mesh.positions += piece.positions
            mesh.indices += piece.indices.map { $0 + shift }
        }
        return mesh
    }

    /// Rotated around Y, then moved: a prop's mesh in room space.
    public func placed(_ placement: RoomLayout.Placement) -> LowPolyMesh {
        let angle = Double(placement.rotationDegrees) * Double.pi / 180
        let s = Float(sinApprox(angle)), c = Float(sinApprox(angle + Double.pi / 2))
        return LowPolyMesh(positions: positions.map { p in
            SIMD3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c) + placement.position
        }, indices: indices)
    }

    mutating func append(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) {
        let start = UInt32(positions.count)
        positions += [a, b, c]
        indices += [start, start + 1, start + 2]
    }

    /// 0…1, the same for the same inputs.
    private static func hash(_ i: UInt32, _ seed: UInt32) -> Float {
        var h = i &* 2_654_435_761 ^ seed &* 2_246_822_519
        h ^= h >> 15; h &*= 0x2c1b_3c6d; h ^= h >> 12; h &*= 0x297a_2d39; h ^= h >> 15
        return Float(h % 10_000) / 10_000
    }

    /// Smooth 1D value noise, 0…1.
    private static func smoothNoise(_ x: Float, seed: UInt32) -> Float {
        let i = x.rounded(.down), f = x - i
        let a = hash(UInt32(Int32(i) & 0x7fff_ffff), seed), b = hash(UInt32(Int32(i + 1) & 0x7fff_ffff), seed)
        let t = f * f * (3 - 2 * f)
        return a + (b - a) * t
    }
}
