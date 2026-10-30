import Foundation

/// Workouts as coaches write them on a whiteboard (docs/DATA-AND-SERVICES.md §2.3), read when the box app's format
/// (WorkoutParser) finds nothing:
/// `Back squat 5x5 @ 75%` · `5 × 5 @ 75%` (the lift on the line above) · `Deadlift 3-3-3 @80%` ·
/// `EMOM 10: 3 cleans @ 70%` · `Bench 5/3/1` · `Strict press 4x6 @ 40kg` · `A. BACK SQUAT` then `5x5 @ 75%`.
/// `×`/`x`/`X`, `@`, `%`, `kg`/`lb`/`#` and spacing are normalised. A line that's unclear (no lift for its sets,
/// a load that isn't a % or a weight) is left out, never guessed; the result is checked like every stage's.
public enum BoardFormats {
    public static func read(_ text: String) -> ReadResult? {
        var blocks: [ReadResult.Block] = []
        var units: [WeightUnit] = []
        var label: String?
        var lift: String?
        var emom: (count: Int, note: String)?

        func add(_ scheme: Scheme) {
            guard let name = scheme.lift ?? lift else { return }
            var sets = scheme.sets
            // A format header repeats a single set (SPEC 3.6 rule 5); `NxR` and `3-3-3` count their own.
            if let emom, scheme.single, emom.count > 1 { sets = Array(repeating: sets[0], count: emom.count) }
            if let unit = scheme.unit { units.append(unit) }
            let note = emom?.note
            if let last = blocks.last, last.lift == name, last.label == label, last.note == note {
                blocks[blocks.count - 1] = .init(label: label, lift: name, sets: last.sets + sets, note: note)
            } else {
                blocks.append(.init(label: label, lift: name, sets: sets, note: note))
            }
            lift = name
        }

        for raw in OCRText.latinized(text).split(whereSeparator: \.isNewline) {
            let line = normalized(String(raw))
            guard !line.isEmpty else { continue }
            // "A. BACK SQUAT": a new section, maybe naming its lift, maybe with its sets on the same line.
            if let m = line.wholeMatch(of: #/(?<letter>[A-Z])[.)]\s*(?<rest>.*)/#) {
                label = String(m.letter)
                emom = nil
                lift = nil
                let rest = String(m.rest)
                if let scheme = scheme(in: rest) { add(scheme) } else if LiftNames.isKnown(rest) { lift = LiftNames.canonical(rest) }
                continue
            }
            // "EMOM 10", "EMOM 10: 3 cleans @ 70%", "E2MOM 12 min".
            if let m = line.wholeMatch(of: #/(?<every>E(?<n>\d*)MOM)\s*(?<minutes>\d+)\s*(?:min(?:utes?)?)?\s*:?\s*(?<rest>.*)/#.ignoresCase()),
               let minutes = Int(m.minutes) {
                let every = Int(m.n) ?? 1
                emom = (max(1, minutes / max(1, every)), "\(m.every.uppercased()) \(minutes)")
                let rest = String(m.rest)
                if !rest.isEmpty, let scheme = scheme(in: rest) { add(scheme) }
                continue
            }
            if let scheme = scheme(in: line) {
                add(scheme)
            } else if !line.contains(where: \.isNumber), LiftNames.isKnown(line) {
                // A lift on its own line: the sets below are its.
                lift = LiftNames.canonical(line)
            }
        }
        guard !blocks.isEmpty else { return nil }
        return ReadResult(kind: .workout, unit: units.first, blocks: blocks).validated()
    }

    // MARK: - Lines

    struct Scheme {
        let lift: String?
        let sets: [ReadResult.Set]
        /// One set as written ("3 cleans @ 70%"): a format header repeats it.
        let single: Bool
        let unit: WeightUnit?
    }

    /// "Back squat 5x5 @ 75%", "Deadlift 3-3-3 @80%", "Bench 5/3/1", "3 cleans @ 70%", "5x5 @ 75%".
    static func scheme(in line: String) -> Scheme? {
        let liftPart = #"(?<lift>[A-Za-z][A-Za-z&'. -]*?)"#
        let loadPart = #"(?:\s*(?<load>@.*))?"#
        // Sets × reps.
        if let m = try? Regex(#"^\#(liftPart)?\s*(?<sets>\d+)\s*x\s*(?<reps>\d+)\#(loadPart)$"#).wholeMatch(in: line),
           let sets = m["sets"]?.substring.flatMap({ Int($0) }), let reps = m["reps"]?.substring.flatMap({ Int($0) }),
           sets > 0, let load = load(m["load"]?.substring) {
            let set = ReadResult.Set(reps: reps, percent: load.percent, weight: load.weight)
            return make(lift: m["lift"]?.substring, sets: Array(repeating: set, count: sets), single: false, unit: load.unit)
        }
        // Reps for each set: 3-3-3, 5/3/1.
        if let m = try? Regex(#"^\#(liftPart)?\s*(?<reps>\d+(?:\s*[-/]\s*\d+)+)\#(loadPart)$"#).wholeMatch(in: line),
           let list = m["reps"]?.substring, let load = load(m["load"]?.substring) {
            let reps = list.split(whereSeparator: { "-/ ".contains($0) }).compactMap { Int($0) }
            let sets = reps.map { ReadResult.Set(reps: $0, percent: load.percent, weight: load.weight) }
            return make(lift: m["lift"]?.substring, sets: sets, single: false, unit: load.unit)
        }
        // Reps, then the lift, then its load: "3 cleans @ 70%".
        if let m = try? Regex(#"^(?<reps>\d+)\s+\#(liftPart)\s*(?<load>@.*)$"#).wholeMatch(in: line),
           let reps = m["reps"]?.substring.flatMap({ Int($0) }), let load = load(m["load"]?.substring), load.given {
            let set = ReadResult.Set(reps: reps, percent: load.percent, weight: load.weight)
            return make(lift: m["lift"]?.substring, sets: [set], single: true, unit: load.unit)
        }
        return nil
    }

    private static func make(lift text: Substring?, sets: [ReadResult.Set], single: Bool, unit: WeightUnit?) -> Scheme? {
        guard !sets.isEmpty else { return nil }
        let name = text.map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: " .-")) }.flatMap { $0.isEmpty ? nil : $0 }
        if let name, !LiftNames.couldBeALift(name) { return nil }
        return Scheme(lift: name.map(LiftNames.canonical), sets: sets, single: single, unit: unit)
    }

    /// "@ 75%" → a percent, "@ 40kg" / "@ 225 lb" / "@ 225#" → a weight; nothing → neither. Anything else is unclear.
    private static func load(_ text: Substring?) -> (percent: Double?, weight: Double?, unit: WeightUnit?, given: Bool)? {
        guard let text else { return (nil, nil, nil, false) }
        if let m = text.wholeMatch(of: #/@\s*(?<value>\d+(?:[.,]\d+)?)\s*%/#), let value = number(m.value) {
            return (value, nil, nil, true)
        }
        if let m = text.wholeMatch(of: #/@\s*(?<value>\d+(?:[.,]\d+)?)\s*(?<unit>kgs?|kilos?|lbs?|pounds?)/#.ignoresCase()),
           let value = number(m.value) {
            return (nil, value, m.unit.lowercased().hasPrefix("k") ? .kg : .lb, true)
        }
        return nil
    }

    /// One spelling: `×`/`X` → `x` between numbers, `#` → `lb`, single spaces.
    static func normalized(_ line: String) -> String {
        var text = line.replacingOccurrences(of: "×", with: "x")
        text = text.replacing(#/(\d)\s*[xX]\s*(\d)/#) { "\($0.1)x\($0.2)" }
        text = text.replacing(#/(\d)\s*#/#) { "\($0.1) lb" }
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func number(_ text: Substring) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }
}
