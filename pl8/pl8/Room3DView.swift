import Foundation
import RealityKit
import SwiftData
import SwiftUI
import UIKit
import PlateKit

/// The 3D box (M6): the room, its stations and camera shots (SPEC 2.1), copied from the prototype and baked by
/// PlateKit. Drag to go round, pinch to zoom; a camera chip flies to its shot.
struct Room3DView: View {
    @State private var station: RoomLayout.Station

    init(station: RoomLayout.Station = .overview) {
        _station = State(initialValue: station)
    }
    @Query private var gyms: [Gym]
    @Query private var records: [PersonalRecord]
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    private var gym: Gym? { Gym.current(in: gyms) }

    /// Your PRs on the board, today's workout on the whiteboard.
    private var boards: Boards {
        let today = workouts.first { Calendar.current.isDateInToday($0.date) }
        return Boards(prs: Planner.boardRows(records), workout: Planner.boardLines(for: today, gym: gym, records: records))
    }

    var body: some View {
        VStack(spacing: 0) {
            RoomStage(station: station, gymName: gym?.name ?? "", unit: gym?.unit ?? .kg,
                      plateSizes: gym?.plateSizes ?? Plate.catalog(.kg).map(\.size),
                      barWeight: gym?.barWeight ?? 20, boards: boards, interactive: true)

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

/// Builds the room from PlateKit's bake, and points the camera.
@MainActor
enum RoomScene {
    static let worldName = "world"
    static let cameraName = "camera"
    static let skyName = "sky"

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
        case .kitFloor: "Kit (session)"
        case .sleeve: "Sleeve (session)"
        case .far: "Opening"
        case .sleeveFloor: "Sleeve, floor (session)"
        }
    }

    /// Moves the room so the camera sits where `orbit` says, sets the field of view, and cuts away the walls
    /// between the camera and the room. `box` moves the box itself (the opening's pop, turn and float); `screen`
    /// moves everything as seen from the camera (the tilt effects); the sky stays put.
    static func show(_ orbit: Orbit, box: simd_float4x4 = matrix_identity_float4x4, screen: simd_float4x4 = matrix_identity_float4x4,
                     in entities: some Sequence<Entity>) {
        if let world = entities.first(where: { $0.name == worldName }) {
            let view = Diorama.worldTransform(target: orbit.target, position: orbit.position).matrix
            let whole = screen * view * box
            world.transform = Transform(matrix: whole)
            let camera = whole.inverse * SIMD4<Float>(0, 0, 0, 1)
            Diorama.showWalls(from: SIMD3(camera.x, camera.y, camera.z), in: world)
            if let sky = world.findEntity(named: skyName) {
                sky.transform = Transform(matrix: box.inverse * Transform(translation: RoomLayout.room.centre).matrix)
            }
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
            sky.name = skyName
            world.addChild(sky)
        }
        for entity in Diorama.entities(for: pieces) { world.addChild(entity) }

        let camera = PerspectiveCamera()
        camera.name = cameraName
        camera.camera.fieldOfViewInDegrees = 50
        return [world, camera]
    }
}
