import Testing
@testable import PlateKit

@Suite("Orbit and zoom (prototype OrbitControls)")
struct OrbitTests {
    let overview = RoomLayout.shots[.overview]!

    @Test func startsExactlyAtTheShot() {
        let orbit = Orbit(overview)
        #expect((orbit.position - overview.position).length < 0.001)
    }

    @Test func dragGoesRoundAtTheSameDistance() {
        let orbit = Orbit(overview).dragged(dx: 200, dy: 0)
        #expect(abs((orbit.position - orbit.target).length - Orbit(overview).distance) < 0.001)
        #expect((orbit.position - overview.position).length > 1)
    }

    @Test func neverBelowTheFloorOrStraightDown() {
        #expect(Orbit(overview).dragged(dx: 0, dy: -10_000).elevation == Orbit.elevationRange.lowerBound)
        #expect(Orbit(overview).dragged(dx: 0, dy: 10_000).elevation == Orbit.elevationRange.upperBound)
    }

    @Test func pinchZoomsWithinLimits() {
        let orbit = Orbit(overview)
        #expect(orbit.zoomed(by: 2).distance < orbit.distance)
        #expect(orbit.zoomed(by: 1000).distance == 1.2)
        #expect(orbit.zoomed(by: 0.001).distance == 90)
    }

    @Test func turningRoundShowsTheRightWallAgain() {
        // From the overview the right wall is cut away; from the left of the room it comes back.
        #expect(!RoomLayout.Wall.right.isVisible(from: Orbit(overview).position))
        let fromLeft = Orbit(overview).dragged(dx: -300, dy: 0)
        #expect(RoomLayout.Wall.right.isVisible(from: fromLeft.position))
    }
}
