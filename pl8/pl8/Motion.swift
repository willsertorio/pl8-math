import CoreMotion
import SwiftUI

/// The phone's tilt for the "move with the phone" effects (Will, 2026-10-19): the intro gets depth, the room at home
/// swings as if gravity pulls it. Read from the motion sensors' gravity, relative to how the phone was held when the
/// effect started, slowly re-centred so a new way of holding it becomes the new rest. Off with the switch in the Gym
/// drawer, and with Reduce Motion.
@MainActor
final class MotionSource {
    static let shared = MotionSource()
    /// The setting's key (on unless switched off).
    static let settingKey = "motionEffects"

    /// Which way is downhill now, about −1…1: x to the right of the screen, y up it.
    private(set) var tilt = SIMD2<Float>.zero

    private let manager = CMMotionManager()
    private var rest: SIMD2<Float>?
    private var users = 0

    func start() {
        users += 1
        guard users == 1, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let gravity = motion?.gravity else { return }
            MainActor.assumeIsolated { self?.update(SIMD2(Float(gravity.x), Float(gravity.y))) }
        }
    }

    func stop() {
        users = max(0, users - 1)
        guard users == 0 else { return }
        manager.stopDeviceMotionUpdates()
        rest = nil
        tilt = .zero
    }

    private func update(_ gravity: SIMD2<Float>) {
        // Gravity points to the lower side of the phone: x to the right edge, y to the top.
        let start = rest ?? gravity
        rest = start + (gravity - start) / (60 * 4)                  // re-centres over about 4 seconds
        let raw = gravity - (rest ?? gravity)
        tilt = SIMD2(min(0.6, max(-0.6, raw.x)), min(0.6, max(-0.6, raw.y)))
    }
}

/// A springy follower of the tilt: it swings past and settles, like something hanging.
struct TiltSpring {
    private(set) var value = SIMD2<Float>.zero
    private var speed = SIMD2<Float>.zero

    mutating func step(towards target: SIMD2<Float>, dt: Float) -> SIMD2<Float> {
        speed += ((target - value) * 40 - speed * 6) * dt
        value += speed * dt
        return value
    }
}
