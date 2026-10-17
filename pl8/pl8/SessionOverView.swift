import AVFoundation
import RealityKit
import SwiftUI
import UIKit
import PlateKit

/// Session over (SPEC 2.3 step 7), like the prototype's 'done' scene (AnimLayer buildDone and stepDone): the
/// bell rings three times, then the heaviest set's plates fall one by one onto a scale, heaviest first, and the
/// bar lands across them. The scale's screen counts up as each one lands; then "You lifted a lion." appears word
/// by word. Tap to go back.
struct SessionOverView: View {
    let perSide: [Double]
    let unit: WeightUnit
    let barWeight: Double
    var onDone: () -> Void

    @State private var stage = ScaleStage()
    @State private var words = 0
    @State private var landings = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var total: Double { ScaleScene.total(perSide: perSide, barWeight: barWeight) }
    private var message: [String] { Animals.message(for: total, unit: unit).split(separator: " ").map(String.init) }
    private var cream: Color { Color(Diorama.uiColor(Look.boxLight)) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            RealityView { content in
                for entity in stage.build(perSide: perSide, unit: unit, barWeight: barWeight) { content.add(entity) }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Heaviest set")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(2.2)
                    .textCase(.uppercase)
                    .foregroundStyle(cream)
                    .padding(.top, 24)
                Spacer()
                // Each word simply appears, one after another (the prototype's dMsgIn "words", 260 ms apart).
                HStack(spacing: 0) {
                    ForEach(Array(message.enumerated()), id: \.offset) { index, word in
                        Text(word + (index < message.count - 1 ? " " : ""))
                            .opacity(index < words ? 1 : 0)
                    }
                }
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(cream)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 140)
                .accessibilityElement(children: .combine)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDone() }
        .sensoryFeedback(.impact(weight: .medium), trigger: landings)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .task {
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

/// The scale's 3D scene: built once, then played frame by frame.
@MainActor
final class ScaleStage {
    private var drops: [ScaleScene.Drop] = []
    private var dropEntities: [Entity] = []
    private let platform = Entity()
    private var screen: ModelEntity?
    private var unit: WeightUnit = .kg
    private var barWeight: Double = 0
    private var built = false
    var onLanding: () -> Void = {}

    func build(perSide: [Double], unit: WeightUnit, barWeight: Double) -> [Entity] {
        self.unit = unit
        self.barWeight = barWeight
        let world = Entity()
        let still = RoomLayout.Placement(position: .zero, rotationDegrees: 0)
        // The orange all round, then the scale, lit like the room.
        if let sky = try? ModelEntity(mesh: Diorama.meshResource(LowPolyMesh.box(size: [200, 200, 200]).insideOut()),
                                      materials: [Diorama.flat(Diorama.background)]) {
            world.addChild(sky)
        }
        let parts = ScaleScene.parts()
        for child in Diorama.entities(for: SceneBake.bake(parts.base, placement: still, wall: nil, content: .withoutShadows)) {
            world.addChild(child)
        }
        for child in Diorama.entities(for: SceneBake.bake(parts.platform, placement: still, wall: nil, content: .withoutShadows)) {
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
        dropEntities = drops.map { drop in
            let parts = drop.plate.map { SessionScene.parts(.init(plate: $0, centre: .zero, axis: .y, turn: drop.turn)) }
                ?? PropModels.barbellParts()
            let entity = Entity()
            for child in Diorama.entities(for: SceneBake.bake(parts, placement: still, wall: nil, content: .withoutShadows)) {
                entity.addChild(child)
            }
            entity.isEnabled = false
            world.addChild(entity)
            return entity
        }

        // The prototype's camera: 45° round, 32° up, 3.5 m of the scene in view (a long lens from 20 m).
        let distance: Float = 20
        let flat = distance * cos(ScaleScene.cameraElevation)
        let eye = ScaleScene.cameraTarget + SIMD3(flat * sin(ScaleScene.cameraYaw), distance * sin(ScaleScene.cameraElevation),
                                                  flat * cos(ScaleScene.cameraYaw))
        world.transform = Diorama.worldTransform(target: ScaleScene.cameraTarget, position: eye)
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 2 * atan(ScaleScene.viewHeight / 2 / distance) * 180 / .pi
        built = true
        return [world, camera]
    }

    /// Drops everything in turn; the platform dips on a spring at each landing. Returns once the last one lands.
    func play(instantly: Bool) async {
        while !built && !Task.isCancelled { try? await Task.sleep(for: .milliseconds(16)) }
        var dip: Float = 0, dipSpeed: Float = 0, read: Double = 0
        var landed = Array(repeating: false, count: drops.count)
        let start = ContinuousClock.now
        var last = start
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
                    read += drop.plate?.size ?? barWeight
                    show(read)
                    onLanding()
                }
                let fall = min(1, elapsed / ScaleScene.fallTime), tilt = ScaleScene.tilt(at: elapsed)
                entity.position = SIMD3(drop.offset.x, dip + ScaleScene.height(above: drop.restY, at: elapsed), drop.offset.y)
                entity.orientation = simd_quatf(angle: drop.tilt.x * tilt, axis: [1, 0, 0])
                    * simd_quatf(angle: drop.turn + drop.spin * fall, axis: [0, 1, 0])
                    * simd_quatf(angle: drop.tilt.y * tilt, axis: [0, 0, 1])
            }
            if landed.allSatisfy({ $0 }) && t > (drops.last?.at ?? 0) + ScaleScene.fallTime + 1 { break }
            if landed.allSatisfy({ $0 }) && instantly { break }
            try? await Task.sleep(for: .milliseconds(8))
        }
    }

    /// The scale's screen: the reading in cream on dark brown, like the prototype's drawReadout.
    private func show(_ value: Double) {
        guard let screen, let image = Self.readout(value, unit: unit).cgImage,
              let texture = try? TextureResource(image: image, options: .init(semantic: .color)) else { return }
        var material = UnlitMaterial(applyPostProcessToneMap: false)
        material.color = .init(tint: .white, texture: .init(texture))
        screen.model?.materials = [material]
    }

    private static func readout(_ value: Double, unit: WeightUnit) -> UIImage {
        let size = CGSize(width: 512, height: 224)
        let dark = Diorama.uiColor(RGB(hex: "#2B1E16")), cream = Diorama.uiColor(Look.boxLight)
        return UIGraphicsImageRenderer(size: size).image { _ in
            dark.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let number = NSAttributedString(string: WeightUnit.trimmed(value), attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 120, weight: .bold), .foregroundColor: cream])
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
    private static let engine = AVAudioEngine()
    private static let player = AVAudioPlayerNode()
    private static var ready = false

    static func ring() {
        let strikes: [Double] = [0, 0.32, 0.64]
        let haptic = UIImpactFeedbackGenerator(style: .rigid)
        haptic.prepare()
        Task { @MainActor in
            // Worked out off the main thread (a few hundred thousand samples), then played with the strikes felt.
            let samples = await Task.detached(priority: .userInitiated, operation: { sound(strikes: strikes) }).value
            if let buffer = buffer(samples) { play(buffer) }
            var last = 0.0
            for delay in strikes {
                try? await Task.sleep(for: .seconds(delay - last))
                last = delay
                haptic.impactOccurred(intensity: 1)
            }
        }
    }

    private static func play(_ buffer: AVAudioPCMBuffer) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient)          // quiet when the phone is on silent
            try AVAudioSession.sharedInstance().setActive(true)
            if !ready {
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
                ready = true
            }
            if !engine.isRunning { try engine.start() }
            player.scheduleBuffer(buffer, at: nil)
            player.play()
        } catch {}
    }

    private static let rate = 44_100.0

    private static func buffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = buffer.frameCapacity
        for (index, sample) in samples.enumerated() { channel[index] = sample }
        return buffer
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
