import Testing
@testable import PlateKit

@Suite("Units (SPEC 3.2)")
struct UnitsTests {
    @Test func kilogramsToPounds() {
        let lb = WeightUnit.kg.convert(100, to: .lb)
        #expect(abs(lb - 220.46226218) < 1e-9)
    }

    @Test func poundsToKilograms() {
        let kg = WeightUnit.lb.convert(170, to: .kg)
        #expect(abs(kg - 77.1107) < 1e-4)
    }

    @Test func sameUnitIsUnchanged() {
        #expect(WeightUnit.kg.convert(62.5, to: .kg) == 62.5)
    }

    @Test func roundTripKeepsFullPrecision() {
        let back = WeightUnit.lb.convert(WeightUnit.kg.convert(85, to: .lb), to: .kg)
        #expect(abs(back - 85) < 1e-9)
    }

    // Fixtures 01/10, lb gym: set 1 is 170 lb and the PR is in kg.
    @Test func convertedTotalShowsOneDecimal() {
        #expect(WeightUnit.lb.display(170, in: .kg) == "77.1 kg")
        #expect(WeightUnit.kg.display(20, in: .lb) == "44.1 lb")
    }

    @Test func sameUnitTotalShowsNoTrailingZero() {
        #expect(WeightUnit.lb.display(170, in: .lb) == "170 lb")
        #expect(WeightUnit.kg.display(62.5, in: .kg) == "62.5 kg")
    }
}
