import Testing
@testable import PlateKit

@Suite("Plates and bars (SPEC 3.1)")
struct PlatesTests {
    @Test func kilogramPlateSizesHeaviestFirst() {
        #expect(Plate.catalog(.kg).map(\.size) == [25, 20, 15, 10, 5, 2.5, 2, 1.5, 1, 0.5])
    }

    @Test func poundPlateSizesHeaviestFirst() {
        #expect(Plate.catalog(.lb).map(\.size) == [55, 45, 35, 25, 15, 10, 5, 2.5])
    }

    @Test func plateLooksMatchTheSpecTable() throws {
        let red25 = try #require(Plate.find(25, .kg))
        #expect(red25.colorHex == "#D3262E")
        #expect(red25.diameter == 0.450)
        #expect(red25.thickness == 0.056)
        #expect(red25.kind == .bumper)

        let iron10 = try #require(Plate.find(10, .lb))
        #expect(iron10.colorHex == "#26282C")
        #expect(iron10.diameter == 0.250)
        #expect(iron10.thickness == 0.024)
        #expect(iron10.kind == .change)
    }

    @Test func everyPlateHasAHexColour() {
        for unit in WeightUnit.allCases {
            for plate in Plate.catalog(unit) {
                #expect(plate.colorHex.count == 7 && plate.colorHex.hasPrefix("#"), "\(plate.size) \(unit)")
            }
        }
    }

    @Test func unknownPlateIsNil() {
        #expect(Plate.find(7, .kg) == nil)
    }

    @Test func barSizes() {
        #expect(Bar.weights(.kg) == [20, 15, 10])
        #expect(Bar.weights(.lb) == [45, 35, 15])
    }

    @Test func barNames() {
        #expect(Bar.name(20, .kg) == "Olympic")
        #expect(Bar.name(15, .kg) == "Women's Olympic")
        #expect(Bar.name(10, .kg) == "Technique")
        #expect(Bar.name(45, .lb) == nil)                           // lb bars go by weight only
    }

    @Test func newGymHasEveryPlateOfItsUnit() {
        let gym = GymSetup(unit: .lb)
        #expect(gym.plateSizes == [55, 45, 35, 25, 15, 10, 5, 2.5])
        #expect(gym.barWeight == 45)
    }

    @Test func gymPlateSizesAreSortedHeaviestFirst() {
        let gym = GymSetup(unit: .kg, plateSizes: [0.5, 25, 2.5, 25], barWeight: 15)
        #expect(gym.plateSizes == [25, 2.5, 0.5])
        #expect(gym.barWeight == 15)
    }
}

@Suite("Gym name (SPEC 2.2)")
struct GymNameTests {
    @Test func uppercaseUpToEightCharacters() {
        #expect(GymSetup.normalizedName("crossfit jennie") == "CROSSFIT")
        #expect(GymSetup.normalizedName("  my box ") == "MY BOX")
        #expect(GymSetup.normalizedName("") == "")
    }
}
