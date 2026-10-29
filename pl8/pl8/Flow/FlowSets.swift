import QuartzCore
import RealityKit
import SwiftUI
import PlateKit

/// The sets' cards (flSetCardEl, flCardDrag): the card in place, and the next or previous one following the
/// finger in.
@MainActor @Observable
final class SetsUI {
    var current = 0
    var peek: Int?
    var currentOffset: CGFloat = 0
    var currentOpacity: Double = 1
    var peekOffset: CGFloat = 0
    var peekOpacity: Double = 0
    /// The card's height in points.
    var cardHeight: CGFloat = 150
    /// A swipe's cards are still sliding into place.
    var settling = false
    var done: Set<Int> = []
    var visible = true
    /// Bumped when a card is changed by a tap (it slides in from below) rather than by a drag.
    var swaps = 0
}

/// A plate on the bar.
@MainActor
final class FlowBarPlate {
    let entity: Entity
    let side: Float
    let k: Int
    let x: Float
    var t: Float
    let delay: Float
    var out = false
    var manual = false
    var seated: Bool
    var gone = false

    init(entity: Entity, side: Float, k: Int, x: Float, t: Float = 0, delay: Float, seated: Bool = false) {
        self.entity = entity
        self.side = side
        self.k = k
        self.x = x
        self.t = t
        self.delay = delay
        self.seated = seated
    }
}

/// The bar during the sets: its plates and what's on each side now.
@MainActor
final class FlowBarState {
    let bar: Entity
    var on: [FlowBarPlate] = []
    var side: [Double] = []
    let y: Float = 0.9

    init(bar: Entity) { self.bar = bar }
}

extension Flow {
    // MARK: - 8 · Sets (flSets)

    func stepSets() {
        guard let plan else { go(.wod); return }
        setCamera(Self.setsCamera.position, Self.setsCamera.target, fov: 40)
        let rest = Self.setsCamera
        let bar = add(build(FlowProps.barbell()))
        let state = FlowBarState(bar: bar)
        barState = state
        var yaw: Float = 0, pitch: Float = 0, targetYaw: Float = 0, targetPitch: Float = 0, orbiting = false
        let offset = rest.position - rest.target
        let radius = simd_length(offset), theta0 = atan2(offset.x, offset.z), phi0 = acos(max(-1, min(1, offset.y / radius)))
        setsPan = nil
        setsProxy = nil
        let ui = SetsUI()
        ui.current = min(setIndex, plan.sets.count - 1)
        ui.done = doneSets
        setsUI = ui

        tick = { [weak self] dt, _ in
            guard let self else { return }
            if !orbiting { targetYaw *= exp(-dt * 2.5); targetPitch *= exp(-dt * 2.5) }
            yaw += (targetYaw - yaw) * (1 - exp(-dt * 10))
            pitch += (targetPitch - pitch) * (1 - exp(-dt * 10))
            let phi = max(0.35, min(.pi - 0.35, phi0 - pitch)), theta = theta0 + yaw
            var c = FlowCam(position: rest.target + radius * SIMD3(sin(phi) * sin(theta), cos(phi), sin(phi) * cos(theta)),
                            target: rest.target, fov: self.cam.fov)
            if let pan = self.setsPan, pan.px != 0 {
                c.position += pan.up * Float(pan.px) * pan.worldPerPoint
                c.target += pan.up * Float(pan.px) * pan.worldPerPoint
            }
            self.cam = c
            if let proxy = self.setsProxy {
                let on = (self.setsPan?.px ?? 0) > 0.5
                proxy.entity.isEnabled = on
                if on, let px = self.setsPan?.px {
                    self.place(proxy.entity, as: proxy.kit, up: proxy.up, worldPerPoint: proxy.worldPerPoint, offset: -(proxy.height - px))
                }
            }
            for m in state.on {
                m.t += dt
                if m.manual { continue }
                if m.out {
                    let q = min(1, m.t / 0.3)
                    m.entity.position = [m.x + m.side * 0.9 * q * q, state.y - 0.8 * max(0, q - 0.5), 0]
                    m.entity.scale = SIMD3(repeating: max(0.001, 1 - max(0, q - 0.6) / 0.4))
                    if q >= 1 { m.entity.removeFromParent(); m.gone = true }
                    continue
                }
                let q = min(1, max(0, (m.t - m.delay) / 0.34))
                m.entity.isEnabled = m.t >= m.delay
                m.entity.position = [m.side * 1.5 + (m.x - m.side * 1.5) * Float(Ease.outCubic(Double(q))), state.y, 0]
                if q >= 1 && !m.seated { m.seated = true; self.click(0.45); self.buzz(.light) }
            }
            state.on.removeAll { $0.gone }
        }

        // A sideways drag orbits; a vertical drag moves between sets (or, from the first set, back up to the kit);
        // a tap moves on.
        hit = { [weak self] point in
            guard let self else { return nil }
            var last = point, lastTime = CACurrentMediaTime(), velocity: CGFloat = 0
            var mode: String?
            var inner: FlowDrag?
            return FlowDrag(move: { [weak self] p in
                guard let self else { return }
                // Speed in points per ms from the touches' own times (the frame clock can't tell two touches apart).
                let dx = p.x - point.x, dy = p.y - point.y, now = CACurrentMediaTime()
                velocity = (p.y - last.y) / max(4, CGFloat((now - lastTime) * 1000))
                lastTime = now
                if mode == nil {
                    if hypot(dx, dy) < 10 { last = p; return }
                    if abs(dx) > abs(dy) * 0.9 {
                        mode = "orbit"; orbiting = true
                    } else if dy > 0 && self.setIndex == 0 {
                        mode = "kit"; inner = self.setsKitDrag(resetOrbit: { targetYaw = 0; targetPitch = 0 })
                    } else {
                        mode = "card"; inner = self.cardDrag()
                        if inner == nil { mode = "none" }
                    }
                }
                if mode == "orbit" {
                    targetYaw = max(-0.7, min(0.7, targetYaw - Float(p.x - last.x) * 0.006))
                    targetPitch = max(-0.25, min(0.25, targetPitch + Float(p.y - last.y) * 0.003))
                }
                if mode == "kit" || mode == "card" { inner?.move?(CGPoint(x: 0, y: dy)) }
                last = p
            }, up: { [weak self] p, tap in
                guard let self else { return }
                orbiting = false
                if tap && mode == nil { self.setGo(1); return }
                if mode == "kit" { inner?.up?(.zero, false) }
                if mode == "card" { inner?.up?(CGPoint(x: 0, y: velocity), false) }
            })
        }
        load(setIndex)
    }

    /// Puts set `i`'s plates on the bar (flLoad): what stays stays; the outer ones slide off the sleeve and drop,
    /// the new ones slide on, innermost first, and seat with a click.
    func load(_ i: Int) {
        guard let plan, let state = barState, plan.sets.indices.contains(i) else { return }
        let next = plan.sets[i].perSide, prev = state.side
        let common = zip(prev, next).prefix { $0 == $1 }.count
        for m in state.on where !m.out && m.k >= common { m.out = true; m.t = 0 }
        var cumulative: Float = 0
        for (k, size) in next.enumerated() {
            guard let plate = Plate.find(size, plan.unit) else { continue }
            let t = Float(plate.thickness), x = 0.695 + cumulative + t / 2
            cumulative += t + 0.002
            if k < common { continue }
            for side: Float in [-1, 1] {
                let entity = barPlate(plate)
                entity.position = [side * 1.5, state.y, 0]
                entity.isEnabled = false
                add(entity)
                state.on.append(FlowBarPlate(entity: entity, side: side, k: k, x: side * x,
                                             delay: 0.15 + Float(k - common) * 0.18 + (side > 0 ? 0.05 : 0)))
            }
        }
        state.side = next
    }

    /// A plate on its side, threaded on the bar (axis along X), turned a random way round.
    func barPlate(_ plate: Plate) -> Entity {
        let holder = Entity()
        let model = build(FlowProps.plate(plate))
        model.orientation = Flow.quaternion([.random(in: 0...6.28), 0, .pi / 2])
        holder.addChild(model)
        return holder
    }

    /// Next or previous set by a tap or a button (flSetGo).
    func setGo(_ direction: Int) {
        guard let plan, let ui = setsUI else { return }
        let n = plan.sets.count, i = setIndex
        if direction > 0 {
            guard i < n - 1 else { return }                      // the last set ends with its button
            doneSets.insert(i)
            checkSound()
            buzz(.success)
            setIndex = i + 1
        } else {
            checkSound()
            buzz(.light)
            guard i > 0 else { kitPlaced = true; go(.kit); return }
            setIndex = i - 1
            doneSets.remove(setIndex)
        }
        ui.done = doneSets
        ui.current = setIndex
        ui.swaps += 1
        later(0.25) { [weak self] in
            guard let self, self.barState != nil else { return }
            self.load(self.setIndex)
        }
    }

    /// The card follows the finger and the next one slides in; the plates follow too (flCardDrag, flPlateSwap).
    func cardDrag() -> FlowDrag? {
        guard let plan, let ui = setsUI, !ui.settling else { return nil }
        let n = plan.sets.count, i0 = setIndex
        let off = ui.cardHeight + 40 * layoutScale
        var direction = 0, dy: CGFloat = 0
        var swap: FlowPlateSwap?
        let place = { () -> Bool in
            let dir = dy < 0 ? 1 : dy > 0 ? -1 : 0, j = i0 + dir
            let ok = dir != 0 && j >= 0 && j < n
            if dir != direction {
                swap?.cancel()
                swap = nil
                ui.peek = nil
                direction = dir
                if ok {
                    ui.peek = j
                    swap = self.plateSwap(to: j)
                }
            }
            let d = ok ? dy : dy * 0.25, a = min(1, abs(d) / off)
            swap?.at(Float(a))
            ui.currentOffset = d
            ui.currentOpacity = Double(1 - a * 0.9)
            if ui.peek != nil {
                ui.peekOffset = (dir > 0 ? off : -off) + d
                ui.peekOpacity = Double(0.1 + a * 0.9)
            }
            return ok
        }
        return FlowDrag(move: { p in
            dy = p.y
            _ = place()
        }, up: { [weak self] p, _ in
            guard let self else { return }
            let velocity = p.y
            let ok = place()
            let go = ok && (abs(dy) > off * 0.32 || (abs(velocity) > 0.5 && (velocity > 0) == (dy > 0)))
            let d0 = ok ? dy : dy * 0.25, d1: CGFloat = go ? (direction > 0 ? -off : off) : 0
            let o0 = ui.currentOpacity, po0 = ui.peekOffset, pe0 = ui.peekOpacity
            let pEnd: CGFloat = go ? 0 : (direction > 0 ? off : -off)
            let s = swap, a0 = s?.a ?? 0
            // Committed on release (flCardDrag): the set changes now; the cards finish sliding after.
            let next = ui.peek
            if go, next != nil {
                if direction > 0 { self.doneSets.insert(i0); self.buzz(.success) } else { self.doneSets.remove(i0 - 1); self.buzz(.light) }
                self.checkSound()
                self.setIndex = i0 + direction
                ui.done = self.doneSets
            }
            ui.settling = true
            self.anim(0.24, { u in
                let e = CGFloat(Ease.card(u))
                ui.currentOffset = d0 + (d1 - d0) * e
                ui.currentOpacity = o0 + ((go ? 0 : 1) - o0) * Double(e)
                ui.peekOffset = po0 + (pEnd - po0) * e
                ui.peekOpacity = pe0 + ((go ? 1 : 0) - pe0) * Double(e)
                s?.at(a0 + ((go ? 1 : 0) - a0) * Float(Ease.outCubic(u)))
            }, done: {
                if go { s?.commit() } else { s?.cancel() }
                if go, let next { ui.current = next }
                ui.peek = nil
                ui.currentOffset = 0
                ui.currentOpacity = 1
                ui.settling = false
            })
        })
    }

    /// The plates tied to the drag: the outer ones slide off, the new ones slide on, outermost first.
    func plateSwap(to j: Int) -> FlowPlateSwap? {
        guard let plan, let state = barState else { return nil }
        let next = plan.sets[j].perSide, prev = state.side
        let common = zip(prev, next).prefix { $0 == $1 }.count
        let leaving = state.on.filter { !$0.out && $0.k >= common }.sorted { $0.k > $1.k }
        for m in leaving { m.manual = true }
        var entering: [FlowBarPlate] = []
        var cumulative: Float = 0
        for (k, size) in next.enumerated() {
            guard let plate = Plate.find(size, plan.unit) else { continue }
            let t = Float(plate.thickness), x = 0.695 + cumulative + t / 2
            cumulative += t + 0.002
            if k < common { continue }
            for side: Float in [-1, 1] {
                let entity = barPlate(plate)
                entity.position = [side * 1.5, state.y, 0]
                entity.isEnabled = false
                add(entity)
                entering.append(FlowBarPlate(entity: entity, side: side, k: k, x: side * x, t: 10, delay: 0, seated: true))
            }
        }
        let nl = Float(max(1, leaving.count / 2)), ne = Float(max(1, next.count - common))
        let swap = FlowPlateSwap()
        swap.at = { a in
            swap.a = a
            for (i, m) in leaving.enumerated() {
                let q = min(1, max(0, a * 1.4 - Float(i / 2) * 0.4 / nl)), e = q * q
                m.entity.position = [m.x + m.side * 0.9 * e, state.y - 0.5 * max(0, e - 0.6), 0]
                m.entity.scale = SIMD3(repeating: max(0.001, 1 - max(0, q - 0.75) / 0.25))
            }
            for m in entering {
                let q = min(1, max(0, a * 1.4 - 0.25 - Float(m.k - common) * 0.15 / ne)), e = Float(Ease.outCubic(Double(q)))
                m.entity.isEnabled = q > 0
                m.entity.position = [m.side * 1.5 + (m.x - m.side * 1.5) * e, state.y, 0]
            }
        }
        swap.commit = { [weak self] in
            for m in leaving { m.entity.removeFromParent(); m.gone = true }
            state.on = state.on.filter { !$0.gone } + entering
            state.side = next
            if !entering.isEmpty { self?.click(0.45); self?.buzz(.light) }
        }
        swap.cancel = {
            for m in entering { m.entity.removeFromParent() }
            for m in leaving {
                m.manual = false
                m.entity.position = [m.x, state.y, 0]
                m.entity.scale = [1, 1, 1]
            }
        }
        return swap
    }

    /// From the first set, a drag down pans back up to the kit, laid out exactly as it was (flSetsKitDrag).
    func setsKitDrag(resetOrbit: @escaping () -> Void) -> FlowDrag {
        let height = max(1, viewSize.height)
        let rest = FlowCam(position: Self.setsCamera.position, target: Self.setsCamera.target, fov: 40)
        let up = rest.basis.up, wpp = 2 * simd_length(rest.position - rest.target) * tan(20 * Float.pi / 180) / Float(height)
        if setsProxy == nil, let plan {
            let kit = FlowCam(position: Self.kitCamera.position, target: Self.kitCamera.target, fov: 35)
            let proxy = Entity()
            for spot in FlowKitLayout.spots(kit: plan.kit, unit: plan.unit) {
                let model = build(FlowProps.plate(spot.plate))
                model.position = [spot.x, Float(spot.plate.thickness) / 2 + 0.002, spot.z]
                model.orientation = simd_quatf(angle: spot.yaw, axis: [0, 1, 0])
                proxy.addChild(model)
            }
            proxy.isEnabled = false
            add(proxy)
            setsProxy = (proxy, kit, kit.basis.up, 2 * simd_length(kit.position - kit.target) * tan(17.5 * Float.pi / 180) / Float(height), height)
        }
        resetOrbit()
        let set = { [weak self] (px: CGFloat) in
            guard let self else { return }
            self.setsPan = (up, wpp, px)
            self.cam.fov = 40 - 5 * Float(min(1, px / height))
            self.uiPan = -px
            self.gridY = px
        }
        var px: CGFloat = 0
        return FlowDrag(move: { p in
            px = max(0, p.y)
            set(px)
        }, up: { [weak self] _, _ in
            guard let self else { return }
            let p0 = px
            if p0 > CGFloat(FlowPan.commitDistance) {
                self.hit = nil
                self.anim(0.3, { u in set(p0 + (height - p0) * CGFloat(1 - pow(1 - u, 2))) }, done: { [weak self] in
                    guard let self else { return }
                    self.setsPan = nil
                    self.uiPan = 0
                    self.gridY = 0
                    self.checkSound()
                    self.buzz(.light)
                    self.kitPlaced = true
                    self.go(.kit)
                })
            } else {
                self.anim(0.28, { u in set(p0 * CGFloat(pow(1 - u, 3))) }, done: { [weak self] in
                    self?.setsPan = nil
                    self?.uiPan = 0
                    self?.gridY = 0
                })
            }
        })
    }

    /// End session on the last card: the scale weighs the heaviest set (flFinish).
    func endSession() {
        checkSound()
        buzz(.success)
        doneSets.insert(setIndex)
        data.endSession()
        setsUI?.visible = false
        later(0.5) { [weak self] in self?.go(.done) }
    }

    // MARK: - 9 · The scale (flFinish → showSessionOver)

    func stepDone() {
        lastPlan = plan
        hit = nil
    }

    /// Tap on the scale: to the menu.
    func closeScale() {
        buzz(.light)
        plan = nil
        barState = nil
        menuPosition = 0
        menuActive = nil
        mode = .menu
        UserDefaults.standard.set(true, forKey: Flow.liftedKey)
        go(.menu)
    }

    static let liftedKey = "flowHasLifted"
    /// The first run's gym and PRs are done (the workout question is next).
    static let setUpKey = "hasFinishedFirstRun"
}

final class FlowPlateSwap {
    var a: Float = 0
    var at: (Float) -> Void = { _ in }
    var commit: () -> Void = {}
    var cancel: () -> Void = {}
}

/// The set cards: the one in place and the one following the finger in.
struct SetsOverlay: View {
    let flow: Flow

    var body: some View {
        if let ui = flow.setsUI, let plan = flow.plan, ui.visible {
            ZStack(alignment: .bottom) {
                Color.clear
                if let peek = ui.peek, plan.sets.indices.contains(peek) {
                    SetCard(flow: flow, plan: plan, index: peek, done: ui.done)
                        .offset(y: ui.peekOffset)
                        .opacity(ui.peekOpacity)
                        .allowsHitTesting(false)
                }
                SetCard(flow: flow, plan: plan, index: ui.current, done: ui.done)
                    .id(ui.current)
                    .offset(y: ui.currentOffset)
                    .opacity(ui.currentOpacity)
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { ui.cardHeight = $0 }
                    .transition(.asymmetric(insertion: .offset(y: 70).combined(with: .opacity), removal: .offset(y: -60).combined(with: .opacity)))
            }
            .animation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.32), value: ui.swaps)
            .modifier(CardEntrance(shownAt: 0, flow: flow))
        }
    }
}

/// One set's card (flSetCardEl): the group small and faded, "Set 2 of 5" big, reps and weight on the right,
/// progress dots, and on the last set End session.
struct SetCard: View {
    let flow: Flow
    let plan: FlowPlan
    let index: Int
    let done: Set<Int>

    var body: some View {
        let set = plan.sets[index], dark = Color(rgb: FlowLook.dark)
        let group = plan.sets.indices.filter { plan.sets[$0].groupIndex == set.groupIndex }
        VStack(alignment: .leading, spacing: 0) {
            Text(set.group.uppercased())
                .font(.custom("SpaceGrotesk-Bold", size: 13))
                .tracking(13 * 0.08)
                .foregroundStyle(dark.opacity(0.6))
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(set.label)
                    .font(.custom("SpaceGrotesk-Bold", size: 30))
                    .tracking(-0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Text(set.totalText)
                    .font(.custom("SpaceGrotesk-Bold", size: 17))
                    .lineLimit(1)
            }
            .padding(.top, 2)
            .padding(.bottom, 12)
            HStack(spacing: 6) {
                ForEach(group, id: \.self) { j in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(done.contains(j) ? Color(rgb: FlowLook.orange) : j == index ? dark : dark.opacity(Double(0x22) / 255))
                        .frame(height: 7)
                }
            }
            if index == plan.sets.count - 1 {
                Button { flow.endSession() } label: {
                    Text("End session")
                        .font(.custom("SpaceGrotesk-Bold", size: 19))
                        .foregroundStyle(Color(rgb: FlowLook.light))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(RoundedRectangle(cornerRadius: 16).fill(dark))
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
        }
        .foregroundStyle(dark)
        .padding(.top, 16)
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.white).shadow(color: .black.opacity(0.18), radius: 15, y: 10))
        .padding(.horizontal, 12)
        .padding(.bottom, 24)
    }
}
