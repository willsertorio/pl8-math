import Testing
@testable import PlateKit

@Suite("Baked sunlight, shadows and rough edges (M6, matching the prototype)")
struct SunlightTests {
    let room = RoomLayout.room

    @Test func lightMatchesThePrototype() {
        // three.js Lambert, sky 2.7 + sun 1.5: box light in full sun is the prototype's #FFF9FF floor.
        #expect(Look.lit(Look.boxLight, sun: Sunlight.towardsSun.y).hex == "#FFF9FF")
        #expect(Look.sunStep(normal: [1, 0, 0]) == 0)                         // the left wall faces away
        #expect(Look.sunStep(normal: [0, 1, 0]) > Look.sunStep(normal: [0, 0, 1]))
        let shade = Look.lit(Look.boxLight, sun: 0)
        #expect(shade.r < 0.92 && shade.r > 0.85)                              // a soft lavender, not grey
    }

    var floor: Sunlight.Receiver { Sunlight.receivers[0] }
    var backWall: Sunlight.Receiver { Sunlight.receivers[1] }
    var rightWall: Sunlight.Receiver { Sunlight.receivers[2] }

    @Test func aBoxCastsItsShadowAwayFromTheSun() {
        let box = LowPolyMesh.box(size: [0.5, 1, 0.5]).translated(by: [0, 0.5, 0])
        let shadow = Sunlight.shadow(of: box, on: floor)
        #expect(shadow.triangleCount > 0)
        #expect(shadow.positions.allSatisfy { abs($0.y - Sunlight.floorLift) < 0.0001 })   // flat on the floor
        let xs = shadow.positions.map(\.x), zs = shadow.positions.map(\.z)
        #expect((xs.max() ?? 0) > 0.6)                                         // the sun is front-left: the shadow goes right…
        #expect((zs.min() ?? 0) < -0.6)                                        // …and back
        #expect(shadow.faceNormal(0).y > 0.99)                                 // facing up, so it shows
    }

    @Test func shadowClimbsTheBackWall() {
        let post = LowPolyMesh.box(size: [0.2, 2, 0.2]).translated(by: [0, 1, room.minZ + 0.3])
        let onWall = Sunlight.shadow(of: post, on: backWall).positions
        #expect(!onWall.isEmpty && onWall.allSatisfy { abs($0.z - (room.minZ + Sunlight.wallLift)) < 0.0001 })
        #expect(Sunlight.shadow(of: post, on: floor).positions.allSatisfy { $0.z >= room.minZ })   // cut to the room
    }

    @Test func wallFanShadowFallsOnTheRightWall() {
        let fan = LowPolyMesh.box(size: [0.1, 0.4, 0.4]).translated(by: [room.maxX - 0.1, 2, -2.75])
        let onWall = Sunlight.shadow(of: fan, on: rightWall).positions
        #expect(!onWall.isEmpty && onWall.allSatisfy { abs($0.x - (room.maxX - Sunlight.wallLift)) < 0.0001 })
        #expect(onWall.allSatisfy { $0.y < 2.2 && $0.z < -2.5 })               // lower and further back than the fan
    }

    @Test func placingRotatesAroundYThenMoves() {
        let bar = LowPolyMesh.box(size: [2, 0.1, 0.1])
        let placed = bar.placed(RoomLayout.Placement(position: [1, 0, 1], rotationDegrees: 90))
        let xs = placed.positions.map(\.x), zs = placed.positions.map(\.z)
        #expect(abs((xs.max() ?? 0) - (xs.min() ?? 0) - 0.1) < 0.001)          // now along Z
        #expect(abs((zs.max() ?? 0) - (zs.min() ?? 0) - 2) < 0.001)
        #expect(abs((xs.max() ?? 0) - 1.05) < 0.001)
    }

    @Test func roughEdgeIsBrokenAndWobbly() {
        let edge = LowPolyMesh.roughEdge(from: [0, 0, 0], to: [4, 0, 0], width: 0.04, seed: 1)
        let pieces = edge.triangleCount / 12
        let full = Int(4 / LowPolyMesh.roughStep)
        #expect(pieces > full / 2 && pieces < full)                            // grain: some pieces drop out
        let ys = edge.positions.map(\.y)
        #expect((ys.max() ?? 0) - (ys.min() ?? 0) > 0.05)                      // wobbles off the straight line
        #expect(edge.positions.allSatisfy { $0.x >= -0.05 && $0.x <= 4.05 })
        #expect(edge == LowPolyMesh.roughEdge(from: [0, 0, 0], to: [4, 0, 0], width: 0.04, seed: 1))   // the same every launch
    }

    @Test func roomHasRoughBorderOnItsOuterEdges() {
        let top = PropModels.border(.back).flatMap { $0.mesh.positions.map(\.y) }
        #expect((top.max() ?? 0) > room.wallHeight - 0.05)                     // along the wall tops
        let slab = PropModels.border(nil).flatMap { $0.mesh.positions.map(\.y) }
        #expect((slab.min() ?? 0) < -0.25)                                     // and the bottom of the floor slab
    }

    @Test func somethingStandingOnThePlatformShadowsIt() {
        let top = Sunlight.receivers.first { $0.axis == 1 && $0.plane > 0.04 }!
        let platform = RoomLayout.objects[.platform]!.position
        let post = LowPolyMesh.box(size: [0.1, 1, 0.1]).translated(by: platform + [0, 0.5, 0.5])
        let shadow = Sunlight.shadow(of: post, on: top)
        #expect(shadow.triangleCount > 0)
        #expect(shadow.positions.allSatisfy { $0.y > 0.05 })
        // A surface doesn't shadow itself.
        let mat = LowPolyMesh.box(size: [1.2, 0.05, 2.4]).translated(by: platform + [0, 0.025, 0])
        #expect(Sunlight.shadow(of: mat, on: top).triangleCount == 0)
    }

    @Test func bakeHidesWallsAndWhatHangsOnThem() {
        let pieces = SceneBake.pieces(plates: Plate.catalog(.kg), gymName: "79")
        let overview = RoomLayout.shots[.overview]!.position                   // from beyond the right wall
        #expect(RoomLayout.Wall.right.isVisible(from: overview) == false)
        #expect(RoomLayout.Wall.back.isVisible(from: overview))
        let hidden = pieces.filter { !$0.isVisible(from: overview) }
        #expect(!hidden.isEmpty && hidden.allSatisfy { $0.walls.contains(.right) })
        #expect(pieces.contains { if case .picture(.plateFace, _) = $0.paint { true } else { false } })
    }
}

@Suite("Texture coordinates survive merging")
struct UVMergeTests {
    @Test func appendingAPictureToAnEmptyMeshKeepsItsUVs() {
        var mesh = LowPolyMesh()
        let sheet = LowPolyMesh.sheet(width: 1, height: 1, columns: 1, rows: 1)
        mesh.append(sheet)
        #expect(mesh.uvs == sheet.uvs)
        mesh.append(.box(size: [1, 1, 1]))
        #expect(mesh.uvs.count == mesh.positions.count)
    }
}
