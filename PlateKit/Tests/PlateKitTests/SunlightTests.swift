import Testing
@testable import PlateKit

@Suite("Baked sunlight, shadows and rough edges (M6, matching the prototype)")
struct SunlightTests {
    let room = RoomLayout.room

    @Test func floorIsFullSunAndTheLeftWallIsInShade() {
        #expect(Sunlight.level(normal: [0, 1, 0]) == Sunlight.levels - 1)     // floor and table tops
        #expect(Sunlight.level(normal: [1, 0, 0]) == 0)                        // the left wall faces away from the sun
        #expect(Sunlight.level(normal: [0, -1, 0]) == 0)
        let back = Sunlight.level(normal: [0, 0, 1]), right = Sunlight.level(normal: [-1, 0, 0])
        #expect(back > right && right > 0)                                     // back wall brighter than the right wall
        #expect(back < Sunlight.levels - 1)
    }

    @Test func bandsKeepEveryFace() {
        let box = LowPolyMesh.box(size: [1, 1, 1])
        let bands = Sunlight.bands(box)
        #expect(bands.values.map(\.triangleCount).reduce(0, +) == box.triangleCount)
        #expect(bands[Sunlight.levels - 1]?.triangleCount == 2)               // only the top is in full sun
    }

    @Test func aBoxCastsItsShadowAwayFromTheSun() {
        let box = LowPolyMesh.box(size: [0.5, 1, 0.5]).translated(by: [0, 0.5, 0])
        let shadow = Sunlight.shadow(of: box, in: room)
        #expect(shadow.triangleCount > 0)
        #expect(shadow.positions.allSatisfy { abs($0.y - Sunlight.floorLift) < 0.0001 })   // flat on the floor
        let xs = shadow.positions.map(\.x), zs = shadow.positions.map(\.z)
        #expect((xs.max() ?? 0) > 0.6)                                         // the sun is front-left: the shadow goes right…
        #expect((zs.min() ?? 0) < -0.6)                                        // …and back
        #expect(shadow.faceNormal(0).y > 0.99)                                 // facing up, so it shows
    }

    @Test func shadowClimbsTheBackWall() {
        let post = LowPolyMesh.box(size: [0.2, 2, 0.2]).translated(by: [0, 1, room.minZ + 0.3])
        let shadow = Sunlight.shadow(of: post, in: room)
        let onWall = shadow.positions.filter { abs($0.z - (room.minZ + Sunlight.wallLift)) < 0.0001 }
        #expect(!onWall.isEmpty)
        #expect(shadow.positions.allSatisfy { $0.z >= room.minZ && $0.y >= 0 && $0.x <= room.maxX })   // cut to the room
    }

    @Test func wallFanShadowFallsOnTheRightWall() {
        let fan = LowPolyMesh.box(size: [0.1, 0.4, 0.4]).translated(by: [room.maxX - 0.1, 2, -2.75])
        let shadow = Sunlight.shadow(of: fan, in: room)
        let onWall = shadow.positions.filter { abs($0.x - (room.maxX - Sunlight.wallLift)) < 0.0001 }
        #expect(!onWall.isEmpty)
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
        let rough = PropModels.room().filter { $0.tone == .dark && !$0.outlined && $0.mesh.triangleCount > 500 }
        #expect(!rough.isEmpty)
        let ys = rough.flatMap { $0.mesh.positions.map(\.y) }
        #expect((ys.max() ?? 0) > room.wallHeight - 0.05)                      // along the wall tops
        #expect((ys.min() ?? 0) < -0.25)                                       // and the bottom of the floor slab
    }
}
