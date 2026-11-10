import Testing
@testable import PlateKit

/// The PR notebook's page fold (Will, 2026-11-10): a dog-ear at the top right when there's another page, and a turn
/// that peels from that corner: a fold line sweeps from the corner to the spine, the part past it folding over.
@Suite("Page fold")
struct PageFoldTests {
    let fold = PageFold(width: 1.05, height: 1.4)

    func area(_ polygon: [SIMD2<Float>]) -> Float {
        var sum: Float = 0
        for i in polygon.indices {
            let a = polygon[i], b = polygon[(i + 1) % polygon.count]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }

    @Test func theTwoPartsMakeThePage() {
        for t in [PageFold.dogEar, 0.3, 0.6, 0.9] {
            let parts = fold.parts(at: t)
            #expect(abs(area(parts.flat) + area(parts.flap) - 1.05 * 1.4) < 0.001)
        }
    }

    @Test func theDogEarIsASmallCornerAtTheTopRight() {
        let flap = fold.parts(at: PageFold.dogEar).flap
        #expect(flap.contains { abs($0.x - 0.525) < 0.001 && abs($0.y - 0.7) < 0.001 })
        #expect(area(flap) > 0.002 && area(flap) < 0.02)
    }

    @Test func atTheEndTheWholePageHasTurned() {
        let parts = fold.parts(at: 1)
        #expect(area(parts.flat) < 0.001)
        // Folded over the spine (x = −0.525): every point lies to its left.
        for corner: SIMD2<Float> in [[-0.525, -0.7], [0.525, -0.7], [0.525, 0.7], [-0.525, 0.7]] {
            #expect(fold.place(corner, at: 1).x <= -0.524)
        }
    }

    @Test func theFlapKeepsItsShape() {
        // A rigid fold: distances on the page stay the same in 3D.
        let a: SIMD2<Float> = [0.5, 0.68], b: SIMD2<Float> = [0.3, 0.6], t: Float = 0.4
        let flat = ((a - b) * (a - b)).sum().squareRoot()
        let d = fold.place(a, at: t) - fold.place(b, at: t)
        let folded = (d * d).sum().squareRoot()
        #expect(abs(flat - folded) < 0.0001)
    }

    @Test func midTurnThePeelStandsUp() {
        // Not flat on the page: the corner rises towards the camera.
        #expect(fold.place([0.525, 0.7], at: 0.5).z > 0.2)
    }

    @Test func pointsBeforeTheLineStayFlat() {
        let p: SIMD2<Float> = [-0.5, -0.65]
        #expect(fold.place(p, at: 0.3) == SIMD3(p.x, p.y, 0))
    }
}
