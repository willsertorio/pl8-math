import Testing
@testable import PlateKit

// The Flow (design/flow-handoff/HANDOFF.md): its timings, light, kit layout and props.

@Suite("Flow text reveal")
struct FlowTextTests {
    @Test("Each word waits 95 ms + 18 ms per letter, and longer after punctuation (HANDOFF 1)")
    func spokenTiming() {
        let reveal = FlowText.schedule("What’s the name of your Gym?")
        #expect(reveal.words.map(\.word) == ["What’s", "the", "name", "of", "your", "Gym?"])
        let times = reveal.words.map(\.at)
        let expected = [0, 0.203, 0.352, 0.519, 0.650, 0.817]
        for (time, want) in zip(times, expected) { #expect(abs(time - want) < 0.0005) }
        // "Gym?": 3 letters, then the question mark's pause, then 120 ms before the object comes in.
        #expect(abs(reveal.total - (0.817 + 0.149 + 0.42 + 0.12)) < 0.0005)
    }

    @Test("Commas pause 230 ms, full stops 420 ms")
    func pauses() {
        let reveal = FlowText.schedule("Cool. Let’s go, now")
        #expect(abs(reveal.words[1].at - (0.095 + 0.018 * 4 + 0.42)) < 0.0005)
        let afterComma = reveal.words[3].at - reveal.words[2].at
        #expect(abs(afterComma - (0.095 + 0.018 * 2 + 0.23)) < 0.0005)
    }
}

@Suite("Flow pan")
struct FlowPanTests {
    @Test("Out eases in over 0.30 s, in eases out over 0.45 s, at the same speed where they meet")
    func continuous() {
        #expect(FlowPan.out(0) == 0)
        #expect(FlowPan.out(1) == 1)
        #expect(FlowPan.into(0) == -1)
        #expect(FlowPan.into(1) == 0)
        let outSpeed = (FlowPan.out(1) - FlowPan.out(0.999)) / 0.001 / FlowPan.outDuration
        let inSpeed = (FlowPan.into(0.001) - FlowPan.into(0)) / 0.001 / FlowPan.inDuration
        #expect(abs(outSpeed - inSpeed) / outSpeed < 0.01)
    }

    @Test("A swipe back commits past 110 pt and springs back with an ease-out otherwise")
    func swipeBack() {
        #expect(FlowPan.commits(dragged: 111))
        #expect(!FlowPan.commits(dragged: 100))
        #expect(FlowPan.springBack(from: 80, at: 0) == 80)
        #expect(FlowPan.springBack(from: 80, at: 1) == 0)
        #expect(FlowPan.springBack(from: 80, at: 0.5) < 20)
    }
}

@Suite("Flow light")
struct FlowLightTests {
    @Test("Toon: the prototype's ramp under its hemisphere and sun (three.js r169, no tone mapping)")
    func toonFront() {
        // Box dark on a face looking at the camera: worked out by hand from three.js's toon shader.
        let front = FlowLight.toon(RGB(hex: "#6C3713"), normal: [0, 0, 1])
        #expect(abs(front.r * 255 - 105.3) < 1)
        #expect(abs(front.g * 255 - 52.9) < 1)
        #expect(abs(front.b * 255 - 17.8) < 1)
    }

    @Test("Top faces are brightest, then front, side, bottom")
    func order() {
        let base = RGB(hex: "#B4BAC1")
        let top = FlowLight.toon(base, normal: [0, 1, 0]).g
        let front = FlowLight.toon(base, normal: [0, 0, 1]).g
        let side = FlowLight.toon(base, normal: [-1, 0, 0]).g
        let bottom = FlowLight.toon(base, normal: [0, -1, 0]).g
        #expect(top > front && front > side && side > bottom)
    }

    @Test("A toon face takes one of three steps of the sun")
    func ramp() {
        #expect(FlowLight.rampStep(dot: -0.9) == Float(90.0 / 255))
        #expect(FlowLight.rampStep(dot: 0) == Float(175.0 / 255))
        #expect(FlowLight.rampStep(dot: 0.6) == 1)
    }
}

@Suite("Flow kit layout")
struct FlowKitLayoutTests {
    @Test("One line per size, heaviest first; small sizes share a line (flKitLayout)")
    func lines() {
        let kit = [(25.0, 4), (20, 2), (5, 2), (2.5, 2)]
        let spots = FlowKitLayout.spots(kit: kit, unit: .kg)
        #expect(spots.map(\.size) == [25, 25, 25, 25, 20, 20, 5, 5, 2.5, 2.5])
        // Rows at z −0.13, 0.48 and 0.96: 25s alone, 20s with the 5s, then the 2.5s.
        let z = spots.map { ($0.z * 1000).rounded() / 1000 }
        #expect(z == [-0.13, -0.13, -0.13, -0.13, 0.48, 0.48, 0.48, 0.48, 0.96, 0.96])
        let x = spots.map { ($0.x * 1000).rounded() / 1000 }
        #expect(x == [-0.75, -0.25, 0.25, 0.75, -0.625, -0.125, 0.455, 0.735, -0.12, 0.12])
        #expect(abs(spots[1].yaw - 1.37) < 0.0001)
    }
}

@Suite("Flow geometry")
struct FlowGeometryTests {
    @Test("A three.js cylinder: radial segments × (2 side + 2 cap) triangles, along Y")
    func cylinder() {
        let mesh = Geo.cylinder(top: 0.5, bottom: 0.5, height: 2, segments: 10)
        #expect(mesh.triangleCount == 40)
        let ys = mesh.positions.map(\.y)
        #expect(ys.min() == -1 && ys.max() == 1)
    }

    @Test("A box comes as six faces in three.js's order (+x, −x, +y, −y, +z, −z), each with a full picture")
    func box() {
        let faces = Geo.box(1, 2, 3)
        #expect(faces.count == 6)
        #expect(faces[4].faceNormal(0).z > 0.99)
        #expect(faces[2].faceNormal(0).y > 0.99)
        #expect(faces[4].uvs.map(\.x).max() == 1)
    }

    @Test("The kettlebell stands on its foot at 0 and carries its label on the front")
    func kettlebell() {
        let bell = FlowProps.kettlebell(label: "KG")
        let bounds = bell.bounds()
        #expect(abs(bounds.min.y) < 0.002)
        #expect(abs(bounds.max.y - 1.206) < 0.01)
        #expect(bell.find("label") != nil)
    }

    @Test("The whiteboard stands 1.45 up with a 1.7 × 1.1 face, on four wheels")
    func whiteboard() {
        let board = FlowProps.whiteboard(lines: nil)
        #expect(board.findPart("face") != nil)
        #expect(board.findAll { $0.name.hasPrefix("wheel") }.count == 4)
        let bounds = board.bounds()
        #expect(abs(bounds.max.y - (1.45 + 0.55 + 0.03)) < 0.01)
    }

    @Test("The gym room has its four things to edit, and the opening parts on pivots")
    func gymRoom() {
        let room = FlowProps.gymRoom(name: "79", unit: .kg, plates: Plate.catalog(.kg).map(\.size))
        for name in ["flag", "bars", "plates", "bell", "frontPivot", "rightPivot", "lid"] { #expect(room.find(name) != nil) }
    }
}

@Suite("Flow theme (CHANGES-v2 §2)")
struct FlowThemeTests {
    @Test("Swiss red is the palette, read everywhere through FlowLook")
    func swissRed() {
        let p = FlowLook.palette
        #expect(p == FlowPalette.swissRed)
        #expect(p.bg.hex == "#E5321C" && p.light.hex == "#F4F1EA" && p.dark.hex == "#151515")
        #expect(p.card.hex == "#FFFFFF" && p.accent.hex == "#E5321C")
        #expect(FlowLook.bg == p.bg && FlowLook.light == p.light && FlowLook.dark == p.dark)
        #expect(FlowLook.card == p.card && FlowLook.accent == p.accent)
        // Grid lines: dark at 9 % on the light screens, 11 % on the whiteboard.
        #expect(FlowLook.gridOpacity == 0.09 && FlowLook.boardGridOpacity == 0.11)
        // The first handoff's orange stays on record.
        #expect(FlowPalette.orange.bg.hex == "#FF6200" && FlowPalette.orange.dark.hex == "#6C3713")
    }
}

@Suite("Flow details")
struct FlowDetailTests {
    @Test("Lift names read in sentence case in the Flow (the prototype's \"Back squat?\")")
    func sentenceCase() {
        #expect(LiftNames.sentenceCase("Back Squat") == "Back squat")
        #expect(LiftNames.sentenceCase("Clean & Jerk") == "Clean & jerk")
        #expect(LiftNames.sentenceCase("Snatch") == "Snatch")
    }

    @Test("A plate's printed faces are two parts, one per side, so each is lit for its own side")
    func plateFaces() {
        let plate = FlowProps.plate(Plate.find(20, .kg)!)
        let faces = plate.parts.filter { $0.name == "face" }
        #expect(faces.count == 2)
        let up = { (part: FlowPart) in (0..<part.mesh.triangleCount).allSatisfy { part.mesh.faceNormal($0).y > 0.9 } }
        let down = { (part: FlowPart) in (0..<part.mesh.triangleCount).allSatisfy { part.mesh.faceNormal($0).y < -0.9 } }
        #expect(faces.contains(where: up) && faces.contains(where: down))
    }

    @Test("The abduction's beam reads like the prototype's: a grainy haze over the red, not a white column")
    func beamHaze() {
        let beam = FlowProps.beam().beam
        guard case .colour(let colour) = beam.parts.first?.paint else { Issue.record("the beam has no colour"); return }
        // Seen through both walls of the open cylinder, at full strength: about (212, 107, 42) in the prototype's 02c.
        var seen = FlowLook.bg
        for _ in 0..<2 {
            let a = FlowLook.beamOpacity
            seen = RGB(seen.r + (colour.r - seen.r) * a, seen.g + (colour.g - seen.g) * a, seen.b + (colour.b - seen.b) * a)
        }
        // Through both walls over the red, about (180, 73, 61) in the v2 prototype's 02c.
        #expect(abs(seen.r * 255 - 180) < 16 && abs(seen.g * 255 - 73) < 8 && abs(seen.b * 255 - 61) < 8)
        // The bell it takes is washed towards a neutral grey, about (155, 155, 155) by then.
        #expect(abs(FlowLook.wash.r * 255 - 155) < 8 && abs(FlowLook.wash.g * 255 - 155) < 8 && abs(FlowLook.wash.b * 255 - 155) < 8)
    }

    @Test("A missing plate's ghost is flat grey and reads like the v2 prototype's over the red, about (138, 58, 47)")
    func ghost() {
        let ghost = FlowProps.ghost(Plate.find(5, .kg)!)
        #expect(ghost.parts.allSatisfy { $0.shade == .flat && $0.opacity == FlowLook.missingOpacity })
        // Seen through two of its see-through layers, as it draws (one layer's maths came out too light).
        let g = FlowLook.missing, a = FlowLook.missingOpacity
        var seen = FlowLook.bg
        for _ in 0..<2 { seen = RGB(seen.r + (g.r - seen.r) * a, seen.g + (g.g - seen.g) * a, seen.b + (g.b - seen.b) * a) }
        #expect(abs(seen.r * 255 - 138) < 10 && abs(seen.g * 255 - 58) < 6 && abs(seen.b * 255 - 47) < 6)
        #expect(g.r == g.g && g.g == g.b)
    }

    @Test("The empty gym slot's edges are dashed: 0.07 dashes, 0.05 gaps, centred on each edge (CHANGES-v2 §6)")
    func dashedSlot() {
        let dashes = FlowProps.dashes(from: [0, 0, 0], to: [1, 0, 0])
        // As many as fit: 8 dashes and 7 gaps make 0.91, centred with 0.045 to spare at each end.
        #expect(dashes.count == 8)
        #expect(abs(dashes[0].start.x - 0.045) < 1e-4 && abs(dashes[0].end.x - 0.115) < 1e-4)
        #expect(abs(dashes[1].start.x - 0.165) < 1e-4)
        #expect(abs((dashes.last?.end.x ?? 0) - 0.955) < 1e-4)
        // The slot: thin dark lines, nothing else.
        let slot = FlowProps.addCube()
        #expect(slot.parts.count == 1 && slot.parts[0].shade == .flat)
        let ys = slot.parts[0].mesh.positions.map(\.y)
        #expect((ys.min() ?? 1) > -0.01 && (ys.max() ?? 0) < 1.16)
    }

    @Test("The racked bars cast soft shadows on the room's left wall, below and behind them like the sun's")
    func barShadowsOnTheWall() {
        func find(_ node: FlowNode, _ name: String) -> FlowNode? { node.name == name ? node : node.children.lazy.compactMap { find($0, name) }.first }
        guard let bars = find(FlowProps.gymRoom(name: "79", unit: .kg, plates: [25]), "bars") else { Issue.record("no bars"); return }
        let shadows = bars.children.filter { $0.parts.contains { $0.name == "barShadow" } }
        #expect(shadows.count == 3)
        // On the wall (6 cm behind the bars; 1.5 cm off it so it draws), 0.06 × 6 / 2.5 lower and 0.06 × 4 / 2.5 back.
        #expect(shadows.allSatisfy { abs($0.position.x + 0.045) < 0.003 && abs($0.position.z + 0.096) < 0.003 })
        #expect(Set(shadows.map { (($0.position.y + 0.144) * 100).rounded() }) == [42, 60, 78])
    }

    @Test("The gym room's edges are faint hairlines, like the prototype's one-pixel lines")
    func gymRoomEdges() {
        func edges(_ node: FlowNode) -> [FlowPart] { node.parts.filter { $0.name == "edges" } + node.children.flatMap(edges) }
        let all = edges(FlowProps.gymRoom(name: "79", unit: .kg, plates: [25, 20, 15, 10, 5]))
        #expect(!all.isEmpty)
        #expect(all.allSatisfy { $0.opacity <= 0.4 })
    }
}
