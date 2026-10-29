import RealityKit
import SwiftUI
import PlateKit

/// A dial (flDrum): a drum of labels on the front of a cylinder that spins with the finger, flicks and settles on
/// a detent with a click. `position` is a float index; the label on the reading line is `index`.
@MainActor
final class FlowDial {
    let root: Entity
    let frame: Entity?
    let labels: [String]
    let radius: Float, step: Float, wrap: Bool
    let labelWidth: Float, fontSize: Int
    var position: Float = 0
    var velocity: Float = 0
    private(set) var index = 0
    var locked = false
    var dragging = false
    var opacity: Float = 1
    var onTap: (() -> Void)?
    var onDetent: (() -> Void)?
    private var pool: [(entity: ModelEntity, shown: Int?)] = []
    private let span: Int
    private weak var flow: Flow?

    init(flow: Flow, labels: [String], radius: Float, step: Float, width: Float, labelWidth: Float, size: Int, wrap: Bool = true) {
        self.flow = flow
        self.labels = labels
        self.radius = radius
        self.step = step
        self.wrap = wrap
        self.labelWidth = labelWidth
        self.fontSize = size
        root = flow.build(FlowProps.drum(radius: radius, step: step, width: width))
        frame = root.children.first { $0.name == "frame" }
        span = Int((1.45 / step).rounded(.up)) + 1
        let mesh = (try? Flow.meshResource(Geo.plane(labelWidth, step * radius * 0.95), palette: false)) ?? .generatePlane(width: labelWidth, height: step * radius * 0.95)
        for _ in -span...span {
            let label = ModelEntity(mesh: mesh, materials: [UnlitMaterial(applyPostProcessToneMap: false)])
            root.addChild(label)
            pool.append((label, nil))
        }
        layout()
    }

    func set(_ i: Int) {
        position = Float(i)
        index = normalised(i)
    }

    private func normalised(_ i: Int) -> Int {
        let n = labels.count
        return wrap ? ((i % n) + n) % n : max(0, min(n - 1, i))
    }

    func layout() {
        let base = Int(position.rounded(.down))
        for j in pool.indices {
            let li = base + j - span, th = (Float(li) - position) * step
            let inRange = wrap || (li >= 0 && li < labels.count)
            let entity = pool[j].entity
            entity.isEnabled = inRange && abs(th) < 1.45
            guard entity.isEnabled else { continue }
            let front = max(0, 1 - abs(th) / (step * 0.75))          // 1 on the reading line, 0 a notch away
            entity.position = [0, -radius * sin(th), radius * cos(th) + 0.004 + front * 0.03]
            entity.orientation = simd_quatf(angle: th, axis: [1, 0, 0])
            entity.scale = SIMD3(repeating: 1 + 0.18 * front)
            let alpha = opacity * (0.28 + 0.72 * front) * max(0, cos(th * 1.05))
            let shown = normalised(li)
            guard let flow, let texture = flow.texture(.text(labels[shown], width: 256, height: 140, size: fontSize, colour: FlowLook.light, dy: 6)) else { continue }
            var material = UnlitMaterial(applyPostProcessToneMap: false)
            material.color = .init(tint: .white, texture: .init(texture))
            material.blending = .transparent(opacity: .init(floatLiteral: alpha))
            entity.model?.materials = [material]
            pool[j].shown = shown
        }
        frame?.isEnabled = opacity > 0.5
    }

    func tick(_ dt: Float) {
        if !dragging {
            position += velocity * dt
            velocity *= exp(-dt * 4.5)
            if !wrap {
                if position < 0 { position += (0 - position) * 0.3; velocity = 0 }
                if position > Float(labels.count - 1) { position += (Float(labels.count - 1) - position) * 0.3; velocity = 0 }
            }
            if abs(velocity) < 2 { position += (position.rounded() - position) * (1 - exp(-dt * 12)) }
        }
        let i = normalised(Int(position.rounded()))
        if i != index { index = i; onDetent?() }
        layout()
    }

    /// Dragging a dial (flDrumDrag): points to turns, with a flick.
    func drag(from start: CGPoint, pointsPerItem: Float, flow: Flow) -> FlowDrag {
        var y0 = start.y, t0 = flow.t, dragged = false
        return FlowDrag(move: { [weak self, weak flow] p in
            guard let self, let flow else { return }
            let dy = Float(p.y - y0) / Float(flow.layoutScale), now = flow.t
            if abs(dy) > 2 { dragged = true }
            let d = -dy / pointsPerItem
            self.position += d
            self.velocity = d / Float(max(0.008, now - t0))
            y0 = p.y; t0 = now
            self.dragging = true
        }, up: { [weak self, weak flow] _, _ in
            guard let self, let flow else { return }
            self.dragging = false
            if flow.t - t0 > 0.09 { self.velocity = 0 }
            if !dragged { self.onTap?() }
        })
    }
}

extension Flow {
    // MARK: - 1 · "What's the name of your Gym?" (flName)

    func stepName() {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789").map(String.init)
        setCamera([0, 0.5, 10.5], [0, -0.4, 0])
        var dials: [FlowDial] = []
        var current = 0
        let dim = {
            for (i, dial) in dials.enumerated() {
                dial.opacity = i == current || dial.locked ? 1 : 0.35
                dial.layout()
            }
        }
        say("What’s the name of your Gym?") { [weak self] in
            guard let self else { return }
            let name = Array(self.data.name)
            for (i, x) in [Float(-0.62), 0.62].enumerated() {
                let dial = FlowDial(flow: self, labels: chars, radius: 0.95, step: 0.38, width: 0.95, labelWidth: 0.7, size: 120)
                dial.root.position = [-5, -0.45, 0]
                dial.onDetent = { [weak self] in self?.click(1) }
                self.add(dial.root)
                if self.editOne, name.indices.contains(i) { dial.set(max(0, chars.firstIndex(of: String(name[i])) ?? 0)) }
                let x0 = -5 - Float(i) * 0.6
                self.later(Double(i) * 0.14) { [weak self] in
                    self?.click(0.6)
                    self?.anim(0.75) { u in
                        let e = Float(Ease.outCubic(u))
                        dial.root.position.x = x0 + (x - x0) * e
                        dial.root.orientation = simd_quatf(angle: -0.4 * (1 - e) * sin(Float(u) * 6), axis: [1, 0, 0])
                    }
                }
                dials.append(dial)
            }
            dim()
        }
        let lockOne = { [weak self] in
            guard let self, dials.indices.contains(current) else { return }
            let dial = dials[current]
            dial.locked = true
            self.buzz(.light)
            self.click(0.7)
            let y0 = dial.root.position.y
            self.anim(0.25) { u in dial.root.position.y = y0 - 0.08 * sin(Float(u) * .pi) }
            current += 1
            dim()
            guard current >= 2 else { return }
            self.data.name = chars[dials[0].index] + chars[dials[1].index]
            // Both picked: a reflection runs over the dials, then down to the next question.
            self.later(0.25) { [weak self] in
                self?.shine(dials.map(\.root), duration: 0.8)
                for dial in dials { self?.sparkles(at: dial.root.position + [0, 0, 1], count: 4, spread: 1.2) }
            }
            self.later(1.3) { [weak self] in if self?.step == .name { self?.panTo(.unit) } }
        }
        hit = { [weak self] point in
            guard let self, dials.indices.contains(current) else { return nil }
            let dial = dials[current]
            guard self.touches(point, dial.root) else { return nil }
            dial.onTap = { if !dial.locked { lockOne() } }
            return dial.drag(from: point, pointsPerItem: 46, flow: self)
        }
        tick = { dt, _ in for dial in dials { dial.tick(dt) } }
    }
}
