import Foundation
import PlateKit

/// Turns saved data (blocks, gym, PRs) into PlateKit's plan.
enum Planner {
    /// The plan for these blocks in this gym. Blocks still missing a % are left out.
    static func plan(blocks: [StrengthBlock], gym: Gym?, records: [PersonalRecord]) -> SessionPlan {
        let lifts = blocks.filter { !$0.pctMissing }.map { block in
            let record = self.record(for: block.prLift, in: records)
            return LiftInput(
                name: block.name,
                pr: record?.value ?? 0,
                prUnit: record?.unit ?? .kg,
                sets: block.sets.compactMap { set in
                    set.target.map { LiftInput.WorkSet(reps: set.reps, target: $0) }
                }
            )
        }
        return SessionPlan(gym: gym?.setup ?? GymSetup(unit: .lb), lifts: lifts)
    }

    /// The PR each planned lift is based on, in plan order (same blocks `plan` keeps).
    static func prLifts(blocks: [StrengthBlock]) -> [String] {
        blocks.filter { !$0.pctMissing }.map { LiftNames.canonical($0.prLift) }
    }

    /// PR lifts these blocks need that have no value yet, in workout order.
    static func missingPRs(blocks: [StrengthBlock], records: [PersonalRecord]) -> [String] {
        var names: [String] = []
        for block in blocks {
            let name = LiftNames.canonical(block.prLift)
            if record(for: name, in: records)?.value == nil, !names.contains(name) {
                names.append(name)
            }
        }
        return names
    }

    static func record(for lift: String, in records: [PersonalRecord]) -> PersonalRecord? {
        let name = LiftNames.canonical(lift)
        return records.first { $0.lift == name }
    }

    // MARK: - What the room's boards say (M6)

    /// The PR board: every PR with a value, by lift name, e.g. "100 kg".
    static func boardRows(_ records: [PersonalRecord]) -> [BoardRow] {
        records
            .filter { ($0.value ?? 0) > 0 }
            .sorted { $0.lift < $1.lift }
            .map { BoardRow(left: $0.lift, right: "\(WeightUnit.trimmed((($0.value ?? 0) * 10).rounded() / 10)) \($0.unit.rawValue)") }
    }

    /// The whiteboard: today's workout, one line per lift.
    static func boardLines(for workout: Workout?, gym: Gym?, records: [PersonalRecord]) -> [BoardLine] {
        guard let workout else { return [] }
        return BoardLine.lines(for: plan(blocks: workout.blocks, gym: gym, records: records))
    }
}
