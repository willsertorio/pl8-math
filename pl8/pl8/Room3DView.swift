import RealityKit
import SwiftData
import SwiftUI
import UIKit
import PlateKit

/// The 3D box (M6): the room, its stations and camera shots (SPEC 2.1), copied from the prototype and baked by
/// PlateKit. Drag to go round, pinch to zoom; a camera chip flies back to its shot.
struct Room3DView: View {
    @State private var station: RoomLayout.Station = .overview
    @State private var orbit = Orbit(RoomLayout.shots[.overview]!)
    @State private var dragStart: Orbit?
    @State private var pinchStart: Orbit?
    @Query private var gyms: [Gym]

    private var gym: Gym? { gyms.first(where: { $0.isCurrent }) ?? gyms.first }

    /// The current gym's plates hang on the shelf.
    private var plates: [Plate] {
        guard let gym else { return Plate.catalog(.kg) }
        return Plate.catalog(gym.unit).filter { gym.plateSizes.contains($0.size) }
    }

    var body: some View {
        VStack(spacing: 0) {
            RealityView { content in
                let plates = plates, name = gym?.name ?? ""
                // Baking takes a moment: do it off the main thread, then build the models.
                let pieces = await Task.detached(priority: .userInitiated) {
                    SceneBake.pieces(plates: plates, gymName: name)
                }.value
                for entity in RoomScene.entities(pieces: pieces) {
                    content.add(entity)
                }
                RoomScene.show(orbit, in: content.entities)
            } update: { content in
                RoomScene.show(orbit, in: content.entities)
            }
            .background(Theme.background)
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        let start = dragStart ?? orbit
                        dragStart = start
                        orbit = start.dragged(dx: Float(value.translation.width), dy: Float(value.translation.height))
                    }
                    .onEnded { _ in dragStart = nil }
                    .simultaneously(with: MagnifyGesture()
                        .onChanged { value in
                            let start = pinchStart ?? orbit
                            pinchStart = start
                            orbit = start.zoomed(by: Float(value.magnification))
                        }
                        .onEnded { _ in pinchStart = nil })
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("Camera").sectionLabel()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(RoomLayout.Station.allCases, id: \.self) { item in
                            Chip(isOn: item == station, action: {
                                station = item
                                orbit = Orbit(RoomLayout.shots[item]!)
                            }) {
                                Text(RoomScene.title(item))
                            }
                            .fixedSize()
                        }
                    }
                    .padding(2)
                }
                .sensoryFeedback(.selection, trigger: station)
            }
            .drawer()
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("3D room")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Builds the room from PlateKit's bake, and points the camera.
@MainActor
enum RoomScene {
    static let worldName = "world"
    static let cameraName = "camera"

    static func title(_ station: RoomLayout.Station) -> String {
        switch station {
        case .overview: "Overview"
        case .corner: "Plate shelf"
        case .nameFlag: "Flag (name)"
        case .flag: "Flag"
        case .bar: "Bar holder"
        case .pr: "PR board"
        case .board: "Whiteboard"
        case .kit: "Kit floor"
        case .setv: "Rack"
        }
    }

    /// Moves the room so the camera sits where `orbit` says, sets the field of view, and cuts away the walls
    /// between the camera and the room.
    static func show(_ orbit: Orbit, in entities: some Sequence<Entity>) {
        if let world = entities.first(where: { $0.name == worldName }) {
            world.transform = Diorama.worldTransform(target: orbit.target, position: orbit.position)
            Diorama.showWalls(from: orbit.position, in: world)
        }
        if let camera = entities.first(where: { $0.name == cameraName }) as? PerspectiveCamera {
            camera.camera.fieldOfViewInDegrees = orbit.fieldOfView
        }
    }

    static func entities(pieces: [BakedPiece]) -> [Entity] {
        let world = Entity()
        world.name = worldName
        // Backdrop: the flat orange all around (inside-out box, exact colour).
        if let sky = try? ModelEntity(mesh: Diorama.meshResource(LowPolyMesh.box(size: [300, 300, 300]).insideOut()),
                                      materials: [Diorama.flat(Diorama.background)]) {
            sky.position = RoomLayout.room.centre
            world.addChild(sky)
        }
        for entity in Diorama.entities(for: pieces) { world.addChild(entity) }

        let camera = PerspectiveCamera()
        camera.name = cameraName
        camera.camera.fieldOfViewInDegrees = 50
        return [world, camera]
    }
}
