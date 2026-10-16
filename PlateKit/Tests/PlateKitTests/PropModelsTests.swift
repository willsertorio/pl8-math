import Testing
@testable import PlateKit

@Suite("Props, copied from the prototype's builders")
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

    @Test func barbellOnTheRackIsSteel() {
        let steel = PropModels.parts(for: .rack, plates: []).filter { if case .metal = $0.tone { true } else { false } }
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
        let faces = parts.filter { if case .picture(.plateFace) = $0.tone { true } else { false } }
        // Bumpers 6, 5, 6, 5; change plates 8, 6, 8, 6, 8, 6 (the prototype's piles).
        #expect(faces.count == 22 + 42)
        #expect(parts.contains { $0.tone == .picture(.plateFace(Plate.find(25, .kg)!)) })
    }

    @Test func onlyTheGymsPlatesAreOnTheShelf() {
        let parts = PropModels.parts(for: .shelf, plates: [Plate.find(20, .kg)!])
        #expect(parts.filter { $0.tone == .picture(.plateFace(Plate.find(20, .kg)!)) }.count == 5)   // its own peg: 5 plates
    }

    @Test func platesHavePrintedFacesARimAndAChromeHub() {
        let plate = Plate.find(25, .kg)!
        let parts = PropModels.plateParts(plate)
        let face = parts.first { $0.tone == .picture(.plateFace(plate)) }!
        #expect(face.mesh.uvs.count == face.mesh.positions.count)
        #expect(face.mesh.uvs.allSatisfy { $0.x >= -0.001 && $0.x <= 1.001 && $0.y >= -0.001 && $0.y <= 1.001 })
        #expect(parts.contains { $0.tone == .metal(RGB(hex: "#D8DCE1")) })                    // hub
        #expect(parts.contains { $0.tone == .paint(RGB(hex: plate.colorHex).offsetLightness(-0.05)) })   // rim
        let xs = parts.flatMap { $0.mesh.positions.map(\.x) }
        #expect(abs((xs.max() ?? 0) - (0.056 + 0.005) / 2) < 0.001)                         // the hub stands proud
    }

    @Test func shelfIsAlreadyInRoomSpace() {
        #expect(PropModels.placement(for: .shelf).position == .zero)
        #expect(PropModels.placement(for: .rack) == RoomLayout.objects[.rack])
        let xs = PropModels.parts(for: .shelf, plates: Plate.catalog(.kg)).flatMap { $0.mesh.positions.map(\.x) }
        #expect(abs((xs.min() ?? 0) - (RoomLayout.room.minX + 0.06)) < 0.01)     // against the left wall
    }

    @Test func rackUprightsHavePunchedHoles() {
        let holes = PropModels.parts(for: .rack, plates: []).filter { $0.tone == .light && !$0.inked }
        #expect(holes.count >= 40)                                     // a column of holes on each upright
    }

    @Test func noLeftWallWindowOrBenchClutter() {
        // The prototype hides its first room (with a window strip on the left wall) and removed the notebook
        // and bottle from the bench.
        let walls = RoomLayout.Wall.allCases.flatMap { PropModels.wall($0) }
        #expect(walls.count == 6)                                      // a wall and its floor line, each
        #expect(PropModels.parts(for: .bench, plates: []).allSatisfy { $0.mesh.positions.allSatisfy { $0.y < 0.5 } })
    }

    @Test func wallPropsHangOnTheRightWall() {
        #expect(RoomLayout.Object.wallFan.wall == .right)
        #expect(RoomLayout.Object.barHolder.wall == .right)
        #expect(RoomLayout.Object.wallWindow.wall == .right)
        #expect(RoomLayout.Object.flag.wall == nil)                    // the prototype keeps these up
        #expect(RoomLayout.Object.prBoard.wall == nil)
    }

    @Test func wallFanHasBladesGuardAndCable() {
        let fan = PropModels.parts(for: .wallFan, plates: [])
        #expect(fan.count >= 20)
        let zs = fan.flatMap { $0.mesh.positions.map(\.z) }
        #expect((zs.max() ?? 0) > 0.5)                                 // the head stands off the wall
    }

    @Test func flagCarriesTheGymName() {
        #expect(PropModels.parts(for: .flag, plates: [], gymName: "SS").contains { $0.tone == .picture(.flag("SS")) })
    }
}
