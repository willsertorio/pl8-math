import RealityKit
import SwiftUI
import UIKit
import PlateKit

/// The 3D box as a stage behind the app's screens (SPEC 2.1): it flies to `station`, and the props the gym
/// setup changes follow the gym live — the flag shows the name, the shelf the unit's pegs with the gym's piles
/// popping on and off, the rack the gym's bar (SPEC 2.2). With `interactive`, drag to go round and pinch to zoom.
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

    @State private var orbit: Orbit
    @State private var dragStart: Orbit?
    @State private var pinchStart: Orbit?
    @State private var flight: Task<Void, Never>?
    @State private var props = SetupProps()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(station: RoomLayout.Station, gymName: String, unit: WeightUnit, plateSizes: [Double], barWeight: Double,
         boards: Boards = Boards(), session: SessionProps? = nil, interactive: Bool = false) {
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
            // The rest of the room is baked once, off the main thread; the setup's props are built here.
            let except = SetupProps.objects
            let pieces = await Task.detached(priority: .userInitiated) {
                SceneBake.pieces(plates: [], gymName: "", except: except)
            }.value
            let entities = RoomScene.entities(pieces: pieces)
            for entity in entities { content.add(entity) }
            if let world = entities.first(where: { $0.name == RoomScene.worldName }) {
                props.attach(to: world)
                props.sync(name: gymName, unit: unit, plateSizes: plateSizes, barWeight: barWeight, boards: boards, animate: false)
                props.syncSession(session, animate: !reduceMotion)
            }
            RoomScene.show(orbit, in: content.entities)
        } update: { content in
            props.sync(name: gymName, unit: unit, plateSizes: plateSizes, barWeight: barWeight, boards: boards, animate: !reduceMotion)
            props.syncSession(session, animate: !reduceMotion)
            RoomScene.show(orbit, in: content.entities)
        }
        .background(Theme.background)
        .gesture(gestures, including: interactive ? .all : .subviews)
        .onChange(of: station) { _, item in fly(to: item) }
        .onDisappear { flight?.cancel() }
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
        let path = Flight(from: orbit, to: destination, duration: Flight.duration(to: item))
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
    nonisolated static let objects: Set<RoomLayout.Object> = [.flag, .rack, .shelf, .prBoard, .board]

    private let flag = Entity(), rack = Entity(), shelf = Entity(), prBoard = Entity(), board = Entity()
    private var boards: Boards?
    private let kitFloor = Entity(), barPlates = Entity()
    private var kit: Kit?
    private var kitItems: [(size: Double, entity: Entity)] = []
    private var onBar: [(size: Double, entity: Entity, k: Int)] = []
    private var barSide: [Double] = []
    private var piles: [Double: Entity] = [:]
    private var name: String?, unit: WeightUnit?, barWeight: Double?
    private var attached = false

    func attach(to world: Entity) {
        for group in [flag, rack, shelf, prBoard, board, kitFloor, barPlates] { world.addChild(group) }
        attached = true
    }

    func sync(name: String, unit: WeightUnit, plateSizes: [Double], barWeight: Double, boards: Boards, animate: Bool) {
        guard attached else { return }
        if boards.prs != self.boards?.prs {
            rebuild(prBoard, SceneBake.bake(PropModels.parts(for: .prBoard, plates: [], boards: boards),
                                            placement: PropModels.placement(for: .prBoard), wall: nil))
        }
        if boards.workout != self.boards?.workout {
            rebuild(board, SceneBake.bake(PropModels.parts(for: .board, plates: [], boards: boards),
                                          placement: PropModels.placement(for: .board), wall: nil))
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
                flag.scale = [1, 0.01, 1]
                _ = flag.move(to: Transform(scale: .one, rotation: flag.orientation, translation: rod), relativeTo: flag.parent,
                          duration: 0.6, timingFunction: .easeOut)
            } else {
                flag.scale = .one
            }
        }
        if unit != self.unit || barWeight != self.barWeight {
            self.barWeight = barWeight
            rebuild(rack, SceneBake.bake(PropModels.parts(for: .rack, plates: [], barWeight: barWeight, unit: unit),
                                         placement: PropModels.placement(for: .rack), wall: nil))
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
            kitItems = []; onBar = []; barSide = []; kit = nil
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
            // Heaviest first, a beat apart, from a few metres up.
            if animate {
                let order = placed.indices.sorted { placed[$0].plate.size > placed[$1].plate.size }
                for (n, index) in order.enumerated() {
                    drop(plates[index], to: placed[index].centre, after: 0.4 + Double(n) * 0.12, from: 6 + Float(n % 3))
                }
            }
        }
        if session.perSide != barSide { load(session.perSide, unit: session.unit, barWeight: session.barWeight, animate: animate) }
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

    /// Changes the bar to `perSide`: the plates that differ come off from the outside in, then the new ones go on.
    private func load(_ perSide: [Double], unit: WeightUnit, barWeight: Double, animate: Bool) {
        let kept = zip(barSide, perSide).prefix { $0 == $1 }.count
        let sleeveEnd = RoomLayout.barOnRack.x
        for plate in onBar where plate.k >= kept {
            let entity = plate.entity
            if animate {
                let outward: Float = entity.position.x > sleeveEnd ? 1 : -1
                slide(entity, to: SIMD3(sleeveEnd + outward * 1.5, entity.position.y, entity.position.z),
                      after: Double(plate.k - kept) * 0.05, removing: true)
            } else {
                entity.removeFromParent()
            }
        }
        onBar.removeAll { $0.k >= kept }
        let placed = SessionScene.barPlates(perSide: perSide, unit: unit, barWeight: barWeight)
        for (index, plate) in placed.enumerated() where index / 2 >= kept {
            let entity = Self.plateEntity(plate)
            barPlates.addChild(entity)
            onBar.append((plate.plate.size, entity, index / 2))
            if animate {
                let outward: Float = plate.centre.x > sleeveEnd ? 1 : -1
                let target = plate.centre
                entity.position = SIMD3(sleeveEnd + outward * 1.5, target.y, target.z)
                entity.findEntity(named: "shadow")?.isEnabled = false
                slide(entity, to: target, after: 0.3 + Double(index / 2 - kept) * 0.2, removing: false)
            }
        }
        barSide = perSide
    }

    private func drop(_ entity: Entity, to target: SIMD3<Float>, after delay: Double, from height: Float) {
        entity.position = target + SIMD3(0, height, 0)
        entity.isEnabled = false
        entity.findEntity(named: "shadow")?.isEnabled = false
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            entity.isEnabled = true
            _ = entity.move(to: Transform(scale: .one, rotation: entity.orientation, translation: target), relativeTo: entity.parent,
                            duration: 0.55, timingFunction: .easeIn)
            try? await Task.sleep(for: .seconds(0.55))
            entity.findEntity(named: "shadow")?.isEnabled = true
            // A small bounce as it lands.
            _ = entity.move(to: Transform(scale: .one, rotation: entity.orientation, translation: target + [0, 0.05, 0]),
                            relativeTo: entity.parent, duration: 0.1, timingFunction: .easeOut)
            try? await Task.sleep(for: .seconds(0.1))
            _ = entity.move(to: Transform(scale: .one, rotation: entity.orientation, translation: target), relativeTo: entity.parent,
                            duration: 0.1, timingFunction: .easeIn)
        }
    }

    private func slide(_ entity: Entity, to target: SIMD3<Float>, after delay: Double, removing: Bool) {
        Task { @MainActor in
            entity.findEntity(named: "shadow")?.isEnabled = false
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            _ = entity.move(to: Transform(scale: .one, rotation: entity.orientation, translation: target), relativeTo: entity.parent,
                            duration: 0.35, timingFunction: .easeInOut)
            try? await Task.sleep(for: .seconds(0.35))
            if removing { entity.removeFromParent() } else { entity.findEntity(named: "shadow")?.isEnabled = true }
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
}
