/// The prototype's sun (reference/prototype-app-logic.js initScene: a DirectionalLight at (−8, 20, 12) aimed at
/// the origin, casting soft shadows), baked: the shadows are the props pushed along the sun's rays onto the
/// surfaces the sun lights — the floor, the platform's top, the back wall and the right wall — and drawn there in
/// the colour that surface has out of the sun.
public enum Sunlight {
    /// Unit vector towards the sun.
    public static let towardsSun = SIMD3<Float>(-8, 20, 12).normalized
    /// How far shadows sit above a floor (under the 2 mm tile seams, so the seams still show) and off a wall.
    public static let floorLift: Float = 0.0015
    public static let wallLift: Float = 0.003

    /// A flat, axis-aligned surface that takes shadows: the plane `position[axis] == plane`, bounded in its
    /// other two axes, facing `normal`.
    public struct Receiver: Sendable {
        public let axis: Int, plane: Float, normal: SIMD3<Float>
        public let u: Int, uRange: ClosedRange<Float>
        public let v: Int, vRange: ClosedRange<Float>
        /// What the surface is made of, for its shadow colour.
        public let tone: PropPart.Tone
        /// Shown only with this wall.
        public let wall: RoomLayout.Wall?

        var lift: Float { (axis == 1 ? floorLift : wallLift) * normal[axis] }
    }

    /// The floor, the platform's light strip and mats, the back wall and the right wall (the left wall faces away
    /// from the sun, so nothing shadows it).
    public static var receivers: [Receiver] {
        let r = RoomLayout.room
        var list = [
            Receiver(axis: 1, plane: 0, normal: [0, 1, 0], u: 0, uRange: r.minX...r.maxX, v: 2, vRange: r.minZ...r.maxZ,
                     tone: .light, wall: nil),
            Receiver(axis: 2, plane: r.minZ, normal: [0, 0, 1], u: 0, uRange: r.minX...r.maxX, v: 1, vRange: 0...r.wallHeight,
                     tone: .light, wall: .back),
            Receiver(axis: 0, plane: r.maxX, normal: [-1, 0, 0], u: 2, uRange: r.minZ...r.maxZ, v: 1, vRange: 0...r.wallHeight,
                     tone: .light, wall: .right),
        ]
        let platform = RoomLayout.objects[.platform]!.position
        for top in PropModels.platformTops {
            let c = platform + top.centre
            list.append(Receiver(axis: 1, plane: c.y, normal: [0, 1, 0],
                                 u: 0, uRange: (c.x - top.size.x / 2)...(c.x + top.size.x / 2),
                                 v: 2, vRange: (c.z - top.size.y / 2)...(c.z + top.size.y / 2), tone: top.tone, wall: nil))
        }
        return list
    }

    /// The shadow `mesh` (in room space) casts on `receiver`: each face, cut to the part in front of the
    /// surface, pushed along the sun's rays onto it and cut to its edges. In a box room a ray lands inside
    /// exactly one wall or floor, so the pieces meet without overlapping. Props don't shadow each other except on
    /// the platform; at this size nobody notices.
    public static func shadow(of mesh: LowPolyMesh, on receiver: Receiver) -> LowPolyMesh {
        let ray = -towardsSun
        guard ray.dot(receiver.normal) < 0 else { return LowPolyMesh() }               // the sun can't reach it
        var shadow = LowPolyMesh()
        for triangle in 0..<mesh.triangleCount {
            let corners = (0..<3).map { mesh.positions[Int(mesh.indices[triangle * 3 + $0])] }
            // Only what's in front of the surface can shadow it (a rack upright standing on the platform).
            let front = clip(corners) { ($0[receiver.axis] - receiver.plane) * receiver.normal[receiver.axis] - 0.001 }
            guard front.count >= 3 else { continue }
            let projected = front.map { corner -> SIMD3<Float> in
                let t = (receiver.plane - corner[receiver.axis]) / ray[receiver.axis]
                var point = corner + ray * t
                point[receiver.axis] = receiver.plane + receiver.lift
                return point
            }
            var piece = projected
            for (index, bound, above) in [(receiver.u, receiver.uRange.lowerBound, true), (receiver.u, receiver.uRange.upperBound, false),
                                          (receiver.v, receiver.vRange.lowerBound, true), (receiver.v, receiver.vRange.upperBound, false)] {
                piece = clip(piece) { above ? $0[index] - bound : bound - $0[index] }
            }
            guard piece.count >= 3 else { continue }
            for i in 1..<(piece.count - 1) {
                var (a, b, c) = (piece[0], piece[i], piece[i + 1])
                let normal = (b - a).cross(c - a)
                guard normal.length > 1e-7 else { continue }
                if normal.dot(receiver.normal) < 0 { swap(&b, &c) }                    // face into the room
                shadow.append(a, b, c)
            }
        }
        return shadow
    }

    /// Sutherland–Hodgman: keeps the part of the polygon where `inside` ≥ 0.
    static func clip(_ polygon: [SIMD3<Float>], _ inside: (SIMD3<Float>) -> Float) -> [SIMD3<Float>] {
        var kept: [SIMD3<Float>] = []
        for i in polygon.indices {
            let current = polygon[i], next = polygon[(i + 1) % polygon.count]
            let dc = inside(current), dn = inside(next)
            if dc >= 0 { kept.append(current) }
            if (dc >= 0) != (dn >= 0) { kept.append(current + (next - current) * (dc / (dc - dn))) }
        }
        return kept
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

    /// The same rough, grainy line along any path (a plate's rim, a tilted edge): short rods every `step` along it,
    /// wobbling off the path, some left out. Seen from far, use longer steps (the grain stays the same on screen).
    public static func roughLine(_ points: [SIMD3<Float>], width: Float, seed: UInt32, step: Float = roughStep) -> LowPolyMesh {
        var mesh = LowPolyMesh()
        guard points.count > 1 else { return mesh }
        var travelled: Float = 0, next: Float = step / 2, i = 0
        let period: Float = 0.5 * step / roughStep
        for (a, b) in zip(points, points.dropFirst()) {
            let delta = b - a, length = delta.length
            guard length > 0 else { continue }
            let along = delta / length
            let helper: SIMD3<Float> = abs(along.y) < 0.9 ? [0, 1, 0] : [1, 0, 0]
            let u = along.cross(helper).normalized, v = along.cross(u).normalized
            while next < travelled + length {
                defer { next += step; i += 1 }
                if hash(UInt32(i), seed &+ 7) < 0.2 { continue }                           // grain: a gap
                let s = next
                let wobbleU: Float = (smoothNoise(s / period, seed: seed) - 0.5) * width * 1.6      // slow wobble
                let wobbleV: Float = (smoothNoise(s / period, seed: seed &+ 31) - 0.5) * width * 1.6
                let onPath: SIMD3<Float> = a + along * (s - travelled)
                let centre: SIMD3<Float> = onPath + u * wobbleU + v * wobbleV
                let thickness: Float = width * (0.45 + 0.9 * hash(UInt32(i), seed &+ 13))
                let half: SIMD3<Float> = along * (step * 0.55)
                mesh.append(.rod(from: centre - half, to: centre + half, width: thickness))
            }
            travelled += length
        }
        return mesh
    }

    /// The prototype's sketch outline on a shape: a rough double line along every hard edge, joined into paths so
    /// rims come out as one wobbling stroke.
    public func roughInk(width: Float, seed: UInt32, step: Float = roughStep) -> LowPolyMesh {
        var mesh = LowPolyMesh()
        for (n, path) in Self.paths(hardEdges()).enumerated() {
            let base = seed &* 7919 &+ UInt32(n) &* 2
            mesh.append(.roughLine(path, width: width, seed: base, step: step))
            mesh.append(.roughLine(path, width: width * 0.6, seed: base &+ 1, step: step))
        }
        return mesh
    }

    /// Edges chained end to end wherever exactly two meet.
    static func paths(_ edges: [(SIMD3<Float>, SIMD3<Float>)]) -> [[SIMD3<Float>]] {
        func key(_ p: SIMD3<Float>) -> SIMD3<Int32> { SIMD3(Int32((p.x * 10_000).rounded()), Int32((p.y * 10_000).rounded()), Int32((p.z * 10_000).rounded())) }
        var at: [SIMD3<Int32>: [Int]] = [:]
        for (i, edge) in edges.enumerated() { at[key(edge.0), default: []].append(i); at[key(edge.1), default: []].append(i) }
        var used = Array(repeating: false, count: edges.count)
        var paths: [[SIMD3<Float>]] = []
        for start in edges.indices where !used[start] {
            used[start] = true
            var path = [edges[start].0, edges[start].1]
            // Grow from the end while the path continues through a point where only two edges meet.
            while let end = path.last, let around = at[key(end)], around.count == 2,
                  let next = around.first(where: { !used[$0] }) {
                used[next] = true
                path.append(key(edges[next].0) == key(end) ? edges[next].1 : edges[next].0)
            }
            paths.append(path)
        }
        return paths
    }

    /// Rotated around Y, then moved: a prop's mesh in room space.
    public func placed(_ placement: RoomLayout.Placement) -> LowPolyMesh {
        let angle = Double(placement.rotationDegrees) * Double.pi / 180
        let s = Float(sinApprox(angle)), c = Float(sinApprox(angle + Double.pi / 2))
        return LowPolyMesh(positions: positions.map { p in
            SIMD3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c) + placement.position
        }, indices: indices, uvs: uvs)
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
