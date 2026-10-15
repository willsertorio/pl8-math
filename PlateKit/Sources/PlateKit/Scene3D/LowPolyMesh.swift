/// Flat-shaded low-poly geometry for the diorama look (SPEC 2.5, M5): the shapes, their ink outline (an
/// inside-out, slightly bigger copy — the "inverted hull"), and toon shading bands. Pure maths; RealityKit draws it.
/// Every triangle has its own three vertices, so each face is one flat colour.
public struct LowPolyMesh: Equatable, Sendable {
    public var positions: [SIMD3<Float>]
    /// Three per triangle, counter-clockwise seen from outside.
    public var indices: [UInt32]

    public init(positions: [SIMD3<Float>] = [], indices: [UInt32] = []) {
        self.positions = positions
        self.indices = indices
    }

    public var triangleCount: Int { indices.count / 3 }

    // MARK: - Shapes (axis along X)

    /// A closed n-sided prism, centred on the origin.
    public static func cylinder(radius: Float, length: Float, sides: Int) -> LowPolyMesh {
        var mesh = LowPolyMesh()
        let half = length / 2
        let ring = circle(radius: radius, sides: sides)
        let front = SIMD3<Float>(half, 0, 0), back = SIMD3<Float>(-half, 0, 0)
        for i in 0..<sides {
            let a = ring[i], b = ring[(i + 1) % sides]
            mesh.addTriangle(front, at(half, a), at(half, b))                     // +X cap
            mesh.addTriangle(back, at(-half, b), at(-half, a))                    // -X cap
            mesh.addQuad(at(-half, a), at(-half, b), at(half, b), at(half, a))    // rim
        }
        return mesh
    }

    /// A plate: an n-sided disc with a hole, thickness along X, centred on the origin.
    public static func plate(radius: Float, holeRadius: Float, thickness: Float, sides: Int) -> LowPolyMesh {
        var mesh = LowPolyMesh()
        let half = thickness / 2
        let outer = circle(radius: radius, sides: sides)
        let inner = circle(radius: holeRadius, sides: sides)
        for i in 0..<sides {
            let j = (i + 1) % sides
            mesh.addQuad(at(half, inner[i]), at(half, outer[i]), at(half, outer[j]), at(half, inner[j]))       // front
            mesh.addQuad(at(-half, inner[j]), at(-half, outer[j]), at(-half, outer[i]), at(-half, inner[i]))   // back
            mesh.addQuad(at(-half, outer[i]), at(-half, outer[j]), at(half, outer[j]), at(half, outer[i]))     // outer rim
            mesh.addQuad(at(half, inner[i]), at(half, inner[j]), at(-half, inner[j]), at(-half, inner[i]))     // hole
        }
        return mesh
    }

    // MARK: - Faces

    public func faceCentre(_ triangle: Int) -> SIMD3<Float> {
        let (a, b, c) = corners(triangle)
        return (a + b + c) / 3
    }

    public func faceNormal(_ triangle: Int) -> SIMD3<Float> {
        let (a, b, c) = corners(triangle)
        return (b - a).cross(c - a).normalized
    }

    /// Toon shading: each face gets a band 0 (in shadow) … levels-1 (facing the light). How dark each band is
    /// is the colour palette's job. `lightDirection` is the direction the light travels.
    public func toonBands(lightDirection: SIMD3<Float>, levels: Int) -> [UInt32] {
        let towardsLight = (-lightDirection).normalized
        return (0..<triangleCount).map { triangle in
            let lit = max(0, faceNormal(triangle).dot(towardsLight))
            return UInt32(min(levels - 1, Int(lit * Float(levels))))
        }
    }

    // MARK: - Ink outline

    /// The inverted hull: every corner pushed out by `width` (± `roughness` × width of noise, the same for every
    /// face sharing that corner so there are no cracks), with the winding reversed so only the rim shows.
    public func hull(width: Float, roughness: Float, seed: UInt32) -> LowPolyMesh {
        // Push each corner along the average normal of the faces that share it.
        var directions: [CornerKey: SIMD3<Float>] = [:]
        for triangle in 0..<triangleCount {
            let normal = faceNormal(triangle)
            for vertex in 0..<3 {
                let key = CornerKey(positions[Int(indices[triangle * 3 + vertex])])
                directions[key, default: .zero] += normal
            }
        }
        let moved = positions.map { position -> SIMD3<Float> in
            let key = CornerKey(position)
            let noise = Self.noise(key, seed: seed) * 2 - 1
            return position + (directions[key] ?? .zero).normalized * width * (1 + roughness * noise)
        }
        var reversed: [UInt32] = []
        reversed.reserveCapacity(indices.count)
        for triangle in 0..<triangleCount {
            reversed += [indices[triangle * 3], indices[triangle * 3 + 2], indices[triangle * 3 + 1]]
        }
        return LowPolyMesh(positions: moved, indices: reversed)
    }

    // MARK: - Placing

    public func translated(by offset: SIMD3<Float>) -> LowPolyMesh {
        LowPolyMesh(positions: positions.map { $0 + offset }, indices: indices)
    }

    public func combined(with other: LowPolyMesh) -> LowPolyMesh {
        let shift = UInt32(positions.count)
        return LowPolyMesh(positions: positions + other.positions, indices: indices + other.indices.map { $0 + shift })
    }

    // MARK: - Private

    private func corners(_ triangle: Int) -> (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) {
        (positions[Int(indices[triangle * 3])], positions[Int(indices[triangle * 3 + 1])], positions[Int(indices[triangle * 3 + 2])])
    }

    private mutating func addTriangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) {
        let start = UInt32(positions.count)
        positions += [a, b, c]
        indices += [start, start + 1, start + 2]
    }

    /// a-b-c-d counter-clockwise from outside.
    private mutating func addQuad(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>) {
        addTriangle(a, b, c)
        addTriangle(a, c, d)
    }

    /// Points on a circle in the YZ plane, going counter-clockwise seen from +X.
    private static func circle(radius: Float, sides: Int) -> [SIMD2<Float>] {
        (0..<sides).map { i in
            let angle = Float(i) / Float(sides) * 2 * Float.pi
            return SIMD2(radius * cosine(angle), radius * sine(angle))
        }
    }

    private static func at(_ x: Float, _ point: SIMD2<Float>) -> SIMD3<Float> {
        SIMD3(x, point.x, point.y)
    }

    /// A corner, rounded to 0.1 mm so the copies of it on different faces match.
    private struct CornerKey: Hashable {
        let x: Int32, y: Int32, z: Int32
        init(_ p: SIMD3<Float>) {
            x = Int32((p.x * 10_000).rounded()); y = Int32((p.y * 10_000).rounded()); z = Int32((p.z * 10_000).rounded())
        }
    }

    /// 0…1, the same for the same corner and seed.
    private static func noise(_ key: CornerKey, seed: UInt32) -> Float {
        var h = UInt32(bitPattern: key.x) &* 73_856_093 ^ UInt32(bitPattern: key.y) &* 19_349_663
        h ^= UInt32(bitPattern: key.z) &* 83_492_791 ^ seed &* 2_654_435_761
        h ^= h >> 13; h &*= 0x5bd1_e995; h ^= h >> 15
        return Float(h % 10_000) / 10_000
    }
}

// MARK: - Vector maths (works on Linux too, where Apple's simd module isn't available)

extension SIMD3 where Scalar == Float {
    public func dot(_ other: SIMD3<Float>) -> Float { (self * other).sum() }

    public func cross(_ other: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3(y * other.z - z * other.y, z * other.x - x * other.z, x * other.y - y * other.x)
    }

    public var length: Float { dot(self).squareRoot() }

    public var normalized: SIMD3<Float> {
        let l = length
        return l > 0 ? self / l : self
    }
}

// Sine and cosine without Foundation, so the geometry stays plain Swift.
private func sine(_ x: Float) -> Float { Float(sinApprox(Double(x))) }
private func cosine(_ x: Float) -> Float { Float(sinApprox(Double(x) + Double.pi / 2)) }

/// Taylor series after reducing to −π…π: plenty for drawing 14-sided plates.
private func sinApprox(_ value: Double) -> Double {
    var x = value.truncatingRemainder(dividingBy: 2 * Double.pi)
    if x > Double.pi { x -= 2 * Double.pi }
    if x < -Double.pi { x += 2 * Double.pi }
    var term = x, sum = x
    for n in 1...12 {
        term *= -x * x / Double((2 * n) * (2 * n + 1))
        sum += term
    }
    return sum
}
