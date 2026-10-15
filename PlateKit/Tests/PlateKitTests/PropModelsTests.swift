import Testing
@testable import PlateKit

@Suite("Props, ported from the prototype's builders")
struct PropModelsTests {
    @Test func cylindersCanStandOnAnyAxis() {
        let upright = LowPolyMesh.cylinder(radius: 0.1, length: 2, sides: 8, axis: .y)
        #expect(abs((upright.positions.map(\.y).max() ?? 0) - 1) < 1e-5)
        #expect((upright.positions.map(\.x).max() ?? 0) <= 0.1001)
        let deep = LowPolyMesh.cylinder(radius: 0.1, length: 2, sides: 8, axis: .z)
        #expect(abs((deep.positions.map(\.z).min() ?? 0) + 1) < 1e-5)
        // Turning the shape keeps its faces pointing out.
        for triangle in 0..<upright.triangleCount {
            #expect(upright.faceNormal(triangle).dot(upright.faceCentre(triangle)) > 0)
        }
    }

    @Test func everyObjectHasParts() {
        for object in RoomLayout.Object.allCases where object != .kitPlates {
            #expect(!PropModels.parts(for: object, plates: Plate.catalog(.kg)).isEmpty, "\(object)")
        }
    }

    @Test func twoTonesOnlyPlusSteelAndPlates() {
        // The prototype draws in black and white, recoloured to the palette's dark and light (SPEC 2.5).
        let tones = Set(RoomLayout.Object.allCases.flatMap { PropModels.parts(for: $0, plates: []) }.map(\.tone))
        #expect(tones.isSubset(of: [.dark, .light, .steel, .faint]))
    }

    @Test func barbellOnTheRackIsSteel() {
        let steel = PropModels.parts(for: .rack, plates: []).filter { $0.tone == .steel }
        #expect(steel.count == 13)                                     // centre + 6 pieces per side
        let xs = steel.flatMap { $0.mesh.positions.map(\.x) }
        #expect(abs((xs.max() ?? 0) - 1.1) < 0.001)                    // 2.2 m bar
    }

    @Test func rackArmsReachTheBackWall() {
        let rack = RoomLayout.objects[.rack]!.position
        let zs = PropModels.parts(for: .rack, plates: []).flatMap { $0.mesh.positions.map(\.z) }
        #expect(abs(rack.z + (zs.min() ?? 0) - RoomLayout.room.minZ) < 0.05)
    }

    @Test func plateShelfHasPilesOfEachSize() {
        let parts = PropModels.parts(for: .shelf, plates: Plate.catalog(.kg))
        let plates = parts.filter { if case .plate = $0.tone { return true } else { return false } }
        // Bumpers 6, 5, 6, 5; change plates 8, 6, 8, 6, 8, 6 (the prototype's piles).
        #expect(plates.count == 22 + 42)
        #expect(parts.contains { $0.tone == .plate(Plate.find(25, .kg)!) })
    }

    @Test func onlyTheGymsPlatesAreOnTheShelf() {
        let parts = PropModels.parts(for: .shelf, plates: [Plate.find(20, .kg)!])
        #expect(parts.filter { $0.tone == .plate(Plate.find(20, .kg)!) }.count == 6)
    }

    @Test func roomHasFloorWallsAndLines() {
        let room = PropModels.room()
        #expect(room.contains { $0.tone == .light && $0.outlined })    // floor and walls
        #expect(room.contains { $0.tone == .faint && !$0.outlined })   // tile seams: faint hairlines, like the prototype
    }

    @Test func shelfIsAlreadyInRoomSpace() {
        #expect(PropModels.placement(for: .shelf).position == .zero)
        #expect(PropModels.placement(for: .rack) == RoomLayout.objects[.rack])
        let xs = PropModels.parts(for: .shelf, plates: Plate.catalog(.kg)).flatMap { $0.mesh.positions.map(\.x) }
        #expect(abs((xs.min() ?? 0) - (RoomLayout.room.minX + 0.06)) < 0.01)     // against the left wall
    }

    @Test func rackUprightsHavePunchedHoles() {
        let holes = PropModels.parts(for: .rack, plates: []).filter { $0.tone == .light && !$0.outlined }
        #expect(holes.count >= 40)                                     // a column of holes on each upright
    }
}
