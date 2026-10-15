/// More shapes and tools for copying the prototype's props: turning parts, its thin ink lines on hard edges
/// (three.js `EdgesGeometry`), and plates with their printed faces.
extension LowPolyMesh {
    // MARK: - Turning

    /// Turned around X by `angle` radians (right-handed, like three.js `rotateX`).
    public func rotatedX(_ angle: Float) -> LowPolyMesh {
        let (s, c) = (sine(angle), cosine(angle))
        return mapped { SIMD3($0.x, $0.y * c - $0.z * s, $0.y * s + $0.z * c) }
    }

    public func rotatedY(_ angle: Float) -> LowPolyMesh {
        let (s, c) = (sine(angle), cosine(angle))
        return mapped { SIMD3($0.x * c + $0.z * s, $0.y, -$0.x * s + $0.z * c) }
    }

    public func rotatedZ(_ angle: Float) -> LowPolyMesh {
        let (s, c) = (sine(angle), cosine(angle))
        return mapped { SIMD3($0.x * c - $0.y * s, $0.x * s + $0.y * c, $0.z) }
    }

    func mapped(_ transform: (SIMD3<Float>) -> SIMD3<Float>) -> LowPolyMesh {
        LowPolyMesh(positions: positions.map(transform), indices: indices, uvs: uvs)
    }

    // MARK: - Ink lines

    /// The hard edges: where two faces meet at more than `degrees`, or where a face has no neighbour —
    /// what three.js `EdgesGeometry(geo, degrees)` draws.
    public func hardEdges(degrees: Float = 28) -> [(SIMD3<Float>, SIMD3<Float>)] {
        struct EdgeKey: Hashable { let a: Key, b: Key }
        struct Key: Hashable, Comparable {
            let x: Int32, y: Int32, z: Int32
            init(_ p: SIMD3<Float>) {
                x = Int32((p.x * 10_000).rounded()); y = Int32((p.y * 10_000).rounded()); z = Int32((p.z * 10_000).rounded())
            }
            static func < (l: Key, r: Key) -> Bool { (l.x, l.y, l.z) < (r.x, r.y, r.z) }
        }
        var normals: [EdgeKey: [SIMD3<Float>]] = [:]
        var ends: [EdgeKey: (SIMD3<Float>, SIMD3<Float>)] = [:]
        var order: [EdgeKey] = []
        for triangle in 0..<triangleCount {
            let normal = faceNormal(triangle)
            guard normal.length > 0.5 else { continue }
            for corner in 0..<3 {
                let p = positions[Int(indices[triangle * 3 + corner])], q = positions[Int(indices[triangle * 3 + (corner + 1) % 3])]
                let (kp, kq) = (Key(p), Key(q))
                guard kp != kq else { continue }
                let key = kp < kq ? EdgeKey(a: kp, b: kq) : EdgeKey(a: kq, b: kp)
                if normals[key] == nil { order.append(key); ends[key] = (p, q) }
                normals[key, default: []].append(normal)
            }
        }
        let threshold = cosine(degrees * Float.pi / 180)
        return order.compactMap { key in
            let list = normals[key]!
            if list.count == 1 || list[0].dot(list[1]) < threshold { return ends[key] }
            return nil
        }
    }

    /// The hard edges drawn as thin square rods `width` across: RealityKit has no lines.
    public func inkLines(width: Float, degrees: Float = 28) -> LowPolyMesh {
        var mesh = LowPolyMesh()
        for (a, b) in hardEdges(degrees: degrees) { mesh.append(.rod(from: a, to: b, width: width)) }
        return mesh
    }

    /// A thin square rod between two points.
    public static func rod(from a: SIMD3<Float>, to b: SIMD3<Float>, width: Float) -> LowPolyMesh {
        let along = (b - a).normalized
        let helper: SIMD3<Float> = abs(along.y) < 0.9 ? [0, 1, 0] : [1, 0, 0]
        let u = along.cross(helper).normalized * (width / 2), v = along.cross(u).normalized * (width / 2)
        let ring = [u + v, -u + v, -u - v, u - v]
        var mesh = LowPolyMesh()
        for i in 0..<4 {
            let j = (i + 1) % 4
            mesh.addQuadPublic(a + ring[i], a + ring[j], b + ring[j], b + ring[i])
        }
        return mesh
    }

    // MARK: - More shapes

    /// An open ring (like a fan guard): a thin rod bent into a circle of `radius` in the XY plane.
    public static func hoop(radius: Float, width: Float, segments: Int) -> LowPolyMesh {
        var mesh = LowPolyMesh()
        for i in 0..<segments {
            let a0 = Float(i) / Float(segments) * 2 * Float.pi, a1 = Float(i + 1) / Float(segments) * 2 * Float.pi
            mesh.append(.rod(from: [radius * cosine(a0), radius * sine(a0), 0], to: [radius * cosine(a1), radius * sine(a1), 0], width: width))
        }
        return mesh
    }

    /// A rod following a path of points.
    public static func tube(through points: [SIMD3<Float>], width: Float) -> LowPolyMesh {
        var mesh = LowPolyMesh()
        for i in 1..<max(1, points.count) { mesh.append(.rod(from: points[i - 1], to: points[i], width: width)) }
        return mesh
    }

    /// A flat ring in the YZ plane facing +X (or −X when `facingBack`), from `inner` to `outer` radius, with
    /// texture coordinates mapping a square picture across the whole `outer` disc (three.js `RingGeometry`),
    /// turned by `turn` radians. Seen from the side it faces, the picture reads the right way round.
    public static func ring(inner: Float, outer: Float, sides: Int, facingBack: Bool, turn: Float = 0) -> LowPolyMesh {
        var mesh = LowPolyMesh()
        let (s, c) = (sine(turn), cosine(turn))
        func point(_ radius: Float, _ angle: Float) -> (SIMD3<Float>, SIMD2<Float>) {
            // In the picture: right = u, up = v. Seen from +X, right is −Z; seen from −X, right is +Z.
            let pu = radius * cosine(angle), pv = radius * sine(angle)
            let position = SIMD3<Float>(0, pv, facingBack ? pu : -pu)
            let ru = pu * c - pv * s, rv = pu * s + pv * c
            return (position, SIMD2(0.5 + ru / (2 * outer), 0.5 + rv / (2 * outer)))
        }
        for i in 0..<sides {
            let a0 = Float(i) / Float(sides) * 2 * Float.pi, a1 = Float(i + 1) / Float(sides) * 2 * Float.pi
            let p = [point(inner, a0), point(outer, a0), point(outer, a1), point(inner, a1)]
            let start = UInt32(mesh.positions.count)
            mesh.positions += p.map(\.0)
            mesh.uvs += p.map(\.1)
            mesh.indices += [start, start + 1, start + 2, start, start + 2, start + 3]
        }
        return mesh.facing(facingBack ? [-1, 0, 0] : [1, 0, 0])
    }

    /// An open tube (no caps) along X: a plate's rim or hub.
    public static func sleeve(radius: Float, length: Float, sides: Int, inward: Bool = false) -> LowPolyMesh {
        var mesh = cylinder(radius: radius, length: length, sides: sides, axis: .x)
        mesh = mesh.keepingFaces { abs($0.x) < 0.5 }                              // drop the two caps
        return inward ? mesh.insideOut() : mesh
    }

    /// A plane `width` × `height` in XY facing +Z, split into a grid, with texture coordinates; `depth` pushes
    /// each point out along Z (the flag's folds).
    public static func sheet(width: Float, height: Float, columns: Int, rows: Int,
                             depth: (Float, Float) -> Float = { _, _ in 0 }) -> LowPolyMesh {
        var mesh = LowPolyMesh()
        func point(_ i: Int, _ j: Int) -> (SIMD3<Float>, SIMD2<Float>) {
            let u = Float(i) / Float(columns), v = Float(j) / Float(rows)
            let x = (u - 0.5) * width, y = (v - 0.5) * height
            return (SIMD3(x, y, depth(x, y)), SIMD2(u, v))
        }
        for i in 0..<columns {
            for j in 0..<rows {
                let p = [point(i, j), point(i + 1, j), point(i + 1, j + 1), point(i, j + 1)]
                for triangle in [[0, 1, 2], [0, 2, 3]] {
                    let start = UInt32(mesh.positions.count)
                    mesh.positions += triangle.map { p[$0].0 }
                    mesh.uvs += triangle.map { p[$0].1 }
                    mesh.indices += [start, start + 1, start + 2]
                }
            }
        }
        return mesh
    }

    /// Only the faces whose normal passes `keep`.
    public func keepingFaces(_ keep: (SIMD3<Float>) -> Bool) -> LowPolyMesh {
        var mesh = LowPolyMesh()
        for triangle in 0..<triangleCount where keep(faceNormal(triangle)) { mesh.append(face(triangle)) }
        return mesh
    }

    /// One triangle as its own mesh.
    public func face(_ triangle: Int) -> LowPolyMesh {
        let corners = (0..<3).map { Int(indices[triangle * 3 + $0]) }
        return LowPolyMesh(positions: corners.map { positions[$0] }, indices: [0, 1, 2],
                           uvs: uvs.isEmpty ? [] : corners.map { uvs[$0] })
    }

    /// Flips any face whose normal points against `direction`.
    func facing(_ direction: SIMD3<Float>) -> LowPolyMesh {
        var mesh = self
        for triangle in 0..<triangleCount where faceNormal(triangle).dot(direction) < 0 {
            mesh.indices.swapAt(triangle * 3 + 1, triangle * 3 + 2)
        }
        return mesh
    }

    mutating func addQuadPublic(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>) {
        let start = UInt32(positions.count)
        positions += [a, b, c, a, c, d]
        indices += [start, start + 1, start + 2, start + 3, start + 4, start + 5]
        if !uvs.isEmpty { uvs += Array(repeating: .zero, count: 6) }
    }
}

func sine(_ x: Float) -> Float { Float(sinApprox(Double(x))) }
func cosine(_ x: Float) -> Float { Float(sinApprox(Double(x) + Double.pi / 2)) }
