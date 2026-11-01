import Testing
@testable import PlateKit

@Suite("Box mesh")
struct BoxMeshTests {
    @Test func boxHasSixFacesFacingOut() {
        let box = LowPolyMesh.box(size: SIMD3(2, 1, 0.5))
        #expect(box.triangleCount == 12)
        #expect(box.positions.map(\.x).max() == 1)
        #expect(box.positions.map(\.y).min() == -0.5)
        for triangle in 0..<box.triangleCount {
            // Every face points away from the centre.
            #expect(box.faceNormal(triangle).dot(box.faceCentre(triangle)) > 0)
        }
    }

    @Test func insideOutFacesPointIn() {
        let sky = LowPolyMesh.box(size: SIMD3(10, 10, 10)).insideOut()
        for triangle in 0..<sky.triangleCount {
            #expect(sky.faceNormal(triangle).dot(sky.faceCentre(triangle)) < 0)
        }
    }
}

@Suite("Room layout (reference/scene-layout-and-look.json)")
struct RoomLayoutTests {
    @Test func roomIsNineByNineSevenTilesWithWallsAtItsEdges() {
        let room = RoomLayout.room
        #expect(room.minX == -4 && room.maxX == 5)
        #expect(room.minZ == -4 && room.maxZ == 3)
        #expect(room.wallHeight == 2.6)
    }

    @Test func shotsFromTheReference() throws {
        let overview = try #require(RoomLayout.shots[.overview])
        #expect(overview.target == SIMD3(0.44, 1.33, -0.89))
        #expect(overview.position == SIMD3(13.28, 10.8, 14.36))
        #expect(overview.fieldOfView == 50)
        #expect(RoomLayout.shots[.board]?.fieldOfView == 40)
        #expect(RoomLayout.Station.allCases.allSatisfy { RoomLayout.shots[$0] != nil })
    }

    // The prototype computes these two from the flag and the rack.
    @Test func nameFlagShotLooksAtTheFlagFromInFront() throws {
        let shot = try #require(RoomLayout.shots[.nameFlag])
        #expect(approx(shot.target, SIMD3(3.2, 1.45, -3.99)))
        #expect(approx(shot.position, SIMD3(2.6, 2.15, 0.41)))
    }

    @Test func barShotLooksAtTheSleeveFromItsEnd() throws {
        let shot = try #require(RoomLayout.shots[.bar])
        #expect(approx(shot.target, SIMD3(1.16, 1.22, -3.08)))
        #expect(approx(shot.position, SIMD3(2.86, 1.9, -0.73)))
    }

    @Test func objectsWhereTheLayoutPutThem() {
        #expect(RoomLayout.objects[.rack]?.position == SIMD3(0.61, 0, -2.31))
        #expect(RoomLayout.objects[.board]?.rotationDegrees == 25)
        #expect(RoomLayout.objects[.barHolder]?.position == SIMD3(5, 0, -0.45))
    }

    func approx(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Bool { (a - b).length < 1e-4 }
}
