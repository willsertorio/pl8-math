import RealityKit
import SwiftUI
import PlateKit

/// A kettlebell on the units question: a body that falls, lands with a small bounce and stays put, and never turns
/// (the prototype's cannon body with its rotation locked and the skid damped). Simple enough to integrate here.
@MainActor
final class FlowBell {
    let outer: Entity
    let model: Entity
    let shadow: Entity
    let unit: WeightUnit
    var position: SIMD3<Float>
    var velocity = SIMD3<Float>.zero
    /// The finger: where the grabbed point should go, and where on the bell it was grabbed.
    var target: SIMD3<Float>?
    var grabOffset = SIMD3<Float>.zero
    var onPad = false
    var raptured = false
    var abducted: Float = 0
    var lift0: Float = 0
    var beam: Entity?
    var pool: Entity?
    static let halfHeight: Float = 0.39, radius: Float = 0.4

    init(outer: Entity, model: Entity, shadow: Entity, unit: WeightUnit, position: SIMD3<Float>) {
        self.outer = outer
        self.model = model
        self.shadow = shadow
        self.unit = unit
        self.position = position
    }
}

extension Flow {
    // MARK: - 2 · "Cool. Let's set 79. Do they use kilos or pounds there?" (flUnit)

    func stepUnit() {
        setCamera([0, 6.2, 10.4], [0, -0.35, 0.45])
        let size: Float = 1.25, square = SIMD3<Float>(0, 0, 1.55), inner = size - 0.12
        let parts = FlowProps.unitSquare(ink: ink)
        let frame = add(build(parts.frame))
        frame.position = square
        frame.isEnabled = false
        let occluder = add(build(parts.occluder))
        occluder.position = square
        let platform = add(build(parts.platform))
        platform.position = square
        platform.isEnabled = false

        var bells: [FlowBell] = []
        var chosen: FlowBell?
        var padY: Float = -0.1, padV: Float = 0, sinking = false

        let choose: (FlowBell) -> Void = { [weak self] bell in
            guard let self, chosen == nil else { return }
            chosen = bell
            self.buzz(.success)
            self.data.setUnit(bell.unit)
            // A bounce on the scale, then the scale sinks and settles.
            self.later(0.06) { [weak self] in self?.click(0.5) }
            self.later(0.7) { sinking = true }
            // The other one is abducted: a beam comes down, it lifts slowly, spins and shrinks away into the light.
            self.later(0.45) { [weak self] in
                guard let self, let other = bells.first(where: { $0 !== bell }) else { return }
                other.raptured = true
                other.abducted = 0
                other.velocity = .zero
                other.target = nil
                other.lift0 = other.position.y
                let light = FlowProps.beam()
                let beam = self.add(self.build(light.beam))
                beam.position = [other.position.x, 3.5, other.position.z]
                let pool = self.add(self.build(light.pool))
                pool.position = [other.position.x, 0.01, other.position.z]
                other.beam = beam
                other.pool = pool
            }
            self.later(2.3) { [weak self] in
                guard let self, self.step == .unit else { return }
                self.checkSound()
                self.panTo(.plates)
            }
        }

        say("Cool. Let’s set \(data.name.isEmpty ? "it" : data.name). Do they use kilos or pounds there?") { [weak self] in
            guard let self else { return }
            frame.isEnabled = true
            self.popIn(frame)
            platform.isEnabled = true
            self.popIn(platform, delay: 0.06)
            for (i, item) in [("KG", WeightUnit.kg, Float(-0.95)), ("LB", .lb, 0.95)].enumerated() {
                self.later(Double(i) * 0.26) { [weak self] in
                    guard let self, self.step == .unit else { return }
                    let model = self.build(FlowProps.kettlebell(label: item.0))
                    model.position.y = -FlowBell.halfHeight
                    let outer = Entity()
                    outer.addChild(model)
                    outer.orientation = simd_quatf(angle: Float.random(in: -0.2...0.2), axis: [0, 1, 0])
                    let shadow = self.add(self.softShadow(0.62))
                    let bell = FlowBell(outer: outer, model: model, shadow: shadow, unit: item.1, position: [item.2, 5 + Float(i) * 0.6, -0.55])
                    outer.position = bell.position
                    self.add(outer)
                    bells.append(bell)
                }
            }
        }

        /// Where the floor is under a point: the pad inside the square, else the floor.
        let ground = { (p: SIMD3<Float>) -> (height: Float, pad: Bool) in
            abs(p.x - square.x) < inner / 2 && abs(p.z - square.z) < inner / 2 ? (padY + 0.1, true) : (0, false)
        }
        let landed = { [weak self] (bell: FlowBell, speed: Float, pad: Bool) in
            guard let self else { return }
            if speed > 1 { self.impact(mass: 16, speed: speed, x: bell.position.x, z: bell.position.z, radius: 0.3, target: bell.model) }
            if speed > 1.2 { self.physDust(x: bell.position.x, z: bell.position.z, count: 200 * min(1, speed / 5), speed: 2.4, ring: 0.32, size: 1.5) }
            if pad, chosen == nil, bell.target == nil { choose(bell) }
        }

        /// One step of the bells (1/120 s): the finger's spring or gravity, landing, stacking, the fences.
        let integrate = { (dt: Float) in
            let h = FlowBell.halfHeight
            for bell in bells where !bell.raptured {
                if let target = bell.target {
                    // The grabbed point pulled to the finger: k 260, ζ 0.85, at most 140 (gravity is held).
                    let k = FlowPhysics.grabStiffness, c = 2 * k.squareRoot() * FlowPhysics.grabDamping
                    var a = (target - (bell.position + bell.grabOffset)) * k - bell.velocity * c
                    let length = simd_length(a)
                    if length > FlowPhysics.grabMaxForce { a *= FlowPhysics.grabMaxForce / length }
                    bell.velocity += a * dt
                } else {
                    bell.velocity.y -= FlowPhysics.gravity * dt
                }
                bell.position += bell.velocity * dt
                // The fences just out of view.
                bell.position.x = min(1.15, max(-1.15, bell.position.x))
                bell.position.z = min(2.0, max(-2.7, bell.position.z))
                let floor = ground(bell.position)
                if bell.position.y - h < floor.height {
                    bell.position.y = floor.height + h
                    if bell.velocity.y < 0 {
                        let speed = -bell.velocity.y
                        bell.velocity.y = speed > 0.6 ? speed * FlowPhysics.groundRestitution : 0
                        if speed > 0.6 || (floor.pad && !bell.onPad) { landed(bell, speed, floor.pad) }
                    }
                    bell.onPad = floor.pad
                    // On the ground a bell stays where it lands: no skating across the floor.
                    if bell.target == nil {
                        let k = exp(-16 * dt)
                        bell.velocity.x *= k
                        bell.velocity.z *= k
                    }
                } else if bell.position.y - h > floor.height + 0.02 {
                    bell.onPad = false
                }
            }
            // Bells are solid: one landing on the other stacks, side by side they push apart.
            if bells.count == 2, !bells[0].raptured, !bells[1].raptured {
                let a = bells[0], b = bells[1]
                var d = b.position - a.position
                let flat = SIMD2(d.x, d.z), across = simd_length(flat)
                let sideways = 2 * FlowBell.radius - across, upDown = 2 * h - abs(d.y)
                if sideways > 0 && upDown > 0 {
                    if upDown < sideways {
                        let (top, bottom) = d.y > 0 ? (b, a) : (a, b)
                        top.position.y = bottom.position.y + 2 * h
                        if top.velocity.y < 0 { top.velocity.y = 0 }
                    } else {
                        if across < 1e-4 { d = [1, 0, 0] }
                        let push = simd_normalize(SIMD3(d.x, 0, d.z)) * (sideways / 2)
                        a.position -= push
                        b.position += push
                    }
                }
            }
        }

        hit = { [weak self] point in
            guard let self, chosen == nil else { return nil }
            let r = self.ray(point)
            var best: FlowBell?, bestDistance = Float.infinity
            for bell in bells where !bell.raptured {
                let d = r.distance(to: bell.position)
                if d < 0.5 && d < bestDistance { bestDistance = d; best = bell }
            }
            guard let bell = best else { return nil }
            self.buzz(.selection)
            let grabbed = r.closestPoint(to: bell.position)
            bell.grabOffset = grabbed - bell.position
            let planeY = max(grabbed.y, 0.03) + 0.55
            bell.target = [grabbed.x, planeY, grabbed.z]
            return FlowDrag(move: { [weak self] p in
                guard let self, let q = self.onPlane(p, normal: [0, 1, 0], constant: planeY) else { return }
                bell.target = [min(1.5, max(-1.5, q.x)), planeY, min(2.3, max(-3.0, q.z))]
            }, up: { _, _ in
                bell.target = nil
            })
        }

        tick = { [weak self] dt, _ in
            guard let self else { return }
            if sinking {
                padV += (-0.16 - padY) * 60 * dt - padV * 7 * dt
                padY += padV * dt
                platform.position.y = padY + 0.1
            }
            let steps = max(1, Int((dt * 120).rounded(.up)))
            for _ in 0..<steps { integrate(dt / Float(steps)) }
            for bell in bells {
                if bell.raptured {
                    bell.abducted += dt
                    let a = bell.abducted
                    let beamA = min(1, a / 0.3) * (a > 1.7 ? max(0, 1 - (a - 1.7) / 0.4) : 1)
                    if let beam = bell.beam { self.setOpacity(0.32 * beamA, under: beam) }
                    if let pool = bell.pool { self.setOpacity(0.4 * beamA, under: pool) }
                    let lift = a < 0.35 ? 0 : pow(a - 0.35, 2) * 1.6, shrink = a < 0.9 ? 1 : max(0.0001, 1 - (a - 0.9) / 0.8)
                    bell.position.y = bell.lift0 + lift + 0.04 * sin(a * 9)
                    bell.outer.orientation = Flow.quaternion([0.06 * sin(a * 5), a * a * 3, 0])
                    bell.outer.scale = SIMD3(repeating: shrink)
                    self.setOpacity(min(1, shrink * 1.4), under: bell.model)
                    self.setOpacity(0.5 * shrink, under: bell.shadow)
                }
                bell.outer.position = bell.position
                let p = bell.position
                bell.shadow.position = [p.x, bell === chosen ? padY + 0.105 : 0.003, p.z]
                let s = 1 + max(0, p.y - 0.4) * 0.4
                bell.shadow.scale = SIMD3(repeating: s)
                if !bell.raptured { self.setOpacity(1 / (s * s), under: bell.shadow) }
            }
        }
    }

    /// Picking something up off the floor (flGrabber): the nearest body under the finger; the grabbed point is
    /// carried on a plane `lift` above where it was touched.
    func grabber(_ bodies: [FlowBody], radius: (FlowBody) -> Float, lift: Float, point: CGPoint,
                 bounds: (x: ClosedRange<Float>, z: ClosedRange<Float>) = (-1.5...1.5, -3.0...2.3)) -> FlowDrag? {
        guard let world = physics else { return nil }
        let r = ray(point)
        var best: FlowBody?, bestDistance = Float.infinity
        for body in bodies {
            let d = r.distance(to: body.entity.position(relativeTo: nil))
            if d < radius(body) && d < bestDistance { bestDistance = d; best = body }
        }
        guard let body = best else { return nil }
        buzz(.selection)
        let point3 = r.closestPoint(to: body.entity.position(relativeTo: nil))
        let local = body.entity.convert(position: point3, from: nil)
        let planeY = max(point3.y, 0.03) + lift
        world.grab = FlowGrab(body: body, local: local, to: [point3.x, planeY, point3.z])
        return FlowDrag(move: { [weak self] p in
            guard let self, let hitPoint = self.onPlane(p, normal: [0, 1, 0], constant: planeY) else { return }
            self.physics?.grab?.to = [min(bounds.x.upperBound, max(bounds.x.lowerBound, hitPoint.x)), planeY,
                                     min(bounds.z.upperBound, max(bounds.z.lowerBound, hitPoint.z))]
        }, up: { [weak self] _, _ in
            self?.physics?.grab = nil
        })
    }
}
