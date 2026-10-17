import Foundation

/// The session-over "scale" (SPEC 2.3 step 7), copied from the prototype's 'done' scene (AnimLayer buildDone and
/// stepDone): a low platform scale with a digital head; the heaviest set's plates fall onto it one by one,
/// heaviest first, then the bar lands across them. In the scale's own space, y up, the platform's middle at x = z = 0.
public enum ScaleScene {
    /// The platform's rubber top, where the first plate lands.
    public static let platformTop: Float = 0.14
    /// The prototype's drop height and gravity (dHeight 3, 9.8 m/s²).
    public static let dropHeight: Float = 3
    static let gravity: Float = 9.8
    public static var fallTime: Float { (2 * dropHeight / gravity).squareRoot() }

    /// The digital head's screen: its middle, the head's tilt back (radians, around X) and its size.
    public static let screenCentre = SIMD3<Float>(0, 0.86 + 0.041 * sin(0.35), -0.39 + 0.041 * cos(0.35))
    public static let screenTilt: Float = -0.35
    public static let screenSize = SIMD2<Float>(0.31, 0.135)

    /// The camera, like the prototype's: 45° round, 32° up, 3.5 m of the scene in view, aimed 0.3 m up.
    public static let cameraTarget = SIMD3<Float>(0, 0.3, 0)
    public static let cameraYaw: Float = 45 * .pi / 180
    public static let cameraElevation: Float = 32 * .pi / 180
    public static let viewHeight: Float = 3.5

    /// The body (base, feet, column, head) and the platform that dips when something lands.
    public static func parts() -> (base: [PropPart], platform: [PropPart]) {
        let body = PropPart.Tone.paint(Look.boxDark), top = PropPart.Tone.paint(Look.boxLight)
        let dark = PropPart.Tone.paint(RGB(hex: "#2B1E16"))
        var base = PropModels.Builder(), platform = PropModels.Builder()
        base.box([0.84, 0.07, 0.84], [0, 0.055, 0], body)
        for sx: Float in [-1, 1] {
            for sz: Float in [-1, 1] { base.cylinder(0.04, 0.03, .y, 10, [sx * 0.36, 0.015, sz * 0.36], dark) }
        }
        base.cylinder(0.022, 0.72, .y, 10, [0, 0.45, -0.39], body)
        base.add(LowPolyMesh.box(size: [0.36, 0.19, 0.08]).rotatedX(screenTilt).translated(by: [0, 0.86, -0.39]), body)
        platform.box([0.78, 0.04, 0.78], [0, 0.11, 0], body)
        platform.box([0.72, 0.01, 0.72], [0, 0.135, 0], top)
        base.add(outline(base.parts, seed: 70), .flat(Look.ink), ink: false, casts: false)
        platform.add(outline(platform.parts, seed: 80), .flat(Look.ink), ink: false, casts: false)
        return (base.parts, platform.parts)
    }

    /// The prototype's sketch outline (rough, grainy, doubled) round each part, sized for the scale's camera.
    public static func outline(_ parts: [PropPart], seed: UInt32, width: Float = 0.012) -> LowPolyMesh {
        var mesh = LowPolyMesh()
        for (n, part) in parts.enumerated() where part.tone != .flat(Look.ink) {
            // Not the bar's thin shaft: its joints would draw rings across it, which the prototype doesn't.
            let ys = part.mesh.positions.map(\.y), zs = part.mesh.positions.map(\.z)
            guard (ys.max()! - ys.min()!) > 0.03 || (zs.max()! - zs.min()!) > 0.03 else { continue }
            mesh.append(part.mesh.roughInk(width: width, seed: seed &+ UInt32(n), step: max(LowPolyMesh.roughStep, width * 3)))
        }
        return mesh
    }

    /// One thing that falls onto the scale: a plate (lying flat) or, with `plate == nil`, the bar.
    public struct Drop: Equatable, Sendable {
        public let plate: Plate?
        /// Seconds after the scene starts.
        public let at: Float
        /// Its middle's height once it rests on the stack.
        public let restY: Float
        /// Where it lands off the middle, its turn round Y, its tilt while falling and its spin, like the
        /// prototype's messy stack.
        public let offset: SIMD2<Float>
        public let turn: Float
        public let tilt: SIMD2<Float>
        public let spin: Float
    }

    /// The heaviest set's plates, both sides, heaviest at the bottom, 0.38 s apart from 0.5 s; then the bar,
    /// 1.05 s after the last plate.
    public static func drops(perSide: [Double], unit: WeightUnit, barWeight: Double) -> [Drop] {
        let plates = perSide.sorted(by: >).flatMap { size in Plate.find(size, unit).map { [$0, $0] } ?? [] }
        var random = Seeded(seed: UInt32(truncatingIfNeeded: plates.count &* 7919 &+ Int(barWeight)))
        var drops: [Drop] = []
        var height: Float = 0
        for (i, plate) in plates.enumerated() {
            let t = Float(plate.thickness)
            drops.append(Drop(plate: plate, at: 0.5 + Float(i) * 0.38, restY: platformTop + height + t / 2,
                              offset: [random.next(-0.024...0.024), random.next(-0.024...0.024)],
                              turn: random.next(0...(2 * .pi)), tilt: [random.next(-0.72...0.72), random.next(-0.72...0.72)],
                              spin: random.next(-1.2...1.2)))
            height += t + 0.001
        }
        let last = drops.last?.at ?? 0.5 - 0.38
        // Across the stack, turned 165° round from the camera's line like the prototype's bar (dAz + 90 + dBarYaw).
        drops.append(Drop(plate: nil, at: last + 1.05, restY: platformTop + height + 0.014, offset: .zero,
                          turn: 165 * .pi / 180, tilt: [0, random.next(-0.15...0.15)], spin: 0))
        return drops
    }

    /// What the scale reads at the end: both sides' plates and the bar.
    public static func total(perSide: [Double], barWeight: Double) -> Double {
        perSide.reduce(0, +) * 2 + barWeight
    }

    /// A drop's height `elapsed` seconds after it's let go: falling from 3 m above where it rests, then a small
    /// damped hop.
    public static func height(above restY: Float, at elapsed: Float) -> Float {
        if elapsed < fallTime { return restY + dropHeight - 0.5 * gravity * elapsed * elapsed }
        let e = elapsed - fallTime
        return restY + 0.5 * 0.07 * abs(sin(e * 16)) * exp(-e * 7)
    }

    /// How much of its falling tilt is left: all of it in the air, then a wobble that settles flat.
    public static func tilt(at elapsed: Float) -> Float {
        guard elapsed >= fallTime else { return 1 }
        let e = elapsed - fallTime
        return cos(e * 26) * exp(-e * 9)
    }

    /// How hard a landing kicks the platform down (the prototype's dDip 0.5 × 1.6 × hit).
    public static func kick(_ drop: Drop) -> Float {
        let hit = drop.plate.map { Float($0.unit == .lb ? $0.size * 0.4536 : $0.size) / 25 + 0.25 } ?? 1.6
        return 0.8 * hit
    }
}

/// A small repeatable random source, so the stack looks the same every time for the same set.
struct Seeded {
    var state: UInt32
    init(seed: UInt32) { state = seed &+ 0x9E37_79B9 }

    mutating func next(_ range: ClosedRange<Float>) -> Float {
        state = state &* 1_664_525 &+ 1_013_904_223
        return range.lowerBound + Float(state >> 8) / Float(1 << 24) * (range.upperBound - range.lowerBound)
    }
}
