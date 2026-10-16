import Foundation
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

/// Bug from real use, 2026-10-16: the box app's "Recordes pessoais" screen (Fixtures/prs/2026-10-16-app).
/// Each row is a name with its category in brackets and the weight on the right, which Vision reads as two lines.
@Suite("PR screenshot from the box app")
struct PRAppScreenshotTests {
    static let expected = [
        PREntry(lift: "Back Squat", value: 185.19, unit: .lb),
        PREntry(lift: "Bench Press", value: 88.18, unit: .lb),
        PREntry(lift: "Clean & Jerk", value: 125, unit: .lb),
        PREntry(lift: "Clean Pull", value: 132.28, unit: .lb),
        PREntry(lift: "Deadlift", value: 253.53, unit: .lb),
        PREntry(lift: "Front Squat", value: 170, unit: .lb),
        PREntry(lift: "Muscle Snatch", value: 70.55, unit: .lb),
    ]

    static func fixture() throws -> String {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../Fixtures/prs/2026-10-16-app.screen.txt")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test func nameThenWeightOnTheNextLine() throws {
        #expect(PRParser.parse(try Self.fixture()) == Self.expected)          // no "5G 30" from the status bar
    }

    @Test func namesColumnThenWeightsColumn() throws {
        let lines = try Self.fixture().split(separator: "\n").map(String.init)
        let names = lines.filter { $0.contains("(Barbell)") }
        let weights = lines.filter { $0.hasSuffix(" Lb") }
        #expect(PRParser.parse((["Meus recordes", "Barbell"] + names + weights).joined(separator: "\n")) == Self.expected)
    }

    @Test func nameAndWeightOnOneLine() {
        #expect(PRParser.parse("Back Squat (Barbell) 185.19 Lb") == [PREntry(lift: "Back Squat", value: 185.19, unit: .lb)])
    }
}
