/// Lift names: case-insensitive, trimmed, with aliases (SPEC 3.6 rule 7).
public enum LiftNames {
    /// Pulls start with the bar on the floor (prototype liftOnFloor: dead, snatch or clean in the name).
    public static func startsOnFloor(_ name: String) -> Bool {
        let lower = name.lowercased()
        return ["dead", "snatch", "clean"].contains { lower.contains($0) }
    }

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
        "cj": "Clean & Jerk",
        "clean and jerk": "Clean & Jerk",
        "bench": "Bench Press",
    ]

    /// "  back   squat " → "Back Squat", "BS" → "Back Squat", "backsquat" → "Back Squat" (spaces, dashes and
    /// case don't make a new lift). Unknown lifts are tidied the same way every time: "pull ups" → "Pull Ups".
    /// Could this be a lift's name? Letters, none of the marks a lift never has ("@ 80%" is a set, "Total R$" a
    /// receipt), and none of a receipt's words ("Order completed", "Subtotal"), whole words only (2026-10-30).
    public static func couldBeALift(_ name: String) -> Bool {
        guard name.contains(#/[A-Za-z]{2}/#), !name.contains(where: { "@%!?$€£¥#".contains($0) }) else { return false }
        let words = name.lowercased().split { !$0.isLetter }
        return !words.contains { receiptWords.contains(String($0)) }
    }

    static let receiptWords: Set<String> = [
        "order", "completed", "subtotal", "total", "shipping", "delivery", "fee", "discount", "tax", "payment", "paid",
        "price", "amount", "receipt", "invoice", "purchase",
    ]

    /// "Back Squat" → "Back squat": how the Flow's questions and the PR notebook write a lift.
    public static func sentenceCase(_ name: String) -> String {
        guard let first = name.first else { return name }
        return String(first).uppercased() + name.dropFirst().lowercased()
    }

    public static func canonical(_ name: String) -> String {
        let tidy = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if let known = lookup[tidy.lowercased()] ?? compactLookup[key(tidy)] { return known }
        // A plural of a lift we know: "cleans", "Back squats", "snatches".
        for cut in [1, 2] where tidy.count > cut + 2 && tidy.lowercased().hasSuffix(cut == 1 ? "s" : "es") {
            if let known = compactLookup[key(String(tidy.dropLast(cut)))] { return known }
        }
        // Only all-lowercase or ALL-CAPS names get capitalised; "Clean to Parallel" is left as written.
        guard tidy == tidy.lowercased() || tidy == tidy.uppercased() else { return tidy }
        return tidy.split(separator: " ").map { word in
            word.first!.isLetter ? word.prefix(1).uppercased() + word.dropFirst().lowercased() : String(word)
        }.joined(separator: " ")
    }

    /// A lift we know, however it's spelled ("back squats", "BS").
    public static func isKnown(_ name: String) -> Bool { known.contains(canonical(name)) }

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
