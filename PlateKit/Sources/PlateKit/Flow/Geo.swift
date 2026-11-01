import Foundation

/// three.js's geometry generators (r169), so the Flow's props keep the prototype's exact shapes, segment counts
/// and texture coordinates. Each returns a `LowPolyMesh` with every triangle on its own three corners (one flat
/// colour per face) and the prototype's winding (counter-clockwise from the outside).
public enum Geo {
    /// Indexed points → one corner set per triangle.
    static func unweld(_ points: [SIMD3<Float>], _ uvs: [SIMD2<Float>], _ indices: [Int]) -> LowPolyMesh {
        var mesh = LowPolyMesh()
        mesh.positions.reserveCapacity(indices.count)
        for (k, index) in indices.enumerated() {
            mesh.positions.append(points[index])
            mesh.uvs.append(uvs.isEmpty ? .zero : uvs[index])
            mesh.indices.append(UInt32(k))
        }
        return mesh
    }

    /// `CylinderGeometry(radiusTop, radiusBottom, height, radialSegments, 1, openEnded)`: along Y, θ = 0 at +Z.
    public static func cylinder(top: Float, bottom: Float, height: Float, segments: Int, openEnded: Bool = false,
                                thetaStart: Float = 0, thetaLength: Float = 2 * .pi) -> LowPolyMesh {
        var points: [SIMD3<Float>] = [], uvs: [SIMD2<Float>] = [], indices: [Int] = []
        let half = height / 2
        var grid: [[Int]] = []
        for y in 0...1 {
            let v = Float(y), radius = v * (bottom - top) + top
            var row: [Int] = []
            for x in 0...segments {
                let u = Float(x) / Float(segments), theta = u * thetaLength + thetaStart
                points.append([radius * sine(theta), -v * height + half, radius * cosine(theta)])
                uvs.append([u, 1 - v])
                row.append(points.count - 1)
            }
            grid.append(row)
        }
        for x in 0..<segments {
            let a = grid[0][x], b = grid[1][x], c = grid[1][x + 1], d = grid[0][x + 1]
            if top > 0 { indices += [a, b, d] }
            if bottom > 0 { indices += [b, c, d] }
        }
        if !openEnded {
            for isTop in [true, false] {
                let radius = isTop ? top : bottom
                guard radius > 0 else { continue }
                let sign: Float = isTop ? 1 : -1
                let centreStart = points.count
                for _ in 1...segments { points.append([0, half * sign, 0]); uvs.append([0.5, 0.5]) }
                let ringStart = points.count
                for x in 0...segments {
                    let u = Float(x) / Float(segments), theta = u * thetaLength + thetaStart
                    let c = cosine(theta), s = sine(theta)
                    points.append([radius * s, half * sign, radius * c])
                    uvs.append([c * 0.5 + 0.5, s * 0.5 * sign + 0.5])
                }
                for x in 0..<segments {
                    let c = centreStart + x, i = ringStart + x
                    indices += isTop ? [i, i + 1, c] : [i + 1, i, c]
                }
            }
        }
        return unweld(points, uvs, indices)
    }

    /// `ConeGeometry(radius, height, radialSegments)`: point up.
    public static func cone(radius: Float, height: Float, segments: Int) -> LowPolyMesh {
        cylinder(top: 0, bottom: radius, height: height, segments: segments)
    }

    /// `SphereGeometry(radius, widthSegments, heightSegments, phiStart, phiLength, thetaStart, thetaLength)`.
    public static func sphere(radius: Float, widthSegments: Int, heightSegments: Int, phiStart: Float = 0, phiLength: Float = 2 * .pi,
                              thetaStart: Float = 0, thetaLength: Float = .pi) -> LowPolyMesh {
        let thetaEnd = min(thetaStart + thetaLength, .pi)
        var points: [SIMD3<Float>] = [], uvs: [SIMD2<Float>] = [], indices: [Int] = []
        var grid: [[Int]] = []
        for iy in 0...heightSegments {
            let v = Float(iy) / Float(heightSegments)
            var row: [Int] = []
            for ix in 0...widthSegments {
                let u = Float(ix) / Float(widthSegments)
                let phi = phiStart + u * phiLength, theta = thetaStart + v * thetaLength
                points.append([-radius * cosine(phi) * sine(theta), radius * cosine(theta), radius * sine(phi) * sine(theta)])
                uvs.append([u, 1 - v])
                row.append(points.count - 1)
            }
            grid.append(row)
        }
        for iy in 0..<heightSegments {
            for ix in 0..<widthSegments {
                let a = grid[iy][ix + 1], b = grid[iy][ix], c = grid[iy + 1][ix], d = grid[iy + 1][ix + 1]
                if iy != 0 || thetaStart > 0 { indices += [a, b, d] }
                if iy != heightSegments - 1 || thetaEnd < .pi { indices += [b, c, d] }
            }
        }
        return unweld(points, uvs, indices)
    }

    /// `TorusGeometry(radius, tube, radialSegments, tubularSegments, arc)`: in the XY plane, from +X counter-clockwise.
    public static func torus(radius: Float, tube: Float, radialSegments: Int, tubularSegments: Int, arc: Float = 2 * .pi) -> LowPolyMesh {
        var points: [SIMD3<Float>] = [], uvs: [SIMD2<Float>] = [], indices: [Int] = []
        for j in 0...radialSegments {
            for i in 0...tubularSegments {
                let u = Float(i) / Float(tubularSegments) * arc, v = Float(j) / Float(radialSegments) * 2 * .pi
                points.append([(radius + tube * cosine(v)) * cosine(u), (radius + tube * cosine(v)) * sine(u), tube * sine(v)])
                uvs.append([Float(i) / Float(tubularSegments), Float(j) / Float(radialSegments)])
            }
        }
        for j in 1...radialSegments {
            for i in 1...tubularSegments {
                let a = (tubularSegments + 1) * j + i - 1, b = (tubularSegments + 1) * (j - 1) + i - 1
                let c = (tubularSegments + 1) * (j - 1) + i, d = (tubularSegments + 1) * j + i
                indices += [a, b, d, b, c, d]
            }
        }
        return unweld(points, uvs, indices)
    }

    /// `CircleGeometry(radius, segments)`: a disc in the XY plane facing +Z.
    public static func circle(radius: Float, segments: Int) -> LowPolyMesh {
        var points: [SIMD3<Float>] = [[0, 0, 0]], uvs: [SIMD2<Float>] = [[0.5, 0.5]], indices: [Int] = []
        for s in 0...segments {
            let angle = Float(s) / Float(segments) * 2 * .pi
            let p = SIMD3<Float>(radius * cosine(angle), radius * sine(angle), 0)
            points.append(p)
            uvs.append([(p.x / radius + 1) / 2, (p.y / radius + 1) / 2])
        }
        for i in 1...segments { indices += [i, i + 1, 0] }
        return unweld(points, uvs, indices)
    }

    /// `PlaneGeometry(width, height, widthSegments, heightSegments)`: in XY facing +Z.
    public static func plane(_ width: Float, _ height: Float, columns: Int = 1, rows: Int = 1) -> LowPolyMesh {
        var points: [SIMD3<Float>] = [], uvs: [SIMD2<Float>] = [], indices: [Int] = []
        for iy in 0...rows {
            let y = Float(iy) * height / Float(rows) - height / 2
            for ix in 0...columns {
                let x = Float(ix) * width / Float(columns) - width / 2
                points.append([x, -y, 0])
                uvs.append([Float(ix) / Float(columns), 1 - Float(iy) / Float(rows)])
            }
        }
        for iy in 0..<rows {
            for ix in 0..<columns {
                let a = ix + (columns + 1) * iy, b = ix + (columns + 1) * (iy + 1)
                let c = ix + 1 + (columns + 1) * (iy + 1), d = ix + 1 + (columns + 1) * iy
                indices += [a, b, d, b, c, d]
            }
        }
        return unweld(points, uvs, indices)
    }

    /// `BoxGeometry(width, height, depth)` as its six material groups, in three.js's order: +X, −X, +Y, −Y, +Z, −Z.
    /// Each face carries the whole picture (UV 0…1).
    public static func box(_ width: Float, _ height: Float, _ depth: Float) -> [LowPolyMesh] {
        // buildPlane(u, v, w, udir, vdir, width, height, depth): the face's two axes, their directions, its offset.
        func face(_ u: Int, _ v: Int, _ w: Int, _ udir: Float, _ vdir: Float, _ fw: Float, _ fh: Float, _ fd: Float) -> LowPolyMesh {
            var points: [SIMD3<Float>] = [], uvs: [SIMD2<Float>] = []
            for iy in 0...1 {
                let y = Float(iy) * fh - fh / 2
                for ix in 0...1 {
                    let x = Float(ix) * fw - fw / 2
                    var p = SIMD3<Float>.zero
                    p[u] = x * udir; p[v] = y * vdir; p[w] = fd / 2
                    points.append(p)
                    uvs.append([Float(ix), 1 - Float(iy)])
                }
            }
            return unweld(points, uvs, [0, 2, 1, 2, 3, 1])
        }
        return [
            face(2, 1, 0, -1, -1, depth, height, width),
            face(2, 1, 0, 1, -1, depth, height, -width),
            face(0, 2, 1, 1, 1, width, depth, height),
            face(0, 2, 1, 1, -1, width, depth, -height),
            face(0, 1, 2, 1, -1, width, height, depth),
            face(0, 1, 2, -1, -1, width, height, -depth),
        ]
    }

    /// The whole box as one mesh.
    public static func solidBox(_ width: Float, _ height: Float, _ depth: Float) -> LowPolyMesh {
        var mesh = LowPolyMesh()
        for face in box(width, height, depth) { mesh.append(face) }
        return mesh
    }

    /// `IcosahedronGeometry(1, 0)`: the dust chunks.
    public static func icosahedron(radius: Float = 1) -> LowPolyMesh {
        let t: Float = (1 + Float(5).squareRoot()) / 2
        let raw: [SIMD3<Float>] = [[-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0], [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t],
                                   [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]]
        let points = raw.map { $0.normalized * radius }
        let faces = [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
                     3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
        return unweld(points, [], faces)
    }

    /// Points along a Catmull-Rom curve through `points` (three.js CatmullRomCurve3, centripetal off), `count` + 1 of them.
    public static func catmullRom(_ points: [SIMD3<Float>], count: Int) -> [SIMD3<Float>] {
        guard points.count > 1 else { return points }
        let n = points.count
        return (0...count).map { k in
            let t = Float(k) / Float(count) * Float(n - 1)
            let i = min(n - 2, Int(t)), w = t - Float(i)
            let p0 = points[max(0, i - 1)], p1 = points[i], p2 = points[i + 1], p3 = points[min(n - 1, i + 2)]
            // Uniform Catmull-Rom: the end segments mirror their neighbour like three.js does.
            let e0 = i == 0 ? p1 * 2 - p2 : p0, e3 = i + 2 >= n ? p2 * 2 - p1 : p3
            let w2 = w * w, w3 = w2 * w
            let a = e0 * (-0.5 * w3 + w2 - 0.5 * w), b = p1 * (1.5 * w3 - 2.5 * w2 + 1)
            let c = p2 * (-1.5 * w3 + 2 * w2 + 0.5 * w), d = e3 * (0.5 * w3 - 0.5 * w2)
            return a + b + c + d
        }
    }
}
