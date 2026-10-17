import Testing
@testable import PlateKit

@Suite("Session in 3D: kit floor and loaded bar (M6 step 5)")
struct SessionSceneTests {
    let kit = Kit(bar: 20, loads: [Load(total: 100, perSide: [25, 15]), Load(total: 60, perSide: [20])])

    @Test func everyKitPlateLiesOnTheKitFloor() {
        let placed = SessionScene.kitFloor(kit, unit: .kg)
        #expect(placed.count == kit.plates.map(\.count).reduce(0, +))
        let centre = RoomLayout.objects[.kitPlates]!.position
        for p in placed {
            #expect(p.axis == .y)                                                       // lying flat
            #expect(abs(p.centre.y - Float(p.plate.thickness) / 2) < 0.001)              // on the floor
            #expect(SIMD2(p.centre.x - centre.x, p.centre.z - centre.z).length < 2)
        }
        // Side by side, not on top of each other.
        for (i, a) in placed.enumerated() {
            for b in placed[(i + 1)...] {
                let gap = SIMD2(a.centre.x - b.centre.x, a.centre.z - b.centre.z).length
                #expect(gap >= Float(a.plate.diameter + b.plate.diameter) / 2 - 0.001)
            }
        }
    }

    @Test func platesGoOnBothSleevesFromTheCollarOut() {
        let placed = SessionScene.barPlates(perSide: [25, 15], unit: .kg, barWeight: 20)
        #expect(placed.count == 4)
        let bar = RoomLayout.barOnRack
        let right = placed.filter { $0.centre.x > bar.x }.sorted { $0.centre.x < $1.centre.x }
        #expect(right.map(\.plate.size) == [25, 15])                                    // heaviest inside
        #expect(abs(right[0].centre.x - bar.x - (0.701 + 0.028)) < 0.001)               // the 25's middle
        #expect(placed.allSatisfy { $0.axis == .x && abs($0.centre.y - bar.y) < 0.001 })
        let left = placed.filter { $0.centre.x < bar.x }
        #expect(left.count == 2)
    }

    @Test func platesSitClearOfTheRackOnEveryBar() {
        // Will's 2026-10-17 session: on the 35 lb bar the plates went into the J-hooks. The uprights and hooks
        // reach 0.67 m from the middle of the bar, the collar's ring 0.697 m.
        let bar = RoomLayout.barOnRack.x
        for unit in [WeightUnit.kg, .lb] {
            for weight in Bar.weights(unit) {
                let sizes = Plate.catalog(unit).map(\.size).sorted(by: >).prefix(2)
                let placed = SessionScene.barPlates(perSide: Array(sizes), unit: unit, barWeight: weight)
                let inner = placed.map { abs($0.centre.x - bar) - Float($0.plate.thickness) / 2 }.min()!
                #expect(inner > PropModels.collarEnd, "\(weight) \(unit)")
            }
        }
    }

    @Test func shadowsCanBeBakedApart() {
        let plate = SessionScene.kitFloor(kit, unit: .kg)[0]
        let parts = SessionScene.parts(plate)
        let body = SceneBake.bake(parts, placement: .init(position: plate.centre, rotationDegrees: 0), wall: nil, content: .withoutShadows)
        let shadow = SceneBake.bake(parts, placement: .init(position: plate.centre, rotationDegrees: 0), wall: nil, content: .shadowsOnly)
        #expect(!body.isEmpty && !shadow.isEmpty)
        #expect(shadow.allSatisfy { piece in piece.mesh.positions.allSatisfy { $0.y < 0.01 } })
    }
}

@Suite("Session camera shots (Will, 2026-10-17: room on 80% of the screen, closer)")
struct SessionShotTests {
    @Test func kitFloorShotLooksAtTheKitFromCloser() throws {
        let shot = try #require(RoomLayout.shots[.kitFloor])
        let kit = RoomLayout.objects[.kitPlates]!.position
        #expect(SIMD2(shot.target.x - kit.x, shot.target.z - kit.z).length < 0.01)
        #expect((shot.position - shot.target).length < (RoomLayout.shots[.kit]!.position - RoomLayout.shots[.kit]!.target).length)
    }

    @Test func sleeveShotFramesOneSideOfTheBar() throws {
        let shot = try #require(RoomLayout.shots[.sleeve])
        let bar = RoomLayout.barOnRack
        #expect(shot.target.x > bar.x + 0.7 && shot.target.x < bar.x + 1.1)       // the right sleeve
        #expect(abs(shot.target.z - bar.z) < 0.01)
        #expect((shot.position - shot.target).length < 2)                           // close up
    }
}
