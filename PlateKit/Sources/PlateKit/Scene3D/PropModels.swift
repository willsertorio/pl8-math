/// One piece of a prop, already placed in the prop's own space.
public struct PropPart: Equatable, Sendable {
    public enum Tone: Hashable, Sendable {
        /// The prototype's black → the palette's dark (boxDark).
        case dark
        /// The prototype's white → the palette's light (boxLight).
        case light
        /// The barbell: real steel so it reads against the background.
        case steel
        /// A plate, in its own colour.
        case plate(Plate)
        /// Hairlines like the floor's tile seams: a faint mix of dark into light.
        case faint
    }

    public let mesh: LowPolyMesh
    public let tone: Tone
    /// Drawn with the sketch outline. Hairlines and small details aren't.
    public let outlined: Bool
}

/// The diorama's props, ported from the prototype's builders (reference/prototype-app-logic.js:
/// buildRoom, buildPlatform, buildBoardAndBench, buildPRWall, buildFlag, buildPlatePiles, buildBarHolderG,
/// buildWallFanG, buildWallWindowG). Each is in its own space; place it with `RoomLayout.objects`.
public enum PropModels {
    /// - Parameter plates: the gym's plates, for the shelf piles.
    public static func parts(for object: RoomLayout.Object, plates: [Plate]) -> [PropPart] {
        var b = Builder()
        switch object {
        case .platform: platform(&b)
        case .rack: rack(&b)
        case .bench: bench(&b)
        case .board: board(&b)
        case .shelf: shelf(&b, plates: plates)
        case .flag: flag(&b)
        case .prBoard: prBoard(&b)
        case .barHolder: barHolder(&b)
        case .wallFan: wallFan(&b)
        case .wallWindow: wallWindow(&b)
        case .kitPlates: break
        }
        return b.parts
    }

    /// Where to put a prop's parts in the room. The shelf's parts are already in room space (the layout's shelf
    /// position offsets the piles from the left wall), so it gets no further move.
    public static func placement(for object: RoomLayout.Object) -> RoomLayout.Placement {
        if object == .shelf { return RoomLayout.Placement(position: .zero, rotationDegrees: 0) }
        return RoomLayout.objects[object] ?? RoomLayout.Placement(position: .zero, rotationDegrees: 0)
    }

    /// Floor with tile seams, the three walls, the line where they meet the floor, and the high window strip.
    /// In room space.
    public static func room() -> [PropPart] {
        var b = Builder()
        let r = RoomLayout.room, c = r.centre, h = r.wallHeight, t = r.wallThickness
        b.box([r.width + 0.32, 0.3, r.depth + 0.32], [c.x, -0.15, c.z], .light)
        for i in 1..<Int(r.width) { b.box([0.006, 0.002, r.depth], [r.minX + Float(i), 0.001, c.z], .faint, ink: false) }
        for j in 1..<Int(r.depth) { b.box([r.width, 0.002, 0.006], [c.x, 0.001, r.minZ + Float(j)], .faint, ink: false) }
        b.box([r.width + 2 * t, h, t], [c.x, h / 2, r.minZ - t / 2], .light)
        b.box([t, h, r.depth + 2 * t], [r.minX - t / 2, h / 2, c.z], .light)
        b.box([t, h, r.depth + 2 * t], [r.maxX + t / 2, h / 2, c.z], .light)
        b.box([r.width, 0.014, 0.006], [c.x, 0.007, r.minZ + 0.003], .dark, ink: false)
        b.box([0.006, 0.014, r.depth], [r.minX + 0.003, 0.007, c.z], .dark, ink: false)
        b.box([0.006, 0.014, r.depth], [r.maxX - 0.003, 0.007, c.z], .dark, ink: false)
        // A high window strip on the left wall.
        b.box([0.04, 0.5, 3.2], [r.minX + 0.02, 2.05, 0.6], .light)
        for i in 0..<5 { b.box([0.05, 0.5, 0.04], [r.minX + 0.03, 2.05, -1.0 + Float(i) * 0.8], .dark, ink: false) }
        return b.parts
    }

    // MARK: - Props

    /// 2.44 m platform: white wood strip down the middle, black rubber where the plates land.
    private static func platform(_ b: inout Builder) {
        b.box([2.44, 0.04, 2.44], [0, 0.02, 0], .dark)
        b.box([1.2, 0.05, 2.4], [0, 0.025, 0], .light)
        b.box([0.6, 0.05, 2.4], [-0.9, 0.025, 0], .dark)
        b.box([0.6, 0.05, 2.4], [0.9, 0.025, 0], .dark)
        for i in 1..<6 { b.box([1.2, 0.002, 0.004], [0, 0.051, -1.2 + Float(i) * 0.4], .dark, ink: false) }
    }

    /// Wall-mounted rack: two uprights, J-hooks, arms back to the wall, a pull-up bar, and the barbell on the hooks.
    private static func rack(_ b: inout Builder) {
        let z: Float = -0.85, top: Float = 2.35, wallZ: Float = -1.69
        for side: Float in [-1, 1] {
            let x = side * 0.62
            b.box([0.09, top, 0.09], [x, top / 2, z], .dark)                 // upright
            b.box([0.22, 0.02, 0.22], [x, 0.01, z], .dark)                   // floor plate
            var y: Float = 0.25
            while y < top - 0.1 {                                             // punched holes
                b.box([0.02, 0.02, 0.004], [x, y, z + 0.046], .light, ink: false)
                y += 0.1
            }
            b.box([0.1, 0.12, 0.1], [x, 1.22, z + 0.005], .dark)             // J-hook sleeve
            b.box([0.09, 0.03, 0.12], [x, 1.19, z + 0.1], .dark)             // hook seat
            b.box([0.09, 0.08, 0.02], [x, 1.24, z + 0.16], .dark)            // hook lip
            let length = abs(wallZ - z) - 0.065
            b.box([0.04, 0.04, length], [x, 2.02, z - 0.045 - length / 2], .dark)   // arm to the wall
            b.box([0.14, 0.24, 0.02], [x, 2.02, wallZ + 0.01], .dark)        // wall plate
        }
        b.cylinder(0.02, 1.33, .x, 12, [0, top - 0.06, z], .dark)            // pull-up bar
        barbell(&b, at: [0, 1.265, z + 0.08])
    }

    /// An Olympic bar along X: smooth centre, knurled hand sections, collars, sleeves and end caps.
    private static func barbell(_ b: inout Builder, at centre: SIMD3<Float>) {
        b.cylinder(0.0142, 0.16, .x, 20, centre, .steel)
        for side: Float in [-1, 1] {
            b.cylinder(0.0142, 0.26, .x, 20, centre + [side * 0.21, 0, 0], .steel)
            b.cylinder(0.0142, 0.32, .x, 20, centre + [side * 0.497, 0, 0], .steel)
            b.cylinder(0.04, 0.03, .x, 20, centre + [side * 0.67, 0, 0], .steel)
            b.cylinder(0.03, 0.012, .x, 20, centre + [side * 0.691, 0, 0], .steel)
            b.cylinder(0.025, 0.4, .x, 20, centre + [side * 0.897, 0, 0], .steel)
            b.cylinder(0.027, 0.012, .x, 20, centre + [side * 1.094, 0, 0], .steel)
        }
    }

    /// Flat bench: padded top on a rail, two T legs with foot caps; a notebook on it and a bottle beside it.
    private static func bench(_ b: inout Builder) {
        b.box([1.12, 0.085, 0.3], [0, 0.452, 0], .dark)
        b.box([1.06, 0.035, 0.26], [0, 0.392, 0], .dark)
        for side: Float in [-1, 1] {
            let x = side * 0.41
            b.box([0.065, 0.31, 0.065], [x, 0.22, 0], .dark)
            b.box([0.065, 0.055, 0.42], [x, 0.055, 0], .dark)
            for zs: Float in [-1, 1] { b.box([0.085, 0.07, 0.07], [x, 0.035, zs * 0.21], .dark) }
            for z: Float in [-0.07, 0.07] { b.cylinder(0.012, 0.03, .x, 8, [side * 0.52, 0.392, z], .light, ink: false) }
        }
        b.box([0.26, 0.025, 0.2], [-0.18, 0.4875, 0.02], .light)            // notebook
        b.cylinder(0.035, 0.2, .y, 12, [0.6, 0.1, 0.06], .dark)             // bottle
        b.cylinder(0.022, 0.03, .y, 12, [0.6, 0.215, 0.06], .light)
    }

    /// Whiteboard on wheeled legs, with a tray, a marker and an eraser.
    private static func board(_ b: inout Builder) {
        for x: Float in [-0.68, 0.68] {
            b.box([0.05, 1.75, 0.05], [x, 0.875, 0], .dark)
            b.box([0.05, 0.04, 0.5], [x, 0.055, 0], .dark)
            for wz: Float in [-0.22, 0.22] { b.cylinder(0.035, 0.03, .x, 10, [x, 0.035, wz], .dark) }
        }
        b.box([1.42, 0.98, 0.05], [0, 1.25, 0], .dark)                      // frame
        b.box([1.34, 0.9, 0.02], [0, 1.25, 0.03], .light, ink: false)       // writing surface
        b.box([1.2, 0.03, 0.08], [0, 0.77, 0.06], .dark)                    // tray
        b.box([0.12, 0.02, 0.02], [-0.3, 0.795, 0.07], .dark, ink: false)   // marker
        b.box([0.1, 0.035, 0.05], [0.25, 0.8, 0.07], .light)                // eraser
    }

    /// The PR board: a framed table with a chalk ledge.
    private static func prBoard(_ b: inout Builder) {
        b.box([1.7, 1.16, 0.04], [0, 0, 0], .dark)
        b.box([1.6, 1.06, 0.004], [0, 0, 0.022], .light, ink: false)
        b.box([1.5, 0.03, 0.07], [0, -0.6, 0.04], .dark)
        b.box([0.12, 0.02, 0.02], [0.35, -0.575, 0.05], .dark, ink: false)
    }

    /// The flag: dark cloth hanging from a rod on two nails (the gym name goes on it in a later step).
    private static func flag(_ b: inout Builder) {
        let width: Float = 1.45, height: Float = 1.0
        b.box([width, height, 0.01], [0, -height / 2, 0.035], .dark)
        b.cylinder(0.012, width + 0.12, .x, 8, [0, 0, 0.05], .dark)
        for side: Float in [-1, 1] {
            b.cylinder(0.018, 0.03, .x, 8, [side * (width / 2 + 0.06), 0, 0.05], .dark)
            b.cylinder(0.006, 0.05, .z, 5, [side * width * 0.42, 0, 0.025], .dark, ink: false)
        }
    }

    /// Plate piles on pegs off the left wall: bumpers on a low rail, change plates on a high one, heaviest first.
    /// The layout's shelf position offsets the piles from the wall (x), floor (y) and along it (z).
    private static func shelf(_ b: inout Builder, plates: [Plate]) {
        // In room space: see `placement(for:)`.
        let offset = RoomLayout.objects[.shelf]!.position
        let z0 = -3.5 + offset.z, z1 = -1.2 + offset.z
        let wallX = RoomLayout.room.minX + offset.x
        func row(_ list: [Plate], y: Float, counts: [Int], peg: Float) {
            guard !list.isEmpty else { return }
            b.box([0.035, 0.09, z1 - z0 + 0.3], [wallX + 0.0175, y, (z0 + z1) / 2], .dark)          // rail
            for (j, plate) in list.enumerated() {
                let z = z1 - (z1 - z0) * (Float(j) + 0.5) / Float(list.count)
                b.cylinder(0.022, peg, .x, 10, [wallX + 0.035 + peg / 2, y, z], .dark)            // peg
                b.cylinder(0.045, 0.02, .x, 12, [wallX + 0.045, y, z], .dark)                      // its base plate
                let thickness = Float(plate.thickness), radius = Float(plate.diameter) / 2
                for i in 0..<counts[j % counts.count] {
                    let x = wallX + 0.06 + Float(i) * (thickness + 0.003) + thickness / 2
                    let centre = SIMD3<Float>(x, y, z)                                         // hanging on the peg
                    b.add(LowPolyMesh.plate(radius: radius, holeRadius: 0.026, thickness: thickness, sides: 32)
                        .translated(by: centre), .plate(plate))
                }
            }
        }
        let sorted = plates.sorted { $0.size > $1.size }
        row(sorted.filter { $0.kind == .bumper }, y: 0.6 + offset.y, counts: [6, 5, 6, 5], peg: 0.42)
        row(sorted.filter { $0.kind == .change }, y: 1.3 + offset.y, counts: [8, 6, 8, 6, 8, 6], peg: 0.26)
    }

    /// Wall rack holding three bars.
    private static func barHolder(_ b: inout Builder) {
        let levels: [Float] = [0.55, 0.85, 1.15]
        for x: Float in [-0.52, 0.52] {
            b.box([0.07, 0.86, 0.03], [x, 0.85, 0.015], .dark)
            for y in levels {
                b.box([0.05, 0.03, 0.16], [x, y - 0.035, 0.1], .dark)
                b.box([0.05, 0.05, 0.025], [x, y - 0.01, 0.17], .dark, ink: false)
            }
        }
        for (i, (length, dx)) in [(Float(2.2), Float(0)), (2.2, 0.05), (2.01, -0.03)].enumerated() {
            let centre = SIMD3<Float>(dx, levels[i], 0.12), shaft = length - 0.9
            b.cylinder(0.014, shaft, .x, 10, centre, .dark)
            for side: Float in [-1, 1] {
                b.cylinder(0.04, 0.03, .x, 12, centre + [side * (shaft / 2 + 0.015), 0, 0], .dark)
                b.cylinder(0.025, 0.42, .x, 12, centre + [side * (shaft / 2 + 0.24), 0, 0], .light)
            }
        }
    }

    /// A wall fan with its switch below (simplified: no spinning blades yet).
    private static func wallFan(_ b: inout Builder) {
        let radius: Float = 0.27
        b.box([0.16, 0.22, 0.03], [0, 0, 0.015], .dark)                      // bracket
        b.box([0.05, 0.05, 0.2], [0, -0.02, 0.12], .dark)                    // arm
        b.cylinder(0.035, 0.07, .y, 10, [0, -0.02, 0.22], .dark)             // swivel
        b.cylinder(0.095, 0.16, .z, 16, [0, 0, 0.32], .light)                // motor housing
        b.cylinder(radius, 0.1, .z, 28, [0, 0, 0.49], .light)                // drum
        b.cylinder(radius - 0.025, 0.005, .z, 28, [0, 0, 0.542], .dark, ink: false)
        b.box([0.09, 0.13, 0.014], [0, -0.85, 0.008], .light)                // switch plate
        b.box([0.034, 0.06, 0.014], [0, -0.85, 0.02], .dark)                 // rocker
    }

    /// A window high on the right wall.
    private static func wallWindow(_ b: inout Builder) {
        let length: Float = 2.4, height: Float = 0.55, y: Float = 2.05
        b.box([length, height, 0.04], [0, y, 0.02], .light)
        b.box([length + 0.08, 0.04, 0.09], [0, y - height / 2 - 0.02, 0.045], .light)
        for i in 0...4 { b.box([0.04, height, 0.05], [-length / 2 + Float(i) * length / 4, y, 0.03], .dark, ink: false) }
        b.box([length, 0.035, 0.05], [0, y + height / 2 - 0.0175, 0.03], .dark, ink: false)
        b.box([length, 0.035, 0.05], [0, y - height / 2 + 0.0175, 0.03], .dark, ink: false)
    }

    // MARK: - Builder

    private struct Builder {
        var parts: [PropPart] = []

        mutating func add(_ mesh: LowPolyMesh, _ tone: PropPart.Tone, ink: Bool = true) {
            parts.append(PropPart(mesh: mesh, tone: tone, outlined: ink))
        }

        mutating func box(_ size: SIMD3<Float>, _ position: SIMD3<Float>, _ tone: PropPart.Tone, ink: Bool = true) {
            add(LowPolyMesh.box(size: size).translated(by: position), tone, ink: ink)
        }

        mutating func cylinder(_ radius: Float, _ length: Float, _ axis: LowPolyMesh.Axis, _ sides: Int,
                               _ position: SIMD3<Float>, _ tone: PropPart.Tone, ink: Bool = true) {
            add(LowPolyMesh.cylinder(radius: radius, length: length, sides: sides, axis: axis).translated(by: position), tone, ink: ink)
        }
    }
}
