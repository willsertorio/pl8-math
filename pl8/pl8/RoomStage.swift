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
    var interactive = false

    @State private var orbit: Orbit
    @State private var dragStart: Orbit?
    @State private var pinchStart: Orbit?
    @State private var flight: Task<Void, Never>?
    @State private var props = SetupProps()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(station: RoomLayout.Station, gymName: String, unit: WeightUnit, plateSizes: [Double], barWeight: Double,
         boards: Boards = Boards(), interactive: Bool = false) {
        self.boards = boards
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
            }
            RoomScene.show(orbit, in: content.entities)
        } update: { content in
            props.sync(name: gymName, unit: unit, plateSizes: plateSizes, barWeight: barWeight, boards: boards, animate: !reduceMotion)
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
    private var piles: [Double: Entity] = [:]
    private var name: String?, unit: WeightUnit?, barWeight: Double?
    private var attached = false

    func attach(to world: Entity) {
        for group in [flag, rack, shelf, prBoard, board] { world.addChild(group) }
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

    private func rebuild(_ group: Entity, _ pieces: [BakedPiece]) {
        for child in Array(group.children) { child.removeFromParent() }
        for child in Diorama.entities(for: pieces) { group.addChild(child) }
    }
}
