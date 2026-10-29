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

    @Test("A missing plate's ghost is flat grey at 30 %")
    func ghost() {
        let ghost = FlowProps.ghost(Plate.find(5, .kg)!)
        #expect(ghost.parts.allSatisfy { $0.shade == .flat && $0.opacity == 0.3 })
    }
}
