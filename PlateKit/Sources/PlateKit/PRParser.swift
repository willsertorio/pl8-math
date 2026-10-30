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

/// Reads PRs from text: `Back Squat 140 kg`, `Snatch - 85kg`, `Deadlift: 405 lb` (SPEC 3.7). A line without kg or lb
/// must name a lift we know; a lift we don't know needs its unit (`Zercher Squat 120 kg`).
/// Box apps list a lift with its weight on the right, which OCR reads as two lines (`Back Squat (Barbell)`,
/// `185.19 Lb`), row by row (weight first or name first) or as a column of names and a column of weights: each
/// weight-only line pairs with the earliest lift name waiting for one, and the other way round.
public enum PRParser {
    public static func parse(_ text: String) -> [PREntry] {
        var entries: [PREntry] = []
        var waitingNames: [String] = []
        var waitingWeights: [(value: Double, unit: WeightUnit?)] = []
        let lines = OCRText.latinized(text).split(whereSeparator: \.isNewline).map { withoutBrackets(String($0)) }
        // When the list's weights say kg or lb, a lone number without one is something else (the status bar's "30"),
        // not a weight: paired with the first name it shifted every PR by one row (2026-10-30).
        let weightsHaveUnits = lines.contains { weightOnly($0)?.unit != nil }
        for line in lines {
            if let entry = parseLine(line) {
                entries.append(entry)
            } else if let weight = weightOnly(line) {
                if weight.unit == nil && weightsHaveUnits { continue }
                if waitingNames.isEmpty {
                    waitingWeights.append(weight)                       // its name may come next
                } else {
                    entries.append(PREntry(lift: LiftNames.canonical(waitingNames.removeFirst()), value: weight.value, unit: weight.unit))
                }
            } else if isLiftName(line) {
                if waitingWeights.isEmpty {
                    waitingNames.append(line)
                } else {
                    let weight = waitingWeights.removeFirst()
                    entries.append(PREntry(lift: LiftNames.canonical(line), value: weight.value, unit: weight.unit))
                }
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

    /// "Back Squat (Barbell)" → "Back Squat": the app's category isn't part of the lift; nor is the row's arrow.
    private static func withoutBrackets(_ line: String) -> String {
        line.replacing(#/\s*\([^)]*\)/#, with: "")
            .trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: ">›»〉❯")))
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
        // A real word, not the status bar's "5G", nor a set ("@ 80%") or a receipt ("Order completed!").
        guard LiftNames.couldBeALift(name) else { return nil }

        let unit: WeightUnit? = match.unit.map { $0.lowercased().hasPrefix("k") ? .kg : .lb }
        // Without kg or lb, only a lift we know: "Subtotal 45.90" isn't a PR, "Snatch 85" is.
        guard unit != nil || LiftNames.firstKnown(in: name) != nil else { return nil }
        return PREntry(lift: LiftNames.canonical(name), value: value, unit: unit)
    }
}
