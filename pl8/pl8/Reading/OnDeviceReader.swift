#if canImport(FoundationModels)
import Foundation
import FoundationModels
import PlateKit

/// Apple's on-device model (iOS 26+, phones with Apple Intelligence) reading the text the phone recognised into
/// the same result as every stage (docs/DATA-AND-SERVICES.md §2, step 2). Guided generation fills these types, so
/// the answer always has the result's shape; the checks still decide if it's used. Nothing leaves the phone.
@available(iOS 26.0, *)
enum OnDeviceReader {
    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    static func read(_ kind: ReadResult.Kind, text: String) async throws -> ReadResult? {
        let session = LanguageModelSession(instructions: instructions(kind))
        switch kind {
        case .workout:
            let answer = try await session.respond(to: text, generating: GeneratedWorkout.self).content
            return ReadResult(kind: .workout, unit: WeightUnit(rawValue: answer.unit), blocks: answer.blocks.map(block))
        case .prs:
            let answer = try await session.respond(to: text, generating: GeneratedPRs.self).content
            return ReadResult(kind: .prs, unit: WeightUnit(rawValue: answer.unit),
                              prs: answer.prs.map { ReadResult.PR(lift: $0.lift, weight: $0.weight) })
        }
    }

    /// 0 and "" mean "not written".
    private nonisolated static func block(_ block: GeneratedBlock) -> ReadResult.Block {
        let label: String? = block.label.isEmpty ? nil : block.label
        let note: String? = block.note.isEmpty ? nil : block.note
        return ReadResult.Block(label: label, lift: block.lift, sets: block.sets.map(set), note: note)
    }

    private nonisolated static func set(_ set: GeneratedSet) -> ReadResult.Set {
        let percent: Double? = set.percent > 0 ? set.percent : nil
        let weight: Double? = set.weight > 0 ? set.weight : nil
        return ReadResult.Set(reps: set.reps, percent: percent, weight: weight)
    }

    /// The schema's rules in words (§2.4); the types below carry its shape.
    private static func instructions(_ kind: ReadResult.Kind) -> String {
        switch kind {
        case .workout:
            """
            You read the text of a photo of a CrossFit whiteboard or a box app and return only its strength work: \
            each lift with its sets. A set has reps (1 to 50) and either a percent of 1RM (30 to 110) or a fixed \
            weight; use 0 for what isn't written. Unit is "kg", "lb" or "" when not written. Label is the block's \
            letter ("A") or "". Note holds a format like "EMOM 10" or "". Leave out conditioning work without a \
            percent. Never guess: if something isn't clear, leave it out, and return no blocks if nothing is clear.
            """
        case .prs:
            """
            You read the text of a photo of a list of personal records (1RM) and return each lift with its weight. \
            Unit is "kg", "lb" or "" when not written. Weights are between 1 and 500 kg or 1 and 1100 lb. Leave \
            out anything that isn't a lift, like totals, prices or dates. Never guess: return no PRs if nothing is clear.
            """
        }
    }
}

@available(iOS 26.0, *)
@Generable
nonisolated struct GeneratedSet {
    @Guide(description: "Repetitions in the set, 1 to 50")
    var reps: Int
    @Guide(description: "Percent of the 1RM, 30 to 110, or 0 when not written")
    var percent: Double
    @Guide(description: "A fixed weight, or 0 when not written")
    var weight: Double
}

@available(iOS 26.0, *)
@Generable
nonisolated struct GeneratedBlock {
    @Guide(description: "The block's letter, like A, or empty")
    var label: String
    @Guide(description: "The lift, like Back squat")
    var lift: String
    var sets: [GeneratedSet]
    @Guide(description: "A format like EMOM 10, or empty")
    var note: String
}

@available(iOS 26.0, *)
@Generable
nonisolated struct GeneratedWorkout {
    @Guide(description: "kg, lb, or empty when not written")
    var unit: String
    var blocks: [GeneratedBlock]
}

@available(iOS 26.0, *)
@Generable
nonisolated struct GeneratedPR {
    @Guide(description: "The lift, like Deadlift")
    var lift: String
    var weight: Double
}

@available(iOS 26.0, *)
@Generable
nonisolated struct GeneratedPRs {
    @Guide(description: "kg, lb, or empty when not written")
    var unit: String
    var prs: [GeneratedPR]
}
#endif
