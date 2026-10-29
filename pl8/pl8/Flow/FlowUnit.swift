import RealityKit
import SwiftUI
import PlateKit

/// A kettlebell on the units question.
@MainActor
final class FlowBell {
    let outer: Entity
    let model: Entity
    let shadow: Entity
    let unit: WeightUnit
    var body: FlowBody?
    var raptured = false
    var abducted: Float = 0
    var lift0: Float = 0
    var beam: Entity?
    var pool: Entity?

    init(outer: Entity, model: Entity, shadow: Entity, unit: WeightUnit) {
        self.outer = outer
        self.model = model
        self.shadow = shadow
        self.unit = unit
    }
}

extension Flow {
    // MARK: - 2 · "Cool. Let's set 79. Do they use kilos or pounds there?" (flUnit)

    func stepUnit() {
        setCamera([0, 6.2, 10.4], [0, -0.35, 0.45])
        let size: Float = 1.25, square = SIMD3<Float>(0, 0, 1.55), inner = size - 0.12
        let world = FlowPhysicsWorld(parent: scene)
        physics = world
        // The square is a pad set into a hole in the floor: its top sits flush, and it can sink.
        world.floor(hole: (square.x, square.z, size))
        world.fences([(0, -3.3, 3.4, 0.2), (0, 2.6, 3.4, 0.2), (-1.75, -0.4, 0.2, 3.2), (1.75, -0.4, 0.2, 3.2)])
        let pad = world.solid("pad", size: [inner, 0.2, inner], at: [square.x, -0.1, square.z])
        pad.components.set(PhysicsBodyComponent(massProperties: .default, material: FlowPhysicsWorld.groundMaterial, mode: .kinematic))
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
                guard let self, let other = bells.first(where: { $0 !== bell }), let body = other.body else { return }
                other.raptured = true
                other.abducted = 0
                body.entity.components.set(PhysicsBodyComponent(massProperties: .init(mass: 16), material: FlowPhysicsWorld.bodyMaterial, mode: .kinematic))
                other.lift0 = body.entity.position.y
                let light = FlowProps.beam()
                let beam = self.add(self.build(light.beam))
                beam.position = [body.entity.position.x, 3.5, body.entity.position.z]
                let pool = self.add(self.build(light.pool))
                pool.position = [body.entity.position.x, 0.01, body.entity.position.z]
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
                    model.position.y = -0.39
                    let outer = Entity()
                    outer.addChild(model)
                    let shadow = self.add(self.softShadow(0.62))
                    let bell = FlowBell(outer: outer, model: model, shadow: shadow, unit: item.1)
                    outer.position = [item.2, 5 + Float(i) * 0.6, -0.55]
                    outer.orientation = simd_quatf(angle: Float.random(in: -0.2...0.2), axis: [0, 1, 0])
                    world.root.addChild(outer)
                    let body = world.add(outer, shape: FlowPhysicsWorld.cylinderShape(top: 0.34, bottom: 0.4, height: 0.78, sides: 12),
                                         mass: 16, radius: 0.4, lockRotation: true, squash: model)
                    bell.body = body
                    bells.append(bell)
                    if let scene = outer.scene {
                        self.stepSubscriptions.append(scene.subscribe(to: CollisionEvents.Began.self, on: outer) { [weak self] event in
                            guard let self else { return }
                            let other = event.entityA === outer ? event.entityB : event.entityA
                            let v = max(abs(body.lastVelocity.y), event.impulse / 16)
                            if v > 1 { self.impact(mass: 16, speed: v, x: outer.position.x, z: outer.position.z, radius: 0.3, target: model) }
                            if v > 1.2 { self.physDust(x: outer.position.x, z: outer.position.z, count: 200 * min(1, v / 5), speed: 2.4, ring: 0.32, size: 1.5) }
                            if other === pad, chosen == nil, world.grab == nil { choose(bell) }
                        })
                    }
                }
            }
        }

        hit = { [weak self] point in
            guard let self, chosen == nil else { return nil }
            return self.grabber(bells.compactMap(\.body), radius: { _ in 0.5 }, lift: 0.55, point: point)
        }

        tick = { [weak self] dt, _ in
            guard let self else { return }
            if sinking {
                padV += (-0.16 - padY) * 60 * dt - padV * 7 * dt
                padY += padV * dt
                pad.position.y = padY
                platform.position.y = padY + 0.1
            }
            for bell in bells {
                guard let body = bell.body else { continue }
                let entity = body.entity
                if bell.raptured {
                    bell.abducted += dt
                    let a = bell.abducted
                    let beamA = min(1, a / 0.3) * (a > 1.7 ? max(0, 1 - (a - 1.7) / 0.4) : 1)
                    if let beam = bell.beam { self.setOpacity(0.32 * beamA, under: beam) }
                    if let pool = bell.pool { self.setOpacity(0.4 * beamA, under: pool) }
                    let lift = a < 0.35 ? 0 : pow(a - 0.35, 2) * 1.6, shrink = a < 0.9 ? 1 : max(0.0001, 1 - (a - 0.9) / 0.8)
                    entity.position.y = bell.lift0 + lift + 0.04 * sin(a * 9)
                    entity.orientation = Flow.quaternion([0.06 * sin(a * 5), a * a * 3, 0])
                    bell.model.scale = SIMD3(repeating: shrink)
                    self.setOpacity(min(1, shrink * 1.4), under: bell.model)
                    self.setOpacity(0.5 * shrink, under: bell.shadow)
                } else if world.grab?.body !== body, entity.position.y < 0.62 {
                    // On the ground a bell stays where it lands: no skating across the floor.
                    if var motion = entity.components[PhysicsMotionComponent.self] {
                        let k = exp(-16 * dt)
                        motion.linearVelocity.x *= k
                        motion.linearVelocity.z *= k
                        entity.components.set(motion)
                    }
                }
                let p = entity.position
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
