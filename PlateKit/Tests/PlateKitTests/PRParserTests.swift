import Testing
@testable import PlateKit

@Suite("PR parser (SPEC 3.7)")
struct PRParserTests {
    @Test func specExamples() {
        let prs = PRParser.parse("""
        Back Squat 140 kg
        Snatch - 85kg
        Deadlift: 405 lb
        """)
        #expect(prs == [
            PREntry(lift: "Back Squat", value: 140, unit: .kg),
            PREntry(lift: "Snatch", value: 85, unit: .kg),
            PREntry(lift: "Deadlift", value: 405, unit: .lb),
        ])
    }

    @Test func namesAndUnitSpellings() {
        let prs = PRParser.parse("""
        back squat 140kgs
        BS: 315 lbs
        Clean – 100 kilos
        Bench Press 225 pounds
        Zercher Squat 120 kg
        """)
        #expect(prs.map(\.lift) == ["Back Squat", "Back Squat", "Clean", "Bench Press", "Zercher Squat"])
        #expect(prs.map(\.unit) == [.kg, .lb, .kg, .lb, .kg])
    }

    @Test func decimals() {
        let prs = PRParser.parse("Snatch 82.5 kg\nClean 102,5 kg")
        #expect(prs.map(\.value) == [82.5, 102.5])
    }

    @Test func labelsLike1RMArePartOfTheLineNotTheName() {
        #expect(PRParser.parse("Back Squat 1RM: 140 kg").first?.lift == "Back Squat")
        #expect(PRParser.parse("Snatch PR - 85 kg").first?.lift == "Snatch")
    }

    @Test func noiseIsIgnored() {
        let prs = PRParser.parse("""
        14:06
        My PRs
        Deadlift 0 kg
        3 Back Squat @80% 1RM Back Squat
        Front Squat 120 kg
        """)
        #expect(prs.map(\.lift) == ["Front Squat"])
    }

    @Test func missingUnitIsAskedOnceForTheWholeScreenshot() {
        let prs = PRParser.parse("""
        Clean 100
        Snatch 85
        Deadlift 405 lb
        """)
        #expect(PRParser.needsUnit(prs))
        let filled = PRParser.assumingUnit(.kg, for: prs)
        #expect(filled.map(\.unit) == [.kg, .kg, .lb])               // a unit on the line wins
        #expect(!PRParser.needsUnit(filled))
    }

    @Test func lookalikeLettersAreReadAsLatin() {
        // "Snatch 85 kg" with a Cyrillic а and к.
        #expect(PRParser.parse("Sn\u{0430}tch 85 \u{043A}g") == [PREntry(lift: "Snatch", value: 85, unit: .kg)])
    }
}
