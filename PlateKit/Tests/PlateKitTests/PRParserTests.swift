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
        // Each on its own screenshot: one screenshot keeps one PR per lift.
        let prs = ["back squat 140kgs", "BS: 315 lbs", "Clean – 100 kilos", "Bench Press 225 pounds", "Zercher Squat 120 kg"]
            .flatMap { PRParser.parse($0) }
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

/// Bug from real use, 2026-10-16: "backsquat" and "Back Squat" became two PRs.
@Suite("One name per lift")
struct OneNamePerLiftTests {
    @Test func spacingAndCaseDoNotMakeANewLift() {
        #expect(LiftNames.canonical("backsquat") == "Back Squat")
        #expect(LiftNames.canonical("BACK-SQUAT") == "Back Squat")
        #expect(LiftNames.canonical("clean&jerk") == "Clean & Jerk")
        #expect(LiftNames.canonical("snatchbalance") == "Snatch Balance")
    }

    @Test func unknownLiftsAreTidiedTheSameWayEachTime() {
        #expect(LiftNames.canonical("pull ups") == "Pull Ups")
        #expect(LiftNames.canonical("PULL UPS") == "Pull Ups")
        #expect(LiftNames.key("Pull-Ups") == LiftNames.key("pull ups"))
    }

    @Test func aScreenshotNamingALiftTwiceKeepsTheLastOne() {
        let prs = PRParser.parse("backsquat 120 kg\nBack Squat 132.28 lb")
        #expect(prs == [PREntry(lift: "Back Squat", value: 132.28, unit: .lb)])
    }
}

/// 2026-10-16 again: on the phone only Back Squat came through. Vision can put a row's weight a hair above its
/// name, so the weight comes first; the row's arrow may be read too.
@Suite("PR screenshot, other reading orders")
struct PRReadingOrderTests {
    @Test func weightBeforeItsName() throws {
        let rows = PRAppScreenshotTests.expected.map { "\(WeightUnit.trimmed($0.value)) Lb\n\($0.lift) (Barbell)" }
        #expect(PRParser.parse(rows.joined(separator: "\n")).map(\.lift) == PRAppScreenshotTests.expected.map(\.lift))
        #expect(PRParser.parse(rows.joined(separator: "\n")) == PRAppScreenshotTests.expected)
    }

    @Test func rowArrowsAreIgnored() {
        #expect(PRParser.parse("Back Squat (Barbell)\n185.19 Lb >") == [PREntry(lift: "Back Squat", value: 185.19, unit: .lb)])
        #expect(PRParser.parse("Deadlift (Barbell) 253.53 Lb ›") == [PREntry(lift: "Deadlift", value: 253.53, unit: .lb)])
    }
}

/// Bug from real use, 2026-10-30 (Fixtures/prs/2026-10-30-notebook.webp): on Will's PR page each lift had the weight of
/// the row above (Back squat 30 kg, Bench press 185.19, Deadlift 132.28, Front squat 253.53 lb): the status bar's
/// "30" read on its own line paired with the first name. And a receipt's "Order completed!" line became a PR.
@Suite("PR screenshot, 2026-10-30: stray lines")
struct PRStrayLinesTests {
    @Test func aLoneNumberAboveTheListDoesNotShiftThePRs() throws {
        let text = try PRAppScreenshotTests.fixture().replacingOccurrences(of: "5G 30", with: "5G\n30")
        #expect(PRParser.parse(text) == PRAppScreenshotTests.expected)
    }

    @Test func receiptLinesAreNotPRs() {
        for line in ["Order completed! 45.90", "Order completed! R$ 45,90", "Subtotal 45.90", "Total: $120.00", "Shipping 10"] {
            #expect(PRParser.parse(line).isEmpty, "\(line)")
        }
        // A lift we don't know still counts when its line says kg or lb.
        #expect(PRParser.parse("Zercher Squat 120 kg").map(\.lift) == ["Zercher Squat"])
        #expect(PRParser.parse("Snatch 85").map(\.lift) == ["Snatch"])
    }

    @Test func receiptWordsAreNeverLifts() {
        // The mark after "Order completed" on Will's page is half under the pencil: the words alone are enough.
        for name in ["Order completed", "Order completed l", "Order #48213", "Subtotal", "Total", "Shipping", "Delivery fee",
                     "Discount", "Tax", "Payment", "Amount paid", "Price"] {
            #expect(!LiftNames.couldBeALift(name), "\(name)")
        }
        #expect(PRParser.parse("Order completed 45.90 kg").isEmpty)
        // Lifts that only look close stay lifts.
        for name in ["Back Squat", "Clean & Jerk", "Sots Press", "Pause Squat", "Deficit Deadlift", "Zercher Squat"] {
            #expect(LiftNames.couldBeALift(name), "\(name)")
        }
    }

    @Test func savedNamesThatCannotBeLiftsAreFound() {
        #expect(!LiftNames.couldBeALift("Order completed!"))
        #expect(!LiftNames.couldBeALift("Order completed! R$"))
        #expect(!LiftNames.couldBeALift("3 Back Squat @80%"))
        #expect(LiftNames.couldBeALift("Zercher Squat"))
        #expect(LiftNames.couldBeALift("Clean & Jerk"))
    }
}
