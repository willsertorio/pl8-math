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
        let top = parts.platform.flatMap { $0.mesh.positions.map(\.y) }.max() ?? 0
        #expect(abs(top - ScaleScene.platformTop) < 0.006)
        #expect(ScaleScene.screenCentre.y > 0.8)
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
