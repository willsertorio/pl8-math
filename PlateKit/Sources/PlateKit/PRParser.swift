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
/// Box apps list a lift with its weight on the right, which OCR reads as two lines (`Back Squat (Barbell)`,
/// `185.19 Lb`), row by row or as a column of names then a column of weights: each weight-only line goes to the
/// earliest lift name still waiting for one.
public enum PRParser {
    public static func parse(_ text: String) -> [PREntry] {
        var entries: [PREntry] = []
        var waiting: [String] = []
        for raw in OCRText.latinized(text).split(whereSeparator: \.isNewline) {
            let line = withoutBrackets(String(raw))
            if let entry = parseLine(line) {
                entries.append(entry)
            } else if let weight = weightOnly(line) {
                if !waiting.isEmpty {
                    entries.append(PREntry(lift: LiftNames.canonical(waiting.removeFirst()), value: weight.value, unit: weight.unit))
                }
            } else if isLiftName(line) {
                waiting.append(line)
            }
        }
        // One PR per lift: a lift named twice keeps its last value.
        var latest: [String: Int] = [:]
        for (index, entry) in entries.enumerated() { latest[LiftNames.key(entry.lift)] = index }
        return entries.enumerated().filter { latest[LiftNames.key($0.element.lift)] == $0.offset }.map(\.element)
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

    /// "Back Squat (Barbell)" → "Back Squat": the app's category isn't part of the lift.
    private static func withoutBrackets(_ line: String) -> String {
        line.replacing(#/\s*\([^)]*\)/#, with: "").trimmingCharacters(in: .whitespaces)
    }

    /// "185.19 Lb", "88 kg": a weight with nothing else.
    private static func weightOnly(_ line: String) -> (value: Double, unit: WeightUnit?)? {
        let pattern = #/\s*(?<value>\d+(?:[.,]\d+)?)\s*(?<unit>kgs?|kilos?|kilograms?|lbs?|pounds?)?\.?\s*/#.ignoresCase()
        guard let match = line.wholeMatch(of: pattern),
              let value = Double(match.value.replacingOccurrences(of: ",", with: ".")), value > 0 else { return nil }
        return (value, match.unit.map { $0.lowercased().hasPrefix("k") ? .kg : .lb })
    }

    /// A line that names a lift we know ("Muscle Snatch", "Clean & Jerk"), with no digits — not "Meus recordes".
    private static func isLiftName(_ line: String) -> Bool {
        !line.contains(where: \.isNumber) && LiftNames.firstKnown(in: line) != nil
    }

    private static func parseLine(_ line: String) -> PREntry? {
        let pattern = #/\s*(?<lift>.*?[A-Za-z].*?)\s*[-–:]?\s*(?<value>\d+(?:[.,]\d+)?)\s*(?<unit>kgs?|kilos?|kilograms?|lbs?|pounds?)?\.?\s*/#.ignoresCase()
        guard let match = line.wholeMatch(of: pattern),
              let value = Double(match.value.replacingOccurrences(of: ",", with: ".")), value > 0 else { return nil }

        var name = String(match.lift)
        // "Back Squat 1RM", "Snatch PR" → the lift alone.
        name = name.replacing(#/\s*[-–:]?\s*(?:1\s*RM|PR)\s*$/#.ignoresCase(), with: "")
        // A real word, not the status bar's "5G".
        guard name.contains(#/[A-Za-z]{2}/#), !name.contains("@"), !name.contains("%") else { return nil }

        let unit: WeightUnit? = match.unit.map { $0.lowercased().hasPrefix("k") ? .kg : .lb }
        return PREntry(lift: LiftNames.canonical(name), value: value, unit: unit)
    }
}
