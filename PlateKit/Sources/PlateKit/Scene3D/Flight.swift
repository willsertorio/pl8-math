/// A camera flight between two orbits, like the prototype's flyTo: the look-at point slides across, the camera
/// swings round it the short way, distance, height and field of view blend, all on a smootherstep ease.
/// (With Reduce Motion the app cuts instead — SPEC 2.5.)
public struct Flight: Equatable, Sendable {
    public let from: Orbit
    public let to: Orbit
    /// Seconds.
    public let duration: Double

    public init(from: Orbit, to: Orbit, duration: Double) {
        self.from = from
        self.to = to
        self.duration = duration
    }

    /// The prototype's times: 1.15 s between stations, 1.6 s back out to the overview.
    public static func duration(to station: RoomLayout.Station) -> Double {
        station == .overview ? 1.6 : 1.15
    }

    /// Smootherstep: x³(x(6x − 15) + 10).
    public static func ease(_ x: Double) -> Double {
        let t = min(1, max(0, x))
        return t * t * t * (t * (t * 6 - 15) + 10)
    }

    public func isFinished(at time: Double) -> Bool { time >= duration }

    /// Where the camera is `time` seconds in.
    public func orbit(at time: Double) -> Orbit {
        let u = Float(Self.ease(duration > 0 ? time / duration : 1))
        var turn = to.yaw - from.yaw
        while turn > Float.pi { turn -= 2 * Float.pi }
        while turn < -Float.pi { turn += 2 * Float.pi }
        var orbit = from
        orbit.target = from.target + (to.target - from.target) * u
        orbit.distance = from.distance + (to.distance - from.distance) * u
        orbit.elevation = from.elevation + (to.elevation - from.elevation) * u
        orbit.yaw = from.yaw + turn * u
        orbit.fieldOfView = from.fieldOfView + (to.fieldOfView - from.fieldOfView) * u
        if u >= 1 { orbit = to }
        return orbit
    }
}
