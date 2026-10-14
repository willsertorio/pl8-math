import PlateKit

/// The three real workouts from Fixtures/README.md, for trying the plate math before the app can read screenshots.
struct SampleWorkout: Identifiable, Hashable {
    struct Lift: Hashable {
        let name: String
        /// The lift whose PR applies.
        let prLift: String
        let sets: [LiftInput.WorkSet]
    }

    let name: String
    let lifts: [Lift]

    var id: String { name }

    /// PR lifts in workout order, without repeats.
    var prLifts: [String] {
        lifts.map(\.prLift).reduce(into: []) { names, name in
            if !names.contains(name) { names.append(name) }
        }
    }

    static let all: [SampleWorkout] = [
        SampleWorkout(
            name: "01/10 · Back Squat",
            lifts: [
                Lift(name: "Back Squat", prLift: "Back Squat", sets: sets(3, [
                    .range(75, 78), .range(75, 78), .range(78, 80), .range(78, 80), .plus(80),
                ])),
            ]
        ),
        SampleWorkout(
            name: "02/10 · Snatch Balance, Snatch",
            lifts: [
                Lift(name: "Snatch Balance", prLift: "Snatch Balance",
                     sets: sets(1, [68, 68, 73, 73, 75, 75].map { .single($0) })),
                Lift(name: "Snatch Pull + Snatch", prLift: "Snatch",
                     sets: sets(1, [68, 68, 70, 73, 75, 75, 78, 78].map { .single($0) })),
            ]
        ),
        SampleWorkout(
            name: "05/10 · Snatch, Back Squat",
            lifts: [
                Lift(name: "Snatch", prLift: "Snatch", sets: sets(1, [
                    .range(75, 80), .range(75, 80), .range(75, 80), .range(80, 83), .range(80, 83), .range(80, 83),
                ])),
                Lift(name: "Back Squat", prLift: "Back Squat",
                     sets: sets(2, Array(repeating: .range(83, 85), count: 5))),
            ]
        ),
    ]

    static let screenshotID = "From screenshot"

    /// A workout from parsed blocks. Blocks whose % is still missing are left out until answered.
    static func fromScreenshot(_ blocks: [StrengthBlock]) -> SampleWorkout {
        let lifts = blocks.compactMap { block -> Lift? in
            let sets = block.sets.compactMap { set in
                set.target.map { LiftInput.WorkSet(reps: set.reps, target: $0) }
            }
            guard !sets.isEmpty, !block.pctMissing else { return nil }
            return Lift(name: block.name, prLift: block.prLift, sets: sets)
        }
        return SampleWorkout(name: screenshotID, lifts: lifts)
    }

    private static func sets(_ reps: Int, _ targets: [Target]) -> [LiftInput.WorkSet] {
        targets.map { LiftInput.WorkSet(reps: reps, target: $0) }
    }
}
