import Foundation

/// One PR read from text. `unit` is nil when the line didn't say.
public struct PREntry: Hashable, Codable, Sendable {
    public let lift: String
    public let value: Double
    public let unit: WeightUnit?

    public init(lift: String, value: Double, unit: WeightUnit?) {
        self.lift = lift
        self.value = value
        self.unit = unit
    }
}

/// Reads PRs from text: `Back Squat 140 kg`, `Snatch - 85kg`, `Deadlift: 405 lb` (SPEC 3.7).
public enum PRParser {
    public static func parse(_ text: String) -> [PREntry] {
        OCRText.latinized(text).split(whereSeparator: \.isNewline).compactMap { parseLine(String($0)) }
    }

    /// True when some line had no unit: ask once for the whole screenshot.
    public static func needsUnit(_ entries: [PREntry]) -> Bool {
        entries.contains { $0.unit == nil }
    }

    /// The user's answer applied to every line that had no unit.
    public static func assumingUnit(_ unit: WeightUnit, for entries: [PREntry]) -> [PREntry] {
        entries.map { PREntry(lift: $0.lift, value: $0.value, unit: $0.unit ?? unit) }
    }

    // MARK: - Private

    private static func parseLine(_ line: String) -> PREntry? {
        let pattern = #/\s*(?<lift>.*?[A-Za-z].*?)\s*[-–:]?\s*(?<value>\d+(?:[.,]\d+)?)\s*(?<unit>kgs?|kilos?|kilograms?|lbs?|pounds?)?\.?\s*/#.ignoresCase()
        guard let match = line.wholeMatch(of: pattern),
              let value = Double(match.value.replacingOccurrences(of: ",", with: ".")), value > 0 else { return nil }

        var name = String(match.lift)
        // "Back Squat 1RM", "Snatch PR" → the lift alone.
        name = name.replacing(#/\s*[-–:]?\s*(?:1\s*RM|PR)\s*$/#.ignoresCase(), with: "")
        guard name.contains(where: \.isLetter), !name.contains("@"), !name.contains("%") else { return nil }

        let unit: WeightUnit? = match.unit.map { $0.lowercased().hasPrefix("k") ? .kg : .lb }
        return PREntry(lift: LiftNames.canonical(name), value: value, unit: unit)
    }
}
