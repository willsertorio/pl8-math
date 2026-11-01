import RealityKit
import SwiftUI
import PlateKit

extension Flow {
    // MARK: - 4 · "What bar do you use?" (flBarQ)

    func stepBar() {
        let unit = data.unit, list = Bar.weights(unit), n = list.count, spacing: Float = 1.02
        setCamera([0, 1.05, 7.0], [0, -0.5, 0])
        var bars: [(wrap: Entity, tilt: Entity, bar: Entity)] = []
        let preset = editOne ? list.firstIndex(of: data.bar) : nil
        var position = Float(preset ?? 1), velocity: Float = 0, index = Int(position), dragging = false, done = false, ready = false
        var arrived: Double?
        var labelsAt: Double?

        say("What bar do you use?") { [weak self] in
            guard let self else { return }
            for (i, _) in list.enumerated() {
                let wrap = Entity()
                let tilt = Entity()
                let bar = self.build(FlowProps.standingBar(index: i))
                tilt.addChild(bar)
                tilt.orientation = simd_quatf(angle: -0.24, axis: [0, 0, 1])
                wrap.addChild(tilt)
                let shadow = self.softShadow(0.42)
                shadow.scale = [1, 0.55, 1]
                shadow.position.y = -1.22
                wrap.addChild(shadow)
                wrap.position = [-6 - Float(i) * 1.2, -0.3, 0]
                self.add(wrap)
                bars.append((wrap, tilt, bar))
                self.later(Double(i) * 0.11) { [weak self] in self?.click(0.6) }
            }
            // They slide in from the left, one after another, each braking into its place.
            arrived = self.t
            self.later(0.95) { [weak self] in ready = true; labelsAt = self?.t }
        }

        let pick = { [weak self] in
            guard let self, !done, bars.indices.contains(index) else { return }
            done = true
            self.data.bar = list[index]
            let picked = bars[index]
            self.shine([picked.wrap], duration: 0.9)
            // A twinkle: a quick wiggle and sparkles up the bar.
            self.anim(0.8) { u in
                picked.tilt.orientation = simd_quatf(angle: -0.24 + 0.12 * sin(Float(u) * .pi * 4) * (1 - Float(u)), axis: [0, 0, 1])
            }
            for k in 0..<4 {
                self.later(Double(k) * 0.09) { [weak self] in
                    self?.sparkles(at: [picked.wrap.position.x, -1 + Float(k) * 0.6, 0.2], count: 2, spread: 0.5)
                }
            }
            self.later(1.3) { [weak self] in
                guard let self, self.step == .bar else { return }
                self.checkSound()
                self.panTo(self.mode == .gym ? .menu : .prs)
            }
        }

        tick = { [weak self] dt, t in
            guard let self, !bars.isEmpty else { return }
            if !dragging {
                position += velocity * dt
                velocity *= exp(-dt * 5)
                position = max(-0.3, min(Float(n) - 0.7, position))
                if abs(velocity) < 1.5 { position += (max(0, min(Float(n - 1), position.rounded())) - position) * (1 - exp(-dt * 10)) }
            }
            let i0 = max(0, min(n - 1, Int(position.rounded())))
            if i0 != index { index = i0; self.click(0.8); self.buzz(.selection) }
            let progress = arrived.map { Float(min(1, (t - $0) / 0.9)) } ?? 0
            var labels: [FlowLabel] = []
            for (i, item) in bars.enumerated() {
                let k = min(1, max(0, progress * 1.35 - Float(i) * 0.18)), e = 1 - pow(1 - k, 3)
                item.wrap.position.x = (Float(i) - position) * spacing + (1 - e) * (-6 - Float(i) * 0.8)
                item.bar.orientation = simd_quatf(angle: Float(t) * 0.6 + Float(i), axis: [0, 1, 0])
                if !(done && i == index) { item.tilt.orientation = simd_quatf(angle: -0.24 + (1 - e) * 0.5, axis: [0, 0, 1]) }
                if let point = self.project([item.wrap.position.x, -1.85, 0]) {
                    let opacity = labelsAt.map { min(1, max(0, (t - $0) / 0.3)) } ?? 0
                    labels.append(FlowLabel(id: i, text: "\(WeightUnit.trimmed(list[i])) \(unit.rawValue)", point: point, opacity: opacity))
                }
            }
            self.labels = labels
        }

        let pointsPerItem = 390 * spacing / (7.0 * 0.2914)
        hit = { [weak self] point in
            guard let self, ready, !done else { return nil }
            var x0 = point.x, t0 = self.t
            dragging = true
            return FlowDrag(move: { [weak self] p in
                guard let self else { return }
                let d = -Float((p.x - x0) / self.layoutScale) / pointsPerItem, now = self.t
                position += d
                velocity = d / Float(max(0.008, now - t0))
                x0 = p.x; t0 = now
            }, up: { [weak self] p, tap in
                guard let self else { return }
                dragging = false
                if self.t - t0 > 0.09 { velocity = 0 }
                let dx = p.x - point.x, dy = p.y - point.y
                let swipeUp = dy < -55 && abs(dy) > abs(dx) * 1.5
                if !tap && swipeUp && (self.mode == .menu || self.mode == .gym) {
                    self.checkSound()
                    self.mode = .menu
                    self.panTo(.menu)
                    return
                }
                if tap || swipeUp {
                    velocity = 0
                    position = Float(index)
                    self.buzz(.light)
                    self.checkSound()
                    pick()
                }
            })
        }
    }
}
