import AVFoundation
import RealityKit
import UIKit
import PlateKit

// MARK: - Physics

/// A drop or drag world (flPhysWorld): RealityKit's physics under the stage, the prototype's materials, and the
/// hand — a spring pulling the grabbed point to the finger (k 260, ζ 0.85, at most 140 × mass).
@MainActor
final class FlowPhysicsWorld {
    let root: Entity
    var bodies: [FlowBody] = []
    var grab: FlowGrab?
    var onStep: ((Float) -> Void)?

    /// Plate on plate 0.35 / 0.12. RealityKit averages the two materials in a contact, so the ground's numbers make
    /// plate on ground come out at the prototype's 0.55 / 0.2.
    static let bodyMaterial = PhysicsMaterialResource.generate(staticFriction: FlowPhysics.plateFriction,
                                                               dynamicFriction: FlowPhysics.plateFriction,
                                                               restitution: FlowPhysics.plateRestitution)
    static let groundMaterial = PhysicsMaterialResource.generate(staticFriction: 2 * FlowPhysics.groundFriction - FlowPhysics.plateFriction,
                                                                 dynamicFriction: 2 * FlowPhysics.groundFriction - FlowPhysics.plateFriction,
                                                                 restitution: 2 * FlowPhysics.groundRestitution - FlowPhysics.plateRestitution)

    init(parent: Entity) {
        root = Entity()
        root.name = "physics"
        var simulation = PhysicsSimulationComponent()
        simulation.gravity = [0, -FlowPhysics.gravity, 0]
        root.components.set(simulation)
        parent.addChild(root)
    }

    /// A solid, still box (floor slabs, the fences just out of view, the scale's pad).
    @discardableResult
    func solid(_ name: String, size: SIMD3<Float>, at position: SIMD3<Float>) -> Entity {
        let body = Entity()
        body.name = name
        body.position = position
        body.components.set(CollisionComponent(shapes: [.generateBox(size: size)]))
        body.components.set(PhysicsBodyComponent(massProperties: .default, material: Self.groundMaterial, mode: .static))
        root.addChild(body)
        return body
    }

    /// The floor: a slab with its top at y = 0, cut round a square hole if there is one (the scale's pad).
    func floor(hole: (x: Float, z: Float, size: Float)? = nil) {
        guard let hole else { solid("ground", size: [16, 1, 16], at: [0, -0.5, 0]); return }
        let x0 = hole.x - hole.size / 2, x1 = hole.x + hole.size / 2, z0 = hole.z - hole.size / 2, z1 = hole.z + hole.size / 2
        for (a, b, c, d) in [(-8, x0, -8, 8), (x1, 8, -8, 8), (x0, x1, -8, z0), (x0, x1, z1, 8)] as [(Float, Float, Float, Float)] {
            solid("ground", size: [b - a, 1, d - c], at: [(a + b) / 2, -0.5, (c + d) / 2])
        }
    }

    /// Fences just outside the view, so a thrown thing stays on screen.
    func fences(_ boxes: [(x: Float, z: Float, hx: Float, hz: Float)]) {
        for b in boxes { solid("fence", size: [b.hx * 2, 3, b.hz * 2], at: [b.x, 1.5, b.z]) }
    }

    /// Makes `entity` a dynamic body.
    func add(_ entity: Entity, shape: ShapeResource, mass: Float, radius: Float, lockRotation: Bool = false, squash: Entity? = nil) -> FlowBody {
        add(entity, shapes: [shape], mass: mass, radius: radius, lockRotation: lockRotation, squash: squash)
    }

    /// Makes `entity` a dynamic body of several pieces (the scale's bar).
    func add(_ entity: Entity, shapes: [ShapeResource], mass: Float, radius: Float, lockRotation: Bool = false, squash: Entity? = nil) -> FlowBody {
        entity.components.set(CollisionComponent(shapes: shapes))
        var body = PhysicsBodyComponent(massProperties: .init(mass: mass), material: Self.bodyMaterial, mode: .dynamic)
        if lockRotation { body.isRotationLocked = (x: true, y: true, z: true) }
        entity.components.set(body)
        entity.components.set(PhysicsMotionComponent())
        if entity.parent == nil { root.addChild(entity) }
        let flowBody = FlowBody(entity: entity, mass: mass, radius: radius, squash: squash ?? entity)
        bodies.append(flowBody)
        return flowBody
    }

    func step(_ dt: Float) {
        onStep?(dt)
        for body in bodies { body.lastVelocity = body.entity.components[PhysicsMotionComponent.self]?.linearVelocity ?? .zero }
        guard let grab, dt > 0 else { return }
        // The grabbed point, pulled to the finger: F/m = k (to − p) − c v − g, at most 140.
        let entity = grab.body.entity
        let point = entity.convert(position: grab.local, to: nil)
        var motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
        let k = FlowPhysics.grabStiffness, c = 2 * k.squareRoot() * FlowPhysics.grabDamping
        var force = (grab.to - point) * k - motion.linearVelocity * c + SIMD3(0, FlowPhysics.gravity, 0)
        let length = simd_length(force)
        if length > FlowPhysics.grabMaxForce { force *= FlowPhysics.grabMaxForce / length }
        motion.linearVelocity += force * dt
        // Pulled at the grabbed point, not the middle: a turn too (a disc tilting about its rim, I ≈ m r²/4).
        let arm = point - entity.position(relativeTo: nil)
        let r = max(0.05, grab.body.radius)
        motion.angularVelocity += simd_cross(arm, force) * (4 / (r * r)) * dt * 0.5
        motion.angularVelocity *= pow(1 - FlowPhysics.grabAngularDamping, dt)
        entity.components.set(motion)
    }

    /// Cylinder (or frustum) points for a convex shape along Y.
    static func cylinderShape(top: Float, bottom: Float, height: Float, sides: Int = 16) -> ShapeResource {
        var points: [SIMD3<Float>] = []
        for i in 0..<sides {
            let a = Float(i) / Float(sides) * 2 * .pi
            points.append([top * cos(a), height / 2, top * sin(a)])
            points.append([bottom * cos(a), -height / 2, bottom * sin(a)])
        }
        return ShapeResource.generateConvex(from: points)
    }
}

final class FlowBody {
    let entity: Entity
    let mass: Float
    let radius: Float
    /// What squashes on an impact (the visible model inside the body).
    let squash: Entity
    var lastVelocity: SIMD3<Float> = .zero
    var tag: String = ""

    init(entity: Entity, mass: Float, radius: Float, squash: Entity) {
        self.entity = entity
        self.mass = mass
        self.radius = radius
        self.squash = squash
    }
}

struct FlowGrab {
    let body: FlowBody
    /// The grabbed point in the body's own space.
    let local: SIMD3<Float>
    var to: SIMD3<Float>
}

/// One chunk of dust (flPhysDust).
struct FlowDust {
    let entity: Entity
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var rotation: SIMD3<Float>
    let spin: SIMD3<Float>
    var life: Float = 0
    let lifetime: Float
    let size: Float
}

/// One star (flSparkles).
struct FlowSparkle {
    let holder: Entity
    let star: Entity
    var t: Float
    let lifetime: Float
    let size: Float
}

struct FlowSquash {
    let entity: Entity
    var t: Float = 0
    let amplitude: Float
}

extension Flow {
    // MARK: - Impacts (flImpact): a shake, a squash, a tiny zoom punch, a thud and dust

    func impact(mass: Float, speed v: Float, x: Float, z: Float, radius: Float, flat: Bool = true, target: Entity?) {
        guard v >= 1.2 else { return }
        let f = mass / 25, hit = min(1, v / 12)
        trauma = min(0.7, trauma + 0.45 * f * (0.35 + 0.65 * hit))
        let juice = min(1, (0.3 + 0.7 * hit) * (0.25 + 0.75 * f.squareRoot()))
        if let target { squashes[ObjectIdentifier(target)] = FlowSquash(entity: target, amplitude: 0.22 * juice) }
        fovKick = min(0.025, fovKick + 0.012 * f * hit)
        thud(0.2 + 0.7 * f * (0.4 + 0.6 * hit))
        guard v >= FlowPhysics.dustMinImpact else { return }
        let k = f * (0.45 + 0.55 * hit), sm = 0.2 + 1.25 * f
        if flat {
            physDust(x: x, z: z, count: 6 * f + 110 * k, speed: 0.4 * f + 2.8 * k, ring: radius, size: sm)
        } else {
            physDust(x: x, z: z, count: 4 * f + 60 * k, speed: 0.3 * f + 2.2 * k, ring: 0.03 + 0.06 * f, size: sm)
        }
    }

    func physDust(x: Float, z: Float, count: Float, speed: Float, ring: Float, size sm: Float) {
        let raw = count * FlowPhysics.dustCount * FlowPhysics.dustAmount
        let n = min(220, Int(raw) + (Float.random(in: 0..<1) < raw.truncatingRemainder(dividingBy: 1) ? 1 : 0))
        guard n > 0 else { return }
        let template = dustTemplate()
        for _ in 0..<n {
            let a = Float.random(in: 0..<(2 * .pi)), rr = ring * Float.random(in: 0.8...1.1)
            let spread = speed * FlowPhysics.dustSpread * Float.random(in: 0.3...1.1)
            let chunk = template.clone(recursive: true)
            chunk.scale = SIMD3(repeating: 0.0001)
            scene.addChild(chunk)
            dust.append(FlowDust(entity: chunk,
                                 position: [x + cos(a) * rr, Float.random(in: 0.04...0.08), z + sin(a) * rr],
                                 velocity: [cos(a) * spread, Float.random(in: 0.2...0.8) * speed * 0.5 * FlowPhysics.dustRise, sin(a) * spread],
                                 rotation: [.random(in: 0...6.28), .random(in: 0...6.28), .random(in: 0...6.28)],
                                 spin: [.random(in: -0.8...0.8), .random(in: -0.8...0.8), .random(in: -0.8...0.8)],
                                 lifetime: Float.random(in: FlowPhysics.dustLives) * FlowPhysics.dustLinger,
                                 size: (Float.random(in: FlowPhysics.dustSizes) + speed * 0.012) * FlowPhysics.dustSize * sm))
        }
    }

    private func dustTemplate() -> Entity {
        if let cached = dustCache { return cached }
        // Flat-shaded dust colour, lit once from above: tiny and short-lived, its light doesn't need to follow it.
        let part = FlowPart("dust", mesh: Geo.icosahedron(), paint: .colour(FlowLook.dust), shade: .standard(roughness: 0.85, metalness: 0))
        let entity = Entity()
        entity.addChild(model(part))
        dustCache = entity
        return entity
    }

    func dustTick(_ dt: Float) {
        guard !dust.isEmpty else { return }
        let drag = exp(-3 * dt)
        dust = dust.compactMap { d in
            var d = d
            d.life += dt
            let t = d.life / d.lifetime
            if t >= 1 { d.entity.removeFromParent(); return nil }
            d.velocity.x *= drag; d.velocity.z *= drag
            d.velocity.y = d.velocity.y * drag + 0.18 * FlowPhysics.dustRise * dt
            d.position += d.velocity * dt
            let floorY = d.size * 0.6
            if d.position.y < floorY { d.position.y = floorY; d.velocity.y = max(0, d.velocity.y) }
            d.rotation += d.spin * dt
            let pop = t < 0.22 ? 1 - pow(1 - t / 0.22, 3) : 1, shrink = t > 0.45 ? max(0, 1 - (t - 0.45) / 0.55) : 1
            d.entity.position = d.position
            d.entity.orientation = Self.quaternion(d.rotation)
            d.entity.scale = SIMD3(repeating: max(0.0001, d.size * (0.35 + pop + 0.7 * t) * shrink))
            return d
        }
    }

    // MARK: - Squash (flSquashTick)

    func squashTick(_ dt: Float) {
        guard !squashes.isEmpty else { return }
        for (key, var q) in squashes {
            q.t += dt
            if q.t > 0.6 {
                q.entity.scale = [1, 1, 1]
                squashes[key] = nil
                continue
            }
            let a = q.amplitude * exp(-q.t * 9) * cos(q.t * 34)
            q.entity.scale = [1 + a * 0.45, 1 - a, 1 + a * 0.45]
            squashes[key] = q
        }
    }

    // MARK: - Shine and sparkles (flShine, flSparkles)

    /// A reflection runs over the things: they brighten toward white and back.
    func shine(_ entities: [Entity], duration: Double = 0.7) {
        let items = entities.flatMap { shadedModels(under: $0) }
        anim(duration, { u in
            let k = Float(sin(min(1, u) * .pi) * (u < 0.35 ? 1 : 0.85))
            for item in items { item.state.shine = k }
        }, done: {
            for item in items { item.state.shine = 0 }
        })
        click(1.6)
    }

    func sparkles(at p: SIMD3<Float>, count: Int, spread: Float) {
        for i in 0..<count {
            let holder = Entity()
            holder.position = p + SIMD3(Float.random(in: -0.5...0.5) * spread, Float.random(in: -0.3...0.7) * spread,
                                        Float.random(in: -0.5...0.5) * spread * 0.4)
            let star = model(FlowPart("star", mesh: Geo.plane(1, 1), paint: .picture(.star, tint: RGB(1, 1, 1)), shade: .flat))
            holder.addChild(star)
            holder.scale = SIMD3(repeating: 0.0001)
            scene.addChild(holder)
            sparkles.append(FlowSparkle(holder: holder, star: star, t: -Float(i) * 0.06, lifetime: Float.random(in: 0.55...0.85),
                                        size: Float.random(in: 0.12...0.26)))
        }
    }

    func sparkleTick(_ dt: Float) {
        guard !sparkles.isEmpty else { return }
        // Stars face the screen like three.js sprites.
        let facing = simd_quatf(liveCamera.matrix)
        sparkles = sparkles.compactMap { s in
            var s = s
            s.t += dt
            if s.t < 0 { return s }
            let u = s.t / s.lifetime
            if u >= 1 { s.holder.removeFromParent(); return nil }
            s.holder.orientation = facing
            s.holder.scale = SIMD3(repeating: max(0.0001, s.size * sin(u * .pi)))
            s.star.orientation = simd_quatf(angle: s.t * 3, axis: [0, 0, 1])
            return s
        }
    }

    // MARK: - A soft round shadow (softShadow)

    func softShadow(_ radius: Float) -> Entity { build(FlowProps.softShadow(radius: radius)) }

    // MARK: - Sound and touch

    func buzz(_ kind: FlowBuzz) {
        switch kind {
        case .selection: selectionTicks += 1
        case .light: lightTicks += 1
        case .success: successTicks += 1
        case .warning: warningTicks += 1
        }
    }

    /// A small dry click (flClick): dial detents, plates landing and seating.
    func click(_ pitch: Float = 1) {
        guard t - lastClick >= 0.025 else { return }
        lastClick = t
        FlowSound.click(pitch)
    }

    func thud(_ k: Float) { FlowSound.thud(k) }

    /// The light check (flCheckSound): when a step is confirmed.
    func checkSound() { FlowSound.check() }
}

enum FlowBuzz { case selection, light, success, warning }

/// The prototype's Web Audio sounds, synthesised the same way and played through `Sounds` (respects the silent switch).
enum FlowSound {
    static let rate = Sounds.rate

    /// Band-passed noise at 2400 × pitch with a little wooden body under it.
    static func click(_ pitch: Float) {
        let n = Int(rate * 0.06)
        var noise = (0..<Int(rate * 0.05)).map { i in Float.random(in: -1...1) * pow(1 - Float(i) / Float(rate * 0.05), 6) }
        noise = resample(noise, by: Float.random(in: 0.9...1.1))
        var out = biquad(noise, bandPass: 2400 * Double(pitch), q: 3.5)
        out += [Float](repeating: 0, count: max(0, n - out.count))
        for i in out.indices {
            let t = Double(i) / rate
            out[i] *= Float(t < 0.045 ? 0.55 * pow(0.001 / 0.55, t / 0.045) : 0)
        }
        var phase = 0.0
        for i in 0..<min(n, out.count) {
            let t = Double(i) / rate
            let f = 420 * Double(pitch) * pow(180 / (420 * Double(pitch)), min(1, t / 0.04))
            phase += f / rate
            let triangle = 4 * abs(phase.truncatingRemainder(dividingBy: 1) - 0.5) - 1
            out[i] += Float(triangle * (t < 0.05 ? 0.12 * pow(0.001 / 0.12, t / 0.05) : 0))
        }
        Sounds.play(out.map { $0 * 0.6 })
    }

    /// A low thump: a sine falling 120 → 42 Hz and a puff of low noise.
    static func thud(_ k: Float) {
        let a = Double(min(1, k)), n = Int(rate * 0.32)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / rate
            let f = 120 * pow(42.0 / 120, min(1, t / 0.25))
            phase += f / rate
            out[i] = Float(sin(2 * .pi * phase) * 0.7 * a * pow(0.001 / max(0.0001, 0.7 * a), min(1, t / 0.3)))
        }
        let noise = (0..<Int(rate * 0.05)).map { i in Float.random(in: -1...1) * pow(1 - Float(i) / Float(rate * 0.05), 6) }
        let low = biquad(noise, lowPass: 900)
        for i in low.indices where i < n {
            let t = Double(i) / rate
            out[i] += low[i] * Float(0.5 * a * pow(0.001 / max(0.0001, 0.5 * a), min(1, t / 0.12)))
        }
        Sounds.play(out.map { $0 * 0.6 })
    }

    /// Two quick triangle notes, 1320 then 1980 Hz.
    static func check() {
        let n = Int(rate * 0.16)
        var out = [Float](repeating: 0, count: n)
        for (frequency, delay) in [(1320.0, 0.0), (1980.0, 0.055)] {
            for i in 0..<n {
                let t = Double(i) / rate - delay
                guard t >= 0, t < 0.1 else { continue }
                let envelope = t < 0.006 ? 0.0001 * pow(0.22 / 0.0001, t / 0.006) : 0.22 * pow(0.0001 / 0.22, min(1, (t - 0.006) / 0.084))
                let phase = (t * frequency).truncatingRemainder(dividingBy: 1)
                out[i] += Float((4 * abs(phase - 0.5) - 1) * envelope)
            }
        }
        Sounds.play(out)
    }

    static func resample(_ x: [Float], by rate: Float) -> [Float] {
        let count = Int(Float(x.count) / rate)
        return (0..<count).map { i in
            let p = Float(i) * rate, j = Int(p), w = p - Float(j)
            return j + 1 < x.count ? x[j] * (1 - w) + x[j + 1] * w : x[min(j, x.count - 1)]
        }
    }

    /// Web Audio's biquad band-pass (0 dB at the centre).
    static func biquad(_ x: [Float], bandPass f: Double, q: Double) -> [Float] {
        let w0 = 2 * Double.pi * f / rate, alpha = sin(w0) / (2 * q)
        return filter(x, b: [alpha, 0, -alpha], a: [1 + alpha, -2 * cos(w0), 1 - alpha])
    }

    static func biquad(_ x: [Float], lowPass f: Double) -> [Float] {
        let w0 = 2 * Double.pi * f / rate, alpha = sin(w0) / (2 * 1.12), c = cos(w0)
        return filter(x, b: [(1 - c) / 2, 1 - c, (1 - c) / 2], a: [1 + alpha, -2 * c, 1 - alpha])
    }

    static func filter(_ x: [Float], b: [Double], a: [Double]) -> [Float] {
        var y = [Float](repeating: 0, count: x.count)
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        for i in x.indices {
            let xi = Double(x[i])
            let yi = (b[0] * xi + b[1] * x1 + b[2] * x2 - a[1] * y1 - a[2] * y2) / a[0]
            x2 = x1; x1 = xi; y2 = y1; y1 = yi
            y[i] = Float(yi)
        }
        return y
    }
}
