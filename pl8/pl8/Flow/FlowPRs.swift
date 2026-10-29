import RealityKit
import SwiftUI
import PlateKit

/// The PR dial's switch (flPRDial): KG / LB under the dial.
@MainActor @Observable
final class PRDialUI {
    var unit: WeightUnit = .kg
    var shown = false
    var onSwitch: ((WeightUnit) -> Void)?
}

extension Flow {
    // MARK: - 5 · "Alright. And what are your PRs?" (flPRs)

    func stepPRs() {
        setCamera([0, 0.5, 6.6], [0, 0.02, 0])
        let book = build(FlowProps.notebook(title: "MY PRs", rows: data.prRows))
        book.orientation = Flow.quaternion([-0.28, 0.18, 0.06])
        book.isEnabled = false
        add(book)
        let shadow = add(Entity())
        let blob = softShadow(0.6)
        blob.scale = [1, 0.5, 1]
        shadow.addChild(blob)
        shadow.position = [0, -0.95, 0]
        shadow.isEnabled = false
        let pen = add(build(FlowProps.pencil()))
        pen.position = [0.55, -0.44, 0.34]
        pen.orientation = Flow.quaternion([0.5, 0, -0.95])
        pen.scale = SIMD3(repeating: 0.0001)
        let hinge = book.findEntity(named: "hinge")
        var ready = false, busy = false
        let pose = { (k: Float) in
            hinge?.orientation = simd_quatf(angle: -2.95 * k, axis: [0, 1, 0])
            book.orientation = Flow.quaternion([-0.28 + 0.18 * k, 0.18 * (1 - k), 0.06 * (1 - k)])
            book.scale = SIMD3(repeating: 1 - 0.3 * k)
            book.position.x = 0.37 * k
        }
        say("Alright. And what are your PRs?") { [weak self] in
            guard let self else { return }
            book.isEnabled = true
            shadow.isEnabled = true
            self.popIn(book)
            self.popIn(shadow)
            self.later(0.55) { [weak self] in
                guard let self else { return }
                self.click(0.5)
                self.anim(0.7, { u in pose(Float(Ease.inOutCubic(u))) }, done: { ready = true })
                self.later(0.45) { [weak self] in
                    self?.anim(0.45) { u in pen.scale = SIMD3(repeating: max(0.0001, Float(Ease.outBack(u, 1.4)))) }
                    self?.click(1.4)
                }
            }
        }
        tick = { _, t in
            book.position.y = 0.06 * sin(Float(t) * 1.4)
            pen.position.y = -0.44 + 0.04 * sin(Float(t) * 1.4 + 0.6)
        }
        let leave = { [weak self] in
            // Close, shine, and down to the workout.
            guard let self else { return }
            busy = true
            self.anim(0.6, { u in
                pose(1 - Float(Ease.inOutCubic(u)))
                pen.scale = SIMD3(repeating: max(0.0001, 1 - Float(u)))
            }, done: { [weak self] in
                guard let self else { return }
                self.shine([book], duration: 0.8)
                self.sparkles(at: [0, 0.2, 0.5], count: 7, spread: 1.3)
                self.later(1.0) { [weak self] in self?.checkSound(); self?.panTo(.wod) }
            })
        }
        hit = { [weak self] point in
            guard let self, ready, !busy, self.touches(point, pen) || self.touches(point, book) else { return nil }
            return FlowDrag(move: nil, up: { [weak self] p, tap in
                guard let self, tap, !busy else { return }
                self.buzz(.light)
                self.checkSound()
                if self.touches(p, pen) {
                    busy = true
                    self.prReturn = .wod
                    self.panTo(.prDial)
                    return
                }
                guard self.touches(p, book) else { return }
                self.pickPhoto(.prs, reading: "Reading your PRs…", read: { [weak self] image in
                    await self?.data.readPRs(image) ?? false
                }, then: { [weak self] ok in
                    guard let self, ok else { return }
                    busy = true
                    self.repaint(book, part: "page", with: .notebookPage(self.data.prRows))
                    self.shine([book], duration: 0.6)
                    self.later(0.9) { leave() }
                })
            })
        }
    }

    // MARK: - The PR dial, one lift at a time (flPRDial)

    func stepPRDial(_ i: Int) {
        if i > 0 { clear(); step = .prDial; applyStyle() }
        let records = data.records.filter { LiftNames.defaultPRLifts.contains($0.lift) }
        guard records.indices.contains(i) else { panTo(prReturn ?? .wod); return }
        let record = records[i]
        if data.prUnit == nil { data.prUnit = record.value != nil ? record.unit : data.unit }
        var unit = data.prUnit ?? data.unit
        setCamera([0, 0.2, 9.5], [0, -0.25, 0])
        let ui = PRDialUI()
        ui.unit = unit
        prDialUI = ui
        var dial: FlowDial?
        var values: [Double] = []
        // Where the dial starts: the PR you have, else a typical one (the prototype's demo PRs).
        let typical: [String: Double] = ["Back Squat": 140, "Front Squat": 115, "Deadlift": 180, "Clean": 100, "Snatch": 80, "Bench Press": 100]
        let convert = { (v: Double, from: WeightUnit, to: WeightUnit) -> Double in
            from == to ? v : (to == .lb ? v * 2.20462 : v / 2.20462)
        }
        let buildDial = { [weak self] (keep: Double?) in
            guard let self else { return }
            if let old = dial { old.root.removeFromParent() }
            let step = unit == .lb ? 5.0 : 2.5, top = unit == .lb ? 700.0 : 320.0
            values = stride(from: 0, through: top, by: step).map { $0 }
            let made = FlowDial(flow: self, labels: values.map { WeightUnit.trimmed($0) }, radius: 1.05, step: 0.33, width: 1.5,
                                labelWidth: 1.35, size: 112, wrap: false)
            made.root.position.y = -0.2
            made.onDetent = { [weak self] in self?.click(1); self?.buzz(.selection) }
            self.add(made.root)
            let start = keep ?? convert(record.value ?? (typical[record.lift] ?? 60), record.value != nil ? record.unit : .kg, unit)
            made.set(max(0, min(values.count - 1, Int((start / step).rounded()))))
            dial = made
        }
        say("\(LiftNames.sentenceCase(record.lift))?") { [weak self] in
            guard let self else { return }
            buildDial(nil)
            if let root = dial?.root { self.popIn(root) }
            for side: Float in [-1, 1] {
                let notch = self.add(self.build(FlowProps.notch(ink: self.ink, side: side)))
                self.popIn(notch, delay: 0.1)
            }
            ui.shown = true
            ui.onSwitch = { [weak self] next in
                guard let self, next != unit, let current = dial, values.indices.contains(current.index) else { return }
                let kept = convert(values[current.index], unit, next)
                unit = next
                self.data.prUnit = next
                ui.unit = next
                buildDial(kept)
                self.click(0.9)
                self.buzz(.selection)
            }
            // A swipe up (or a tap) confirms this lift; no sound for each PR.
            let confirm = { [weak self] in
                guard let self, let current = dial, values.indices.contains(current.index) else { return }
                self.data.setPR(record, value: values[current.index], unit: unit)
                if i + 1 < records.count { self.stepPRDial(i + 1) } else { self.panTo(self.prReturn ?? .wod) }
            }
            self.onSwipe = confirm
            self.onTap = { _ in confirm() }
        }
        hit = { [weak self] point in
            guard let self, let dial, self.touches(point, dial.root) else { return nil }
            return dial.drag(from: point, pointsPerItem: 40, flow: self)
        }
        tick = { dt, _ in dial?.tick(dt) }
    }

    /// Swaps a printed surface (the PR page after an upload).
    func repaint(_ entity: Entity, part name: String, with picture: FlowPicture) {
        for item in shadedModels(under: entity) where item.part.name == name {
            if case .picture(_, let tint) = item.part.paint { item.part.paint = .picture(picture, tint: tint) }
            item.dirty = true
        }
    }
}

/// KG / LB under the PR dial: a pill with the chosen one filled.
struct PRDialOverlay: View {
    let flow: Flow

    var body: some View {
        if let ui = flow.prDialUI, ui.shown {
            let ink = flow.inkColor, background = Color(rgb: flow.alt ? FlowLook.light : FlowLook.orange)
            HStack(spacing: 0) {
                ForEach([WeightUnit.kg, .lb], id: \.self) { unit in
                    let on = ui.unit == unit
                    Button { ui.onSwitch?(unit) } label: {
                        Text(unit.rawValue.uppercased())
                            .font(.custom("SpaceGrotesk-Bold", size: 17))
                            .foregroundStyle(on ? background : ink)
                            .frame(width: 68, height: 38)
                            .background(Capsule().fill(on ? ink : Color.clear))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(4)
            .overlay(Capsule().strokeBorder(ink, lineWidth: 2.5))
            .position(x: flow.viewSize.width / 2, y: flow.viewSize.height * 0.79 + 23)
        }
    }
}
