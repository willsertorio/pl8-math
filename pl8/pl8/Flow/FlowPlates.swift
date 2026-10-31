import RealityKit
import SwiftUI
import PlateKit

/// The plates checklist's drawn parts (flPlates): YES / NO boxes, the plates' weights, the pen's trail. In the
/// prototype's pixels (390 × 844); the overlay scales them.
@MainActor @Observable
final class PlatesUI {
    struct Row {
        let label: String
        let y: CGFloat
        let index: Int
        var shownAt: Double
        var state: Bool?
    }

    struct Box {
        let row: Int
        let yes: Bool
        let centre: CGPoint
        let size: CGFloat
        let jitter: [CGFloat]
        let tickPoints: [CGPoint]
        let bornAt: Double
        var tick: Double = 0
        var scale: Double = 0
    }

    var rows: [Row] = []
    var boxes: [Box] = []
    var headersAt: Double?
    /// Where the rows start, in the prototype's points (the headers sit 16 above).
    var top: CGFloat = 272
    var fontSize: CGFloat = 20
    var trail: [CGPoint] = []
    var trailOpacity: Double = 1
    var now: Double = 0
}

extension Flow {
    // MARK: - 3 · "What are the plates available?" (flPlates)

    func stepPlates() {
        let unit = data.unit, plates = Plate.catalog(unit), n = plates.count
        setCamera([0, 0, 8.2], [0, 0, 0])
        // v2: the rows start 58 points lower with the question, at 272, and end at 800 (CHANGES-v2 §3).
        let k = 2 * 8.2 * tan(17.5 * Float.pi / 180) / 844, top: CGFloat = 214 + CGFloat(Self.questionDrop), bottom: CGFloat = 800
        let rowH = (bottom - top) / CGFloat(n)
        let wx = { (px: CGFloat) in Float(px - 195) * k }, wy = { (py: CGFloat) in Float(422 - py) * k }
        let box = (min(46, rowH * 0.74)).rounded(), xYes: CGFloat = 262, xNo: CGFloat = 334
        let ui = PlatesUI()
        ui.fontSize = (min(21, rowH * 0.37)).rounded()
        ui.top = top
        platesUI = ui
        var models: [(wrapper: Entity, plate: Entity, ghost: Entity)] = []
        var done = false, ready = false
        let editing = editOne
        var idle: Int?

        // A NO plate turns grey and see-through: its flat grey twin shows instead.
        let paint = { (row: Int) in
            guard models.indices.contains(row) else { return }
            let no = ui.rows[row].state == false
            models[row].plate.isEnabled = !no
            models[row].ghost.isEnabled = no
        }
        let owned = { ui.rows.filter { $0.state == true }.map { plates[$0.index].size } }
        let finish = { [weak self] in
            guard let self, !done, !ui.rows.contains(where: { $0.state == nil }) else { return }
            if editing {
                // Editing from the gym: changes save as you go; once you stop for a moment it goes back.
                self.data.owned = owned()
                self.cancelTimer(idle)
                idle = self.later(1.8) { [weak self] in
                    guard let self, self.step == .plates, !done else { return }
                    done = true
                    self.shine(ui.rows.filter { $0.state == true }.map { models[$0.index].wrapper }, duration: 0.8)
                    self.later(0.9) { [weak self] in if self?.step == .plates { self?.checkSound(); self?.panTo(.bar) } }
                }
                return
            }
            done = true
            self.data.owned = owned()
            let yes = ui.rows.filter { $0.state == true }.map { models[$0.index].wrapper }
            self.later(0.35) { [weak self] in
                self?.shine(yes, duration: 0.8)
                for (i, wrapper) in yes.enumerated() {
                    self?.later(Double(i) * 0.05) { [weak self] in self?.sparkles(at: wrapper.position + [0, 0, 0.4], count: 2, spread: 0.35) }
                }
            }
            self.later(1.25) { [weak self] in if self?.step == .plates { self?.checkSound(); self?.panTo(.bar) } }
        }
        let decide = { [weak self] (b: Int) in
            guard let self else { return }
            let box = ui.boxes[b], row = box.row
            guard ui.rows[row].state != box.yes else { return }
            ui.rows[row].state = box.yes
            self.tickBox(b, on: true)
            if let other = ui.boxes.firstIndex(where: { $0.row == row && $0.yes != box.yes }) { self.tickBox(other, on: false) }
            paint(row)
            self.buzz(.light)
            self.click(box.yes ? 1.2 : 0.7)
            if box.yes { self.shine([models[row].wrapper], duration: 0.4) }
        }

        debugDecide = { b in if ui.boxes.indices.contains(b) { decide(b) } }
        say("What are the plates available?") { [weak self] in
            guard let self else { return }
            ui.headersAt = self.t
            for (i, plate) in plates.enumerated() {
                let y = top + rowH * (CGFloat(i) + 0.5)
                let d = Float(plate.diameter)
                let dia = Float(rowH) * 0.84 * k * (0.62 + 0.38 * min(1, d / 0.45)), scale = dia / d
                let wrapper = Entity()
                let model = self.build(FlowProps.plate(plate))
                model.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                wrapper.addChild(model)
                let ghost = self.build(FlowProps.ghost(plate))
                ghost.orientation = model.orientation
                ghost.isEnabled = false
                wrapper.addChild(ghost)
                wrapper.scale = SIMD3(repeating: scale)
                wrapper.position = [wx(58), wy(y), 0]
                wrapper.isEnabled = false
                self.add(wrapper)
                models.append((wrapper, model, ghost))
                // v2: each row just appears, plate, weight and boxes together, one every 90 ms; a soft click.
                let at = Double(i) * 0.09
                self.later(at) { [weak self] in
                    wrapper.isEnabled = true
                    self?.click(0.5)
                }
                ui.rows.append(PlatesUI.Row(label: "\(WeightUnit.trimmed(plate.size)) \(unit.rawValue)", y: y, index: i,
                                            shownAt: self.t + at, state: nil))
                for (yes, x) in [(true, xYes), (false, xNo)] {
                    let p: CGFloat = 12, c0 = p + box / 2
                    let anchors = [CGPoint(x: c0 - box * 0.3, y: c0 + box * 0.02), CGPoint(x: c0 - box * 0.08, y: c0 + box * 0.26),
                                   CGPoint(x: c0 + box * 0.34, y: c0 - box * 0.3)]
                    var tickPoints: [CGPoint] = []
                    for s in 0..<2 {
                        for k2 in 0...8 {
                            let f = CGFloat(k2) / 8
                            tickPoints.append(CGPoint(x: anchors[s].x + (anchors[s + 1].x - anchors[s].x) * f + .random(in: -0.7...0.7) - p - box / 2,
                                                      y: anchors[s].y + (anchors[s + 1].y - anchors[s].y) * f + .random(in: -0.7...0.7) - p - box / 2))
                        }
                    }
                    ui.boxes.append(PlatesUI.Box(row: i, yes: yes, centre: CGPoint(x: x, y: y), size: box,
                                                 jitter: (0..<24).map { _ in .random(in: -1.1...1.1) }, tickPoints: tickPoints,
                                                 bornAt: self.t + Double(i) * 0.09))
                }
            }
            ready = true
            // Editing: what you said before is already ticked.
            if editing {
                let had = self.data.owned
                for i in ui.rows.indices {
                    ui.rows[i].state = had.contains(plates[i].size)
                    paint(i)
                    let target = ui.boxes.firstIndex { $0.row == i && $0.yes == ui.rows[i].state }
                    self.later(0.14 + Double(i) * 0.09) { [weak self] in if let target { self?.tickBox(target, on: true) } }
                }
            }
        }

        // One drawing surface over the whole screen: the pen leaves a trail that fades; every box the line runs
        // through gets ticked.
        let local = { [weak self] (point: CGPoint) -> CGPoint in
            guard let self else { return point }
            let s = self.layoutScale
            return CGPoint(x: (point.x - self.viewSize.width / 2) / s + 195, y: point.y / s)
        }
        let inBox = { (b: PlatesUI.Box, q: CGPoint, pad: CGFloat) in
            abs(q.x - b.centre.x) <= b.size / 2 + pad && abs(q.y - b.centre.y) <= b.size / 2 + pad
        }
        var strokes = 0
        let fadeTrail = { [weak self] in
            let stroke = strokes
            self?.anim(0.38, { u in if strokes == stroke { ui.trailOpacity = 1 - Ease.outCubic(u) } },
                       done: { if strokes == stroke { ui.trail = []; ui.trailOpacity = 1 } })
        }
        hit = { [weak self] point in
            guard let self, !done, ready else { return nil }
            self.cancelTimer(idle)
            let start = local(point)
            strokes += 1
            var last = start, length: CGFloat = 0, hitBox = false, moves = 0
            var amount = [CGFloat](repeating: 0, count: ui.boxes.count)
            ui.trail = [start]
            ui.trailOpacity = 1
            return FlowDrag(move: { [weak self] p in
                guard let self else { return }
                let q = local(p), segment = hypot(q.x - last.x, q.y - last.y)
                guard segment >= 1 else { return }
                length += segment
                ui.trail.append(q)
                let steps = max(1, Int((segment / 3).rounded(.up)))
                for i in 1...steps {
                    let f = CGFloat(i) / CGFloat(steps)
                    let x = CGPoint(x: last.x + (q.x - last.x) * f, y: last.y + (q.y - last.y) * f)
                    for b in ui.boxes.indices where inBox(ui.boxes[b], x, 4) {
                        amount[b] += segment / CGFloat(steps)
                        if amount[b] >= ui.boxes[b].size * 0.22 { hitBox = true; decide(b) }
                    }
                }
                last = q
                moves += 1
                if moves % 6 == 0 { self.click(2.2) }
            }, up: { [weak self] _, _ in
                guard let self else { return }
                if length < 6 {
                    // A tap on a box ticks it.
                    if let b = ui.boxes.firstIndex(where: { inBox($0, start, 8) }) { decide(b) }
                } else if !hitBox, self.panBack, start.y - last.y > 90, abs(last.x - start.x) < (start.y - last.y) / 1.5 {
                    fadeTrail()
                    self.panBackGo()
                    return
                }
                fadeTrail()
                finish()
            })
        }
        tick = { [weak self] _, t in
            guard self != nil else { return }
            ui.now = t
            for (i, model) in models.enumerated() {
                let turn = simd_quatf(angle: .pi / 2, axis: [1, 0, 0]) * simd_quatf(angle: sin(Float(t) * 0.8 + Float(i)) * 0.12, axis: [0, 1, 0])
                model.plate.orientation = turn
                model.ghost.orientation = turn
            }
            for b in ui.boxes.indices {
                let scale: Double = t >= ui.boxes[b].bornAt ? 1 : 0
                if ui.boxes[b].scale != scale { ui.boxes[b].scale = scale }
            }
        }
    }

    /// The tick draws itself in over 0.16 s (or clears).
    private func tickBox(_ b: Int, on: Bool) {
        guard let ui = platesUI, ui.boxes.indices.contains(b) else { return }
        guard on else { ui.boxes[b].tick = 0; return }
        guard ui.boxes[b].tick < 1 else { return }
        anim(0.16) { u in ui.boxes[b].tick = u }
    }
}

/// The checklist's boxes, weights, headers and the pen's trail, drawn in the prototype's pixels.
struct PlatesOverlay: View {
    let flow: Flow

    var body: some View {
        let ui = flow.platesUI
        Canvas { context, size in
            guard let ui else { return }
            let s = flow.layoutScale
            context.translateBy(x: size.width / 2 - 195 * s, y: 0)
            context.scaleBy(x: s, y: s)
            let ink = flow.inkColor
            if ui.headersAt != nil {
                for (text, x) in [("YES", CGFloat(262)), ("NO", 334)] {
                    let label = Text(text).font(FlowType.smallCaps).tracking(FlowType.smallCapsTracking).foregroundColor(ink)
                    context.draw(label, at: CGPoint(x: x, y: ui.top - 16))
                }
            }
            for row in ui.rows where ui.now >= row.shownAt {
                let c = context
                let label = Text(row.label).font(FlowType.label(ui.fontSize)).tracking(FlowType.labelTracking(ui.fontSize)).monospacedDigit()
                    .foregroundColor(ink)
                c.draw(label, at: CGPoint(x: 106, y: row.y), anchor: .leading)
            }
            for box in ui.boxes where box.scale > 0.001 {
                var c = context
                c.translateBy(x: box.centre.x, y: box.centre.y)
                c.scaleBy(x: box.scale, y: box.scale)
                var square = Path()
                let h = box.size / 2
                let corners = [CGPoint(x: -h, y: -h), CGPoint(x: h, y: -h), CGPoint(x: h, y: h), CGPoint(x: -h, y: h)]
                var j = 0
                func jit() -> CGFloat { defer { j += 1 }; return box.jitter[j % box.jitter.count] }
                for i in 0..<4 {
                    let a = corners[i], b = corners[(i + 1) % 4]
                    square.move(to: CGPoint(x: a.x + jit(), y: a.y + jit()))
                    square.addQuadCurve(to: CGPoint(x: b.x + jit(), y: b.y + jit()),
                                        control: CGPoint(x: (a.x + b.x) / 2 + jit(), y: (a.y + b.y) / 2 + jit()))
                }
                c.stroke(square, with: .color(ink), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                let m = Int((box.tick * Double(box.tickPoints.count)).rounded(.up))
                if m > 1 {
                    var tick = Path()
                    tick.addLines(Array(box.tickPoints.prefix(m)))
                    c.stroke(tick, with: .color(ink), style: StrokeStyle(lineWidth: 4.4, lineCap: .round, lineJoin: .round))
                }
            }
            if ui.trail.count > 1 {
                var trail = Path()
                trail.addLines(ui.trail)
                var c = context
                c.opacity = ui.trailOpacity
                c.stroke(trail, with: .color(ink), style: StrokeStyle(lineWidth: 4.2, lineCap: .round, lineJoin: .round))
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Plates checklist")
    }
}
