/// Lift names: case-insensitive, trimmed, with aliases (SPEC 3.6 rule 7).
public enum LiftNames {
    /// The default PR list (SPEC Part 4).
    public static let defaultPRLifts = ["Back Squat", "Front Squat", "Deadlift", "Clean", "Snatch", "Bench Press"]

    static let known = defaultPRLifts + [
        "Overhead Squat", "Snatch Balance", "Power Snatch", "Hang Snatch", "Squat Snatch",
        "Power Clean", "Hang Clean", "Squat Clean", "Clean & Jerk", "Jerk", "Push Jerk", "Split Jerk",
        "Strict Press", "Push Press", "Thruster", "Sumo Deadlift",
    ]

    static let aliases = [
        "bs": "Back Squat",
        "fs": "Front Squat",
        "ohs": "Overhead Squat",
        "dl": "Deadlift",
        "c&j": "Clean & Jerk",
        "clean and jerk": "Clean & Jerk",
    ]

    /// "  back   squat " → "Back Squat", "BS" → "Back Squat", "backsquat" → "Back Squat" (spaces, dashes and
    /// case don't make a new lift). Unknown lifts are tidied the same way every time: "pull ups" → "Pull Ups".
    public static func canonical(_ name: String) -> String {
        let tidy = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if let known = lookup[tidy.lowercased()] ?? compactLookup[key(tidy)] { return known }
        // Only all-lowercase or ALL-CAPS names get capitalised; "Clean to Parallel" is left as written.
        guard tidy == tidy.lowercased() || tidy == tidy.uppercased() else { return tidy }
        return tidy.split(separator: " ").map { word in
            word.first!.isLetter ? word.prefix(1).uppercased() + word.dropFirst().lowercased() : String(word)
        }.joined(separator: " ")
    }

    /// The same for every spelling of a lift: letters and digits only, lowercased ("Pull-Ups" → "pullups";
    /// "&" counts as "and"). Use it to find a lift's one PR.
    public static func key(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: "&", with: "and").filter { $0.isLetter || $0.isNumber }
    }

    /// The known lift `text` starts with (longest match, whole words) and what follows it.
    static func knownPrefix(of text: Substring) -> (name: String, rest: Substring)? {
        let lower = text.lowercased()
        for key in lookupKeysLongestFirst where lower.hasPrefix(key) {
            let rest = text.dropFirst(key.count)
            if rest.first.map({ !$0.isLetter }) ?? true {
                return (lookup[key]!, rest)
            }
        }
        return nil
    }

    /// The first known lift named anywhere in `text` (whole words, longest name at that spot), e.g. the PR a
    /// complex like "Muscle Clean + 3 Hang Power Clean" is based on → "Clean".
    public static func firstKnown(in text: String) -> String? {
        let lower = text.lowercased()
        var best: (offset: Int, name: String)?
        for key in lookupKeysLongestFirst {
            var start = lower.startIndex
            while let range = lower.range(of: key, range: start..<lower.endIndex) {
                let wordStart = range.lowerBound == lower.startIndex || !lower[lower.index(before: range.lowerBound)].isLetter
                let wordEnd = range.upperBound == lower.endIndex || !lower[range.upperBound].isLetter
                if wordStart && wordEnd {
                    let offset = lower.distance(from: lower.startIndex, to: range.lowerBound)
                    if best.map({ offset < $0.offset }) ?? true {
                        best = (offset, lookup[key]!)
                    }
                    break
                }
                start = range.upperBound
            }
        }
        return best?.name
    }

    private static let lookup: [String: String] = {
        var table = aliases
        for name in known { table[name.lowercased()] = name }
        return table
    }()

    private static let compactLookup: [String: String] = {
        var table: [String: String] = [:]
        for (alias, name) in lookup { table[key(alias)] = name }
        return table
    }()

    private static let lookupKeysLongestFirst = lookup.keys.sorted { $0.count > $1.count }
}
