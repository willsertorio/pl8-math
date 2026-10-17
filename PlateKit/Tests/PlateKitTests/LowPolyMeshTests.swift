import Testing
@testable import PlateKit

@Suite("Low-poly meshes for the 3D look (M5)")
struct LowPolyMeshTests {
    let plate = LowPolyMesh.plate(radius: 0.225, holeRadius: 0.026, thickness: 0.056, sides: 14)

    @Test func plateHasFrontBackOuterAndInnerRims() {
        // Each of the 4 surfaces is 14 quads = 28 triangles.
        #expect(plate.triangleCount == 4 * 14 * 2)
        #expect(plate.indices.count == plate.triangleCount * 3)
    }

    @Test func barPartIsAClosedPrism() {
        let shaft = LowPolyMesh.cylinder(radius: 0.014, length: 1.31, sides: 10)
        #expect(shaft.triangleCount == 10 * 2 + 10 * 2)                // two caps + the rim
    }

    @Test func plateAxisIsX() {
        let xs = plate.positions.map(\.x)
        #expect(abs((xs.max() ?? 0) - 0.028) < 1e-5)
        #expect(abs((xs.min() ?? 0) + 0.028) < 1e-5)
    }

    @Test func faceNormalsAreUnitAndPointOut() {
        for triangle in 0..<plate.triangleCount {
            let n = plate.faceNormal(triangle)
            #expect(abs(n.length - 1) < 1e-4)
        }
        // The front face (+X side) faces +X.
        let front = (0..<plate.triangleCount).filter { plate.faceCentre($0).x > 0.0279 }
        #expect(!front.isEmpty)
        #expect(front.allSatisfy { plate.faceNormal($0).x > 0.99 })
    }

    @Test func hullIsBiggerAndInsideOut() {
        let hull = plate.hull(width: 0.004, roughness: 0, seed: 1)
        #expect(hull.triangleCount == plate.triangleCount)
        for triangle in 0..<plate.triangleCount {
            // Reversed winding: the hull's faces point the other way.
            #expect(hull.faceNormal(triangle).dot(plate.faceNormal(triangle)) < -0.99)
        }
        let outer = plate.positions.map { ($0.y * $0.y + $0.z * $0.z).squareRoot() }.max() ?? 0
        let hullOuter = hull.positions.map { ($0.y * $0.y + $0.z * $0.z).squareRoot() }.max() ?? 0
        // Edge corners move diagonally (between the face and the rim), so outward by about 0.7 × width.
        #expect(hullOuter > outer + 0.0025)
    }

    @Test func roughHullHasNoCracks() {
        // The same corner of the shape always moves to the same place, whichever face it belongs to.
        let hull = plate.hull(width: 0.004, roughness: 0.6, seed: 7)
        var moved: [String: SIMD3<Float>] = [:]
        for (original, expanded) in zip(plate.positions, hull.positions) {
            let key = "\(Int((original.x * 1e4).rounded())),\(Int((original.y * 1e4).rounded())),\(Int((original.z * 1e4).rounded()))"
            if let earlier = moved[key] { #expect((earlier - expanded).length < 1e-6) }
            moved[key] = expanded
        }
    }

    @Test func roughnessDependsOnTheSeed() {
        let a = plate.hull(width: 0.004, roughness: 0.6, seed: 1)
        let b = plate.hull(width: 0.004, roughness: 0.6, seed: 2)
        let same = plate.hull(width: 0.004, roughness: 0.6, seed: 1)
        #expect(a.positions == same.positions)
        #expect(a.positions != b.positions)
    }

    @Test func toonBandsFollowTheLight() {
        // Light shining from +X towards -X: the front (+X) face is brightest, the back face darkest.
        let bands = plate.toonBands(lightDirection: SIMD3(-1, 0, 0), levels: 3)
        let front = (0..<plate.triangleCount).first { plate.faceNormal($0).x > 0.99 }!
        let back = (0..<plate.triangleCount).first { plate.faceNormal($0).x < -0.99 }!
        #expect(bands[front] == 2)
        #expect(bands[back] == 0)
        #expect(bands.count == plate.triangleCount)
    }

    @Test func meshesCanBeMovedAndCombined() {
        let shaft = LowPolyMesh.cylinder(radius: 0.014, length: 1.31, sides: 10)
        let moved = plate.translated(by: SIMD3(0.8, 0, 0))
        #expect(abs((moved.positions.map(\.x).min() ?? 0) - 0.772) < 1e-5)
        let both = shaft.combined(with: moved)
        #expect(both.triangleCount == shaft.triangleCount + plate.triangleCount)
        #expect(both.indices.max() == UInt32(both.positions.count - 1))
    }
}
