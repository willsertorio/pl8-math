import Foundation
import Testing
@testable import PlateKit

@Suite("Session over: the scale and its animal (SPEC 2.3 step 7, prototype AnimLayer 'done')")
struct SessionOverTests {
    @Test func theAnimalIsTheNearestOnALogScale() {
        #expect(Animals.nearest(kg: 180).name == "a lion")
        #expect(Animals.nearest(kg: 100).name == "a giant panda")     // 100/110 is closer than 100/85
        #expect(Animals.nearest(kg: 4).name == "a house cat")
        #expect(Animals.nearest(kg: 0).name == "a feather")
        #expect(Animals.nearest(kg: 1_000_000).name == "a blue whale")
    }

    @Test func poundsAreWeighedInKilos() {
        // 405 lb ≈ 184 kg: a lion.
        #expect(Animals.nearest(405, unit: .lb).name == "a lion")
        #expect(Animals.message(for: 180, unit: .kg) == "You lifted a lion.")
    }

    @Test func theHeaviestSetDropsHeaviestFirstThenTheBar() {
        let drops = ScaleScene.drops(perSide: [25, 10], unit: .kg, barWeight: 20)
        #expect(drops.count == 5)
        #expect(drops.prefix(4).map { $0.plate?.size } == [25, 25, 10, 10])
        #expect(drops.last?.plate == nil)                                       // the bar comes last
        // The prototype's timing: 0.5 s, then every 0.38 s; the bar 0.6 + 0.45 s after the last plate.
        #expect(abs(drops[0].at - 0.5) < 0.001 && abs(drops[1].at - 0.88) < 0.001)
        #expect(abs(drops[4].at - (drops[3].at + 1.05)) < 0.001)
        // Stacked on the platform: each plate rests on the one below.
        #expect(abs(drops[0].restY - (ScaleScene.platformTop + 0.028)) < 0.001)
        #expect(drops[1].restY > drops[0].restY)
        #expect(ScaleScene.total(perSide: [25, 10], barWeight: 20) == 90)
    }

    @Test func theScalesBarIsADarkShaftWithLightCollarsAndSleeves() {
        // buildDone's bar: a #6E7378 shaft 1.31 m long, #B9BEC4 collars at ±0.67 and sleeves out to ±1.13.
        let parts = ScaleScene.barParts()
        #expect(parts.count == 5)
        let xs = parts.flatMap { part in part.mesh.positions.map { $0.x } }
        #expect(abs((xs.max() ?? 0) - 1.13) < 0.001 && abs((xs.min() ?? 0) + 1.13) < 0.001)
        for part in parts {
            let shaft = part.mesh.positions.allSatisfy { abs($0.y) < 0.015 && abs($0.z) < 0.015 }
            // Two-tone like the prototype's picture: every face of the shaft dark; the collars and sleeves light
            // along their tops (their sides go dark like the prototype's, steel lit side-on is about 0.80).
            let pieces = SceneBake.shaded(part, light: .animation).compactMap { paint, mesh -> (RGB, Float)? in
                guard case .colour(let colour) = paint else { return nil }
                return (colour, (0..<mesh.triangleCount).map { mesh.faceNormal($0).y }.max() ?? 0)
            }
            if shaft {
                #expect(pieces.allSatisfy { Look.duotone($0.0) == Look.duotoneDark })
            } else if let top = pieces.max(by: { $0.1 < $1.1 }) {
                #expect(Look.duotone(top.0) == Look.duotoneLight)
            }
        }
    }

    @Test func theScaleIsLitLikeThePrototypesDoneScene() {
        // Toon steps 70 / 160 / 255 under hemisphere 2.7 and a 1.5 sun from (2, 6.46, 3): a face towards the sun
        // gets (2.7 + 1.5) / π, one side-on (2.7 + 1.5 × 160/255) / π, one away (2.7 + 1.5 × 70/255) / π.
        #expect(abs(Look.animationLight(normal: [0, 1, 0]) - 4.2 / .pi) < 0.001)
        #expect(abs(Look.animationLight(normal: [1, 0, 0]) - (2.7 + 1.5 * 160 / 255) / .pi) < 0.001)
        #expect(abs(Look.animationLight(normal: [0, -1, 0]) - (2.7 + 1.5 * 70 / 255) / .pi) < 0.001)
        // Lit so, the scale reads like the prototype's picture: a dark body, a light top.
        let parts = ScaleScene.parts()
        let tones = parts.platform.flatMap { SceneBake.shaded($0, light: .animation) }.compactMap { paint, mesh -> RGB? in
            guard case .colour(let colour) = paint, (0..<mesh.triangleCount).contains(where: { mesh.faceNormal($0).y > 0.9 })
            else { return nil }
            return Look.duotone(colour)
        }
        #expect(tones.contains(Look.duotoneLight) && tones.contains(Look.duotoneDark))
    }

    @Test func aFallTakesTheTimeToDropThreeMetres() {
        let fall = ScaleScene.fallTime
        #expect(abs(fall - (2 * 3 / 9.8).squareRoot()) < 0.001)
        #expect(ScaleScene.height(above: 0, at: 0) == 3)
        #expect(abs(ScaleScene.height(above: 0, at: fall)) < 0.001)
        #expect(ScaleScene.height(above: 0, at: fall + 2) < 0.001)              // settled
    }

    @Test func theScaleHasABaseAPlatformAndAHead() {
        let parts = ScaleScene.parts()
        #expect(parts.base.count > 4 && !parts.platform.isEmpty)
        let top = parts.platform.filter { $0.tone != .flat(Look.ink) }.flatMap { $0.mesh.positions.map(\.y) }.max() ?? 0
        #expect(abs(top - ScaleScene.platformTop) < 0.006)
        #expect(ScaleScene.screenCentre.y > 0.8)
        // Nothing dark faces up under the cream top: seen from 20 m, 1 cm below it would win the depth test (the
        // top vanished in the sketch stage). The base shows through the thin rim instead, dark either way.
        let body = parts.platform.filter { $0.tone == .paint(Look.boxDark) }
        #expect(!body.isEmpty)
        #expect(body.allSatisfy { part in (0..<part.mesh.triangleCount).allSatisfy { part.mesh.faceNormal($0).y < 0.5 } })
        // Nor the base: under the top it has no top face, only the rim round the platform (seen from 20 m in the
        // Simulator even 5 cm wasn't enough). The feet, 11 cm down, are far enough.
        for part in parts.base where part.tone != .flat(Look.ink) {
            for t in 0..<part.mesh.triangleCount where part.mesh.faceNormal(t).y > 0.5 {
                let c = part.mesh.faceCentre(t)
                #expect(c.y > ScaleScene.platformTop || c.y < ScaleScene.platformTop - 0.08 || abs(c.x) > 0.37 || abs(c.z) > 0.37)
            }
        }
    }
}

@Suite("Opening: the closed box opens into the room (SPEC 2.2 step 0, prototype runOnb)")
struct OpeningTests {
    @Test func closedBoxIsACubeWithALid() {
        let closed = Opening.pose(at: 0)
        #expect(closed.walls == 1 && closed.lidUp == 0)
        #expect(Opening.cubeHeight == 8)
        let slabs = Opening.slabs()
        #expect(slabs.count == 4)                                              // back, left, right and front
        #expect(slabs.allSatisfy { $0.parts.flatMap { $0.mesh.positions.map(\.y) }.max()! > 7.9 })
    }

    @Test func itOpensInAboutTwoSeconds() {
        let open = Opening.pose(at: Opening.duration)
        #expect(open.walls == 0 && open.lidUp > 30 && open.lift == 0)
        #expect(Opening.duration < 2.2)
        let half = Opening.pose(at: Opening.duration / 2)
        #expect(half.walls > 0 && half.walls < 1)
    }

    @Test func theWallsFacingTheOverviewDropAllTheWay() {
        // From the overview (in front, to the right) the front and right walls go down to the floor; the back
        // and left ones stop at the room's height.
        #expect(Opening.dropsAllTheWay(.front) && Opening.dropsAllTheWay(.right))
        #expect(!Opening.dropsAllTheWay(.back) && !Opening.dropsAllTheWay(.left))
        #expect(Opening.slabHeight(.back, walls: 0) == RoomLayout.room.wallHeight)
        #expect(Opening.slabHeight(.front, walls: 0) == 0)
        #expect(Opening.slabHeight(.left, walls: 1) == Opening.cubeHeight)
    }

    @Test func theBoardRollsInAndTheBenchIsTossed() {
        let start = Opening.board(at: 0), end = Opening.board(at: 3)
        #expect(!start.visible && end.visible)
        #expect(end.offset == .zero && end.turn == 0)
        let mid = Opening.bench(at: 0.6)
        #expect(mid.visible && mid.offset.y > 0.5)                             // up in the air on its way in
        #expect(Opening.bench(at: 3).offset == .zero)
    }

    @Test func farShotLooksAtTheBoxFromAfar() {
        let far = RoomLayout.shots[.far]!
        #expect((far.position - far.target).length > 50)
    }
}

@Suite("The animation scenes' two-tone look (prototype AnimLayer: posterize 2, duotone)")
struct DuotoneTests {
    @Test func everyColourBecomesTheThemesDarkOrLight() {
        // The two tones are the Flow's theme (CHANGES-v2 §2, §8): the opening and the scale in its dark and light.
        #expect(Look.duotoneDark == FlowLook.dark && Look.duotoneLight == FlowLook.light)
        #expect(Look.duotone(Look.boxLight) == Look.duotoneLight)
        #expect(Look.duotone(Look.boxDark) == Look.duotoneDark)
        #expect(Look.duotone(RGB(hex: "#D3262E")) == Look.duotoneDark)        // red 25: dark, its print light
        #expect(Look.duotone(RGB(hex: "#1E5BC6")) == Look.duotoneDark)
        #expect(Look.duotone(RGB(hex: "#F2F2EE")) == Look.duotoneLight)       // white change plate
        // The prototype grades first (contrast 0.71, then brightness 0.68) and splits at half after that: only
        // what's brighter than about 0.83 comes out light.
        #expect(Look.duotone(RGB(0.84, 0.84, 0.84)) == Look.duotoneLight)
        #expect(Look.duotone(RGB(0.82, 0.82, 0.82)) == Look.duotoneDark)
        #expect(Look.duotone(RGB(hex: "#7F7F7F")) == Look.duotoneDark)
    }

    @Test func aTitlePlateKeepsALightHubUnderTheAnimationLight() {
        // The title's plates lie along x, side-on to the sun: the chrome hub's faces stay light, the red rim dark.
        guard let red = Plate.find(25, .kg) else { Issue.record("no 25 kg plate"); return }
        let parts = PropModels.plateParts(red)
        let hubFaces = SceneBake.shaded(parts[2], light: .animation).compactMap { paint, mesh -> RGB? in
            guard case .colour(let colour) = paint, abs(mesh.faceNormal(0).x) > 0.9 else { return nil }
            return Look.duotone(colour)
        }
        #expect(!hubFaces.isEmpty && hubFaces.allSatisfy { $0 == Look.duotoneLight })
        let rim = SceneBake.shaded(parts[1], light: .animation).compactMap { paint, _ -> RGB? in
            if case .colour(let colour) = paint { return Look.duotone(colour) } else { return nil }
        }
        #expect(rim.allSatisfy { $0 == Look.duotoneDark })
    }
}

@Suite("The prototype's rough sketch outline on the closed box and the scale")
struct RoughOutlineTests {
    @Test func aRoughLineFollowsACurveWithGaps() {
        let circle = (0...64).map { i -> SIMD3<Float> in
            let a = Float(i) / 64 * 2 * .pi
            return [0.225 * cos(a), 0, 0.225 * sin(a)]
        }
        let line = LowPolyMesh.roughLine(circle, width: 0.01, seed: 3)
        #expect(line.triangleCount > 0)
        #expect(line.positions.allSatisfy { abs(SIMD2($0.x, $0.z).length - 0.225) < 0.03 && abs($0.y) < 0.03 })
        let steps = Int(2 * Float.pi * 0.225 / LowPolyMesh.roughStep)
        #expect(line.triangleCount / 8 < steps)                               // grain: some pieces drop out
        #expect(line == LowPolyMesh.roughLine(circle, width: 0.01, seed: 3))  // the same every launch
    }

    @Test func roughInkTracesEveryHardEdgeIncludingRims() {
        let box = LowPolyMesh.box(size: [1, 1, 1])
        let ink = box.roughInk(width: 0.02, seed: 1)
        // Something near each of the 12 edges' middles.
        let middles: [SIMD3<Float>] = [[0, 0.5, 0.5], [0, -0.5, 0.5], [0, 0.5, -0.5], [0, -0.5, -0.5],
                                       [0.5, 0, 0.5], [-0.5, 0, 0.5], [0.5, 0, -0.5], [-0.5, 0, -0.5],
                                       [0.5, 0.5, 0], [-0.5, 0.5, 0], [0.5, -0.5, 0], [-0.5, -0.5, 0]]
        for m in middles { #expect(ink.positions.contains { ($0 - m).length < 0.12 }) }
        let disc = LowPolyMesh.cylinder(radius: 0.225, length: 0.05, sides: 48, axis: .y)
        let rims = disc.roughInk(width: 0.01, seed: 2)
        #expect(rims.positions.contains { $0.y > 0.02 } && rims.positions.contains { $0.y < -0.02 })
    }

    @Test func theClosedBoxAndTheScaleHaveTheirOutline() {
        #expect(Opening.slabs().allSatisfy { $0.parts.contains { $0.tone == .flat(Look.ink) } })
        #expect(Opening.lid().contains { $0.tone == .flat(Look.ink) })
        #expect(ScaleScene.parts().base.contains { $0.tone == .flat(Look.ink) })
        #expect(ScaleScene.outline(PropModels.barbellParts(), seed: 1).triangleCount > 0)
    }

    // MARK: - At the end: drag the bar and the plates (startDonePhysics, stepDonePhysics)

    @Test func theScalesSolidPartsAreItsBodyColumnAndHead() {
        // No floor and no walls: only the scale itself is solid; its body's top is the platform's top.
        let solids = ScaleScene.solids
        #expect(solids.count == 3)
        let body = solids[0]
        #expect(abs(body.centre.y + body.size.y / 2 - ScaleScene.platformTop) < 0.0001)
        #expect(abs(body.size.x - 0.84) < 0.0001)
        #expect(abs(body.size.z - 0.84) < 0.0001)
        // The column and the head stand at the back, under the screen.
        #expect(solids[1].centre.z < -0.3 && solids[2].centre.z < -0.3)
        #expect(abs(solids[2].centre.y - 0.86) < 0.0001)
    }

    @Test func theBarsPiecesAreTheShaftCollarsAndSleeves() {
        let pieces = ScaleScene.barPieces
        #expect(pieces.count == 5)
        #expect(pieces[0].radius == 0.014 && pieces[0].length == 1.31 && pieces[0].x == 0)
        let ends = pieces.map { abs($0.x) + $0.length / 2 }
        #expect(abs((ends.max() ?? 0) - 1.13) < 0.0001)
    }

    @Test func somethingIsOnThePlatformWhenItRestsWithinItsEdges() {
        let top = ScaleScene.platformTop
        #expect(ScaleScene.onPlatform([0, top + 0.03, 0]))
        #expect(ScaleScene.onPlatform([0.4, top + 0.2, -0.4]))                 // near a corner, up the stack
        #expect(!ScaleScene.onPlatform([0.45, top + 0.03, 0]))                 // over the edge
        #expect(!ScaleScene.onPlatform([0, top - 0.2, 0]))                     // fallen past it
    }

    @Test func onceTouchedTheReadingIsWhatIsStillOnThePlatform() {
        let top = ScaleScene.platformTop
        let things: [(position: SIMD3<Float>, weight: Double, held: Bool)] = [
            ([0, top + 0.03, 0], 25, false),
            ([0.02, top + 0.09, 0], 25, false),
            ([0, top + 0.6, 0.1], 20, true),                                   // the bar, in the hand
            ([1.2, -3, 0], 2.5, false)                                         // pulled off, falling away
        ]
        #expect(ScaleScene.reading(things) == 50)
        #expect(ScaleScene.reading([]) == 0)
    }

    @Test func theDragStartsShortlyAfterTheLastLanding() {
        // The prototype's physAt: 0.7 s after the bar lands.
        #expect(abs(ScaleScene.dragDelay - 0.7) < 0.0001)
    }
}
