import Foundation

/// The Flow's 3D props, built like the prototype builds them (design/flow-handoff/source; the newest
/// `comp_flow*.js` version of each): same shapes, sizes, segment counts and colours.
public enum FlowProps {
    static let dark = FlowLook.dark, light = FlowLook.light

    // MARK: - Plates and bars

    /// A plate lying flat, faces up and down, its printed number pointing away (−Z), like three.js `plate(spec)`.
    public static func plate(_ plate: Plate, sides: Int = 48) -> FlowNode {
        // PropModels' plate is along X with its picture's top at +Y; turn X → Y and the picture's top → −Z.
        let toY: (SIMD3<Float>) -> SIMD3<Float> = { SIMD3(-$0.z, $0.x, -$0.y) }
        let bumper = plate.kind == .bumper
        let parts: [FlowPart] = PropModels.plateParts(plate, sides: sides).enumerated().flatMap { index, part -> [FlowPart] in
            let mesh = part.mesh.mapped(toY)
            switch part.tone {
            case .picture(.plateFace(let p)):
                // Each side its own part: a printed face is lit as one flat surface.
                return [mesh.keepingFaces { $0.y > 0 }, mesh.keepingFaces { $0.y < 0 }].map { side in
                    FlowPart("face", mesh: side, paint: .picture(.plateFace(p), tint: RGB(1, 1, 1)),
                             shade: .standard(roughness: bumper ? 0.8 : 0.38, metalness: bumper ? 0 : 0.2))
                }
            case .paint(let colour):
                return [FlowPart("rim", mesh: mesh, paint: .colour(colour), shade: .standard(roughness: bumper ? 0.85 : 0.4, metalness: bumper ? 0 : 0.2))]
            case .metal(let colour):
                return [FlowPart(index == 2 ? "hub" : "hole", mesh: mesh, paint: .colour(colour), shade: .standard(roughness: 0.2, metalness: 1))]
            default:
                return [FlowPart("part", mesh: mesh, paint: .colour(dark), shade: .toon)]
            }
        }
        return FlowNode("plate", parts: parts)
    }

    /// A plate you don't have (flPlates' grey): every part flat grey at 30 %.
    public static func ghost(_ plate: Plate) -> FlowNode {
        var node = Self.plate(plate)
        node.name = "ghost"
        node.parts = node.parts.map { FlowPart($0.name, mesh: $0.mesh, paint: .colour(FlowLook.missing), shade: .flat, opacity: FlowLook.missingOpacity) }
        return node
    }

    /// The sets' bar (flBarGroup): shaft, collars, sleeves and end caps along X, standing at 0.9 m.
    public static func barbell() -> FlowNode {
        let steel = RGB(hex: "#C9CED4"), sleeve = RGB(hex: "#EEF1F4")
        var bar = FlowNode("bar", position: [0, 0.9, 0])
        func cylinder(_ r: Float, _ length: Float, _ colour: RGB, _ x: Float, rough: Float) {
            let mesh = Geo.cylinder(top: r, bottom: r, height: length, segments: 20)
            bar.add(FlowPart("steel", mesh: mesh, paint: .colour(colour), shade: .standard(roughness: rough, metalness: 0.9)),
                    at: [x, 0, 0], rotation: [0, 0, .pi / 2])
        }
        cylinder(0.0142, 1.31, steel, 0, rough: 0.3)
        for s: Float in [-1, 1] {
            cylinder(0.032, 0.03, steel, s * 0.67, rough: 0.3)
            cylinder(0.025, 0.42, sleeve, s * 0.895, rough: 0.15)
            cylinder(0.03, 0.02, steel, s * 1.105, rough: 0.3)
        }
        return bar
    }

    /// The bar question's bars (barModel): standing on end, flat-shaded toon; `index` 0, 1, 2 for the heavy,
    /// middle and light bar (shorter and thinner).
    public static func standingBar(index: Int) -> FlowNode {
        let lengths: [Float] = [1, 0.914, 0.8], thick: [Float] = [1, 0.88, 0.8]
        let l = lengths[min(2, max(0, index))], th = thick[min(2, max(0, index))]
        let shaft = RGB(hex: "#B4BAC1"), sleeve = RGB(hex: "#EDEFF1"), collar = RGB(hex: "#5E6670")
        var bar = FlowNode("bar")
        func cylinder(_ r: Float, _ length: Float, _ colour: RGB, _ y: Float) {
            bar.add(.toon("steel", Geo.cylinder(top: r, bottom: r, height: length, segments: 8), colour), at: [0, y, 0])
        }
        let half = 1.1 * l, sl = 0.42 * l, sr = 0.025 * th * 1.6, rr = 0.0142 * th * 1.7
        cylinder(rr, (half - sl) * 2, shaft, 0)
        for s: Float in [-1, 1] {
            cylinder(rr * 2.6, 0.035, collar, s * (half - sl))
            cylinder(sr, sl, sleeve, s * (half - sl / 2))
            cylinder(sr * 1.15, 0.02, collar, s * half)
        }
        return bar
    }

    // MARK: - The questions' objects

    /// A letter or number dial's body (flDrum): a ten-sided drum along X, light rims, and a light frame round the
    /// reading window. The labels are laid out by the app. The front of the drum is at z = 0.
    public static func drum(radius r: Float, step a0: Float, width w: Float) -> FlowNode {
        var drum = FlowNode("drum", position: [0, 0, -r])
        drum.add(.toon("body", Geo.cylinder(top: r - 0.03, bottom: r - 0.03, height: w, segments: 10), dark), rotation: [0, 0, .pi / 2])
        for s: Float in [-1, 1] {
            drum.add(.toon("rim", Geo.cylinder(top: r + 0.04, bottom: r + 0.04, height: 0.07, segments: 10), light),
                     at: [s * (w / 2 + 0.03), 0, 0], rotation: [0, 0, .pi / 2])
        }
        let fh = a0 * r * 1.02, fw = w + 0.14, bt: Float = 0.035
        var frame = FlowNode("frame")
        for (x, y, bw, bh) in [(0, fh / 2, fw, bt), (0, -fh / 2, fw, bt), (-fw / 2, 0, bt, fh + bt), (fw / 2, 0, bt, fh + bt)] as [(Float, Float, Float, Float)] {
            frame.add(.flat("frame", Geo.solidBox(bw, bh, 0.03), light), at: [x, y, r + 0.06])
        }
        drum.add(frame)
        return drum
    }

    /// A kettlebell (kettlebell): a sphere cut flat at the bottom and closed with a disc, a half-torus handle on
    /// two posts, and its unit in light on the front. Stands on y = 0.
    public static func kettlebell(label: String) -> FlowNode {
        let cut = Float.pi * 0.84, yb = 0.42 * cosine(cut), top = 0.42 - yb
        var bell = FlowNode("kettlebell")
        bell.add(.toon("body", Geo.sphere(radius: 0.42, widthSegments: 16, heightSegments: 12, thetaLength: cut), dark), at: [0, -yb, 0])
        bell.add(.toon("foot", Geo.circle(radius: 0.42 * sine(cut), segments: 16), dark), at: [0, 0.001, 0], rotation: [.pi / 2, 0, 0])
        bell.add(.toon("handle", Geo.torus(radius: 0.24, tube: 0.058, radialSegments: 8, tubularSegments: 18, arc: .pi), dark), at: [0, top + 0.12, 0])
        for s: Float in [-1, 1] {
            bell.add(.toon("post", Geo.cylinder(top: 0.058, bottom: 0.07, height: 0.2, segments: 8), dark), at: [s * 0.24, top + 0.04, 0])
        }
        let picture = FlowPicture.text(label, width: 256, height: 160, size: 120, colour: light, dy: 8)
        bell.add(FlowPart("label", mesh: Geo.plane(0.5, 0.32), paint: .picture(picture, tint: RGB(1, 1, 1)), shade: .flat), at: [0, -yb, 0.43])
        return bell
    }

    /// The units question's floor square (flUnit): a fixed light outline, the platform inside it that sinks like a
    /// scale, and the depth-only floor around the hole that hides the platform's sides when it sinks.
    public static func unitSquare(ink: RGB) -> (frame: FlowNode, platform: FlowNode, occluder: FlowNode) {
        let size: Float = 1.25, th: Float = 0.06, inner = size - 0.12, it: Float = 0.035
        var frame = FlowNode("square")
        for (x, z, w, d) in [(0, -size / 2, size + th, th), (0, size / 2, size + th, th), (-size / 2, 0, th, size), (size / 2, 0, th, size)] as [(Float, Float, Float, Float)] {
            frame.add(.flat("line", Geo.solidBox(w, 0.02, d), ink), at: [x, 0.01, z])
        }
        var platform = FlowNode("platform")
        platform.add(.toon("slab", Geo.solidBox(inner, 0.5, inner), light), at: [0, -0.25, 0])
        for (x, z, w, d) in [(0, -inner / 2 + it / 2, inner, it), (0, inner / 2 - it / 2, inner, it), (-inner / 2 + it / 2, 0, it, inner), (inner / 2 - it / 2, 0, it, inner)] as [(Float, Float, Float, Float)] {
            platform.add(.flat("line", Geo.solidBox(w, 0.012, d), ink), at: [x, 0.006, z])
        }
        var occluder = FlowNode("occluder")
        for (x, z, w, d) in [(-(size / 2 + 3), 0, 6, size + 12), (size / 2 + 3, 0, 6, size + 12), (0, -(size / 2 + 3), size, 6), (0, size / 2 + 3, size, 6)] as [(Float, Float, Float, Float)] {
            occluder.add(FlowPart("floor", mesh: Geo.solidBox(w, 1, d), paint: .colour(dark), shade: .occluder), at: [x, -0.5, z])
        }
        return (frame, platform, occluder)
    }

    /// The abduction (flUnit): the beam and its pool on the floor, in `FlowLook.beam` (fade them in from 0).
    public static func beam() -> (beam: FlowNode, pool: FlowNode) {
        let beam = FlowNode.part(FlowPart("beam", mesh: Geo.cylinder(top: 0.22, bottom: 0.62, height: 7, segments: 28, openEnded: true),
                                          paint: .colour(FlowLook.beam), shade: .flat, twoSided: true))
        let pool = FlowNode.part(FlowPart("pool", mesh: Geo.circle(radius: 0.62, segments: 28), paint: .colour(FlowLook.beam), shade: .flat),
                                 rotation: [-.pi / 2, 0, 0])
        return (beam, pool)
    }

    /// The PR dial's reading notches: small triangles each side.
    public static func notch(ink: RGB, side: Float) -> FlowNode {
        .part(.flat("notch", Geo.cone(radius: 0.09, height: 0.2, segments: 3), ink), at: [side * 0.98, -0.2, 0.05], rotation: [0, 0, side * .pi / 2])
    }

    /// The whiteboard on wheels (whiteboardModel): 1.7 × 1.1 face 1.45 up in a dark frame, a tray, two legs on feet
    /// with two wheels each.
    public static func whiteboard(lines: [FlowBoardLine]?) -> FlowNode {
        let bw: Float = 1.7, bh: Float = 1.1, y: Float = 1.45
        var board = FlowNode("whiteboard")
        let faces = Geo.box(bw, bh, 0.04)
        var front = FlowNode("board", position: [0, y, 0])
        for (i, face) in faces.enumerated() {
            if i == 4 {
                front.parts.append(FlowPart("face", mesh: face, paint: .picture(.whiteboard(lines), tint: RGB(1, 1, 1)), shade: .flat))
            } else {
                front.parts.append(.toon("edge", face, dark))
            }
        }
        board.add(front)
        func frame(_ w: Float, _ h: Float, _ x: Float, _ fy: Float) { board.add(.toon("frame", Geo.solidBox(w, h, 0.07), dark), at: [x, fy, 0]) }
        frame(bw + 0.1, 0.06, 0, y + bh / 2); frame(bw + 0.1, 0.06, 0, y - bh / 2); frame(0.06, bh, -bw / 2, y); frame(0.06, bh, bw / 2, y)
        board.add(.toon("tray", Geo.solidBox(bw * 0.6, 0.03, 0.12), dark), at: [0, y - bh / 2 - 0.04, 0.06])
        var wheel = 0
        for s: Float in [-1, 1] {
            board.add(.toon("leg", Geo.solidBox(0.05, y + 0.05, 0.05), dark), at: [s * (bw / 2 - 0.05), (y + 0.05) / 2 + 0.05, 0])
            board.add(.toon("foot", Geo.solidBox(0.06, 0.05, 0.62), dark), at: [s * (bw / 2 - 0.05), 0.09, 0])
            for z: Float in [-1, 1] {
                // The wheel turns about X inside its holder, which lays the cylinder on its side.
                var holder = FlowNode("wheel\(wheel)", position: [s * (bw / 2 - 0.05), 0.05, z * 0.27])
                holder.add(.toon("tyre", Geo.cylinder(top: 0.05, bottom: 0.05, height: 0.04, segments: 10), RGB(hex: "#333333")), rotation: [0, 0, .pi / 2])
                board.add(holder)
                wheel += 1
            }
        }
        return board
    }

    /// The PR notebook (notebookModel2): a block of pages with the PR page on top, and a front cover on a hinge at
    /// the spine (node "hinge"; turn it −2.95 about Y to open).
    public static func notebook(title: String, rows: [String]) -> FlowNode {
        let w: Float = 1.05, h: Float = 1.4, d: Float = 0.1
        let pages = RGB(hex: "#F6F2EA")
        var book = FlowNode("notebook")
        var block = FlowNode("block", position: [0, 0, -d * 0.1])
        for (i, face) in Geo.box(w, h, d * 0.8).enumerated() {
            switch i {
            case 4: block.parts.append(FlowPart("page", mesh: face, paint: .picture(.notebookPage(rows), tint: RGB(1, 1, 1)), shade: .toon))
            case 1, 5: block.parts.append(.toon("side", face, dark))
            default: block.parts.append(.toon("pages", face, pages))
            }
        }
        book.add(block)
        var hinge = FlowNode("hinge", position: [-w / 2, 0, d * 0.35])
        var cover = FlowNode("cover", position: [w / 2, 0, 0])
        for (i, face) in Geo.box(w, h, 0.025).enumerated() {
            cover.parts.append(i == 4 ? FlowPart("front", mesh: face, paint: .picture(.notebookCover(title), tint: RGB(1, 1, 1)), shade: .toon)
                                      : .toon("side", face, dark))
        }
        hinge.add(cover)
        book.add(hinge)
        return book
    }

    /// The pencil (penModel): a dark body, a sharpened wooden cone, a black tip; point down.
    public static func pencil() -> FlowNode {
        var pen = FlowNode("pencil")
        pen.add(.toon("body", Geo.cylinder(top: 0.035, bottom: 0.035, height: 0.72, segments: 10), dark))
        pen.add(.toon("wood", Geo.cone(radius: 0.035, height: 0.12, segments: 10), FlowLook.dust), at: [0, -0.42, 0], rotation: [.pi, 0, 0])
        pen.add(.toon("tip", Geo.cone(radius: 0.012, height: 0.04, segments: 8), RGB(hex: "#111111")), at: [0, -0.49, 0], rotation: [.pi, 0, 0])
        return pen
    }

    // MARK: - The gym room

    /// gymRoomModel: a light box that opens into a small room. Its lid ("lid") lifts off and the front
    /// ("frontPivot") and right ("rightPivot") walls fall outward; inside, the things to tap: the flag ("flag",
    /// its cloth "flagCloth"), three racked bars ("bars"), the plates in tall piles ("plates") and a kettlebell
    /// with the unit ("bell").
    public static func gymRoom(name: String, unit: WeightUnit, plates owned: [Double]) -> FlowNode {
        let s: Float = 1.15, th: Float = 0.04
        var room = FlowNode("gymRoom")
        func slab(_ name: String, _ w: Float, _ h: Float, _ d: Float) -> FlowNode {
            var node = FlowNode(name)
            node.parts = [.toon(name, Geo.solidBox(w, h, d), light), edges(Geo.solidBox(w, h, d))]
            return node
        }
        // The prototype's edge lines are one device pixel: half a point of ink, which reads as a faint line.
        func edges(_ mesh: LowPolyMesh) -> FlowPart {
            FlowPart("edges", mesh: mesh.inkLines(width: 0.0035, degrees: 1), paint: .colour(dark), shade: .flat, opacity: 0.35)
        }
        var floor = slab("floor", s, th, s); floor.position = [0, th / 2, 0]; room.add(floor)
        var back = slab("back", s, s, th); back.position = [0, s / 2, -s / 2 + th / 2]; room.add(back)
        var left = slab("left", th, s, s); left.position = [-s / 2 + th / 2, s / 2, 0]; room.add(left)
        var frontPivot = FlowNode("frontPivot", position: [0, 0, s / 2])
        var front = FlowNode("front", position: [0, s / 2, -th / 2])
        for (i, face) in Geo.box(s, s, th).enumerated() {
            front.parts.append(i == 4 ? FlowPart("name", mesh: face, paint: .picture(.gymFront(name), tint: RGB(1, 1, 1)), shade: .toon)
                                      : .toon("wall", face, light))
        }
        front.parts.append(edges(Geo.solidBox(s, s, th)))
        frontPivot.add(front)
        room.add(frontPivot)
        var rightPivot = FlowNode("rightPivot", position: [s / 2, 0, 0])
        var right = slab("right", th, s, s); right.position = [-th / 2, s / 2, 0]; rightPivot.add(right)
        room.add(rightPivot)
        var lid = slab("lid", s, th, s); lid.position = [0, s - th / 2, 0]; room.add(lid)

        var inside = FlowNode("inside")
        // The flag, hung from its top edge at the top of the back wall.
        let fw: Float = 0.56, fh: Float = 0.35
        var flag = FlowNode("flag", position: [0.1, 0.98, -s / 2 + th + 0.035])
        flag.add(FlowNode("flagCloth", parts: [FlowPart("cloth", mesh: Geo.plane(fw, fh, columns: 12, rows: 8).translated(by: [0, -fh / 2, 0]),
                                                         paint: .picture(.flag(name), tint: RGB(1, 1, 1)), shade: .flat, twoSided: true)]))
        flag.add(FlowNode("hit", position: [0, -fh / 2, 0.05], hitBox: [fw + 0.16, fh + 0.18, 0.14]))
        inside.add(flag)
        // Three bars on hooks along the left wall.
        var bars = FlowNode("bars", position: [-s / 2 + th + 0.06, 0, 0.02])
        for y: Float in [0.42, 0.6, 0.78] {
            var bar = barbell()
            bar.position = [0, y, 0]; bar.scale = [0.4, 0.4, 0.4]; bar.rotation = [0, .pi / 2, 0]
            bars.add(bar)
            for hz: Float in [-0.25, 0.25] { bars.add(.toon("hook", Geo.solidBox(0.09, 0.03, 0.04), RGB(hex: "#2B2B2B")), at: [-0.03, y - 0.03, hz]) }
        }
        bars.add(FlowNode("hit", position: [0.02, 0.6, 0], hitBox: [0.22, 0.62, 1.0]))
        inside.add(bars)
        // The plates in tall sorted piles under the flag.
        var piles = FlowNode("plates", position: [0, th, 0])
        let catalog = Plate.catalog(unit).filter { owned.isEmpty || owned.contains($0.size) }.prefix(6)
        let spots: [(Float, Float)] = [(-0.16, -0.34), (0.15, -0.34), (0.43, -0.34), (-0.02, -0.06), (0.27, -0.06), (0.48, -0.06)]
        let scale: Float = 0.52
        for (i, p) in catalog.enumerated() {
            let (cx, cz) = spots[i], count = p.diameter > 0.4 ? 6 : 5, t = Float(p.thickness)
            let model = plate(p, sides: 28)
            for j in 0..<count {
                var one = model
                one.scale = [scale, scale, scale]
                one.rotation = [0, Float(j) * 0.7, 0]
                one.position = [cx, 0.004 + Float(j) * t * scale + t * scale / 2, cz]
                piles.add(one)
            }
        }
        piles.add(FlowNode("hit", position: [0.16, 0.18, -0.2], hitBox: [0.95, 0.4, 0.62]))
        inside.add(piles)
        // A small kettlebell out front with the unit.
        var bell = FlowNode("bell", position: [-0.32, th, 0.3])
        var kb = kettlebell(label: unit == .kg ? "KG" : "LB")
        kb.scale = [0.26, 0.26, 0.26]; kb.rotation = [0, 0.65, 0]
        bell.add(kb)
        bell.add(FlowNode("hit", position: [0, 0.2, 0], hitBox: [0.36, 0.42, 0.36]))
        inside.add(bell)
        room.add(inside)
        return room
    }

    /// The last slot in the row of gyms (gymAddModel): an empty cube in thin wobbly dark lines, no fill.
    public static func addCube() -> FlowNode {
        let s: Float = 1.15, h = s / 2
        let corners: [SIMD3<Float>] = [[-h, 0, -h], [h, 0, -h], [h, 0, h], [-h, 0, h], [-h, s, -h], [h, s, -h], [h, s, h], [-h, s, h]]
        let edges = [(0, 1), (1, 2), (2, 3), (3, 0), (4, 5), (5, 6), (6, 7), (7, 4), (0, 4), (1, 5), (2, 6), (3, 7)]
        var seed = 7.0
        func rnd() -> Float {
            seed = (seed * 16807).truncatingRemainder(dividingBy: 2_147_483_647)
            return Float(seed / 2_147_483_647 - 0.5)
        }
        var lines = LowPolyMesh()
        for (i, j) in edges {
            let a = corners[i], b = corners[j]
            var points: [SIMD3<Float>] = []
            for k in 0...6 {
                var p = a + (b - a) * (Float(k) / 6)
                if k > 0 && k < 6 { p += SIMD3(rnd(), rnd(), rnd()) * 0.022 }
                points.append(p)
            }
            lines.append(.tube(through: Geo.catmullRom(points, count: 24), width: 0.011))
        }
        var cube = FlowNode("addCube", parts: [.flat("lines", lines, dark)])
        cube.add(FlowNode("hit", position: [0, s / 2, 0], hitBox: [s, s, s]))
        return cube
    }

    // MARK: - Little things

    /// softShadow: a soft round shadow lying on the floor, `radius` across.
    public static func softShadow(radius: Float) -> FlowNode {
        .part(FlowPart("shadow", mesh: Geo.plane(radius * 2, radius * 2), paint: .picture(.shadowBlob, tint: RGB(1, 1, 1)), shade: .flat),
              at: [0, 0.003, 0], rotation: [-.pi / 2, 0, 0])
    }

    /// A dust chunk: a unit icosahedron.
    public static func dustChunk() -> LowPolyMesh { Geo.icosahedron() }
}
