import RealityKit
import SwiftUI
import PlateKit

/// The kit's card: one chip per plate size to tick off (flKit).
@MainActor @Observable
final class KitUI {
    struct Chip: Identifiable {
        let size: Double
        let count: Int
        let plate: Plate?
        var id: Double { size }
    }
    var chips: [Chip] = []
    var unit: WeightUnit = .kg
    var shownAt: Double = 0
}

/// A plate of the kit on the floor.
@MainActor
final class FlowKitPlate {
    let entity: Entity
    let model: Entity
    let plate: Plate
    var body: FlowBody?
    var clicked = false
    /// When it first touched the floor: for a moment after, it doesn't skid (cannon's plates stay on their spot).
    var landedAt: Double?

    init(entity: Entity, model: Entity, plate: Plate) {
        self.entity = entity
        self.model = model
        self.plate = plate
    }
}

extension Flow {
    static let kitCamera = (position: SIMD3<Float>(0, 6.3, 5.57), target: SIMD3<Float>(0, -1.3, -0.3))
    static let setsCamera = (position: SIMD3<Float>(2.45, 1.25, 1.75), target: SIMD3<Float>(0.78, 0.8, -0.08))

    // MARK: - 7 · The plate kit (flKit, flKitLayout)

    func stepKit() {
        guard let plan else { go(.wod); return }
        setCamera(Self.kitCamera.position, Self.kitCamera.target)
        let world = FlowPhysicsWorld(parent: scene)
        physics = world
        world.floor()
        let spots = FlowKitLayout.spots(kit: plan.kit, unit: plan.unit)
        // Fences just out of view; the near one stays clear of the last row (the prototype's could catch the
        // smallest plates on top of it).
        let near = max(1.3, (spots.map { $0.z + Float($0.plate.diameter) / 2 }.max() ?? 0) + 0.45)
        world.fences([(0, -3.1, 3.2, 0.2), (0, near, 3.2, 0.2), (-1.65, -0.9, 0.2, 2.6), (1.65, -0.9, 0.2, 2.6)])
        let placed = kitPlaced
        kitPlaced = false
        var items: [FlowKitPlate] = []
        for (order, spot) in spots.enumerated() {
            let plate = spot.plate, radius = Float(plate.diameter) / 2, thickness = Float(plate.thickness)
            let model = build(FlowProps.plate(plate))
            let entity = Entity()
            entity.addChild(model)
            entity.isEnabled = false
            world.root.addChild(entity)
            let item = FlowKitPlate(entity: entity, model: model, plate: plate)
            items.append(item)
            // One after another, flat, straight down onto its spot: easy to count.
            let drop = { [weak self] in
                guard let self, self.physics === world else { return }
                if placed {
                    entity.position = [spot.x, thickness / 2 + 0.002, spot.z]
                    entity.orientation = simd_quatf(angle: spot.yaw, axis: [0, 1, 0])
                } else {
                    entity.position = [spot.x, 1.5, spot.z]
                    entity.orientation = Flow.quaternion([.random(in: -0.02...0.02), spot.yaw, .random(in: -0.02...0.02)])
                }
                entity.isEnabled = true
                let mass = Float(plate.unit == .lb ? plate.size * 0.4536 : plate.size)
                let body = world.add(entity, shape: FlowPhysicsWorld.cylinderShape(top: radius, bottom: radius, height: thickness, sides: 28),
                                     mass: mass, radius: radius, squash: model)
                item.body = body
                if let scene = entity.scene {
                    self.stepSubscriptions.append(scene.subscribe(to: CollisionEvents.Began.self, on: entity) { [weak self] event in
                        guard let self else { return }
                        let other = event.entityA === entity ? event.entityB : event.entityA
                        let v = max(abs(body.lastVelocity.y), event.impulse / max(0.5, mass))
                        guard other.name == "ground" else {
                            if !item.clicked && v > 1.5 { item.clicked = true; self.click(0.4) }
                            return
                        }
                        if item.landedAt == nil { item.landedAt = self.t }
                        let axis = entity.orientation(relativeTo: nil).act([0, 1, 0])
                        let flat = abs(axis.y) > 0.7
                        let at = flat ? entity.position(relativeTo: nil) : event.position
                        self.impact(mass: mass, speed: v, x: at.x, z: at.z, radius: radius, flat: flat, target: model)
                    })
                }
            }
            if placed { drop() } else { later(0.3 + Double(order) * 0.15, drop) }
        }
        kitItems = items
        let ui = KitUI()
        ui.unit = plan.unit
        ui.chips = plan.kit.map { KitUI.Chip(size: $0.0, count: $0.1, plate: Plate.find($0.0, plan.unit)) }
        ui.shownAt = t
        kitUI = ui

        world.onStep = { [weak self] dt in
            guard let self else { return }
            for item in items {
                guard let landed = item.landedAt, self.t - landed < 0.8, world.grab?.body !== item.body,
                      var motion = item.entity.components[PhysicsMotionComponent.self] else { continue }
                let k = exp(-14 * dt)
                motion.linearVelocity.x *= k
                motion.linearVelocity.z *= k
                motion.angularVelocity.y *= k
                item.entity.components.set(motion)
            }
        }
        let preview = kitPreview()
        hit = { [weak self] point in
            guard let self else { return nil }
            let r = self.ray(point)
            var best: FlowKitPlate?, bestDistance = Float.infinity
            for item in items where item.body != nil {
                let d = r.distance(to: item.entity.position(relativeTo: nil))
                if d < Float(item.plate.diameter) / 2 * 1.1 && d < bestDistance { bestDistance = d; best = item }
            }
            if let best, let body = best.body {
                return self.grabber([body], radius: { _ in .infinity }, lift: 0.35, point: point, bounds: (-1.45...1.45, -2.9...1.1))
            }
            return preview(point)
        }
    }

    /// Dragging off the plates previews where you're going (flKitPreview): down, the plates fold away and the
    /// camera pulls back out of the board; up, the camera pans down and the bar comes up from below, framed like
    /// the sets. A tap goes to the sets.
    func kitPreview() -> (CGPoint) -> FlowDrag {
        let far = SIMD3<Float>(0, 0, -40)
        let board = makeBoard()
        board.entity.scale = SIMD3(repeating: Self.boardScale)
        board.entity.orientation = simd_quatf(angle: Self.boardTurn, axis: [0, 1, 0])
        board.entity.position = far
        board.canvas?.draw(data.boardLines)
        board.entity.isEnabled = false
        add(board.entity)
        let cy = 1.45 * Self.boardScale
        let zoom = (position: far + SIMD3(0.15, cy, 0.7), target: far + SIMD3(0, cy, 0))
        let rest = (position: far + Self.boardCamera.position, target: far + Self.boardCamera.target)
        let kit = cam
        let geo = panGeometry()
        let down = geo.up * (-Float(geo.height) * geo.worldPerPoint)
        let sets = FlowCam(position: Self.setsCamera.position, target: Self.setsCamera.target, fov: 40)
        let setsUp = sets.basis.up, setsWpp = 2 * simd_length(sets.position - sets.target) * tan(20 * Float.pi / 180) / Float(geo.height)
        let proxy = Entity()
        proxy.addChild(build(FlowProps.barbell()))
        proxy.isEnabled = false
        add(proxy)
        let kitBackground = Color(rgb: alt ? FlowLook.light : FlowLook.orange)
        let boardBackground = Color(rgb: userBackground ? FlowLook.light : FlowLook.orange)
        var v: Float = 0
        let pose = { [weak self] (value: Float) in
            guard let self else { return }
            let a = min(1, abs(value))
            self.uiOpacity = Double(1 - min(1, a * 2.6))
            if value <= 0 {
                proxy.isEnabled = false
                // Back: first the plates fold away, then the camera pulls back out of the board.
                let a1 = min(1, a / 0.28), a2 = max(0, (a - 0.28) / 0.72), e2 = Float(Ease.inOutCubic(Double(a2)))
                for item in self.kitItems { item.model.scale = SIMD3(repeating: max(0.0001, 1 - a1 * a1)) }
                if a2 <= 0 {
                    board.entity.isEnabled = false
                    self.cam = kit
                    self.backgroundOverride = nil
                } else {
                    board.entity.isEnabled = true
                    self.cam = FlowCam(position: zoom.position + (rest.position - zoom.position) * e2,
                                       target: zoom.target + (rest.target - zoom.target) * e2, fov: kit.fov)
                    self.backgroundOverride = Color.mix(kitBackground, boardBackground, Double(e2))
                }
            } else {
                // Next: a pan straight down; the bar comes up from below.
                let e = Float(Ease.inOutQuad(Double(a)))
                board.entity.isEnabled = false
                for item in self.kitItems { item.model.scale = [1, 1, 1] }
                self.cam = FlowCam(position: kit.position + down * e, target: kit.target + down * e, fov: kit.fov + (40 - kit.fov) * e)
                proxy.isEnabled = e > 0.002
                if proxy.isEnabled { self.place(proxy, as: sets, up: setsUp, worldPerPoint: setsWpp, offset: geo.height * CGFloat(1 - e)) }
                self.gridY = -geo.height * CGFloat(e)
            }
        }
        let commit = { [weak self] (direction: Float) in
            guard let self else { return }
            self.hit = nil; self.onTap = nil; self.onSwipe = nil
            let v0 = v
            self.anim(direction < 0 ? 0.55 : 0.4, { u in
                v = v0 + (direction - v0) * Float(Ease.outCubic(u))
                pose(v)
            }, done: { [weak self] in
                guard let self else { return }
                self.uiOpacity = 1
                self.backgroundOverride = nil
                self.gridY = 0
                self.checkSound()
                if direction < 0 {
                    self.again = true
                    self.fromKit = true
                    self.go(.wod)
                } else {
                    self.go(.sets)
                }
            })
        }
        return { [weak self] start in
            var moved = false
            return FlowDrag(move: { [weak self] p in
                guard let self else { return }
                let dy = (p.y - start.y) / self.layoutScale
                if abs(dy) > 6 { moved = true }
                v = max(-1, min(1, -Float(dy) / 340))
                pose(v)
            }, up: { [weak self] _, tap in
                guard let self else { return }
                if tap && !moved { commit(1); return }
                if abs(v) > 0.3 { commit(v < 0 ? -1 : 1); return }
                let v0 = v
                self.anim(0.3, { u in v = v0 * Float(pow(1 - u, 3)); pose(v) }, done: { [weak self] in
                    self?.uiOpacity = 1
                    self?.backgroundOverride = nil
                    self?.gridY = 0
                })
            })
        }
    }

    /// flProxyAt: puts `proxy` where it has to be, relative to the camera now, to look as it would from `view`
    /// shifted `offset` points along its up (so a scene that isn't there yet can be seen coming).
    func place(_ proxy: Entity, as view: FlowCam, up: SIMD3<Float>, worldPerPoint: Float, offset: CGFloat) {
        var shifted = view
        shifted.position += up * Float(offset) * worldPerPoint
        shifted.target += up * Float(offset) * worldPerPoint
        var now = liveCamera
        now.fov = view.fov
        proxy.transform = Transform(matrix: now.matrix * shifted.matrix.inverse)
    }
}

extension Color {
    static func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ua = UIColor(a), ub = UIColor(b)
        var (ar, ag, ab, aa) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        var (br, bg, bb, ba) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        ua.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        ub.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let f = CGFloat(t)
        return Color(red: ar + (br - ar) * f, green: ag + (bg - ag) * f, blue: ab + (bb - ab) * f)
    }
}

/// The kit's white card at the bottom: a chip per plate size ("4 × 25 kg") to tick off.
struct KitOverlay: View {
    let flow: Flow

    var body: some View {
        if let ui = flow.kitUI {
            VStack {
                Spacer()
                FlowLayout(spacing: 8) {
                    ForEach(ui.chips) { chip in
                        let on = flow.collected.contains(chip.size)
                        Button {
                            if on { flow.collected.remove(chip.size) } else { flow.collected.insert(chip.size); flow.buzz(.light) }
                        } label: {
                            HStack(spacing: 8) {
                                if let plate = chip.plate {
                                    let d = (10 + plate.diameter * 14).rounded()
                                    Circle().fill(Color(hex: plate.colorHex)).frame(width: d, height: d)
                                        .overlay(Circle().strokeBorder(Color.black.opacity(0.2), lineWidth: 1))
                                }
                                Text("\(chip.count) × \(WeightUnit.trimmed(chip.size)) \(ui.unit.rawValue)")
                                    .font(.custom("SpaceGrotesk-Bold", size: 16))
                            }
                            .foregroundStyle(Color(rgb: on ? FlowLook.light : FlowLook.dark))
                            .padding(.leading, 10)
                            .padding(.trailing, 14)
                            .frame(height: 40)
                            .background(Capsule().fill(on ? Color(rgb: FlowLook.dark) : Color.clear))
                            .overlay(Capsule().strokeBorder(Color(rgb: FlowLook.dark), lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 22).fill(Color.white).shadow(color: .black.opacity(0.18), radius: 15, y: 10))
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
                .modifier(CardEntrance(shownAt: ui.shownAt, flow: flow))
            }
        }
    }
}

/// Cards slide up into place (translateY 120 % → 0 over 0.42 s, a strong ease-out).
struct CardEntrance: ViewModifier {
    let shownAt: Double
    let flow: Flow
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .offset(y: shown ? 0 : 300)
            .onAppear { withAnimation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.42)) { shown = true } }
    }
}
