/// The diorama's room, objects and camera shots (SPEC 2.1), from reference/scene-layout-and-look.json.
/// Metres, y up. The box is 8 m (`S`), the floor 9 × 7 one-metre tiles from (−4, −4).
public enum RoomLayout {
    public struct Room: Sendable {
        public let minX: Float, maxX: Float, minZ: Float, maxZ: Float
        public let wallHeight: Float
        public let wallThickness: Float
        public var centre: SIMD3<Float> { SIMD3((minX + maxX) / 2, 0, (minZ + maxZ) / 2) }
        public var width: Float { maxX - minX }
        public var depth: Float { maxZ - minZ }
    }

    /// Cols 9, rows 7, starting at −S/2 with S = 8; walls 2.6 m high, 0.15 m thick.
    public static let room = Room(minX: -4, maxX: 5, minZ: -4, maxZ: 3, wallHeight: 2.6, wallThickness: 0.15)

    public enum Object: String, CaseIterable, Sendable {
        case platform, rack, bench, board, shelf, flag, prBoard, barHolder, kitPlates, wallFan, wallWindow

        /// The wall this prop hangs on and hides with (prototype propsTick: the fan, bar holder and window go
        /// with a wall they are within 0.35 m of). Other props always show.
        public var wall: Wall? {
            guard [.wallFan, .barHolder, .wallWindow].contains(self), let position = RoomLayout.objects[self]?.position
            else { return nil }
            return Wall.allCases.first { abs((position - $0.point).dot($0.normal)) < 0.35 }
        }
    }

    /// The three walls. Like the prototype's cut-away, a wall hides while the camera is outside it, so you
    /// always see into the box.
    public enum Wall: String, CaseIterable, Sendable {
        case back, left, right

        /// Into the room.
        public var normal: SIMD3<Float> {
            switch self {
            case .back: [0, 0, 1]
            case .left: [1, 0, 0]
            case .right: [-1, 0, 0]
            }
        }

        /// A point on the wall's inside face.
        public var point: SIMD3<Float> {
            let r = room, c = r.centre
            switch self {
            case .back: return [c.x, 0, r.minZ]
            case .left: return [r.minX, 0, c.z]
            case .right: return [r.maxX, 0, c.z]
            }
        }

        public func isVisible(from camera: SIMD3<Float>) -> Bool {
            (camera - point).dot(normal) > 0
        }
    }

    public struct Placement: Equatable, Sendable {
        public let position: SIMD3<Float>
        /// Around Y.
        public let rotationDegrees: Float

        public init(position: SIMD3<Float>, rotationDegrees: Float) {
            self.position = position
            self.rotationDegrees = rotationDegrees
        }
    }

    public static let objects: [Object: Placement] = [
        .platform: Placement(position: [0.66, 0, -1.86], rotationDegrees: 0),
        .rack: Placement(position: [0.61, 0, -2.31], rotationDegrees: 0),
        .bench: Placement(position: [0.95, 0, 0.63], rotationDegrees: 180),
        .board: Placement(position: [-2.16, 0, -3.07], rotationDegrees: 25),
        .shelf: Placement(position: [0.06, 0.3, 2.32], rotationDegrees: 0),
        .flag: Placement(position: [3.2, 1.95, -3.99], rotationDegrees: 0),
        .prBoard: Placement(position: [-3.97, 1.15, -2.76], rotationDegrees: 90),
        .barHolder: Placement(position: [5, 0, -0.45], rotationDegrees: -90),
        .kitPlates: Placement(position: [3.45, 0, -1.85], rotationDegrees: 0),
        .wallFan: Placement(position: [4.94, 2, -2.75], rotationDegrees: -90),
        .wallWindow: Placement(position: [5, -0.15, 1.2], rotationDegrees: -90),
    ]

    /// Where the bar rests on the rack's J-hooks: 0.77 m behind the rack's origin, 1.265 m up (prototype).
    public static var barOnRack: SIMD3<Float> {
        let rack = objects[.rack]!.position
        return SIMD3(rack.x, 1.265, rack.z - 0.77)
    }

    /// Camera shots (SPEC 2.1 stations).
    public enum Station: String, CaseIterable, Sendable {
        case overview, corner, nameFlag, flag, bar, pr, board, kit, setv
    }

    public struct Shot: Equatable, Sendable {
        /// Look-at point.
        public let target: SIMD3<Float>
        public let position: SIMD3<Float>
        /// Vertical, degrees.
        public let fieldOfView: Float

        public init(target: SIMD3<Float>, position: SIMD3<Float>, fieldOfView: Float) {
            self.target = target
            self.position = position
            self.fieldOfView = fieldOfView
        }
    }

    public static let shots: [Station: Shot] = {
        var shots: [Station: Shot] = [
            .overview: Shot(target: [0.44, 1.33, -0.89], position: [13.28, 10.8, 14.36], fieldOfView: 50),
            .corner: Shot(target: [-4.31, 0.69, -0.22], position: [1.27, 2.01, 3.24], fieldOfView: 50),
            .flag: Shot(target: [3.03, 0.98, -2.31], position: [-0.45, 6.06, 1.46], fieldOfView: 50),
            .pr: Shot(target: [-3.93, 1.18, -2.72], position: [-0.81, 1.77, -0.02], fieldOfView: 50),
            .board: Shot(target: [-0.93, 1.97, 2.15], position: [-0.65, 2.21, 3.29], fieldOfView: 40),
            .kit: Shot(target: [2.59, 1.44, -1.05], position: [-0.31, 5.35, 4.42], fieldOfView: 50),
            .setv: Shot(target: [2.38, 1.54, -1.86], position: [3.04, 1.75, -0.89], fieldOfView: 50),
        ]
        // Computed like the prototype: the flag from 4.4 m in front, a little to the side and above.
        let flag = objects[.flag]!
        let angle = Double(flag.rotationDegrees) * Double.pi / 180
        let facing = SIMD3<Float>(Float(sinApprox(angle)), 0, Float(sinApprox(angle + Double.pi / 2)))
        shots[.nameFlag] = Shot(
            target: flag.position + SIMD3(0, -0.5, 0),
            position: SIMD3(flag.position.x + facing.x * 4.4 - facing.z * 0.6, flag.position.y + 0.2,
                            flag.position.z + facing.z * 4.4 + facing.x * 0.6),
            fieldOfView: 50
        )
        // Three-quarter view from the bar's end, close enough to see the sleeve.
        let bar = barOnRack
        shots[.bar] = Shot(target: SIMD3(bar.x + 0.55, 1.22, bar.z), position: SIMD3(bar.x + 2.25, 1.9, bar.z + 2.35), fieldOfView: 50)
        return shots
    }()
}
