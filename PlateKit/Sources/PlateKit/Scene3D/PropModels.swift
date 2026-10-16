/// One piece of a prop, already placed in the prop's own space.
public struct PropPart: Equatable, Sendable {
    public enum Tone: Hashable, Sendable {
        /// The prototype's black ('#111111') → the palette's dark, lit by the sun.
        case dark
        /// The prototype's white → the palette's light, lit by the sun.
        case light
        /// A painted colour, lit by the sun (a plate's rim).
        case paint(RGB)
        /// Shiny metal (the bar, the plates' hubs): it reflects the room, so it reads bright on top, mid-grey on
        /// the sides and dark underneath, whatever the sun does (the prototype's MeshStandardMaterial, metalness 1).
        case metal(RGB)
        /// Exactly this colour, unlit (ink).
        case flat(RGB)
        /// A printed surface (a plate's face, the PR table, the flag), lit by the sun.
        case picture(Picture)
    }

    public let mesh: LowPolyMesh
    public let tone: Tone
    /// Gets the prototype's thin ink lines on its hard edges (its `put` with ink).
    public let inked: Bool
    /// Casts a shadow.
    public let casts: Bool

    public init(mesh: LowPolyMesh, tone: Tone, inked: Bool, casts: Bool) {
        self.mesh = mesh
        self.tone = tone
        self.inked = inked
        self.casts = casts
    }
}

/// What's printed on a picture surface. The app draws it (reference/prototype-app-logic.js faceTexture,
/// buildPRWall, drawFlag), in black and white recoloured to the palette like the prototype.
public enum Picture: Hashable, Sendable {
    /// A plate's face: its number and unit.
    case plateFace(Plate)
    /// The PR board's empty table: "My PR's", a heavy rule, 8 ruled rows, 4 columns.
    case prTable
    /// The flag: the gym's name in light on the dark cloth.
    case flag(String)
}

/// The diorama's props, copied from the prototype's builders (reference/prototype-app-logic.js: applyLayout,
/// buildPlatform, buildBoardAndBench, buildPRWall, buildFlag, buildPlatePiles, assets, buildBarHolderG,
/// buildWallFanG, buildWallWindowG). Each is in its own space; place it with `RoomLayout.objects`.
/// Only what the prototype shows: its original room, bell, calendar, clipboard, notebook, bottle, chalk and wall
/// bars are hidden or removed there.
public enum PropModels {
    /// - Parameters:
    ///   - plates: the gym's plates, for the shelf piles.
    ///   - gymName: on the flag.
    ///   - barWeight, unit: the gym's bar, on the rack (lighter bars are shorter and thinner).
    public static func parts(for object: RoomLayout.Object, plates: [Plate], gymName: String = "",
                             barWeight: Double? = nil, unit: WeightUnit? = nil) -> [PropPart] {
        var b = Builder()
        switch object {
        case .platform: platform(&b)
        case .rack:
            let u = unit ?? plates.first?.unit ?? .kg
            rack(&b, barScale: barScale(barWeight ?? Bar.weights(u)[0], unit: u))
        case .bench: bench(&b)
        case .board: board(&b)
        case .shelf:
            b.parts = shelf(unit: unit ?? plates.first?.unit ?? .kg)
            for plate in plates {
                let pile = pile(plate)
                b.parts += pile.parts.map { PropPart(mesh: $0.mesh.translated(by: pile.pivot), tone: $0.tone, inked: $0.inked, casts: $0.casts) }
            }
        case .flag: flag(&b, text: gymName)
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

    // MARK: - The room (applyLayout)

    /// The floor slab (0.3 m thick, 0.16 m past the walls) and its 4 mm tile seams. In room space.
    public static func floor() -> [PropPart] {
        var b = Builder()
        let r = RoomLayout.room, c = r.centre
        b.box([r.width + 0.32, 0.3, r.depth + 0.32], [c.x, -0.15, c.z], .light)
        for i in 1..<Int(r.width) { b.box([0.004, 0.002, r.depth], [r.minX + Float(i), 0.001, c.z], .dark, ink: false, casts: false) }
        for j in 1..<Int(r.depth) { b.box([r.width, 0.002, 0.004], [c.x, 0.001, r.minZ + Float(j)], .dark, ink: false, casts: false) }
        return b.parts
    }

    /// A wall (0.15 m thick, outside the floor's tiles, 0.3 m longer than its side) and the fine line where it
    /// meets the floor. In room space.
    public static func wall(_ wall: RoomLayout.Wall) -> [PropPart] {
        var b = Builder()
        let r = RoomLayout.room, c = r.centre, h = r.wallHeight, t = r.wallThickness
        switch wall {
        case .back:
            b.box([r.width + 0.3, h, t], [c.x, h / 2, r.minZ - t / 2], .light)
            b.box([r.width, 0.014, 0.006], [c.x, 0.007, r.minZ + 0.003], .dark, ink: false, casts: false)
        case .left:
            b.box([t, h, r.depth + 0.3], [r.minX - t / 2, h / 2, c.z], .light)
            b.box([0.006, 0.014, r.depth], [r.minX + 0.003, 0.007, c.z], .dark, ink: false, casts: false)
        case .right:
            b.box([t, h, r.depth + 0.3], [r.maxX + t / 2, h / 2, c.z], .light)
            b.box([0.006, 0.014, r.depth], [r.maxX - 0.003, 0.007, c.z], .dark, ink: false, casts: false)
        }
        return b.parts
    }

    /// The prototype's rough, grainy sketch line around the box (its screen-space sketch pass), as 3D strokes on
    /// the outside edges: along the top of `wall`, or (for `nil`) round the bottom of the floor slab and up its
    /// corners. A double line, like the sketch pass.
    public static func border(_ wall: RoomLayout.Wall?) -> [PropPart] {
        let r = RoomLayout.room, h = r.wallHeight, t = r.wallThickness
        let x0 = r.minX - t, x1 = r.maxX + t, z0 = r.minZ - t, zFront = r.maxZ + 0.15
        let sx0 = r.minX - 0.16, sx1 = r.maxX + 0.16, sz0 = r.minZ - 0.16, sz1 = r.maxZ + 0.16
        let edges: [(SIMD3<Float>, SIMD3<Float>)]
        switch wall {
        case .back?: edges = [([x0, h, z0], [x1, h, z0]), ([x0, 0, z0], [x0, h, z0]), ([x1, 0, z0], [x1, h, z0])]
        case .left?: edges = [([x0, h, z0], [x0, h, zFront]), ([x0, 0, zFront], [x0, h, zFront])]
        case .right?: edges = [([x1, h, z0], [x1, h, zFront]), ([x1, 0, zFront], [x1, h, zFront])]
        case nil:
            edges = [([sx0, -0.3, sz0], [sx1, -0.3, sz0]), ([sx0, -0.3, sz1], [sx1, -0.3, sz1]),
                     ([sx0, -0.3, sz0], [sx0, -0.3, sz1]), ([sx1, -0.3, sz0], [sx1, -0.3, sz1]),
                     ([sx0, -0.3, sz1], [sx0, 0, sz1]), ([sx1, -0.3, sz1], [sx1, 0, sz1])]
        }
        let base: UInt32 = switch wall { case .back?: 10; case .left?: 20; case .right?: 30; case nil: 40 }
        var stroke = LowPolyMesh()
        for (i, edge) in edges.enumerated() {
            stroke.append(.roughEdge(from: edge.0, to: edge.1, width: 0.035, seed: base + UInt32(i * 2)))
            stroke.append(.roughEdge(from: edge.0, to: edge.1, width: 0.02, seed: base + UInt32(i * 2 + 1)))
        }
        return [PropPart(mesh: stroke, tone: .flat(Look.ink), inked: false, casts: false)]
    }

    // MARK: - Props

    /// 2.44 m platform: white wood strip down the middle, black rubber where the plates land.
    private static func platform(_ b: inout Builder) {
        b.box([2.44, 0.04, 2.44], [0, 0.02, 0], .dark)
        b.box([1.2, 0.05, 2.4], [0, 0.025, 0], .light)
        b.box([0.6, 0.05, 2.4], [-0.9, 0.025, 0], .dark)
        b.box([0.6, 0.05, 2.4], [0.9, 0.025, 0], .dark)
        for i in 1..<6 { b.box([1.2, 0.002, 0.004], [0, 0.051, -1.2 + Float(i) * 0.4], .dark, ink: false, casts: false) }
    }

    /// The platform's top surfaces, in its own space, for shadows to fall on: the light strip and the two mats.
    public static let platformTops: [(centre: SIMD3<Float>, size: SIMD2<Float>, tone: PropPart.Tone)] = [
        ([0, 0.05, 0], [1.2, 2.4], .light), ([-0.9, 0.05, 0], [0.6, 2.4], .dark), ([0.9, 0.05, 0], [0.6, 2.4], .dark),
    ]

    /// Wall-mounted rack: two uprights, J-hooks, arms back to the wall, a pull-up bar, and the barbell on the hooks.
    /// How much shorter (x) and thinner (y) the gym's bar is than the full Olympic bar: the prototype's
    /// setBarModel, by the bar's place in the unit's list (20/15/10 kg, 45/35/15 lb).
    public static func barScale(_ weight: Double, unit: WeightUnit) -> SIMD2<Float> {
        let index = max(0, Bar.weights(unit).firstIndex(of: weight) ?? 0)
        return [SIMD2<Float>(1, 1), SIMD2(0.914, 0.88), SIMD2(0.8, 0.8)][min(index, 2)]
    }

    private static func rack(_ b: inout Builder, barScale: SIMD2<Float> = [1, 1]) {
        let z: Float = -0.85, top: Float = 2.35, wallZ: Float = -1.69
        for side: Float in [-1, 1] {
            let x = side * 0.62
            b.box([0.09, top, 0.09], [x, top / 2, z], .dark)                 // upright
            b.box([0.22, 0.02, 0.22], [x, 0.01, z], .dark)                   // floor plate
            var y: Float = 0.25
            while y < top - 0.1 {                                             // punched holes
                b.box([0.02, 0.02, 0.004], [x, y, z + 0.046], .light, ink: false, casts: false)
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
        let bar = SIMD3<Float>(0, 1.265, z + 0.08)
        var barbellParts = Builder()
        barbell(&barbellParts, at: .zero)
        b.parts += barbellParts.parts.map { part in
            PropPart(mesh: part.mesh.mapped { SIMD3($0.x * barScale.x, $0.y * barScale.y, $0.z * barScale.y) + bar },
                     tone: part.tone, inked: part.inked, casts: part.casts)
        }
    }

    /// An Olympic bar along X, in the prototype's steels: smooth centre, knurled hand sections, collars,
    /// sleeves and end caps.
    private static func barbell(_ b: inout Builder, at centre: SIMD3<Float>) {
        let smooth = PropPart.Tone.metal(RGB(hex: "#CDD2D8")), knurl = PropPart.Tone.metal(RGB(hex: "#D3D8DD"))
        let sleeve = PropPart.Tone.metal(RGB(hex: "#EEF1F4")), collar = PropPart.Tone.metal(RGB(hex: "#A9B0B8"))
        b.cylinder(0.0142, 0.16, .x, 28, centre, smooth, ink: false)
        for side: Float in [-1, 1] {
            b.cylinder(0.0142, 0.26, .x, 28, centre + [side * 0.21, 0, 0], knurl, ink: false)
            b.cylinder(0.0142, 0.32, .x, 28, centre + [side * 0.497, 0, 0], smooth, ink: false)
            b.cylinder(0.04, 0.03, .x, 28, centre + [side * 0.67, 0, 0], collar, ink: false)
            b.cylinder(0.03, 0.012, .x, 28, centre + [side * 0.691, 0, 0], collar, ink: false)
            b.cylinder(0.025, 0.4, .x, 28, centre + [side * 0.897, 0, 0], sleeve, ink: false)
            b.cylinder(0.027, 0.012, .x, 28, centre + [side * 1.094, 0, 0], sleeve, ink: false)
        }
    }

    /// Flat bench: a thick padded top on a steel rail, two T legs with rubber foot caps.
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
    }

    /// Whiteboard on wheeled legs, with a tray, a marker and an eraser.
    private static func board(_ b: inout Builder) {
        for x: Float in [-0.68, 0.68] {
            b.box([0.05, 1.75, 0.05], [x, 0.875, 0], .dark)
            b.box([0.05, 0.04, 0.5], [x, 0.055, 0], .dark)
            for wz: Float in [-0.22, 0.22] { b.cylinder(0.035, 0.03, .x, 8, [x, 0.035, wz], .dark) }
        }
        b.box([1.42, 0.98, 0.05], [0, 1.25, 0], .dark)                      // frame
        b.box([1.34, 0.9, 0.02], [0, 1.25, 0.03], .light, ink: false)       // writing surface
        b.box([1.2, 0.03, 0.08], [0, 0.77, 0.06], .dark)                    // tray
        b.box([0.12, 0.02, 0.02], [-0.3, 0.795, 0.07], .dark, ink: false)   // marker
        b.box([0.1, 0.035, 0.05], [0.25, 0.8, 0.07], .light)                // eraser
    }

    /// The PR board: a frame, the printed table, a ledge and a marker.
    private static func prBoard(_ b: inout Builder) {
        b.box([1.7, 1.16, 0.04], [0, 0, 0], .dark)
        b.add(LowPolyMesh.sheet(width: 1.6, height: 1.06, columns: 1, rows: 1).translated(by: [0, 0, 0.022]),
              .picture(.prTable), ink: false, casts: false)
        b.box([1.5, 0.03, 0.07], [0, -0.6, 0.04], .dark)
        b.box([0.12, 0.02, 0.02], [0.35, -0.575, 0.05], .dark, ink: false)
    }

    /// The flag: cloth with a few soft vertical folds, hanging from a rod on two nails, the gym's name on it.
    private static func flag(_ b: inout Builder, text: String) {
        let width: Float = 1.45, height: Float = 1.0
        let cloth = LowPolyMesh.sheet(width: width, height: height, columns: 24, rows: 12) { x, y in
            let sag = (height / 2 - y) / height
            return 0.035 + sine(x * 7.5 + 0.6) * 0.02 * (0.4 + sag) + sag * 0.02
        }
        b.add(cloth.translated(by: [0, -height / 2, 0]), .picture(.flag(text)), ink: false)
        b.cylinder(0.012, width + 0.12, .x, 8, [0, 0, 0.05], .dark)
        for side: Float in [-1, 1] {
            b.cylinder(0.018, 0.03, .x, 8, [side * (width / 2 + 0.06), 0, 0.05], .dark)
            b.cylinder(0.006, 0.05, .z, 5, [side * width * 0.42, 0, 0.025], .dark, ink: false)
        }
    }

    // MARK: - The plate shelf (buildPlatePiles)

    /// Bumpers hang on a low rail, change plates on a high one, heaviest first; the layout's shelf position
    /// offsets them from the wall (x), floor (y) and along it (z). Every size of the unit has its peg.
    private struct ShelfSpot {
        let y: Float, z: Float, peg: Float, count: Int
    }

    private static func spots(_ unit: WeightUnit) -> [(Plate, ShelfSpot)] {
        let offset = RoomLayout.objects[.shelf]!.position
        let z0 = -3.5 + offset.z, z1 = -1.2 + offset.z
        let sorted = Plate.catalog(unit).sorted { $0.size > $1.size }
        var result: [(Plate, ShelfSpot)] = []
        for (list, y, counts, peg) in [(sorted.filter { $0.kind == .bumper }, 0.6 + offset.y, [6, 5, 6, 5], Float(0.42)),
                                       (sorted.filter { $0.kind == .change }, 1.3 + offset.y, [8, 6, 8, 6, 8, 6], Float(0.26))] {
            for (j, plate) in list.enumerated() {
                let z = z1 - (z1 - z0) * (Float(j) + 0.5) / Float(list.count)
                result.append((plate, ShelfSpot(y: y, z: z, peg: peg, count: counts[j % counts.count])))
            }
        }
        return result
    }

    private static var wallX: Float { RoomLayout.room.minX + RoomLayout.objects[.shelf]!.position.x }

    /// The rails and a peg (with its base plate) for every plate size of `unit`. In room space.
    public static func shelf(unit: WeightUnit) -> [PropPart] {
        var b = Builder()
        let offset = RoomLayout.objects[.shelf]!.position
        let z0 = -3.5 + offset.z, z1 = -1.2 + offset.z
        for y in Set(spots(unit).map(\.1.y)).sorted() {
            b.box([0.035, 0.09, z1 - z0 + 0.3], [wallX + 0.0175, y, (z0 + z1) / 2], .dark)          // rail
        }
        for (_, spot) in spots(unit) {
            b.cylinder(0.022, spot.peg, .x, 10, [wallX + 0.035 + spot.peg / 2, spot.y, spot.z], .dark)   // peg
            b.cylinder(0.045, 0.02, .x, 12, [wallX + 0.045, spot.y, spot.z], .dark)                       // its base plate
        }
        return b.parts
    }

    /// One plate size's pile on its peg: `pivot` is where it hangs at the wall (room space), the parts are
    /// around it, so the app can pop the pile in and out from there.
    public static func pile(_ plate: Plate) -> (pivot: SIMD3<Float>, parts: [PropPart]) {
        guard let spot = spots(plate.unit).first(where: { $0.0 == plate })?.1 else { return (.zero, []) }
        let pivot = SIMD3<Float>(wallX + 0.06, spot.y, spot.z)
        let thickness = Float(plate.thickness)
        var parts: [PropPart] = []
        for i in 0..<spot.count {
            let x = Float(i) * (thickness + 0.003) + thickness / 2
            // Each hangs at its own angle on the peg, the same every time.
            let seed = UInt32(plate.size * 4) &* 2_654_435_761 &+ UInt32(i) &* 40_503
            let turn = Float(seed % 10_000) / 10_000 * 2 * Float.pi
            for part in plateParts(plate, turn: turn) {
                parts.append(PropPart(mesh: part.mesh.translated(by: [x, 0, 0]), tone: part.tone, inked: false, casts: true))
            }
        }
        return (pivot, parts)
    }

    /// A plate along X, centred on the origin (the prototype's `assets`): printed faces from the hub out, a
    /// slightly darker rim, and a chrome hub a little thicker than the plate.
    public static func plateParts(_ plate: Plate, turn: Float = 0, sides: Int = 64) -> [PropPart] {
        let radius = Float(plate.diameter) / 2, t = Float(plate.thickness), hole: Float = 0.0255
        let hub = plate.kind == .bumper ? 0.068 : min(0.046, radius * 0.46), hubLength = t + 0.005
        let hubSides = max(8, Int((Float(sides) * 0.6).rounded()))
        let colour = RGB(hex: plate.colorHex)
        let chrome = PropPart.Tone.metal(RGB(hex: "#D8DCE1"))
        var faces = LowPolyMesh.ring(inner: hub * 0.98, outer: radius, sides: sides, facingBack: false, turn: turn)
            .translated(by: [t / 2, 0, 0])
        faces.append(LowPolyMesh.ring(inner: hub * 0.98, outer: radius, sides: sides, facingBack: true, turn: turn)
            .translated(by: [-t / 2, 0, 0]))
        var hubMesh = LowPolyMesh.ring(inner: hole, outer: hub, sides: hubSides, facingBack: false).translated(by: [hubLength / 2, 0, 0])
        hubMesh.append(LowPolyMesh.ring(inner: hole, outer: hub, sides: hubSides, facingBack: true).translated(by: [-hubLength / 2, 0, 0]))
        hubMesh.append(LowPolyMesh.sleeve(radius: hub, length: hubLength, sides: hubSides))
        hubMesh.uvs = []
        return [
            PropPart(mesh: faces, tone: .picture(.plateFace(plate)), inked: false, casts: true),
            PropPart(mesh: LowPolyMesh.sleeve(radius: radius, length: t, sides: sides), tone: .paint(colour.offsetLightness(-0.05)),
                     inked: false, casts: true),
            PropPart(mesh: hubMesh, tone: chrome, inked: false, casts: true),
            PropPart(mesh: LowPolyMesh.sleeve(radius: hole, length: hubLength, sides: max(6, sides * 4 / 10), inward: true),
                     tone: .metal(RGB(hex: "#9AA1AA")), inked: false, casts: false),
        ]
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
            b.cylinder(0.014, shaft, .x, 8, centre, .dark)
            for side: Float in [-1, 1] {
                b.cylinder(0.04, 0.03, .x, 10, centre + [side * (shaft / 2 + 0.015), 0, 0], .dark)
                b.cylinder(0.025, 0.42, .x, 10, centre + [side * (shaft / 2 + 0.24), 0, 0], .light)
            }
        }
    }

    /// A wall fan: bracket and arm, a head tilted down a little with its drum, blades, hub, guard rings and
    /// spokes, and the switch below with its cable wiggling up the wall. Still (the prototype's blades spin).
    private static func wallFan(_ b: inout Builder) {
        let radius: Float = 0.27
        b.box([0.16, 0.22, 0.03], [0, 0, 0.015], .dark)                      // wall bracket
        b.box([0.05, 0.05, 0.2], [0, -0.02, 0.12], .dark)                    // arm
        let swivel = SIMD3<Float>(0, 0, 0.22)
        b.add(LowPolyMesh.cylinder(radius: 0.035, length: 0.07, sides: 10, axis: .y).translated(by: swivel + [0, -0.02, 0]), .dark)
        // The head, tilted down 0.28 rad around X, hung from the swivel.
        func head(_ mesh: LowPolyMesh) -> LowPolyMesh { mesh.rotatedX(0.28).translated(by: swivel) }
        b.add(head(LowPolyMesh.cylinder(radius: 0.095, length: 0.16, sides: 16, axis: .z).translated(by: [0, 0, 0.1])), .light)   // motor
        b.add(head(LowPolyMesh.cylinder(radius: radius, length: 0.1, sides: 28, axis: .z).translated(by: [0, 0, 0.27])), .light)  // drum
        b.add(head(LowPolyMesh.cylinder(radius: radius - 0.025, length: 0.005, sides: 28, axis: .z).translated(by: [0, 0, 0.32])),
              .dark, ink: false)
        for i in 0..<3 {                                                                                     // blades
            let blade = LowPolyMesh.box(size: [0.09, 0.2, 0.006]).rotatedY(0.35).translated(by: [0, 0.12, 0])
                .rotatedZ(Float(i) * 2 * Float.pi / 3).translated(by: [0, 0, 0.33])
            b.add(head(blade), .light, ink: false)
        }
        b.add(head(LowPolyMesh.cylinder(radius: 0.04, length: 0.02, sides: 12, axis: .z).translated(by: [0, 0, 0.334])), .light)
        for ring: Float in [0.09, 0.17, radius - 0.01] {                                                    // guard
            b.add(head(LowPolyMesh.hoop(radius: ring, width: 0.01, segments: 32).translated(by: [0, 0, 0.335])), .dark,
                  ink: false, casts: false)
        }
        for i in 0..<4 {                                                                                     // spokes
            let spoke = LowPolyMesh.box(size: [0.006, 2 * radius - 0.02, 0.006]).rotatedZ(Float(i) * Float.pi / 4)
            b.add(head(spoke.translated(by: [0, 0, 0.335])), .dark, ink: false)
        }
        b.box([0.09, 0.13, 0.014], [0, -0.85, 0.008], .light)                                              // switch plate
        b.add(LowPolyMesh.box(size: [0.034, 0.06, 0.014]).rotatedX(-0.32).translated(by: [0, -0.85, 0.02]), .dark)   // rocker: on
        let cable: [SIMD3<Float>] = [[0, -0.78, 0.012], [0.025, -0.66, 0.012], [-0.012, -0.48, 0.012],
                                     [0.02, -0.3, 0.012], [0.004, -0.16, 0.014], [0, -0.11, 0.02]]
        b.add(LowPolyMesh.tube(through: cable, width: 0.012), .dark, ink: false)
    }

    /// A window high on the wall: glass pane, sill, four panes' mullions and the top and bottom rails.
    private static func wallWindow(_ b: inout Builder) {
        let length: Float = 2.4, height: Float = 0.55, y: Float = 2.05
        b.box([length, height, 0.04], [0, y, 0.02], .light)
        b.box([length + 0.08, 0.04, 0.09], [0, y - height / 2 - 0.02, 0.045], .light)
        for i in 0...4 { b.box([0.04, height, 0.05], [-length / 2 + Float(i) * length / 4, y, 0.03], .dark, ink: false) }
        b.box([length, 0.035, 0.05], [0, y + height / 2 - 0.0175, 0.03], .dark, ink: false)
        b.box([length, 0.035, 0.05], [0, y - height / 2 + 0.0175, 0.03], .dark, ink: false)
    }

    // MARK: - Builder

    struct Builder {
        var parts: [PropPart] = []

        mutating func add(_ mesh: LowPolyMesh, _ tone: PropPart.Tone, ink: Bool = true, casts: Bool = true) {
            parts.append(PropPart(mesh: mesh, tone: tone, inked: ink, casts: casts))
        }

        mutating func box(_ size: SIMD3<Float>, _ position: SIMD3<Float>, _ tone: PropPart.Tone, ink: Bool = true, casts: Bool = true) {
            add(LowPolyMesh.box(size: size).translated(by: position), tone, ink: ink, casts: casts)
        }

        mutating func cylinder(_ radius: Float, _ length: Float, _ axis: LowPolyMesh.Axis, _ sides: Int,
                               _ position: SIMD3<Float>, _ tone: PropPart.Tone, ink: Bool = true) {
            add(LowPolyMesh.cylinder(radius: radius, length: length, sides: sides, axis: axis).translated(by: position), tone, ink: ink)
        }
    }
}
