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
    /// Effort out of 10 when the board gives RPE instead of a % (`@ 5/10 RPE`).
    public private(set) var rpe: Double? = nil

    /// Some % couldn't be read; ask "What % for Back Squat?".
    public var pctMissing: Bool { sets.contains { $0.target == nil } }

    /// For an RPE block: RPE × 10, offered as the answer to "What % for …?" (DECISIONS 2026-10-14).
    public var suggestedTarget: Target? {
        rpe.map { .single($0 * 10) }
    }

    /// Fixes blocks saved by older parser versions: a PR name with no letters (")" — Fixtures 14/10) falls back to
    /// the movement.
    public func repaired() -> StrengthBlock {
        guard !prLift.contains(where: \.isLetter) else { return self }
        return settingPRLift(WorkoutParser.movementName(name))
    }

    /// The same block based on another PR (e.g. a complex the app guessed wrong).
    public func settingPRLift(_ lift: String) -> StrengthBlock {
        StrengthBlock(letter: letter, label: label, name: name, prLift: LiftNames.canonical(lift), format: format,
                      note: note, sets: sets, rpe: rpe)
    }

    /// A lift from the "Type it in" form: sets × reps at one % (SPEC 2.2, simple form).
    public static func typed(letter: String, lift: String, sets: Int, reps: Int, target: Target) -> StrengthBlock {
        let name = LiftNames.canonical(lift)
        let set = ParsedSet(reps: max(1, reps), target: target)
        return StrengthBlock(letter: letter, label: nil, name: name, prLift: name, format: nil, note: nil,
                             sets: Array(repeating: set, count: max(1, sets)))
    }

    /// Within the limits every reading stage is held to (§2.4): reps 1–50, any % between 30 and 110, at least one set.
    public var isLikely: Bool {
        !sets.isEmpty && sets.allSatisfy { set in
            ReadResult.reps.contains(set.reps) && set.target.map { target in
                ReadResult.percent.contains(target.low) && (target.high.map { ReadResult.percent.contains($0) } ?? true)
            } ?? true
        }
    }

    /// The same block with other sets (tests).
    func replacingSets(_ sets: [ParsedSet]) -> StrengthBlock {
        StrengthBlock(letter: letter, label: label, name: name, prLift: prLift, format: format, note: note, sets: sets, rpe: rpe)
    }

    /// A block from a reading result (ReadResult): one lift, its PR the lift itself.
    static func read(letter: String, lift: String, format: String?, note: String?, sets: [ParsedSet]) -> StrengthBlock {
        StrengthBlock(letter: letter, label: nil, name: lift, prLift: lift, format: format, note: note, sets: sets)
    }

    /// The same block with every set at `target` (editing the plan).
    public func settingPercent(_ target: Target) -> StrengthBlock {
        StrengthBlock(letter: letter, label: label, name: name, prLift: prLift, format: format, note: note,
                      sets: sets.map { ParsedSet(reps: $0.reps, target: target) }, rpe: rpe)
    }

    /// The same block with every unread % set to `target`.
    public func fillingMissingPercent(with target: Target) -> StrengthBlock {
        StrengthBlock(letter: letter, label: label, name: name, prLift: prLift, format: format, note: note,
                      sets: sets.map { ParsedSet(reps: $0.reps, target: $0.target ?? target) }, rpe: rpe)
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
    /// Several screenshots of one workout (SPEC 3.6 rule 9). They may overlap and may be picked in any order:
    /// lines a screenshot repeats from an earlier one are dropped, a block letter seen twice keeps its longer
    /// version, and blocks come out in letter order.
    public static func parse(screenshots: [String]) -> [StrengthBlock] {
        var sections: [Section] = []
        var earlierLines: [String] = []          // normalized, every screenshot so far
        for (shot, text) in screenshots.enumerated() {
            let lines = prepare(text)
            let (leading, shotSections) = split(lines, shot: shot)

            // Lines before this screenshot's first letter continue the previous screenshot's last block,
            // unless they're the overlap.
            let fresh = droppingOverlap(leading, earlier: earlierLines)
            if !fresh.isEmpty, let last = sections.lastIndex(where: { $0.shot == shot - 1 }) {
                sections[last].lines += fresh
            }

            for section in shotSections {
                if let index = sections.firstIndex(where: { $0.letter == section.letter && $0.shot != shot }) {
                    if section.lines.count > sections[index].lines.count { sections[index] = section }
                } else {
                    sections.append(section)
                }
            }
            earlierLines += lines.map(normalized)
        }

        let ordered = sections.enumerated()
            .sorted { ($0.element.letter, $0.offset) < ($1.element.letter, $1.offset) }
            .map(\.element)
        let blocks = ordered.flatMap { parseBlock(letter: $0.letter, label: $0.label, lines: $0.lines) }
        guard blocks.isEmpty else { return blocks }
        // Not the box app's format: a whiteboard's (docs/DATA-AND-SERVICES.md §2.3), checked like every stage's.
        return BoardFormats.read(screenshots.joined(separator: "\n"))?.strengthBlocks() ?? []
    }

    /// The box app's format first; when it finds nothing, the whiteboard formats (BoardFormats).
    public static func parse(_ text: String) -> [StrengthBlock] {
        parse(screenshots: [text])
    }

    private struct Section {
        let letter: String
        let label: String?
        var lines: [String]
        /// Which screenshot it came from.
        let shot: Int
    }

    /// Latin letters, trimmed non-empty lines, wrapped lines joined.
    private static func prepare(_ text: String) -> [String] {
        let lines = OCRText.latinized(text).split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return joinWrappedLines(lines)
    }

    /// Lines before the first block letter, and the blocks ("A." or "C. After a Party").
    private static func split(_ lines: [String], shot: Int) -> (leading: [String], sections: [Section]) {
        var leading: [String] = []
        var sections: [Section] = []
        for line in lines {
            if let match = line.wholeMatch(of: #/([A-Z])\.(?:\s+(.+))?/#) {
                sections.append(Section(letter: String(match.1), label: match.2.map { clean(String($0)) }, lines: [], shot: shot))
            } else if sections.isEmpty {
                leading.append(line)
            } else {
                sections[sections.count - 1].lines.append(line)
            }
        }
        return (leading, sections)
    }

    /// Finds the longest run of `lines` an earlier screenshot already showed (in a row) and drops everything up to
    /// its end: the overlap, and the status bar and title above it.
    private static func droppingOverlap(_ lines: [String], earlier: [String]) -> [String] {
        let keys = lines.map(normalized)
        for count in stride(from: keys.count, through: 1, by: -1) {
            for start in 0...(keys.count - count) {
                let run = Array(keys[start..<(start + count)])
                let seen = earlier.count >= count && (0...(earlier.count - count)).contains { from in
                    Array(earlier[from..<(from + count)]) == run
                }
                if seen { return Array(lines.dropFirst(start + count)) }
            }
        }
        return lines
    }

    /// Compares lines the way OCR repeats them: no spaces, any case.
    private static func normalized(_ line: String) -> String {
        line.filter { !$0.isWhitespace }.lowercased()
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
        if isAppButton(line) { return false }
        if line.firstMatch(of: #/^\d+\s/#) != nil { return false }

        // An RPE line is complete like a % line.
        if previous.firstMatch(of: #/@\s*(?:RPE|\d+(?:[.,]\d+)?\s*(?:\/\s*10)?\s*RPE)/#.ignoresCase()) != nil { return false }
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
        /// "N Sets": several lines are one round, done N times. EMOM lines are never repeated.
        var repeatsRound = false
        /// "2-3 Sets": always rounds, even when the line count equals the lower number.
        var isRange = false
    }

    private struct Line {
        let movement: String
        let prLift: String
        let sets: [ParsedSet]
        /// `NxR` lines say their own set count; a format header doesn't expand them.
        let countsItself: Bool
        var rpe: Double? = nil
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
            } else if let line = parseStrength(text) ?? parseRPE(text) ?? parseHiddenPercent(text, under: header) {
                if let last = lifts.last, last.movement == line.movement, last.prLift == line.prLift {
                    lifts[lifts.count - 1].lines.append(line)
                } else {
                    lifts.append(Lift(movement: line.movement, prLift: line.prLift, header: header, lines: [line]))
                }
            } else if isAppNoise(text) {
                continue
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
            } else if let header = lift.header, header.repeatsRound, header.count > 1,
                      lift.lines.count > 1, header.isRange || lift.lines.count != header.count,
                      !lift.lines.contains(where: \.countsItself) {
                sets = Array(Array(repeating: sets, count: header.count).joined())
            }
            return StrengthBlock(
                letter: letter,
                label: label,
                name: lift.movement,
                prLift: lift.prLift,
                format: lift.header?.format,
                note: lift.notes.isEmpty ? nil : lift.notes.joined(separator: " "),
                sets: sets,
                rpe: lift.lines.first?.rpe
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
        // "2-3 Sets" → 2 (DECISIONS 2026-10-14)
        if let m = text.wholeMatch(of: #/(\d+)\s*(?:[-–]|to)\s*\d+\s*sets?/#.ignoresCase()), let n = Int(m.1) {
            return Header(format: nil, count: n, repeatsRound: true, isRange: true)
        }
        if let m = text.wholeMatch(of: #/(\d+)\s*sets?/#.ignoresCase()), let n = Int(m.1) {
            return Header(format: nil, count: n, repeatsRound: true)
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
            prText = liftText(String(rm.1))
        }
        let move = movementName(String(movement))
        guard !move.isEmpty || !prText.isEmpty else { return nil }
        let prLift = prText.isEmpty ? move : LiftNames.canonical(prText)

        return Line(
            movement: move.isEmpty ? prLift : move,
            prLift: prLift,
            sets: Array(repeating: ParsedSet(reps: reps, target: target), count: setCount),
            countsItself: setCount > 1
        )
    }

    /// `3 Muscle Clean + 3 Tall Cleans @ 5/10 RPE`, `3 Front Squat @ RPE 8`: % missing, RPE kept for a suggestion.
    /// The PR is the first known lift named in the line.
    private static func parseRPE(_ text: String) -> Line? {
        let pattern = #/(?<reps>\d+)\s+(?<move>.+?)\s*@\s*(?:RPE\s*(?<a>\d+(?:[.,]\d+)?)|(?<b>\d+(?:[.,]\d+)?)\s*(?:\/\s*10)?\s*RPE)\b.*/#.ignoresCase()
        guard let match = text.wholeMatch(of: pattern), let reps = Int(match.reps),
              let rpe = (match.a ?? match.b).flatMap(number), rpe > 0, rpe <= 10 else { return nil }
        let movement = movementName(String(match.move))
        return Line(
            movement: movement,
            prLift: LiftNames.firstKnown(in: movement) ?? movement,
            sets: [ParsedSet(reps: reps, target: nil)],
            countsItself: false,
            rpe: rpe
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

    /// "Deadlift (315/225) (OR" → "Deadlift": fixed loads in brackets and a dangling "or" aren't the movement.
    static func movementName(_ text: String) -> String {
        var name = text.replacing(#/\([^)]*\)/#, with: " ")
        if let open = name.firstIndex(of: "(") { name = String(name[..<open]) }
        name = name.replacing(#/\s+(?:or|ou)\s*$/#.ignoresCase(), with: "")
        return LiftNames.canonical(liftText(name))
    }

    /// The lift after "1RM", without brackets or punctuation around it. Nothing left (e.g. ")") means none.
    static func liftText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.symbols).union(.whitespaces))
        return trimmed.contains(where: \.isLetter) ? trimmed : ""
    }

    /// The box app's own buttons: "Check-In", "Ações".
    private static func isAppButton(_ line: String) -> Bool {
        ["check-in", "ações", "acoes"].contains(line.lowercased())
    }

    /// Buttons and stray marks ("L 0", "c") that aren't labels or notes.
    private static func isAppNoise(_ line: String) -> Bool {
        isAppButton(line) || line.filter(\.isLetter).count < 3
    }

    /// "*Rest 2 minutes between sets." → "Rest 2 minutes between sets"
    private static func clean(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet(charactersIn: "*-–.:").union(.whitespaces))
    }
}
