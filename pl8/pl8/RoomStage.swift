import RealityKit
import SwiftUI
import UIKit
import PlateKit

/// The 3D box as a stage behind the app's screens (SPEC 2.1): it flies to `station`, and the props the gym
/// setup changes follow the gym live — the flag shows the name, the shelf the unit's pegs with the gym's piles
/// popping on and off, the rack the gym's bar (SPEC 2.2). With `interactive`, drag to go round and pinch to zoom.
/// With `opening`, it plays the first run's opening (SPEC 2.2 step 0).
struct RoomStage: View {
    var station: RoomLayout.Station
    var gymName: String
    var unit: WeightUnit
    var plateSizes: [Double]
    var barWeight: Double
    var boards = Boards()
    /// During a session: the kit on the floor and the set's plates on the bar.
    var session: SessionProps?
    var interactive = false
    var opening: OpeningPhase?
    /// Home: the room floats a little in space (prototype floatTick).
    var floating = false

    @State private var orbit: Orbit
    /// The closed box's own move during the opening (pop, turn, float), round the room's centre.
    @State private var box = matrix_identity_float4x4
    @State private var dragStart: Orbit?
    @State private var pinchStart: Orbit?
    @State private var flight: Task<Void, Never>?
    @State private var props = SetupProps()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(station: RoomLayout.Station, gymName: String, unit: WeightUnit, plateSizes: [Double], barWeight: Double,
         boards: Boards = Boards(), session: SessionProps? = nil, interactive: Bool = false, opening: OpeningPhase? = nil,
         floating: Bool = false) {
        self.opening = opening
        self.floating = floating
        self.boards = boards
        self.session = session
        self.station = station
        self.gymName = gymName
        self.unit = unit
        self.plateSizes = plateSizes
        self.barWeight = barWeight
        self.interactive = interactive
        _orbit = State(initialValue: Orbit(RoomLayout.shots[station]!))
    }

    var body: some View {
        RealityView { content in
            // The rest of the room is baked once for the whole app, off the main thread; the setup's props are built here.
            let entities = await RoomTemplate.entities()
            for entity in entities { content.add(entity) }
            if let world = entities.first(where: { $0.name == RoomScene.worldName }) {
                props.attach(to: world)
                props.sync(name: gymName, unit: unit, plateSizes: plateSizes, barWeight: barWeight, boards: boards, animate: false)
                props.syncSession(session, animate: !reduceMotion)
                props.syncOpening(opening)
            }
            RoomScene.show(orbit, box: box, in: content.entities)
        } update: { content in
            props.sync(name: gymName, unit: unit, plateSizes: plateSizes, barWeight: barWeight, boards: boards, animate: !reduceMotion)
            props.syncSession(session, animate: !reduceMotion)
            props.syncOpening(opening)
            RoomScene.show(orbit, box: box, in: content.entities)
        }
        .background(Theme.background)
        .gesture(gestures, including: interactive ? .all : .subviews)
        .onChange(of: station) { _, item in fly(to: item) }
        .onDisappear { flight?.cancel() }
        .task(id: opening) { await play(opening) }
        .task(id: floating) { await float(floating) }
    }

    /// The prototype's floatTick: up and down by 0.2 ± 0.14 m and a slight rock, eased in.
    private func float(_ on: Bool) async {
        guard opening == nil else { return }
        guard on, !reduceMotion else {
            box = matrix_identity_float4x4
            return
        }
        let start = ContinuousClock.now
        while !Task.isCancelled {
            let t = Float((ContinuousClock.now - start) / .seconds(1))
            let k = 1 - exp(-t * 1.4)
            let rock = simd_quatf(angle: k * 0.016 * sin(t * 0.52), axis: [1, 0, 0]) * simd_quatf(angle: k * 0.016 * sin(t * 0.43 + 1.2), axis: [0, 0, 1])
            box = Transform(rotation: rock, translation: [0, k * (0.2 + 0.14 * sin(t * 0.75)), 0]).matrix
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    // MARK: - Opening (SPEC 2.2 step 0, prototype runOnb)

    /// Plays one part of the opening: the closed box popping in and floating, the box opening, or the furniture
    /// arriving. The camera's flights come from `station` as usual.
    private func play(_ phase: OpeningPhase?) async {
        props.syncOpening(phase)
        let centre = RoomLayout.room.centre
        func pose(scale: Float, spin: Float, lift: Float) -> simd_float4x4 {
            Transform(scale: SIMD3(repeating: scale), rotation: simd_quatf(angle: spin, axis: [0, 1, 0]),
                      translation: centre + [0, lift, 0]).matrix * Transform(translation: -centre).matrix
        }
        let start = ContinuousClock.now
        func elapsed() -> Float { Float((ContinuousClock.now - start) / .seconds(1)) }
        switch phase {
        case .title:
            box = pose(scale: 0.0001, spin: props.spin, lift: 0.55)
        case .closed:
            // It pops in and turns slowly in the sky, floating, until the tap.
            while !Task.isCancelled {
                let t = elapsed()
                props.spin = 0.45 + t * 0.1
                box = pose(scale: reduceMotion ? 1 : Opening.popScale(at: t), spin: props.spin, lift: 0.55 + Opening.bob(at: t))
                try? await Task.sleep(for: .milliseconds(8))
            }
        case .opening:
            // It turns back to face us the short way while the lid floats off and the walls glide down.
            let s0 = props.spin, s1 = (s0 / (2 * .pi)).rounded() * 2 * .pi
            while !Task.isCancelled {
                let t = reduceMotion ? Opening.duration : elapsed()
                let p = Opening.pose(at: t)
                props.poseBox(p)
                props.spin = s0 + (s1 - s0) * p.turn
                box = pose(scale: 1, spin: props.spin, lift: p.lift + Opening.bob(at: t) * p.settle)
                if t >= Opening.duration { break }
                try? await Task.sleep(for: .milliseconds(8))
            }
        case .furnishing:
            box = matrix_identity_float4x4
            while !Task.isCancelled {
                let t = reduceMotion ? Opening.furnishTime : elapsed()
                props.furnish(at: t)
                if t >= Opening.furnishTime { break }
                try? await Task.sleep(for: .milliseconds(8))
            }
        case .done, nil:
            box = matrix_identity_float4x4
        }
    }

    private var gestures: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                flight?.cancel()
                let start = dragStart ?? orbit
                dragStart = start
                orbit = start.dragged(dx: Float(value.translation.width), dy: Float(value.translation.height))
            }
            .onEnded { _ in dragStart = nil }
            .simultaneously(with: MagnifyGesture()
                .onChanged { value in
                    flight?.cancel()
                    let start = pinchStart ?? orbit
                    pinchStart = start
                    orbit = start.zoomed(by: Float(value.magnification))
                }
                .onEnded { _ in pinchStart = nil })
    }

    /// Flies the camera to `item`'s shot like the prototype (SPEC 2.5); with Reduce Motion, cuts straight there.
    private func fly(to item: RoomLayout.Station) {
        flight?.cancel()
        let destination = Orbit(RoomLayout.shots[item]!)
        if reduceMotion {
            orbit = destination
            return
        }
        // The opening drifts in to the overview a little slower, like the prototype (2.1 s).
        let path = Flight(from: orbit, to: destination, duration: opening == .opening ? 2.1 : Flight.duration(to: item))
        flight = Task { @MainActor in
            let start = ContinuousClock.now
            while !Task.isCancelled {
                let elapsed = (ContinuousClock.now - start) / .seconds(1)
                orbit = path.orbit(at: elapsed)
                if path.isFinished(at: elapsed) { break }
                try? await Task.sleep(for: .milliseconds(8))       // about one step per screen refresh
            }
        }
    }
}

/// The props the gym setup and the user's data change, rebuilt only when their input changes: the flag (name),
/// the rack's bar (bar), the shelf's pegs (unit), one pile per plate size, which pops in and out from its peg, and
/// what's written on the PR board and the whiteboard.
@MainActor
final class SetupProps {
    nonisolated static let objects: Set<RoomLayout.Object> = [.flag, .rack, .shelf, .prBoard, .board, .bench, .wallFan]

    private let flag = Entity(), rack = Entity(), shelf = Entity(), prBoard = Entity(), board = Entity(), bench = Entity()
    /// The closed box's sides and lid, while the opening plays.
    private let closedBox = Entity()
    private var slabs: [(side: Opening.Side, entity: Entity)] = []
    private let lid = Entity()
    /// The box's turn during the opening.
    var spin: Float = 0.45
    private var openingPhase: OpeningPhase?
    private var boards: Boards?
    private let kitFloor = Entity(), barPlates = Entity()
    /// The rack's bar with its plates, so it can go down to the platform for pulls; its shadow apart.
    private let barGroup = Entity(), barBody = Entity(), barShadow = Entity()
    private var barOnFloor = false
    /// The wall fan: the head sweeps round the swivel, the blades spin round the hub.
    private let fan = Entity(), fanSwivel = Entity(), fanBlades = Entity()
    private var fanAxis = SIMD3<Float>(0, 0, 1), fanPhase: Float = 0, bladeAngle: Float = 0
    /// The flag stirs in the fan's wind; not while it unrolls.
    private var flagStill: Float = 0
    /// The room dims behind the bar while you look at a set (prototype renderDimmed).
    private var dimGoal: Float = 0, dim: Float = 0
    private var undimmed: [ObjectIdentifier: [any RealityKit.Material]] = [:]
    private weak var world: Entity?
    /// Plates sliding on or off the bar, moved frame by frame (prototype showSet and its onBar loop).
    private var moving: [PlateMove] = []
    private var clock: Float = 0
    private var ticker: Task<Void, Never>?
    private var kit: Kit?
    private var kitItems: [(size: Double, entity: Entity)] = []
    private var onBar: [(size: Double, entity: Entity, k: Int)] = []
    private var barSide: [Double] = []
    private var piles: [Double: Entity] = [:]
    private var name: String?, unit: WeightUnit?, barWeight: Double?
    private var attached = false

    func attach(to world: Entity) {
        self.world = world
        for group in [flag, rack, shelf, prBoard, board, bench, kitFloor, barGroup, fan, closedBox] { world.addChild(group) }
        for part in [barBody, barShadow, barPlates] { barGroup.addChild(part) }
        buildFan()
        // The board and the bench sit round their spots, so the opening can roll and toss them in.
        for (group, object) in [(board, RoomLayout.Object.board), (bench, .bench)] {
            group.position = PropModels.placement(for: object).position
        }
        rebuild(bench, Self.bakedAround(.bench, PropModels.parts(for: .bench, plates: [])))
        // Physics for the kit drop, in the room's own space (the room moves for the camera): gravity, and the
        // floor as a solid slab with the prototype's rubber (friction 0.55, a little bounce).
        var simulation = PhysicsSimulationComponent()
        simulation.gravity = [0, -9.81, 0]
        world.components.set(simulation)
        let room = RoomLayout.room
        let floor = Entity()
        floor.position = [room.centre.x, -0.5, room.centre.z]
        floor.components.set(CollisionComponent(shapes: [.generateBox(size: [room.width + 4, 1, room.depth + 4])]))
        floor.components.set(PhysicsBodyComponent(massProperties: .default, material: Self.rubber, mode: .static))
        world.addChild(floor)
        attached = true
        startTicking()
    }

    // MARK: - What moves all the time (prototype propsTick)

    private func startTicking() {
        ticker = Task { @MainActor [weak self] in
            var last = ContinuousClock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard let self else { return }
                let now = ContinuousClock.now
                self.tick(min(0.05, Float((now - last) / .seconds(1))))
                last = now
            }
        }
    }

    private func tick(_ dt: Float) {
        clock += dt
        // The fan sweeps left and right and its blades spin (0.25 rad a frame at 60 fps).
        fanPhase += dt
        let sweep = sin(fanPhase / 1.8) * 0.5
        fanSwivel.orientation = simd_quatf(angle: sweep, axis: [0, 1, 0])
        bladeAngle -= 15 * dt
        fanBlades.orientation = simd_quatf(angle: bladeAngle, axis: fanAxis)
        // Its wind stirs the flag: the cloth swings out from the wall and flutters.
        if clock > flagStill {
            let wind = 0.22 + 0.16 * (sweep + 0.5)
            let placement = PropModels.placement(for: .flag)
            let along = placement.turn([1, 0, 0]), into = placement.turn([0, 0, 1])
            let outward: Float = simd_dot(simd_cross(along, [0, -1, 0]), into) > 0 ? 1 : -1
            let angle = outward * wind * (0.16 + 0.06 * sin(clock * 7.4) + 0.03 * sin(clock * 12.5 + 1))
            flag.orientation = simd_quatf(angle: angle, axis: along)
        }
        // The room fades towards box light behind the bar while a set is in view, and back.
        let next = dim + (dimGoal - dim) * (1 - exp(-dt * 3))
        if abs(next - dim) > 0.004 || (dimGoal == 0 && dim > 0 && next < 0.01) {
            dim = next < 0.01 && dimGoal == 0 ? 0 : next
            applyDim(dim)
        }
        moving = moving.filter { step($0) }
    }

    /// The fan in three parts: what stays put (and the whole fan's shadow), the head round the swivel and the
    /// blades round the hub. Each is baked where it rests, then moved so it turns round its own pivot.
    private func buildFan() {
        let placement = PropModels.placement(for: .wallFan), wall = RoomLayout.Object.wallFan.wall
        let parts = PropModels.wallFanParts()
        let swivel = placement.apply(parts.swivel), hub = placement.apply(parts.hub)
        fanAxis = placement.turn(parts.spinAxis)
        rebuild(fan, SceneBake.bake(parts.fixed, placement: placement, wall: wall, content: .withoutShadows)
            + SceneBake.bake(parts.fixed + parts.head + parts.blades, placement: placement, wall: wall, content: .shadowsOnly))
        fan.addChild(fanSwivel)
        fanSwivel.position = swivel
        for child in Diorama.entities(for: SceneBake.bake(parts.head, placement: placement, wall: wall, content: .withoutShadows)
            .map { $0.translated(by: -swivel) }) {
            fanSwivel.addChild(child)
        }
        fanSwivel.addChild(fanBlades)
        fanBlades.position = hub - swivel
        for child in Diorama.entities(for: SceneBake.bake(parts.blades, placement: placement, wall: wall, content: .withoutShadows)
            .map { $0.translated(by: -hub) }) {
            fanBlades.addChild(child)
        }
    }

    /// Every colour in the room mixed `k` × 62 % towards box light (pictures fade), except the bar and its plates.
    private func applyDim(_ k: Float) {
        guard let world else { return }
        let light = Look.boxLight
        func visit(_ entity: Entity) {
            if entity === barGroup { return }
            if let model = entity as? ModelEntity, let current = model.model?.materials {
                let id = ObjectIdentifier(model)
                let original = undimmed[id] ?? current
                if k <= 0 {
                    model.model?.materials = original
                    undimmed[id] = nil
                } else {
                    undimmed[id] = original
                    model.model?.materials = original.map { material in
                        guard var unlit = material as? UnlitMaterial else { return material }
                        if unlit.color.texture != nil {
                            unlit.blending = .transparent(opacity: .init(floatLiteral: 1 - 0.62 * k))
                        } else {
                            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                            unlit.color.tint.getRed(&r, green: &g, blue: &b, alpha: &a)
                            let m = CGFloat(0.62 * k)
                            unlit.color.tint = UIColor(red: r + (CGFloat(light.r) - r) * m, green: g + (CGFloat(light.g) - g) * m,
                                                       blue: b + (CGFloat(light.b) - b) * m, alpha: a)
                        }
                        return unlit
                    }
                }
            }
            for child in entity.children { visit(child) }
        }
        visit(world)
    }

    static let rubber = PhysicsMaterialResource.generate(staticFriction: 0.55, dynamicFriction: 0.55, restitution: 0.15)

    func sync(name: String, unit: WeightUnit, plateSizes: [Double], barWeight: Double, boards: Boards, animate: Bool) {
        guard attached else { return }
        if boards.prs != self.boards?.prs {
            rebuild(prBoard, SceneBake.bake(PropModels.parts(for: .prBoard, plates: [], boards: boards),
                                            placement: PropModels.placement(for: .prBoard), wall: nil))
        }
        if boards.workout != self.boards?.workout {
            rebuild(board, Self.bakedAround(.board, PropModels.parts(for: .board, plates: [], boards: boards)))
        }
        self.boards = boards
        if name != self.name {
            // No name yet: no flag. With the first letter it unrolls down from its rod (SPEC 2.2).
            let unrolls = (self.name ?? "").isEmpty && !name.isEmpty && self.name != nil
            self.name = name
            let rod = PropModels.placement(for: .flag).position
            flag.position = rod
            rebuild(flag, name.isEmpty ? [] : SceneBake.bake(PropModels.parts(for: .flag, plates: [], gymName: name),
                                                             placement: PropModels.placement(for: .flag), wall: nil)
                .map { $0.translated(by: -rod) })
            if unrolls && animate {
                flagStill = clock + 0.7
                flag.orientation = simd_quatf()
                flag.scale = [1, 0.01, 1]
                _ = flag.move(to: Transform(scale: .one, rotation: flag.orientation, translation: rod), relativeTo: flag.parent,
                          duration: 0.6, timingFunction: .easeOut)
            } else {
                flag.scale = .one
            }
        }
        if unit != self.unit || barWeight != self.barWeight {
            self.barWeight = barWeight
            let parts = PropModels.rackParts(barWeight: barWeight, unit: unit), placement = PropModels.placement(for: .rack)
            rebuild(rack, SceneBake.bake(parts.frame, placement: placement, wall: nil))
            rebuild(barBody, SceneBake.bake(parts.bar, placement: placement, wall: nil, content: .withoutShadows))
            rebuild(barShadow, SceneBake.bake(parts.bar, placement: placement, wall: nil, content: .shadowsOnly))
        }
        var popIn = animate
        if unit != self.unit {
            // New unit: new pegs, and the piles come back one by one.
            popIn = animate && self.unit != nil
            self.unit = unit
            rebuild(shelf, SceneBake.bake(PropModels.shelf(unit: unit), placement: .init(position: .zero, rotationDegrees: 0), wall: nil))
            for pile in piles.values { pile.removeFromParent() }
            piles = [:]
        }
        let wanted = Set(plateSizes)
        for (index, plate) in Plate.catalog(unit).enumerated() {
            if wanted.contains(plate.size), piles[plate.size] == nil {
                let pile = Self.pileEntity(plate)
                shelf.addChild(pile)
                piles[plate.size] = pile
                if popIn { pop(pile, in: true, delay: Double(index) * 0.06) } else { pile.scale = .one }
            } else if !wanted.contains(plate.size), let pile = piles.removeValue(forKey: plate.size) {
                if animate { pop(pile, in: false, delay: 0) } else { pile.removeFromParent() }
            }
        }
    }

    /// A prop baked in its place in the room, then moved so its group can sit at the spot and turn round it.
    private static func bakedAround(_ object: RoomLayout.Object, _ parts: [PropPart]) -> [BakedPiece] {
        let placement = PropModels.placement(for: object)
        return SceneBake.bake(parts, placement: placement, wall: nil).map { $0.translated(by: -placement.position) }
    }

    // MARK: - Opening (SPEC 2.2 step 0)

    /// Before and while the box opens: its sides and lid are up, the board and the bench not in yet. Once the
    /// furniture is in, everything is as usual.
    func syncOpening(_ phase: OpeningPhase?) {
        guard attached, phase != openingPhase else { return }
        openingPhase = phase
        let closed = phase == .title || phase == .closed || phase == .opening
        if closed && slabs.isEmpty {
            for slab in Opening.slabs() {
                let entity = Entity()
                entity.position = slab.position
                for child in Diorama.entities(for: SceneBake.bake(slab.parts, placement: .init(position: .zero, rotationDegrees: 0), wall: nil)
                    .map { $0.translated(by: -slab.position) }) {
                    entity.addChild(child)
                }
                closedBox.addChild(entity)
                slabs.append((slab.side, entity))
            }
            lid.position = RoomLayout.room.centre + [0, Opening.lidHeight, 0]
            for child in Diorama.entities(for: SceneBake.bake(Opening.lid(), placement: .init(position: .zero, rotationDegrees: 0), wall: nil)) {
                lid.addChild(child)
            }
            closedBox.addChild(lid)
            poseBox(Opening.pose(at: 0))
        }
        if !closed {
            for child in Array(closedBox.children) { child.removeFromParent() }
            slabs = []
        }
        let furnished = phase == nil || phase == .done
        board.isEnabled = furnished || phase == .furnishing
        bench.isEnabled = board.isEnabled
        if furnished { furnish(at: Opening.furnishTime) }
        if phase == .furnishing { furnish(at: 0) }
    }

    /// The sides at their height and the lid where it has floated to.
    func poseBox(_ pose: Opening.Pose) {
        for slab in slabs {
            let height = Opening.slabHeight(slab.side, walls: pose.walls)
            slab.entity.scale = [1, max(0.0001, height / Opening.cubeHeight), 1]
            slab.entity.isEnabled = height > 0.01
        }
        lid.position = RoomLayout.room.centre + [0, Opening.lidHeight + pose.lidUp, 0]
        lid.orientation = simd_quatf(angle: pose.lidTilt, axis: [0, 0, 1])
        lid.isEnabled = pose.lidUp < 30
    }

    /// The whiteboard rolling in and the bench landing, `time` seconds after the box opened.
    func furnish(at time: Float) {
        for (group, object, move) in [(board, RoomLayout.Object.board, Opening.board(at: time)), (bench, .bench, Opening.bench(at: time))] {
            let placement = PropModels.placement(for: object)
            group.isEnabled = move.visible
            group.position = placement.position + move.offset
            group.orientation = simd_quatf(angle: move.turn, axis: [0, 1, 0]) * simd_quatf(angle: move.wobble.x, axis: [1, 0, 0])
                * simd_quatf(angle: move.wobble.y, axis: [0, 0, 1])
        }
    }

    /// A pile baked in place (with its shadow), then moved so it sits around its peg and scales from there.
    private static func pileEntity(_ plate: Plate) -> Entity {
        let pile = PropModels.pile(plate)
        let pieces = SceneBake.bake(pile.parts, placement: .init(position: pile.pivot, rotationDegrees: 0), wall: nil)
            .map { $0.translated(by: -pile.pivot) }
        let entity = Entity()
        entity.position = pile.pivot
        entity.scale = SIMD3(repeating: 0.001)
        for child in Diorama.entities(for: pieces) { entity.addChild(child) }
        return entity
    }

    /// The prototype's pile pop: a quick grow from the peg (or shrink back into it).
    private func pop(_ pile: Entity, in growing: Bool, delay: Double) {
        Task { @MainActor in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            var target = pile.transform
            target.scale = SIMD3(repeating: growing ? 1 : 0.001)
            _ = pile.move(to: target, relativeTo: pile.parent, duration: 0.3, timingFunction: growing ? .easeOut : .easeIn)
            if !growing {
                try? await Task.sleep(for: .seconds(0.3))
                pile.removeFromParent()
            }
        }
    }

    // MARK: - Session (SPEC 2.3)

    /// The kit drops onto the kit floor (heaviest first) the first time it's shown; the bar on the rack carries
    /// the set's plates, sliding off and on between sets like the prototype's showSet. Plates on the bar are
    /// missing from the floor.
    func syncSession(_ session: SessionProps?, animate: Bool) {
        guard attached else { return }
        guard let session else {
            for child in Array(kitFloor.children) + Array(barPlates.children) { child.removeFromParent() }
            kitItems = []; onBar = []; barSide = []; kit = nil; moving = []
            if barOnFloor { moveBar(down: false, animate: false) }
            if dimGoal > 0 || dim > 0 { dimGoal = 0; dim = 0; applyDim(0) }
            return
        }
        if session.kit != kit {
            kit = session.kit
            for child in Array(kitFloor.children) { child.removeFromParent() }
            let placed = SessionScene.kitFloor(session.kit, unit: session.unit)
            // Each plate sits in a holder: the holder hides it while it's on the bar, the plate itself drops.
            let plates = placed.map { Self.plateEntity($0) }
            kitItems = zip(placed, plates).map { placed, plate in
                let holder = Entity()
                holder.addChild(plate)
                kitFloor.addChild(holder)
                return (placed.plate.size, holder)
            }
            // Heaviest first, 0.16 s apart, dropped from 7–9.5 m with real physics, like the prototype.
            if animate {
                let order = placed.indices.sorted { placed[$0].plate.size > placed[$1].plate.size }
                for (n, index) in order.enumerated() {
                    physicsDrop(plates[index], placed[index], holder: kitItems[index].entity, after: 0.7 + Double(n) * 0.16)
                }
            }
        }
        if session.perSide != barSide { load(session.perSide, unit: session.unit, barWeight: session.barWeight, animate: animate) }
        if session.onFloor != barOnFloor { moveBar(down: session.onFloor, animate: animate) }
        dimGoal = session.dim ? 1 : 0
        if !animate && dim != dimGoal { dim = dimGoal; applyDim(dim) }
        // What's on the bar isn't on the floor.
        var onBarCount: [Double: Int] = [:]
        for plate in onBar { onBarCount[plate.size, default: 0] += 1 }
        var seen: [Double: Int] = [:]
        for item in kitItems {
            seen[item.size, default: 0] += 1
            item.entity.isEnabled = seen[item.size]! > (onBarCount[item.size] ?? 0)
        }
    }

    /// A plate as an entity at its spot: its body, and its shadow (hidden while it moves).
    private static func plateEntity(_ placed: SessionScene.PlacedPlate) -> Entity {
        let parts = SessionScene.parts(placed)
        let at = RoomLayout.Placement(position: placed.centre, rotationDegrees: 0)
        let entity = Entity()
        entity.position = placed.centre
        let body = Entity(), shadow = Entity()
        shadow.name = "shadow"
        for child in Diorama.entities(for: SceneBake.bake(parts, placement: at, wall: nil, content: .withoutShadows).map { $0.translated(by: -placed.centre) }) {
            body.addChild(child)
        }
        for child in Diorama.entities(for: SceneBake.bake(parts, placement: at, wall: nil, content: .shadowsOnly).map { $0.translated(by: -placed.centre) }) {
            shadow.addChild(child)
        }
        entity.addChild(body)
        entity.addChild(shadow)
        return entity
    }

    /// Changes the bar to `perSide` like the prototype's showSet: the plates that differ slide off the sleeve
    /// end, outermost first, 0.13 s apart, and drop to the floor; then the new ones slide on, innermost first, and
    /// seat with a clank.
    private func load(_ perSide: [Double], unit: WeightUnit, barWeight: Double, animate: Bool) {
        let kept = zip(barSide, perSide).prefix { $0 == $1 }.count
        let centre = RoomLayout.barOnRack.x
        let leaving = onBar.filter { $0.k >= kept }
        for plate in leaving {
            if animate, let found = Plate.find(plate.size, unit) {
                plate.entity.findEntity(named: "shadow")?.isEnabled = false
                let side: Float = plate.entity.position.x > centre ? 1 : -1
                moving.append(PlateMove(entity: plate.entity, plate: found, side: side, off: true,
                                        start: clock + Float(barSide.count - 1 - plate.k) * 0.13, x: plate.entity.position.x))
            } else {
                plate.entity.removeFromParent()
            }
        }
        onBar.removeAll { $0.k >= kept }
        let goingOff = barSide.count - kept
        let first = clock + (goingOff > 0 ? Float(goingOff) * 0.13 + 0.32 : 0.05)
        let placed = SessionScene.barPlates(perSide: perSide, unit: unit, barWeight: barWeight)
        for (index, plate) in placed.enumerated() where index / 2 >= kept {
            let entity = Self.plateEntity(plate)
            barPlates.addChild(entity)
            onBar.append((plate.plate.size, entity, index / 2))
            if animate {
                let side: Float = plate.centre.x > centre ? 1 : -1
                entity.findEntity(named: "shadow")?.isEnabled = false
                entity.position.x = centre + side * 1.5
                entity.isEnabled = false
                moving.append(PlateMove(entity: entity, plate: plate.plate, side: side, off: false,
                                        start: first + Float(index / 2 - kept) * 0.2 + (side > 0 ? 0.05 : 0), x: plate.centre.x))
            } else if barOnFloor {
                entity.findEntity(named: "shadow")?.isEnabled = false
            }
        }
        barSide = perSide
    }

    /// One frame of a plate's slide. Returns false once it's done.
    private func step(_ move: PlateMove) -> Bool {
        let centre = RoomLayout.barOnRack.x, t = clock - move.start, entity = move.entity
        guard t >= 0 else { return true }
        let radius = Float(move.plate.diameter) / 2
        if move.off {
            // Off the end of the sleeve (ease in), then a fall onto its face beside the rack, then it sinks away.
            let end = centre + move.side * (1.25 + radius * 0.2)
            if t < 0.32 {
                let q = t / 0.32
                entity.position.x = move.x + (end - move.x) * q * q
                return true
            }
            let f = t - 0.32, barY = RoomLayout.barOnRack.y + barGroup.position.y
            let y = max(radius * cos(min(1, f * 2.4) * 1.2), barY - 4.9 * f * f)
            entity.position = SIMD3(end + move.side * f * 0.5, y - barGroup.position.y, entity.position.z)
            entity.orientation = simd_quatf(angle: move.side * min(1, f * 2.4) * 1.2, axis: [0, 0, 1])
            if move.landed == nil && f > 0.2 && y <= radius + 0.01 { move.landed = clock }
            if let landed = move.landed {
                let k = min(1, max(0, (clock - landed - 0.35) / 0.35))
                entity.scale = SIMD3(repeating: max(0.001, 1 - k))
                if k >= 1 { entity.removeFromParent(); return false }
            }
            return true
        }
        // On: from the sleeve end to its place (ease out), then it seats with a clank and a small shiver.
        let q = t / 0.34
        entity.isEnabled = true
        if q < 1 {
            let e = 1 - pow(1 - q, 3), start = centre + move.side * 1.5
            entity.position.x = start + (move.x - start) * e
            return true
        }
        if move.landed == nil {
            move.landed = clock
            let kilos = move.plate.unit == .lb ? move.plate.size * 0.4536 : move.plate.size
            Sounds.clank(Float(kilos) / 25 + 0.15)
        }
        let since = clock - (move.landed ?? clock)
        entity.position.x = move.x + move.side * 0.012 * exp(-since * 14) * sin(since * 40)
        if since > 0.4 {
            entity.position.x = move.x
            entity.findEntity(named: "shadow")?.isEnabled = !barOnFloor
            return false
        }
        return true
    }

    /// The bar goes down onto the platform for pulls, and back up onto the J-hooks (prototype barTick: 0.75 s,
    /// cubic in and out). Its shadows only show on the rack.
    private func moveBar(down: Bool, animate: Bool) {
        barOnFloor = down
        let target = Transform(translation: down ? SessionScene.floorOffset : .zero)
        let shadows = [barShadow] + barPlates.children.compactMap { $0.findEntity(named: "shadow") }
        for shadow in shadows { shadow.isEnabled = false }
        guard animate else {
            barGroup.transform = target
            for shadow in shadows { shadow.isEnabled = !down }
            return
        }
        _ = barGroup.move(to: target, relativeTo: barGroup.parent, duration: 0.75, timingFunction: .easeInOut)
        if !down {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(0.75))
                guard let self, !self.barOnFloor else { return }
                for shadow in [self.barShadow] + self.barPlates.children.compactMap({ $0.findEntity(named: "shadow") }) {
                    shadow.isEnabled = true
                }
            }
        }
    }

    /// The prototype's kit drop (spawnKitPlate): a solid disc of the plate's mass, slightly tilted and spinning,
    /// let go 7–9.5 m above its spot; it lands, bounces a little and settles. Its shadow is drawn where it ends up.
    private func physicsDrop(_ entity: Entity, _ placed: SessionScene.PlacedPlate, holder: Entity, after delay: Double) {
        let radius = Float(placed.plate.diameter) / 2, thickness = Float(placed.plate.thickness)
        var rim: [SIMD3<Float>] = []
        for i in 0..<24 {
            let angle = Float(i) / 24 * 2 * .pi
            for y in [-thickness / 2, thickness / 2] { rim.append([radius * cos(angle), y, radius * sin(angle)]) }
        }
        entity.findEntity(named: "shadow")?.removeFromParent()
        entity.components.set(CollisionComponent(shapes: [ShapeResource.generateConvex(from: rim)]))
        entity.position = placed.centre + [0, Float.random(in: 7...9.5), 0]
        entity.orientation = simd_quatf(angle: .random(in: -0.11...0.11), axis: [1, 0, 0])
            * simd_quatf(angle: .random(in: 0...(2 * .pi)), axis: [0, 1, 0])
            * simd_quatf(angle: .random(in: -0.11...0.11), axis: [0, 0, 1])
        entity.isEnabled = false
        let kilos = placed.plate.unit == .lb ? placed.plate.size * 0.4536 : placed.plate.size
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            entity.components.set(PhysicsBodyComponent(massProperties: .init(mass: Float(kilos)), material: Self.rubber, mode: .dynamic))
            entity.components.set(PhysicsMotionComponent(linearVelocity: [0, -2, 0],
                                                         angularVelocity: [.random(in: -0.3...0.3), .random(in: -0.6...0.6), .random(in: -0.3...0.3)]))
            entity.isEnabled = true
            // Once it has settled, its shadow where it lies.
            try? await Task.sleep(for: .seconds(4))
            let pose = entity.transform.matrix
            let parts = SessionScene.parts(placed).map { part -> PropPart in
                let moved = part.mesh.positions.map { p -> SIMD3<Float> in
                    let q = pose * SIMD4(p.x, p.y, p.z, 1)
                    return SIMD3(q.x, q.y, q.z)
                }
                return PropPart(mesh: LowPolyMesh(positions: moved, indices: part.mesh.indices), tone: part.tone,
                                inked: part.inked, casts: part.casts)
            }
            let shadow = Entity()
            for child in Diorama.entities(for: SceneBake.bake(parts, placement: .init(position: .zero, rotationDegrees: 0),
                                                               wall: nil, content: .shadowsOnly)) {
                shadow.addChild(child)
            }
            holder.addChild(shadow)
        }
    }

    private func rebuild(_ group: Entity, _ pieces: [BakedPiece]) {
        for child in Array(group.children) { child.removeFromParent() }
        for child in Diorama.entities(for: pieces) { group.addChild(child) }
    }
}

/// What the stage shows during a session.
struct SessionProps: Equatable {
    var kit: Kit
    var unit: WeightUnit
    var barWeight: Double
    /// The plates on the bar now (the set in view); empty for an empty bar.
    var perSide: [Double]
    /// A pull: the bar is down on the platform.
    var onFloor = false
    /// A set is in view: the room dims behind the bar.
    var dim = false
}

/// A plate sliding on or off the bar.
final class PlateMove {
    let entity: Entity
    let plate: Plate
    /// −1 left sleeve, 1 right.
    let side: Float
    let off: Bool
    let start: Float
    /// Where it sits on the bar (coming on) or sat (going off), along X.
    let x: Float
    var landed: Float?

    init(entity: Entity, plate: Plate, side: Float, off: Bool, start: Float, x: Float) {
        self.entity = entity
        self.plate = plate
        self.side = side
        self.off = off
        self.start = start
        self.x = x
    }
}

/// Where the first run's opening is (SPEC 2.2 step 0): the title over the sky, the closed box waiting for a tap,
/// the box opening, the furniture coming in, then the gym setup.
enum OpeningPhase: Equatable {
    case title, closed, opening, furnishing, done
}

/// The static room, baked once for the whole app (it's the slow part) and copied for each stage: the copies share
/// their meshes and textures.
@MainActor
enum RoomTemplate {
    private static var world: Task<Entity, Never>?

    /// Starts the bake early, e.g. at launch.
    static func warmUp() { _ = template() }

    private static func template() -> Task<Entity, Never> {
        if let world { return world }
        let task = Task { @MainActor in
            let except = SetupProps.objects
            let pieces = await Task.detached(priority: .userInitiated) {
                SceneBake.pieces(plates: [], gymName: "", except: except)
            }.value
            return RoomScene.entities(pieces: pieces)[0]
        }
        world = task
        return task
    }

    /// A fresh world and camera for one stage.
    static func entities() async -> [Entity] {
        let world = await template().value.clone(recursive: true)
        let camera = PerspectiveCamera()
        camera.name = RoomScene.cameraName
        camera.camera.fieldOfViewInDegrees = 50
        return [world, camera]
    }
}
