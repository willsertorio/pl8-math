import Foundation

/// Turning and zooming the camera around what it looks at, like the prototype's OrbitControls: drag to go
/// round, pinch to come closer. The camera never dips below the floor (polar angle ≤ 0.49 π) and stays
/// 1.2–90 m away.
public struct Orbit: Equatable, Sendable {
    public var target: SIMD3<Float>
    public var distance: Float
    /// Around Y, radians.
    public var yaw: Float
    /// Up from level, radians.
    public var elevation: Float
    public var fieldOfView: Float

    public static let distanceRange: ClosedRange<Float> = 1.2...90
    public static let elevationRange: ClosedRange<Float> = (Float.pi * 0.01)...(Float.pi * 0.49)

    public init(_ shot: RoomLayout.Shot) {
        let offset = shot.position - shot.target
        target = shot.target
        distance = offset.length
        yaw = atan2(offset.x, offset.z)
        elevation = asin(offset.y / max(distance, 0.0001))
        fieldOfView = shot.fieldOfView
    }

    public var position: SIMD3<Float> {
        let flat = distance * cos(elevation)
        return target + SIMD3(flat * sin(yaw), distance * sin(elevation), flat * cos(yaw))
    }

    /// A drag by (`dx`, `dy`) points: right turns the room with your finger, down tilts it towards you.
    public func dragged(dx: Float, dy: Float) -> Orbit {
        var next = self
        next.yaw -= dx * 0.008
        next.elevation = min(Self.elevationRange.upperBound, max(Self.elevationRange.lowerBound, elevation + dy * 0.008))
        return next
    }

    /// A pinch by `scale` (above 1 spreads the fingers: closer).
    public func zoomed(by scale: Float) -> Orbit {
        var next = self
        next.distance = min(Self.distanceRange.upperBound, max(Self.distanceRange.lowerBound, distance / max(scale, 0.01)))
        return next
    }
}

