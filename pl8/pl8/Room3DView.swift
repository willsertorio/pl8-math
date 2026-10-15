import RealityKit
import SwiftData
import SwiftUI
import UIKit
import PlateKit

/// M6 step 1: the room, its stations and the camera shots (SPEC 2.1), with stand-in furniture.
struct Room3DView: View {
    @State private var station: RoomLayout.Station = .overview
    @Query private var gyms: [Gym]

    /// The current gym's plates hang on the shelf.
    private var plates: [Plate] {
        guard let gym = gyms.first(where: { $0.isCurrent }) ?? gyms.first else { return Plate.catalog(.kg) }
        return Plate.catalog(gym.unit).filter { gym.plateSizes.contains($0.size) }
    }

    var body: some View {
        VStack(spacing: 0) {
            RealityView { content in
                for entity in RoomScene.entities(plates: plates) {
                    content.add(entity)
                }
                RoomScene.show(station, in: content.entities)
            } update: { content in
                RoomScene.show(station, in: content.entities)
            }
            .background(Theme.background)

            VStack(alignment: .leading, spacing: 10) {
                Text("Camera").sectionLabel()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(RoomLayout.Station.allCases, id: \.self) { item in
                            Chip(isOn: item == station, action: { station = item }) {
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

/// Builds the room from PlateKit's recipes (RoomLayout + PropModels), ported from the prototype.
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

    /// Moves the room so `station`'s shot is in front of the camera, and sets the camera's field of view.
    static func show(_ station: RoomLayout.Station, in entities: some Sequence<Entity>) {
        guard let shot = RoomLayout.shots[station] else { return }
        entities.first { $0.name == worldName }?.transform = Diorama.worldTransform(for: shot)
        if let camera = entities.first(where: { $0.name == cameraName }) as? PerspectiveCamera {
            camera.camera.fieldOfViewInDegrees = shot.fieldOfView
        }
    }

    /// - Parameter plates: the gym's plates, for the shelf piles.
    static func entities(plates: [Plate]) -> [Entity] {
        let world = Entity()
        world.name = worldName
        let room = RoomLayout.room

        // Backdrop: the flat orange all around (inside-out box, exact colour).
        world.addChild(Diorama.flatPart(LowPolyMesh.box(size: [300, 300, 300]).insideOut(), colour: Diorama.background, at: room.centre))

        world.addChild(Diorama.prop(PropModels.room(), line: 0.03,
                                    placement: RoomLayout.Placement(position: .zero, rotationDegrees: 0), name: "room"))
        for object in RoomLayout.Object.allCases {
            let parts = PropModels.parts(for: object, plates: plates)
            guard !parts.isEmpty else { continue }
            world.addChild(Diorama.prop(parts, line: object == .shelf ? 0.006 : 0.012,
                                        placement: PropModels.placement(for: object), name: object.rawValue))
        }

        let camera = PerspectiveCamera()
        camera.name = cameraName
        camera.camera.fieldOfViewInDegrees = 50

        // Sun from the front right and a softer fill, fixed to the room.
        let sun = DirectionalLight()
        sun.light.intensity = 3500
        sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: 25, depthBias: 2)
        sun.look(at: .zero, from: [3, 6, 4], relativeTo: nil)
        world.addChild(sun)
        let fill = DirectionalLight()
        fill.light.intensity = 1500
        fill.look(at: .zero, from: [-4, 3, -2], relativeTo: nil)
        world.addChild(fill)

        return [world, camera]
    }
}
