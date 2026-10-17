import Foundation

/// The opening (SPEC 2.2 step 0), copied from the prototype (reference/prototype-app-logic.js startOnboarding,
/// openBox, poseBox, runOnb and furnish): a closed cube floats in the sky, turning slowly; a tap opens it — the lid
/// floats up and away, the walls glide down (the ones facing the overview all the way), the box settles and the
/// camera drifts in to the overview. Then the whiteboard rolls in and the bench is tossed in.
public enum Opening {
    /// The closed box's height (the prototype's CUBE).
    public static let cubeHeight: Float = 8
    /// The prototype opens 1.7× faster than its choreography: 3.5 of its seconds.
    public static let speed: Float = 1.7
    public static var duration: Float { 3.5 / speed }
    /// After it opens: the furniture's moves, then the setup starts (the prototype's 2.3 s).
    public static let furnishTime: Float = 2.3

    /// The box's four sides. The room has three walls; the front only exists while the box is closed.
    public enum Side: CaseIterable, Sendable { case back, left, right, front }

    /// A side of the closed box, in room space, full cube height, just around the room's wall on that side; it
    /// scales down from `position` (on the floor).
    public struct Slab: Sendable {
        public let side: Side
        public let position: SIMD3<Float>
        public let parts: [PropPart]
    }

    public static func slabs() -> [Slab] {
        let r = RoomLayout.room, c = r.centre, t = r.wallThickness + 0.02, h = cubeHeight
        let long = r.width + 0.32, deep = r.depth + 0.32
        return Side.allCases.map { side in
            let (size, centre): (SIMD3<Float>, SIMD3<Float>) = switch side {
            case .back: ([long, h, t], [c.x, h / 2, r.minZ - r.wallThickness / 2])
            case .front: ([long, h, t], [c.x, h / 2, r.maxZ + r.wallThickness / 2])
            case .left: ([t, h, deep], [r.minX - r.wallThickness / 2, h / 2, c.z])
            case .right: ([t, h, deep], [r.maxX + r.wallThickness / 2, h / 2, c.z])
            }
            var b = PropModels.Builder()
            b.box(size, centre, .light, casts: false)
            b.add(LowPolyMesh.box(size: size).translated(by: centre).roughInk(width: outlineWidth, seed: 50 + UInt32(Side.allCases.firstIndex(of: side)!), step: 0.1),
                  .flat(Look.ink), ink: false, casts: false)
            return Slab(side: side, position: [centre.x, 0, centre.z], parts: b.parts)
        }
    }

    /// The lid, around its own middle; it sits at `lidHeight` over the room's centre.
    public static func lid() -> [PropPart] {
        let r = RoomLayout.room
        var b = PropModels.Builder()
        let size = SIMD3<Float>(r.width + 0.34, 0.15, r.depth + 0.34)
        b.box(size, .zero, .light, casts: false)
        b.add(LowPolyMesh.box(size: size).roughInk(width: outlineWidth, seed: 60, step: 0.1), .flat(Look.ink), ink: false, casts: false)
        return b.parts
    }
    public static var lidHeight: Float { cubeHeight + 0.075 }
    /// The sketch outline's width: about the prototype's 2.5 px stroke from the far shot, 52 m away.
    static let outlineWidth: Float = 0.07

    /// The walls facing the overview camera go all the way down (prototype openBox: the camera is outside them).
    public static func dropsAllTheWay(_ side: Side) -> Bool {
        let camera = RoomLayout.shots[.overview]!.position, r = RoomLayout.room
        return switch side {
        case .back: camera.z < r.minZ
        case .left: camera.x < r.minX
        case .right: camera.x > r.maxX
        case .front: camera.z > r.maxZ
        }
    }

    /// A side's height with the walls `walls` of the way up (1 closed, 0 open).
    public static func slabHeight(_ side: Side, walls: Float) -> Float {
        let h = RoomLayout.room.wallHeight
        return dropsAllTheWay(side) ? walls * cubeHeight : h + (cubeHeight - h) * walls
    }

    /// The box `time` seconds after the tap.
    public struct Pose: Equatable, Sendable {
        /// 1 closed, 0 open.
        public let walls: Float
        /// Metres the lid has risen, and its tilt round Z.
        public let lidUp: Float
        public let lidTilt: Float
        /// How high the box floats (before its bob) and how much of the bob is left.
        public let lift: Float
        public let settle: Float
        /// How far the box has turned back to face the camera (0 → 1).
        public let turn: Float
    }

    public static func pose(at time: Float) -> Pose {
        let pt = time * speed
        let settle = 1 - sine((pt - 0.4) / 2.6)
        return Pose(walls: 1 - sine((pt - 0.8) / 2.0), lidUp: 42 * pow(sine((pt - 0.3) / 2.2), 1.7),
                    lidTilt: 0.25 * sine((pt - 0.3) / 2.0), lift: 0.55 * settle, settle: settle, turn: sine(pt / 1.6))
    }

    /// The closed box popping in, `time` seconds after the title goes (prototype: outBack from 0.5 s over 0.8 s).
    public static func popScale(at time: Float) -> Float {
        max(0.0001, outBack((time - 0.5) / 0.8, 1.6))
    }

    /// The idle float: up and down, with a light sway.
    public static func bob(at time: Float) -> Float { sin(time * 1.1) * 0.12 }

    /// A piece of furniture on its way in: how far from its spot, turned how much round Y, and its wobble
    /// (round X and Z) as it lands.
    public struct Move: Equatable, Sendable {
        public let visible: Bool
        public let offset: SIMD3<Float>
        public let turn: Float
        public let wobble: SIMD2<Float>
    }

    /// The whiteboard rolls in from the front, turning, `time` seconds after the box opened.
    public static func board(at time: Float) -> Move {
        let g0: Float = 0.15, k = 1 - outCubic((time - g0) / 1.1)
        return Move(visible: time > g0, offset: [-k * 1.2, 0, k * 3.6], turn: k * .pi * 1.25,
                    wobble: [wob(time - g0 - 1.1, 0.07, 4, 16), 0])
    }

    /// The bench is tossed in on an arc and wobbles as it lands.
    public static func bench(at time: Float) -> Move {
        let b0: Float = 0.25, x = (time - b0) / 0.85, v = clamp(x), since = time - b0 - 0.85
        return Move(visible: x >= 0, offset: [3 * (1 - v), 1.2 * (1 - v) + 8 * v * (1 - v), 2.6 * (1 - v)], turn: -2.2 * (1 - v),
                    wobble: [wob(since, 0.11, 5, 17), wob(since + 0.05, 0.077, 5, 21)])
    }

    // The prototype's easings.
    static func clamp(_ x: Float) -> Float { min(1, max(0, x)) }
    static func sine(_ x: Float) -> Float { 0.5 - 0.5 * cos(.pi * clamp(x)) }
    static func outCubic(_ x: Float) -> Float { 1 - pow(1 - clamp(x), 3) }
    static func outBack(_ x: Float, _ k: Float) -> Float {
        let x = clamp(x), c = k + 1
        return 1 + c * pow(x - 1, 3) + k * pow(x - 1, 2)
    }
    static func wob(_ since: Float, _ amp: Float, _ k: Float, _ w: Float) -> Float {
        since < 0 ? 0 : amp * exp(-since * k) * sin(since * w)
    }
}
