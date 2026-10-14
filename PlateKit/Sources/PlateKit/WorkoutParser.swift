import Foundation

/// One set as written on the board. `target` is nil when the % couldn't be read.
public struct ParsedSet: Hashable, Codable, Sendable {
    public let reps: Int
    public let target: Target?

    public init(reps: Int, target: Target?) {
        self.reps = reps
        self.target = target
    }
}

/// One lift of a strength block (SPEC 3.6).
public struct StrengthBlock: Hashable, Codable, Sendable {
    /// "A", "B"…
    public let letter: String
    /// A label inside the block before the lift, e.g. "After Party".
    public let label: String?
    /// The movement as written, e.g. "Snatch Pull + Snatch".
    public let name: String
    /// The lift whose PR applies, e.g. "Snatch".
    public let prLift: String
    /// "EMOM", "E2MOM"… or nil.
    public let format: String?
    /// e.g. "Rest 2 minutes between sets".
    public let note: String?
    public let sets: [ParsedSet]

    /// Some % couldn't be read; ask "What % for Back Squat?".
    public var pctMissing: Bool { sets.contains { $0.target == nil } }

    /// A lift from the "Type it in" form: sets × reps at one % (SPEC 2.2, simple form).
    public static func typed(letter: String, lift: String, sets: Int, reps: Int, target: Target) -> StrengthBlock {
        let name = LiftNames.canonical(lift)
        let set = ParsedSet(reps: max(1, reps), target: target)
        return StrengthBlock(letter: letter, label: nil, name: name, prLift: name, format: nil, note: nil,
                             sets: Array(repeating: set, count: max(1, sets)))
    }

    /// The same block with every set at `target` (editing the plan).
    public func settingPercent(_ target: Target) -> StrengthBlock {
        StrengthBlock(letter: letter, label: label, name: name, prLift: prLift, format: format, note: note,
                      sets: sets.map { ParsedSet(reps: $0.reps, target: target) })
    }

    /// The same block with every unread % set to `target`.
    public func fillingMissingPercent(with target: Target) -> StrengthBlock {
        StrengthBlock(letter: letter, label: label, name: name, prLift: prLift, format: format, note: note,
                      sets: sets.map { ParsedSet(reps: $0.reps, target: $0.target ?? target) })
    }
}

extension Target {
    /// The user's answer to "What % for Back Squat?": `83-85`, `80` or `80+` (a `%` is fine too).
    /// Parsed by hand, not with a Regex: it runs on every keystroke and Regex is slow to build.
    public init?(parsing text: String) {
        var compact = String(text.filter { !$0.isWhitespace && $0 != "%" })
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "–", with: "-")
        guard !compact.isEmpty, compact.allSatisfy({ $0.isASCII && ($0.isNumber || ".-+".contains($0)) }) else {
            return nil
        }
        let plus = compact.hasSuffix("+")
        if plus { compact.removeLast() }

        let parts = compact.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count <= 2,
              let low = Double(parts[0]), low > 0 else { return nil }
        var high: Double?
        if parts.count == 2 {
            guard let value = Double(parts[1]), value >= low else { return nil }
            high = value
        }
        self = Target.make(low: low, high: high, plus: plus)
    }

    static func make(low: Double, high: Double?, plus: Bool) -> Target {
        if plus { return .plus(low) }
        if let high, high != low { return .range(low, high) }
        return .single(low)
    }
}

/// "82,5" or "82.5" → 82.5
private func number(_ text: Substring) -> Double? {
    Double(text.replacingOccurrences(of: ",", with: "."))
}

/// Reads strength work from workout text (Vision OCR or typed) — SPEC 3.6.
public enum WorkoutParser {
    /// Several screenshots of one workout, read in order and joined.
    public static func parse(screenshots: [String]) -> [StrengthBlock] {
        parse(screenshots.joined(separator: "\n"))
    }

    public static func parse(_ text: String) -> [StrengthBlock] {
        let lines = OCRText.latinized(text).split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var blocks: [(letter: String, label: String?, lines: [String])] = []
        for line in joinWrappedLines(lines) {
            // "A." or "C. After a Party"
            if let match = line.wholeMatch(of: #/([A-Z])\.(?:\s+(.+))?/#) {
                blocks.append((String(match.1), match.2.map { clean(String($0)) }, []))
            } else if !blocks.isEmpty {
                blocks[blocks.count - 1].lines.append(line)
            }
        }
        return blocks.flatMap { parseBlock(letter: $0.letter, label: $0.label, lines: $0.lines) }
    }

    // MARK: - Private

    /// Long sets wrap over several lines on a phone (Fixtures 14/10). Joins a line onto the one before when that
    /// one starts with reps but has no % yet, or ends right after "1RM". A new set, a header, a note or a block
    /// letter always starts a new line.
    static func joinWrappedLines(_ lines: [String]) -> [String] {
        var result: [String] = []
        for line in lines {
            if let previous = result.last, continues(previous, with: line) {
                result[result.count - 1] = previous + " " + line
            } else {
                result.append(line)
            }
        }
        return result
    }

    private static func continues(_ previous: String, with line: String) -> Bool {
        guard previous.firstMatch(of: #/^\d+\s+\S/#) != nil else { return false }
        if line.wholeMatch(of: #/([A-Z])\.(?:\s+(.+))?/#) != nil || parseHeader(line) != nil { return false }
        if let first = line.first, "*-–•".contains(first) { return false }
        if line.firstMatch(of: #/^\d+\s/#) != nil { return false }

        let endsWith1RM = previous.wholeMatch(of: #/.*1\s*RM\s*/#.ignoresCase()) != nil
        let startsWith1RM = line.firstMatch(of: #/^1\s*RM/#.ignoresCase()) != nil
        if previous.contains("%") {
            return endsWith1RM || (startsWith1RM && !previous.localizedCaseInsensitiveContains("RM"))
        }
        return true
    }

    private struct Header {
        let format: String?
        let count: Int
    }

    private struct Line {
        let movement: String
        let prLift: String
        let sets: [ParsedSet]
        /// `NxR` lines say their own set count; a format header doesn't expand them.
        let countsItself: Bool
    }

    private struct Lift {
        var movement: String
        var prLift: String
        var header: Header?
        var lines: [Line] = []
        var notes: [String] = []
    }

    private static func parseBlock(letter: String, label: String?, lines: [String]) -> [StrengthBlock] {
        var header: Header?
        var label = label
        var lifts: [Lift] = []

        for text in lines {
            if let newHeader = parseHeader(text) {
                header = newHeader
            } else if let line = parseStrength(text) ?? parseHiddenPercent(text, under: header) {
                if let last = lifts.last, last.movement == line.movement, last.prLift == line.prLift {
                    lifts[lifts.count - 1].lines.append(line)
                } else {
                    lifts.append(Lift(movement: line.movement, prLift: line.prLift, header: header, lines: [line]))
                }
            } else if lifts.isEmpty {
                label = label ?? clean(text)
            } else {
                lifts[lifts.count - 1].notes.append(clean(text))
            }
        }

        return lifts.map { lift in
            var sets = lift.lines.flatMap(\.sets)
            if lift.lines.count == 1, !lift.lines[0].countsItself, let count = lift.header?.count, count > 1 {
                sets = Array(repeating: sets[0], count: count)
            }
            return StrengthBlock(
                letter: letter,
                label: label,
                name: lift.movement,
                prLift: lift.prLift,
                format: lift.header?.format,
                note: lift.notes.isEmpty ? nil : lift.notes.joined(separator: " "),
                sets: sets
            )
        }
    }

    /// `5 Minute EMOM`, `EMOM 10 min`, `E2MOM 10 min`, `6 Sets`.
    private static func parseHeader(_ text: String) -> Header? {
        if let m = text.wholeMatch(of: #/(\d+)\s*(?:minutes?|min)\s*EMOM/#.ignoresCase()), let n = Int(m.1) {
            return Header(format: "EMOM", count: n)
        }
        if let m = text.wholeMatch(of: #/EMOM\s*(\d+)\s*(?:minutes?|min)?/#.ignoresCase()), let n = Int(m.1) {
            return Header(format: "EMOM", count: n)
        }
        if let m = text.wholeMatch(of: #/E(\d+)MOM\s*(\d+)\s*(?:minutes?|min)?/#.ignoresCase()),
           let every = Int(m.1), let minutes = Int(m.2), every > 0 {
            return Header(format: "E\(every)MOM", count: minutes / every)
        }
        if let m = text.wholeMatch(of: #/(\d+)\s*sets?/#.ignoresCase()), let n = Int(m.1) {
            return Header(format: nil, count: n)
        }
        return nil
    }

    /// `3 Back Squat @75-78% 1RM Back Squat`, `2 Clean @80%+`, `5x3 @80% 1RM Snatch`.
    private static func parseStrength(_ text: String) -> Line? {
        var setCount = 1
        var reps: Int
        var movement: Substring
        var low: Substring, high: Substring?, plus: Bool, rest: Substring
        if let m = text.wholeMatch(of: #/(?<sets>\d+)\s*[x×]\s*(?<reps>\d+)\b\s*(?<move>.*?)\s*@?\s*(?<low>\d+(?:[.,]\d+)?)\s*(?:[-–]\s*(?<high>\d+(?:[.,]\d+)?))?\s*(?<plusA>\+)?\s*%\s*(?<plusB>\+)?\s*(?<rest>.*)/#.ignoresCase()),
           let count = Int(m.sets), let r = Int(m.reps) {
            setCount = count
            reps = r
            (movement, low, high, plus, rest) = (m.move, m.low, m.high, m.plusA != nil || m.plusB != nil, m.rest)
        } else if let m = text.wholeMatch(of: #/(?<reps>\d+)\s+(?<move>.+?)\s*@?\s*(?<low>\d+(?:[.,]\d+)?)\s*(?:[-–]\s*(?<high>\d+(?:[.,]\d+)?))?\s*(?<plusA>\+)?\s*%\s*(?<plusB>\+)?\s*(?<rest>.*)/#),
                  let r = Int(m.reps) {
            reps = r
            (movement, low, high, plus, rest) = (m.move, m.low, m.high, m.plusA != nil || m.plusB != nil, m.rest)
        } else {
            return nil
        }

        guard let lowValue = number(low) else { return nil }
        let target = Target.make(low: lowValue, high: high.flatMap(number), plus: plus)

        var prText = ""
        if let rm = rest.firstMatch(of: #/1\s*RM\s*(.*)/#.ignoresCase()) {
            prText = clean(String(rm.1))
        }
        let move = LiftNames.canonical(String(movement))
        guard !move.isEmpty || !prText.isEmpty else { return nil }
        let prLift = prText.isEmpty ? move : LiftNames.canonical(prText)

        return Line(
            movement: move.isEmpty ? prLift : move,
            prLift: prLift,
            sets: Array(repeating: ParsedSet(reps: reps, target: target), count: setCount),
            countsItself: setCount > 1
        )
    }

    /// A strength line whose % was cut off or garbled (SPEC 3.6 rule 6): under a format header,
    /// starts with `<reps> <known lift>`, and has leftovers like `@`, `%`, `RM` or the lift's last word again.
    private static func parseHiddenPercent(_ text: String, under header: Header?) -> Line? {
        guard header != nil,
              let m = text.wholeMatch(of: #/(\d+)\s+(.+)/#), let reps = Int(m.1),
              let (lift, rest) = LiftNames.knownPrefix(of: m.2) else { return nil }

        let lastWord = lift.split(separator: " ").last.map { $0.lowercased() } ?? ""
        let repeatsLastWord = rest.split(whereSeparator: \.isWhitespace).contains { $0.lowercased() == lastWord }
        let hasFragments = rest.contains("@") || rest.contains("%") || rest.contains("RM")
        // Complexes joined with + and no @/% are technique work, not a hidden %.
        guard hasFragments || (repeatsLastWord && !text.contains("+")) else { return nil }

        return Line(movement: lift, prLift: lift, sets: [ParsedSet(reps: reps, target: nil)], countsItself: false)
    }

    /// "*Rest 2 minutes between sets." → "Rest 2 minutes between sets"
    private static func clean(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet(charactersIn: "*-–.:").union(.whitespaces))
    }
}
