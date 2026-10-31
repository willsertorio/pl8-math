import Testing
@testable import PlateKit

@Suite("Plate kit (SPEC 3.5)")
struct KitTests {
    func summary(_ kit: Kit) -> [String] {
        kit.plates.map { "\($0.count)×\(WeightUnit.trimmed($0.size))" }
    }

    // Fixtures 01/10 · lb gym: warm-up + Back Squat, per side
    @Test func mostOfEachPlateInAnySetTimesTwo() {
        let sides: [[Double]] = [[15, 5], [35, 2.5], [45, 5], [55, 5, 2.5], [55, 5, 2.5], [55, 10], [55, 10], [55, 10, 2.5]]
        let kit = Kit(bar: 45, loads: sides.map { Load(total: 0, perSide: $0) })
        #expect(summary(kit) == ["2×55", "2×45", "2×35", "2×15", "2×10", "2×5", "2×2.5"])
        #expect(kit.bar == 45)
    }

    // Fixtures edge: missing small plates · two 10s on one side
    @Test func countsRepeatsOnOneSide() {
        let sides: [[Double]] = [[10, 10], [35], [35, 15], [45, 15]]
        let kit = Kit(bar: 45, loads: sides.map { Load(total: 0, perSide: $0) })
        #expect(summary(kit) == ["2×45", "2×35", "2×15", "4×10"])
    }

    // Fixtures edge: empty bar only
    @Test func justTheBar() {
        let kit = Kit(bar: 20, loads: [Load(total: 20, perSide: [])])
        #expect(kit.plates.isEmpty)
        #expect(kit.bar == 20)
    }
}

@Suite("Change between sets (SPEC 3.5)")
struct SetChangeTests {
    // Fixtures 05/10 · Snatch set 3 → 4
    @Test func takeOffOuterFirstThenAdd() {
        let change = SetChange(from: [45, 5], to: [55])
        #expect(change.takeOff == [5, 45])
        #expect(change.add == [55])
        #expect(change.text == "Take off 5 + 45, then add 55 each side")
    }

    @Test func keepsTheCommonInnerPlates() {
        let change = SetChange(from: [55, 5, 2.5], to: [55, 10])
        #expect(change.takeOff == [2.5, 5])
        #expect(change.add == [10])
        #expect(change.text == "Take off 2.5 + 5, then add 10 each side")
    }

    @Test func onlyAdding() {
        #expect(SetChange(from: [55, 10], to: [55, 10, 2.5]).text == "Add 2.5 each side")
        #expect(SetChange(from: [], to: [15, 5]).text == "Add 15 + 5 each side")
    }

    @Test func onlyTakingOff() {
        #expect(SetChange(from: [55, 10, 2.5], to: [55, 10]).text == "Take off 2.5 each side")
    }

    @Test func samePlates() {
        let change = SetChange(from: [55, 5, 2.5], to: [55, 5, 2.5])
        #expect(change.isSame)
        #expect(change.text == "Same plates as the last set")
    }
}
