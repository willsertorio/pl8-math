import Foundation

/// The PR notebook's page fold (Will, 2026-11-10). The page lies in its own plane, x across (−w/2 at the spine),
/// y up, z towards the reader. A fold line starts at the top-right corner, tilted 35°, and sweeps flat to the spine as
/// `t` goes 0 → 1; the part past it turns about the line, standing up mid-turn and lying folded over at the end.
/// At `dogEar` it's the small folded corner that says "there's another page".
public struct PageFold: Sendable {
    public let width: Float
    public let height: Float
    public static let dogEar: Float = 0.08

    public init(width: Float, height: Float) {
        self.width = width
        self.height = height
    }

    /// The fold line at `t`: a point on it and its normal (in the page, towards the part that lifts).
    public func line(at t: Float) -> (point: SIMD2<Float>, normal: SIMD2<Float>) {
        let tilt = 35 * Float.pi / 180 * (1 - t)
        let normal = SIMD2<Float>(cos(tilt), sin(tilt))
        let corner = SIMD2<Float>(width / 2, height / 2)
        let travel = t * (width + 0.4 * height * sin(tilt))
        return (corner - normal * travel, normal)
    }

    /// How far the lifted part has turned about the line: lying folded over (2.9, as a turned page lies) at the
    /// dog-ear and at the end, lifting off a little in between (about 145°). Standing straight up, the camera in
    /// front saw it edge-on: a thin line (CI, 2026-11-10).
    public func angle(at t: Float) -> Float {
        NotebookPages.turnedAngle - 0.12 * .pi * sin(.pi * t)
    }

    /// Where a point of the page is at `t`, `lift` off the page along its own normal (the back is a hair behind).
    /// - Parameter angle: another turn of the lifted part than the fold's own (the dog-ear lies flat as the
    ///   notebook closes).
    public func place(_ p: SIMD2<Float>, at t: Float, lift: Float = 0, angle override: Float? = nil) -> SIMD3<Float> {
        let (a, n) = line(at: t)
        let s = ((p - a) * n).sum()
        guard s > 0 else { return SIMD3(p.x, p.y, lift) }
        let foot = p - n * s, theta = override ?? angle(at: t)
        let across = SIMD3(n.x, n.y, 0) * cos(theta) + SIMD3<Float>(0, 0, 1) * sin(theta)
        let up = SIMD3<Float>(0, 0, 1) * cos(theta) - SIMD3(n.x, n.y, 0) * sin(theta)
        return SIMD3(foot.x, foot.y, 0) + across * s + up * lift
    }

    /// The lifted part's normal (its front, towards the reader at t = 0).
    public func flapNormal(at t: Float, angle override: Float? = nil) -> SIMD3<Float> {
        let (_, n) = line(at: t), theta = override ?? angle(at: t)
        return SIMD3<Float>(0, 0, 1) * cos(theta) - SIMD3(n.x, n.y, 0) * sin(theta)
    }

    /// The page cut along the line: the part that stays flat and the part that lifts, as convex polygons in the
    /// page (counter-clockwise).
    public func parts(at t: Float) -> (flat: [SIMD2<Float>], flap: [SIMD2<Float>]) {
        let (a, n) = line(at: t)
        let w = width / 2, h = height / 2
        let page: [SIMD2<Float>] = [[-w, -h], [w, -h], [w, h], [-w, h]]
        func side(_ p: SIMD2<Float>) -> Float { ((p - a) * n).sum() }
        var flat: [SIMD2<Float>] = [], flap: [SIMD2<Float>] = []
        for i in page.indices {
            let p = page[i], q = page[(i + 1) % page.count]
            let sp = side(p), sq = side(q)
            if sp <= 0 { flat.append(p) } else { flap.append(p) }
            if (sp <= 0) != (sq <= 0) {
                let cut = p + (q - p) * (sp / (sp - sq))
                flat.append(cut)
                flap.append(cut)
            }
        }
        return (flat, flap)
    }
}
