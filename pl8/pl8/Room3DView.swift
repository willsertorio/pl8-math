import RealityKit
import SwiftUI
import UIKit
import PlateKit

/// M6 step 1: the room, its stations and the camera shots (SPEC 2.1), with stand-in furniture.
struct Room3DView: View {
    @State private var station: RoomLayout.Station = .overview

    var body: some View {
        VStack(spacing: 0) {
            RealityView { content in
                for entity in RoomScene.entities() {
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

/// Builds the room from RoomLayout: floor with tile lines, three walls, and stand-ins for each station.
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

    static func entities() -> [Entity] {
        let world = Entity()
        world.name = worldName
        let room = RoomLayout.room
        let centre = room.centre
        let wallLine: Float = 0.03
        let propLine: Float = 0.015

        // Backdrop: the flat orange all around (inside-out box, exact colour).
        world.addChild(Diorama.flatPart(LowPolyMesh.box(size: [300, 300, 300]).insideOut(), colour: Diorama.background, at: centre))

        // Floor slab, a little bigger than the tiles, and the tile lines.
        world.addChild(Diorama.part(.box(size: [room.width + 0.32, 0.3, room.depth + 0.32]), colour: Diorama.boxLight,
                                    outline: wallLine, at: [centre.x, -0.15, centre.z]))
        for i in 1..<Int(room.width) {
            world.addChild(Diorama.flatPart(.box(size: [0.012, 0.004, room.depth]), colour: Diorama.ink,
                                            at: [room.minX + Float(i), 0.002, centre.z]))
        }
        for j in 1..<Int(room.depth) {
            world.addChild(Diorama.flatPart(.box(size: [room.width, 0.004, 0.012]), colour: Diorama.ink,
                                            at: [centre.x, 0.002, room.minZ + Float(j)]))
        }

        // Back, left and right walls (the front is open, like a diorama).
        let h = room.wallHeight, t = room.wallThickness
        world.addChild(Diorama.part(.box(size: [room.width + 2 * t, h, t]), colour: Diorama.boxLight, outline: wallLine,
                                    at: [centre.x, h / 2, room.minZ - t / 2]))
        world.addChild(Diorama.part(.box(size: [t, h, room.depth + 2 * t]), colour: Diorama.boxLight, outline: wallLine,
                                    at: [room.minX - t / 2, h / 2, centre.z]))
        world.addChild(Diorama.part(.box(size: [t, h, room.depth + 2 * t]), colour: Diorama.boxLight, outline: wallLine,
                                    at: [room.maxX + t / 2, h / 2, centre.z]))

        for entity in stations(line: propLine) { world.addChild(entity) }

        let camera = PerspectiveCamera()
        camera.name = cameraName
        camera.camera.fieldOfViewInDegrees = 50

        // Sun from the front right and a softer fill, fixed to the room.
        let sun = DirectionalLight()
        sun.light.intensity = 2500
        sun.look(at: .zero, from: [3, 6, 4], relativeTo: nil)
        world.addChild(sun)
        let fill = DirectionalLight()
        fill.light.intensity = 900
        fill.look(at: .zero, from: [-4, 3, -2], relativeTo: nil)
        world.addChild(fill)

        return [world, camera]
    }

    /// Stand-ins for each station, placed from the layout. Detailed models come in later M6 steps.
    private static func stations(line: Float) -> [Entity] {
        let layout = RoomLayout.objects
        var parts: [Entity] = []

        if let platform = layout[.platform] {
            parts.append(Diorama.part(.box(size: [2.44, 0.06, 2.44]), colour: Diorama.wood, outline: line,
                                      at: platform.position + [0, 0.03, 0]))
        }

        // The rack: two uprights and a top bar, with the barbell resting at 1.22 m.
        let bar = RoomLayout.barOnRack
        for side: Float in [-0.6, 0.6] {
            parts.append(Diorama.part(.box(size: [0.08, 2.3, 0.08]), colour: Diorama.rubber, outline: line,
                                      at: [bar.x + side, 1.15, bar.z]))
        }
        parts.append(Diorama.part(.box(size: [1.28, 0.08, 0.08]), colour: Diorama.rubber, outline: line, at: [bar.x, 2.3, bar.z]))
        let barbell: [LowPolyMesh] = [
            .cylinder(radius: 0.014, length: 1.31, sides: 20),
            LowPolyMesh.cylinder(radius: 0.04, length: 0.03, sides: 20).translated(by: [0.67, 0, 0]),
            LowPolyMesh.cylinder(radius: 0.04, length: 0.03, sides: 20).translated(by: [-0.67, 0, 0]),
            LowPolyMesh.cylinder(radius: 0.025, length: 0.415, sides: 20).translated(by: [0.8925, 0, 0]),
            LowPolyMesh.cylinder(radius: 0.025, length: 0.415, sides: 20).translated(by: [-0.8925, 0, 0]),
        ]
        for piece in barbell {
            parts.append(Diorama.part(piece, colour: Diorama.steel, outline: 0.006, at: bar))
        }

        if let bench = layout[.bench] {
            parts.append(Diorama.part(.box(size: [1.2, 0.45, 0.32]), colour: Diorama.rubber, outline: line,
                                      at: bench.position + [0, 0.225, 0], rotationDegrees: bench.rotationDegrees))
        }

        // The whiteboard on two legs, turned 25°.
        if let board = layout[.board] {
            let group = Entity()
            group.position = board.position
            group.orientation = simd_quatf(angle: board.rotationDegrees * .pi / 180, axis: [0, 1, 0])
            group.addChild(Diorama.part(.box(size: [1.6, 1.05, 0.05]), colour: Diorama.paper, outline: line, at: [0, 1.5, 0]))
            for side: Float in [-0.7, 0.7] {
                group.addChild(Diorama.part(.box(size: [0.05, 1.0, 0.05]), colour: Diorama.rubber, outline: line, at: [side, 0.5, 0]))
            }
            parts.append(group)
        }

        if let shelf = layout[.shelf] {
            parts.append(Diorama.part(.box(size: [2.4, 0.06, 0.45]), colour: Diorama.wood, outline: line,
                                      at: shelf.position, rotationDegrees: shelf.rotationDegrees))
        }
        if let flag = layout[.flag] {
            parts.append(Diorama.part(.box(size: [1.6, 0.55, 0.02]), colour: Diorama.paper, outline: line,
                                      at: flag.position, rotationDegrees: flag.rotationDegrees))
        }
        if let pr = layout[.prBoard] {
            parts.append(Diorama.part(.box(size: [1.4, 1.0, 0.04]), colour: Diorama.rubber, outline: line,
                                      at: pr.position, rotationDegrees: pr.rotationDegrees))
        }
        if let holder = layout[.barHolder] {
            parts.append(Diorama.part(.box(size: [0.3, 1.3, 0.25]), colour: Diorama.rubber, outline: line,
                                      at: holder.position + [-0.15, 0.65, 0], rotationDegrees: holder.rotationDegrees))
        }
        return parts
    }
}
