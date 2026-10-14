import SwiftData
import SwiftUI
import PlateKit

/// The session's plan: kit, warm-up and every set. Set by set comes in the next M4 step.
struct PlanView: View {
    let workout: Workout

    @Query private var gyms: [Gym]
    @Query private var records: [PersonalRecord]

    private var gym: Gym? { gyms.first { $0.isCurrent } ?? gyms.first }

    var body: some View {
        let plan = Planner.plan(blocks: workout.blocks, gym: gym, records: records)
        let unit = plan.gym.unit
        List {
            Section("Plate kit") {
                LabeledContent("Bar", value: "\(WeightUnit.trimmed(plan.kit.bar)) \(unit.rawValue)")
                ForEach(plan.kit.plates, id: \.size) { item in
                    LabeledContent("\(WeightUnit.trimmed(item.size)) \(unit.rawValue)", value: "× \(item.count)")
                }
            }
            .listRowBackground(Theme.paper)

            if !plan.warmUp.isEmpty {
                Section("Warm-up") {
                    ForEach(plan.warmUp, id: \.round.number) { set in
                        SetRow(
                            title: "\(set.round.label) · \(set.reps) reps",
                            total: unit.display(set.load.total, in: plan.lifts.first?.prUnit ?? unit),
                            detail: set.round.percentText,
                            plates: platesText(set.load.perSide, unit),
                            change: set.change.text
                        )
                    }
                }
                .listRowBackground(Theme.paper)
            }

            ForEach(Array(plan.lifts.enumerated()), id: \.offset) { _, lift in
                Section(lift.name) {
                    ForEach(lift.sets, id: \.number) { set in
                        SetRow(
                            title: "Set \(set.number) · \(set.reps) \(set.reps == 1 ? "rep" : "reps")",
                            total: plan.displayTotal(set),
                            detail: set.target.text,
                            plates: platesText(set.load.perSide, unit),
                            change: set.change.text,
                            warning: set.load.isLighterThanBar ? "Lighter than the bar" : nil
                        )
                    }
                }
                .listRowBackground(Theme.paper)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func platesText(_ perSide: [Double], _ unit: WeightUnit) -> String {
        if perSide.isEmpty { return "Empty bar" }
        return perSide.map(WeightUnit.trimmed).joined(separator: " + ") + " \(unit.rawValue) each side"
    }
}
