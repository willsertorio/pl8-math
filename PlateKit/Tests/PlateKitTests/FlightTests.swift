import Testing
@testable import PlateKit

@Suite("Camera flights (prototype flyTo)")
struct FlightTests {
    let overview = Orbit(RoomLayout.shots[.overview]!)
    let pr = Orbit(RoomLayout.shots[.pr]!)

    @Test func startsAndEndsOnTheShots() {
        let flight = Flight(from: overview, to: pr, duration: 1.15)
        #expect((flight.orbit(at: 0).position - overview.position).length < 0.001)
        #expect((flight.orbit(at: 1.15).position - pr.position).length < 0.001)
        #expect((flight.orbit(at: 5).position - pr.position).length < 0.001)      // stays put after
        #expect(flight.orbit(at: 1.15).fieldOfView == pr.fieldOfView)
    }

    @Test func easesInAndOut() {
        #expect(Flight.ease(0) == 0 && Flight.ease(1) == 1)
        #expect(abs(Flight.ease(0.5) - 0.5) < 1e-6)
        #expect(Flight.ease(0.1) < 0.01)                                         // slow start
        #expect(Flight.ease(0.9) > 0.99)                                         // slow landing
    }

    @Test func swingsRoundTheShortWay() {
        var a = overview, b = overview
        a.yaw = 3.0; b.yaw = -3.0                                                // 0.28 rad apart across ±π
        let middle = Flight(from: a, to: b, duration: 1).orbit(at: 0.5)
        #expect(abs(abs(middle.yaw) - Float.pi) < 0.01)
    }

    @Test func durationsLikeThePrototype() {
        #expect(Flight.duration(to: .overview) == 1.6)
        #expect(Flight.duration(to: .pr) == 1.15)
    }
}
