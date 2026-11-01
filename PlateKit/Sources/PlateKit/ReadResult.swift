import Foundation

/// What every reading stage gives back — the rules on the phone, Apple's on-device model, the cloud
/// (docs/DATA-AND-SERVICES.md §2.4) — as JSON:
/// `{"kind": "workout", "unit": "kg", "blocks": [{"label": "A", "lift": "Back squat", "sets": [{"reps": 5, "percent": 75, "weight": null}], "note": "EMOM 10"}]}`
/// or `{"kind": "prs", "unit": null, "prs": [{"lift": "Deadlift", "weight": 180}]}`.
/// A result is used only once it passes `validated()`.
public struct ReadResult: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable { case workout, prs }

    public struct Set: Codable, Hashable, Sendable {
        public let reps: Int
        public let percent: Double?
        /// A fixed load, in the result's unit.
        public let weight: Double?

        public init(reps: Int, percent: Double?, weight: Double?) {
            self.reps = reps
            self.percent = percent
            self.weight = weight
        }
    }

    public struct Block: Codable, Hashable, Sendable {
        /// "A", "B"… when the board gives one.
        public let label: String?
        public let lift: String
        public let sets: [Set]
        /// e.g. "EMOM 10".
        public let note: String?

        public init(label: String?, lift: String, sets: [Set], note: String?) {
            self.label = label
            self.lift = lift
            self.sets = sets
            self.note = note
        }
    }

    public struct PR: Codable, Hashable, Sendable {
        public let lift: String
        public let weight: Double

        public init(lift: String, weight: Double) {
            self.lift = lift
            self.weight = weight
        }
    }

    public let kind: Kind
    public let unit: WeightUnit?
    public let blocks: [Block]?
    public let prs: [PR]?

    public init(kind: Kind, unit: WeightUnit?, blocks: [Block]? = nil, prs: [PR]? = nil) {
        self.kind = kind
        self.unit = unit
        self.blocks = blocks
        self.prs = prs
    }

    // MARK: - Validation (§2.4)

    public static let reps = 1...50
    public static let percent = 30.0...110.0

    /// The heaviest believable weight: 500 kg, or 1,100 lb.
    public static func weights(in unit: WeightUnit?) -> ClosedRange<Double> {
        1...(unit == .lb ? 1100 : 500)
    }

    /// The result with every lift named the way the app names it (`bs` → Back Squat, `c&j` → Clean & Jerk;
    /// a lift we don't know is kept as written), or nil when anything in it is unlikely: reps outside 1–50, a
    /// percent outside 30–110, a weight outside 1–500 kg (1,100 lb), a name that can't be a lift, or nothing at all.
    public func validated() -> ReadResult? {
        let weights = Self.weights(in: unit)
        func name(_ lift: String) -> String? {
            let canonical = LiftNames.canonical(lift.trimmingCharacters(in: .whitespacesAndNewlines))
            return LiftNames.couldBeALift(canonical) ? canonical : nil
        }
        switch kind {
        case .workout:
            guard let blocks, !blocks.isEmpty else { return nil }
            var checked: [Block] = []
            for block in blocks {
                guard let lift = name(block.lift), !block.sets.isEmpty else { return nil }
                for set in block.sets {
                    guard Self.reps.contains(set.reps),
                          set.percent.map({ Self.percent.contains($0) }) ?? true,
                          set.weight.map({ weights.contains($0) }) ?? true else { return nil }
                }
                checked.append(Block(label: block.label, lift: lift, sets: block.sets, note: block.note))
            }
            return ReadResult(kind: .workout, unit: unit, blocks: checked)
        case .prs:
            guard let prs, !prs.isEmpty else { return nil }
            var checked: [PR] = []
            for pr in prs {
                guard let lift = name(pr.lift), weights.contains(pr.weight) else { return nil }
                checked.append(PR(lift: lift, weight: pr.weight))
            }
            return ReadResult(kind: .prs, unit: unit, prs: checked)
        }
    }

    // MARK: - Into the app's own types

    /// The strength blocks the planner works from. Sets with only a fixed weight aren't planned (SPEC 3.6 rule 3:
    /// loads without a % aren't strength work yet), and a block left with no sets goes. Blocks without a letter
    /// carry on from the one before.
    public func strengthBlocks() -> [StrengthBlock] {
        var result: [StrengthBlock] = []
        var next: Character = "A"
        for block in blocks ?? [] {
            let sets = block.sets.filter { $0.percent != nil || $0.weight == nil }
                .map { ParsedSet(reps: $0.reps, target: $0.percent.map { .single($0) }) }
            guard !sets.isEmpty else { continue }
            var letter = String(next)
            if let label = block.label?.trimmingCharacters(in: .whitespaces).uppercased(), label.count == 1,
               let character = label.first, character.isLetter, character.isASCII {
                letter = label
                next = character
            }
            next = Character(UnicodeScalar(min(90, next.asciiValue! + 1)))
            let lift = LiftNames.canonical(block.lift)
            // "EMOM 10", "E2MOM 12": the block's format.
            let format = block.note.flatMap { $0.firstMatch(of: #/^\s*(E\d*MOM)\b/#.ignoresCase()) }.map { $0.1.uppercased() }
            result.append(.read(letter: letter, lift: lift, format: format, note: block.note, sets: sets))
        }
        return result
    }

    /// The PRs, each in the result's unit (nil when it didn't say: the app asks once, SPEC 3.7).
    public func prEntries() -> [PREntry] {
        (prs ?? []).map { PREntry(lift: LiftNames.canonical($0.lift), value: $0.weight, unit: unit) }
    }
}
