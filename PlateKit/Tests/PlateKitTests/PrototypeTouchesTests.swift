import Foundation
import Testing
@testable import PlateKit

@Suite("The prototype's last touches (M6): floor lifts, the fan, the title's plates")
struct PrototypeTouchesTests {
    @Test func pullsStartFromTheFloor() {
        // prototype liftOnFloor: /dead|snatch|clean/i on the lift's name
        for name in ["Deadlift", "Power Clean", "Squat Snatch", "Clean & Jerk", "romanian deadlift"] {
            #expect(LiftNames.startsOnFloor(name), "\(name)")
        }
        for name in ["Back Squat", "Bench Press", "Push Press", "Front Squat"] { #expect(!LiftNames.startsOnFloor(name), "\(name)") }
    }

    @Test func onTheFloorTheBarRestsOnThePlatformAtPlateHeight() {
        let bar = RoomLayout.barOnRack + SessionScene.floorOffset
        #expect(abs(bar.y - (0.05 + 0.225)) < 0.001)                         // a bumper's radius above the platform top
        #expect(abs(bar.z - RoomLayout.objects[.platform]!.position.z) < 0.001)
        let rack = RoomLayout.shots[.sleeve]!, floor = RoomLayout.shots[.sleeveFloor]!
        #expect((floor.target - rack.target - SessionScene.floorOffset).length < 0.001)
        #expect((floor.position - rack.position - SessionScene.floorOffset).length < 0.001)
    }

    @Test func theRackSplitsIntoItsFrameAndItsBar() {
        let all = PropModels.parts(for: .rack, plates: [], barWeight: 20, unit: .kg)
        let split = PropModels.rackParts(barWeight: 20, unit: .kg)
        #expect(split.frame.count + split.bar.count == all.count)
        #expect(split.bar.allSatisfy { if case .metal = $0.tone { true } else { false } })
    }

    @Test func theFanSplitsIntoWhatTurns() {
        let fan = PropModels.wallFanParts()
        #expect(!fan.fixed.isEmpty && !fan.head.isEmpty && fan.blades.count == 3)
        #expect(fan.fixed.count + fan.head.count + fan.blades.count == PropModels.parts(for: .wallFan, plates: []).count)
        // The blades sit round the hub, and spin round the head's axis (tilted down 0.28 rad).
        let mid = fan.blades.flatMap { $0.mesh.positions }.reduce(SIMD3<Float>.zero, +) / Float(fan.blades.flatMap { $0.mesh.positions }.count)
        #expect((mid - fan.hub).length < 0.03)
        #expect(abs(fan.spinAxis.y + sin(0.28)) < 0.001 && fan.spinAxis.z > 0.9)
    }

    @Test func placingAPointMatchesPlacingAMesh() {
        let placement = RoomLayout.Placement(position: [1, 2, 3], rotationDegrees: -90)
        let p = SIMD3<Float>(0.3, 0.1, 0.5)
        let mesh = LowPolyMesh(positions: [p], indices: []).placed(placement)
        #expect((placement.apply(p) - mesh.positions[0]).length < 0.0001)
    }

    @Test func titlePlatesRiseOnTheSidesAndComeBackFromBelow() {
        var field = TitleField(count: 24, seed: 4)
        #expect(field.plates.count == 24)
        #expect(field.plates.allSatisfy { abs($0.u) >= 0.4 && abs($0.u) <= 1.15 })   // lanes keep the title clear
        #expect(field.plates.allSatisfy { $0.z >= 0.75 && $0.z <= 2.4 })
        let before = field.plates.map(\.v)
        field.step(0.5)
        #expect(zip(before, field.plates.map(\.v)).allSatisfy { $1 < $0 })           // all going up (screen v falls)
        for _ in 0..<2000 { field.step(0.05) }
        #expect(field.plates.allSatisfy { $0.v > -2 && $0.v < 2 })                  // they wrap round, never lost
    }
}
