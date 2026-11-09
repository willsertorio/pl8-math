import AVFoundation
import Combine
import RealityKit
import SwiftUI
import UIKit
import PlateKit

/// Session over (SPEC 2.3 step 7), like the prototype's 'done' scene (AnimLayer buildDone and stepDone): the
/// bell rings three times, then the heaviest set's plates fall one by one onto a scale, heaviest first, and the
/// bar lands across them. The scale's screen counts up as each one lands; then "You lifted a lion." appears word
/// by word. Then the bar and the plates can be dragged off (startDonePhysics), and the screen reads what's left.
/// Tap to go back.
struct SessionOverView: View {
    let perSide: [Double]
    let unit: WeightUnit
    let barWeight: Double
    var onDone: () -> Void

    @State private var stage: ScaleStage
    @State private var words = 0
    @State private var landings = 0
    @State private var grabs = 0
    /// The finger: when it went down, and whether it took hold of something.
    @State private var pressed: Date?
    @State private var holding = false
    @State private var appeared = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameter stage: the CI's pictures hand one in, to play a drag on it.
    init(perSide: [Double], unit: WeightUnit, barWeight: Double, stage: ScaleStage? = nil, onDone: @escaping () -> Void) {
        self.perSide = perSide
        self.unit = unit
        self.barWeight = barWeight
        self.onDone = onDone
        _stage = State(initialValue: stage ?? ScaleStage())
    }

    private var total: Double { ScaleScene.total(perSide: perSide, barWeight: barWeight) }
    private var message: [String] { Animals.message(for: total, unit: unit).split(separator: " ").map(String.init) }
    private var cream: Color { Color(rgb: FlowLook.light) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            // Drawn like the prototype's 'done' layer: through the sketch pass, rough on the orange.
            SketchStageView(entities: { stage.build(perSide: perSide, unit: unit, barWeight: barWeight, sketched: true) },
                            made: { stage.view = $0 })
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // The Flow's scale shows no label (the prototype passes "Heaviest set" but hides it).
                Spacer()
                // Each word simply appears, one after another (the prototype's dMsgIn "words", 260 ms apart). One Text,
                // so the spaces are a font's spaces (separate words each with a trailing space lost some of it).
                message.enumerated().reduce(Text("")) { text, item in
                    text + Text(item.element + (item.offset < message.count - 1 ? " " : ""))
                        .foregroundStyle(cream.opacity(item.offset < words ? 1 : 0))
                }
                // In the title's face, as the prototype's dMsgFont "title" asks: Helvetica Neue now.
                .font(.custom(FlowType.medium, size: 24))
                .tracking(-0.02 * 24)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 200)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onDone() }
            }
        }
        .contentShape(Rectangle())
        // Window points, like the stage's view, which fills the screen.
        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if pressed == nil {
                    pressed = .now
                    holding = stage.grab(at: value.startLocation)
                    if holding { grabs += 1 }
                }
                if holding { stage.drag(to: value.location) }
            }
            .onEnded { value in
                // A tap (no drag) moves on, once the message is showing or after 6 s, like the prototype's.
                let tap = hypot(value.translation.width, value.translation.height) < 8 && Date.now.timeIntervalSince(pressed ?? .now) < 0.6
                stage.release()
                pressed = nil
                holding = false
                if tap && (words > 0 || Date.now.timeIntervalSince(appeared) > 6) { onDone() }
            })
        .sensoryFeedback(.impact(weight: .medium), trigger: landings)
        .sensoryFeedback(.selection, trigger: grabs)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .task {
            appeared = .now
            Bell.ring()
            stage.onLanding = { landings += 1 }
            await stage.play(instantly: reduceMotion)
            try? await Task.sleep(for: .milliseconds(350))
            for index in 1...message.count {
                words = index
                try? await Task.sleep(for: .milliseconds(260))
            }
        }
    }
}

/// The scale's 3D scene: built once, then played frame by frame; at the end its bar and plates can be dragged.
@MainActor
final class ScaleStage {
    private var drops: [ScaleScene.Drop] = []
    private var dropEntities: [Entity] = []
    private let world = Entity()
    private let platform = Entity()
    private var screen: ModelEntity?
    /// The display's pictures, made before anything falls: a new texture in the middle of a landing stalled the
    /// stage (the CI caught the scale frozen mid-drop).
    private var readouts: [Double: TextureResource] = [:]
    private var unit: WeightUnit = .kg
    private var barWeight: Double = 0
    private var built = false
    /// The camera, and where it rests: it kicks on each landing (the prototype's dShake 0.3). It moves round the
    /// scale, not the scale round it, so the scale's space is the world's and the drag's physics falls straight down.
    private let camera = PerspectiveCamera()
    private var eye: SIMD3<Float> = .zero
    weak var view: ARView?
    var onLanding: () -> Void = {}

    // The drag at the end (startDonePhysics): one body per drop, nil once it has fallen away.
    private var physics: FlowPhysicsWorld?
    private var bodies: [FlowBody?] = []
    private var grabPlane: (normal: SIMD3<Float>, constant: Float)?
    private var touched = false
    private var reading: Double = -1
    private var update: (any Cancellable)?
    /// The bar and the plates can be grabbed.
    private(set) var draggable = false

    /// - Parameter sketched: drawn through the sketch pass (no orange sky box, no outline strokes of its own).
    func build(perSide: [Double], unit: WeightUnit, barWeight: Double, sketched: Bool = false) -> [Entity] {
        self.unit = unit
        self.barWeight = barWeight
        let still = RoomLayout.Placement(position: .zero, rotationDegrees: 0)
        let ink = { (parts: [PropPart]) in sketched ? parts.filter { $0.tone != .flat(Look.ink) } : parts }
        // The orange all round, then the scale, lit like the room.
        if !sketched, let sky = try? ModelEntity(mesh: Diorama.meshResource(LowPolyMesh.box(size: [200, 200, 200]).insideOut()),
                                      materials: [Diorama.flat(Diorama.background)]) {
            world.addChild(sky)
        }
        let parts = ScaleScene.parts()
        for child in Diorama.entities(for: SceneBake.bake(ink(parts.base), placement: still, wall: nil, content: .withoutShadows, light: .animation), duotone: true) {
            world.addChild(child)
        }
        for child in Diorama.entities(for: SceneBake.bake(ink(parts.platform), placement: still, wall: nil, content: .withoutShadows, light: .animation), duotone: true) {
            platform.addChild(child)
        }
        world.addChild(platform)
        if let mesh = try? Diorama.meshResource(LowPolyMesh.sheet(width: ScaleScene.screenSize.x, height: ScaleScene.screenSize.y, columns: 1, rows: 1)) {
            let screen = ModelEntity(mesh: mesh, materials: [Diorama.flat(.black)])
            screen.position = ScaleScene.screenCentre
            screen.orientation = simd_quatf(angle: ScaleScene.screenTilt, axis: [1, 0, 0])
            world.addChild(screen)
            self.screen = screen
            show(0)
        }

        drops = ScaleScene.drops(perSide: perSide, unit: unit, barWeight: barWeight)
        var reading = 0.0
        for drop in drops {
            reading += weight(drop)
            readouts[reading] = Self.texture(reading, unit: unit)
        }
        dropEntities = drops.map { drop in
            var parts = drop.plate.map { SessionScene.parts(.init(plate: $0, centre: .zero, axis: .y, turn: drop.turn)) }
                ?? ScaleScene.barParts()
            // The prototype's rough sketch line round it (the sketch pass draws it when there is one).
            if !sketched {
                parts.append(PropPart(mesh: ScaleScene.outline(parts, seed: UInt32(drop.at * 100)),
                                      tone: .flat(Look.ink), inked: false, casts: false))
            }
            let entity = Entity()
            for child in Diorama.entities(for: SceneBake.bake(parts, placement: still, wall: nil, content: .withoutShadows, light: .animation), duotone: true) {
                entity.addChild(child)
            }
            entity.isEnabled = false
            world.addChild(entity)
            return entity
        }

        // The prototype's camera: 45° round, 32° up, 3.5 m of the scene in view (a long lens from 20 m).
        let distance: Float = 20
        let flat = distance * cos(ScaleScene.cameraElevation)
        eye = ScaleScene.cameraTarget + SIMD3(flat * sin(ScaleScene.cameraYaw), distance * sin(ScaleScene.cameraElevation),
                                              flat * cos(ScaleScene.cameraYaw))
        camera.look(at: ScaleScene.cameraTarget, from: eye, relativeTo: nil)
        camera.camera.fieldOfViewInDegrees = 2 * atan(ScaleScene.viewHeight / 2 / distance) * 180 / .pi
        // The scene is 20 m off: a near plane close by would leave too little depth precision for the platform's
        // 5 mm cream top (it vanished into the body in the ARView).
        camera.camera.near = distance - 5
        camera.camera.far = distance + 5
        built = true
        return [world, camera]
    }

    /// Drops everything in turn; the platform dips on a spring at each landing. Returns once the last one has
    /// settled, and the bar and plates can be dragged.
    func play(instantly: Bool) async {
        while !built && !Task.isCancelled { try? await Task.sleep(for: .milliseconds(16)) }
        var dip: Float = 0, dipSpeed: Float = 0, read: Double = 0, shake: Float = 0
        var landed = Array(repeating: false, count: drops.count)
        let start = ContinuousClock.now
        var last = start
        let right = camera.orientation.act([1, 0, 0]), up = camera.orientation.act([0, 1, 0])
        while !Task.isCancelled {
            let now = ContinuousClock.now
            let t = instantly ? 100 : Float((now - start) / .seconds(1))
            let dt = min(0.05, Float((now - last) / .seconds(1)))
            last = now
            dipSpeed += (-90 * dip - 11 * dipSpeed) * dt
            dip += dipSpeed * dt
            platform.position.y = dip
            for (index, drop) in drops.enumerated() {
                let elapsed = t - drop.at
                let entity = dropEntities[index]
                guard elapsed >= 0 else { entity.isEnabled = false; continue }
                entity.isEnabled = true
                if elapsed >= ScaleScene.fallTime && !landed[index] {
                    landed[index] = true
                    dipSpeed -= ScaleScene.kick(drop)
                    let kilos = drop.plate.map { Float($0.unit == .lb ? $0.size * 0.4536 : $0.size) }
                    shake = max(shake, 0.3 * (kilos.map { $0 / 25 + 0.3 } ?? 1.4))
                    read += weight(drop)
                    show(read)
                    onLanding()
                }
                let fall = min(1, elapsed / ScaleScene.fallTime), tilt = ScaleScene.tilt(at: elapsed)
                entity.position = SIMD3(drop.offset.x, dip + ScaleScene.height(above: drop.restY, at: elapsed), drop.offset.y)
                entity.orientation = simd_quatf(angle: drop.tilt.x * tilt, axis: [1, 0, 0])
                    * simd_quatf(angle: drop.turn + drop.spin * fall, axis: [0, 1, 0])
                    * simd_quatf(angle: drop.tilt.y * tilt, axis: [0, 0, 1])
            }
            // The kick: the camera jumps at random by up to 5 % of the view, dying away fast.
            shake *= exp(-dt * 10)
            let reach = shake * 0.05 * ScaleScene.viewHeight
            let jolt: SIMD3<Float> = right * Float.random(in: -0.5...0.5) + up * Float.random(in: -0.5...0.5)
            camera.position = eye + jolt * reach
            if landed.allSatisfy({ $0 }) && (instantly || t > (drops.last?.at ?? 0) + ScaleScene.fallTime + ScaleScene.dragDelay) { break }
            try? await Task.sleep(for: .milliseconds(8))
        }
        if !Task.isCancelled { startDrag() }
    }

    private func weight(_ drop: ScaleScene.Drop) -> Double { drop.plate?.size ?? barWeight }

    // MARK: - The drag at the end (startDonePhysics, stepDonePhysics, bindDrag)

    /// The scale becomes solid and everything on it a body; there's no floor, so whatever is pulled off falls away.
    private func startDrag() {
        guard physics == nil, let scene = world.scene else { return }
        platform.position.y = 0
        camera.position = eye
        let physics = FlowPhysicsWorld(parent: world)
        for solid in ScaleScene.solids { physics.solid("ground", size: solid.size, at: solid.centre) }
        let kilos = { (size: Double, unit: WeightUnit) in Float(unit == .lb ? size * 0.4536 : size) }
        bodies = zip(drops, dropEntities).map { (drop: ScaleScene.Drop, entity: Entity) -> FlowBody? in
            guard entity.isEnabled else { return nil }
            // Exactly at rest and flat first, like the prototype's (it lifts each plate onto the platform): the last
            // hop and the platform's bounce left the bottom plate a few millimetres inside the now solid scale, and
            // pushing it out threw the whole stack into the air.
            entity.position = SIMD3(drop.offset.x, drop.restY, drop.offset.y)
            entity.orientation = simd_quatf(angle: drop.turn + drop.spin, axis: [0, 1, 0])
            physics.root.addChild(entity, preservingWorldTransform: true)
            if let plate = drop.plate {
                let radius = Float(plate.diameter) / 2, thickness = Float(plate.thickness)
                return physics.add(entity, shape: FlowPhysicsWorld.cylinderShape(top: radius, bottom: radius, height: thickness, sides: 20),
                                   mass: kilos(plate.size, plate.unit), radius: radius)
            }
            // The bar: its shaft, collars and sleeves along x. Pulled off-centre it turns like a rod (m L² / 12 is
            // a disc's m r² / 4 with r = L / √3).
            let pieces = ScaleScene.barPieces.map { piece in
                FlowPhysicsWorld.cylinderShape(top: piece.radius, bottom: piece.radius, height: piece.length, sides: 12)
                    .offsetBy(rotation: simd_quatf(angle: -.pi / 2, axis: [0, 0, 1]), translation: [piece.x, 0, 0])
            }
            return physics.add(entity, shapes: pieces, mass: kilos(barWeight, unit), radius: 2.26 / Float(3).squareRoot())
        }
        update = scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in self?.frame(Float(event.deltaTime)) }
        self.physics = physics
        draggable = true
    }

    private func frame(_ delta: Float) {
        guard let physics else { return }
        physics.step(min(0.05, max(0, delta)))
        var things: [(position: SIMD3<Float>, weight: Double, held: Bool)] = []
        for (index, body) in bodies.enumerated() {
            guard let body else { continue }
            let position = body.entity.position(relativeTo: nil), held = physics.grab?.body === body
            // Long gone below the screen: no longer simulated.
            if position.y < -12 && !held {
                body.entity.components.remove(PhysicsBodyComponent.self)
                body.entity.components.remove(PhysicsMotionComponent.self)
                body.entity.isEnabled = false
                physics.bodies.removeAll { $0 === body }
                bodies[index] = nil
                continue
            }
            things.append((position, weight(drops[index]), held))
        }
        // Once something's been grabbed, the screen shows what's still on the platform.
        guard touched else { return }
        let on = ScaleScene.reading(things)
        if on != reading {
            reading = on
            show(on)
        }
    }

    /// A finger down at `point` (the screen's points): takes hold of the nearest thing under it. True if it did.
    func grab(at point: CGPoint) -> Bool {
        guard let physics, draggable else { return false }
        let r = ray(point)
        var best: (body: FlowBody, distance: Float)?
        for (index, body) in bodies.enumerated() {
            guard let body, let d = hit(r, body.entity, drops[index]), d < (best?.distance ?? .infinity) else { continue }
            best = (body, d)
        }
        guard let best else { return false }
        let p = r.origin + r.direction * best.distance
        // Pulled about on the plane facing the camera through the grabbed point.
        let forward = simd_normalize(ScaleScene.cameraTarget - eye)
        grabPlane = (forward, simd_dot(forward, p))
        physics.grab = FlowGrab(body: best.body, local: best.body.entity.convert(position: p, from: nil), to: p)
        touched = true
        return true
    }

    func drag(to point: CGPoint) {
        guard let plane = grabPlane, physics?.grab != nil else { return }
        let r = ray(point)
        let denominator = simd_dot(plane.normal, r.direction)
        guard abs(denominator) > 1e-5 else { return }
        physics?.grab?.to = r.origin + r.direction * ((plane.constant - simd_dot(plane.normal, r.origin)) / denominator)
    }

    func release() {
        physics?.grab = nil
        grabPlane = nil
    }

    /// Where a drop is on the screen (for the CI's scripted drag).
    func screenPoint(ofDrop index: Int) -> CGPoint? {
        guard dropEntities.indices.contains(index) else { return nil }
        let size = viewSize, p = dropEntities[index].position(relativeTo: nil)
        let q = camera.orientation(relativeTo: nil).inverse.act(p - camera.position(relativeTo: nil))
        guard q.z < 0 else { return nil }
        let tanHalf = tan(camera.camera.fieldOfViewInDegrees * .pi / 360), aspect = Float(size.width / max(1, size.height))
        let nx = q.x / (-q.z * tanHalf * aspect), ny = q.y / (-q.z * tanHalf)
        return CGPoint(x: CGFloat(nx + 1) / 2 * size.width, y: CGFloat(1 - ny) / 2 * size.height)
    }

    private var viewSize: CGSize { view?.bounds.size ?? CGSize(width: 393, height: 852) }

    /// The ray from the camera through `point`.
    private func ray(_ point: CGPoint) -> FlowRay {
        let size = viewSize
        let tanHalf = tan(camera.camera.fieldOfViewInDegrees * .pi / 360), aspect = Float(size.width / max(1, size.height))
        let nx = Float(point.x / max(1, size.width)) * 2 - 1, ny = 1 - Float(point.y / max(1, size.height)) * 2
        let direction = camera.orientation(relativeTo: nil).act([nx * tanHalf * aspect, ny * tanHalf, -1])
        return FlowRay(origin: camera.position(relativeTo: nil), direction: simd_normalize(direction))
    }

    /// How far along the ray it first touches a drop: a plate's disc or the bar's rod, a little fat for a finger.
    private func hit(_ r: FlowRay, _ entity: Entity, _ drop: ScaleScene.Drop) -> Float? {
        let inverse = entity.transformMatrix(relativeTo: nil).inverse
        let o4 = inverse * SIMD4(r.origin, 1), d4 = inverse * SIMD4(r.direction, 0)
        if let plate = drop.plate {
            return Self.cylinderHit(SIMD3(o4.x, o4.y, o4.z), SIMD3(d4.x, d4.y, d4.z), radius: Float(plate.diameter) / 2 * 1.1,
                                    half: max(Float(plate.thickness) / 2, 0.03))
        }
        // The bar lies along x: with x and y swapped it's upright too.
        return Self.cylinderHit(SIMD3(o4.y, o4.x, o4.z), SIMD3(d4.y, d4.x, d4.z), radius: 0.06, half: 1.13)
    }

    /// A ray against an upright cylinder round the origin: how far along it the first touch is.
    static func cylinderHit(_ o: SIMD3<Float>, _ d: SIMD3<Float>, radius: Float, half: Float) -> Float? {
        var best = Float.infinity
        if abs(d.y) > 1e-6 {
            for y in [-half, half] {
                let t = (y - o.y) / d.y, x = o.x + d.x * t, z = o.z + d.z * t
                if t > 0 && x * x + z * z <= radius * radius { best = min(best, t) }
            }
        }
        let a = d.x * d.x + d.z * d.z
        if a > 1e-8 {
            let b = 2 * (o.x * d.x + o.z * d.z), c = o.x * o.x + o.z * o.z - radius * radius, disc = b * b - 4 * a * c
            if disc >= 0 {
                for t in [(-b - disc.squareRoot()) / (2 * a), (-b + disc.squareRoot()) / (2 * a)] where t > 0 && abs(o.y + d.y * t) <= half {
                    best = min(best, t)
                }
            }
        }
        return best.isFinite ? best : nil
    }

    /// The scale's screen: the reading in cream on dark brown, like the prototype's drawReadout.
    private func show(_ value: Double) {
        guard let screen, let texture = readouts[value] ?? Self.texture(value, unit: unit) else { return }
        var material = UnlitMaterial(applyPostProcessToneMap: false)
        material.color = .init(tint: .white, texture: .init(texture))
        screen.model?.materials = [material]
    }

    private static func texture(_ value: Double, unit: WeightUnit) -> TextureResource? {
        guard let image = readout(value, unit: unit).cgImage else { return nil }
        return try? TextureResource(image: image, options: .init(semantic: .color))
    }

    private static func readout(_ value: Double, unit: WeightUnit) -> UIImage {
        let size = CGSize(width: 512, height: 224)
        // Box dark, like everything dark in the prototype's two-tone scale (no third colour).
        let dark = FlowLook.dark.uiColor, cream = FlowLook.light.uiColor
        let format = UIGraphicsImageRendererFormat()
        format.preferredRange = .standard        // sRGB like the texture reads it, not the phone's Display P3
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            dark.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let number = NSAttributedString(string: WeightUnit.trimmed(value), attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 120, weight: .regular), .foregroundColor: cream])
            let label = NSAttributedString(string: unit.rawValue, attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 54, weight: .bold), .foregroundColor: cream])
            let n = number.size(), l = label.size()
            number.draw(at: CGPoint(x: size.width - 130 - n.width, y: (size.height - n.height) / 2))
            label.draw(at: CGPoint(x: size.width - 24 - l.width, y: size.height / 2 + 30 - l.height / 2 - 10))
        }
    }
}

/// The small brass bell (SPEC 2.5): three strikes, a few inharmonic partials with long staggered decays, like the
/// prototype's ringBell. It follows the silent switch, and each strike is felt too.
@MainActor
enum Bell {

    static func ring() {
        let strikes: [Double] = [0, 0.32, 0.64]
        let haptic = UIImpactFeedbackGenerator(style: .rigid)
        haptic.prepare()
        Task { @MainActor in
            // Worked out off the main thread (a few hundred thousand samples), then played with the strikes felt.
            let samples = await Task.detached(priority: .userInitiated, operation: { sound(strikes: strikes) }).value
            Sounds.play(samples)
            var last = 0.0
            for delay in strikes {
                try? await Task.sleep(for: .seconds(delay - last))
                last = delay
                haptic.impactOccurred(intensity: 1)
            }
        }
    }

    nonisolated private static func sound(strikes: [Double]) -> [Float] {
        let rate = 44_100.0, length = 3.4
        var samples = [Float](repeating: 0, count: Int(rate * length))
        let partials: [(ratio: Double, level: Double, decay: Double)] = [(1, 1, 2.6), (2.76, 0.45, 1.6), (5.4, 0.22, 0.9), (8.9, 0.1, 0.5)]
        for frame in samples.indices {
            let t = Double(frame) / rate
            var value = 0.0
            for (k, start) in strikes.enumerated() where t >= start {
                let since = t - start
                for partial in partials where since < partial.decay {
                    let peak = partial.level * (1 - Double(k) * 0.2)
                    // A fast exponential rise over 8 ms, then an exponential fall to silence over its decay.
                    let envelope = since < 0.008
                        ? 0.0001 * pow(peak / 0.0001, since / 0.008)
                        : peak * pow(0.0001 / peak, (since - 0.008) / (partial.decay - 0.008))
                    value += sin(2 * .pi * 880 * partial.ratio * since) * envelope
                }
            }
            samples[frame] = Float(value * 0.22)
        }
        return samples
    }
}

/// The app's few sounds, made like the prototype's Web Audio ones and played through one engine with a handful of
/// voices so they can overlap. They follow the silent switch.
@MainActor
enum Sounds {
    private static let engine = AVAudioEngine()
    private static var voices: [AVAudioPlayerNode] = []
    private static var nextVoice = 0
    /// The audio session is set up once (the Flow's dials click many times a second).
    private static var sessionReady = false
    static let rate = 44_100.0

    /// A plate seating on the sleeve (prototype clank): three short triangle tones, louder for heavier plates.
    static func clank(_ weight: Float) {
        let length = 0.12, level = 0.05 + 0.1 * min(1, Double(weight))
        var samples = [Float](repeating: 0, count: Int(rate * length))
        for (frequency, decay) in [(1650.0, 0.09), (2430, 0.06), (3900, 0.035)] {
            let f = frequency * Double.random(in: 0.92...1.04)
            for frame in samples.indices {
                let t = Double(frame) / rate
                guard t < decay else { break }
                let envelope = t < 0.003 ? 0.0001 * pow(1 / 0.0001, t / 0.003) : pow(0.0001, (t - 0.003) / (decay - 0.003))
                let phase = (t * f).truncatingRemainder(dividingBy: 1)
                let triangle = 4 * abs(phase - 0.5) - 1
                samples[frame] += Float(triangle * envelope * level)
            }
        }
        play(samples)
    }

    static func play(_ samples: [Float]) {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = buffer.frameCapacity
        for (index, sample) in samples.enumerated() { channel[index] = sample }
        do {
            if !sessionReady {
                try AVAudioSession.sharedInstance().setCategory(.ambient)      // quiet when the phone is on silent
                try AVAudioSession.sharedInstance().setActive(true)
                sessionReady = true
            }
            if voices.isEmpty {
                for _ in 0..<8 {
                    let voice = AVAudioPlayerNode()
                    engine.attach(voice)
                    engine.connect(voice, to: engine.mainMixerNode, format: format)
                    voices.append(voice)
                }
            }
            if !engine.isRunning { try engine.start() }
            let voice = voices[nextVoice]
            nextVoice = (nextVoice + 1) % voices.count
            voice.stop()
            voice.scheduleBuffer(buffer, at: nil)
            voice.play()
        } catch {}
    }
}
