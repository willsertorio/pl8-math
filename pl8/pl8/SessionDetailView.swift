import Foundation
import SwiftUI
import PlateKit

/// A saved session: every set as it was planned, grouped by warm-up and lift.
struct SessionDetailView: View {
    let session: Session

    private var groups: [(title: String, logs: [SetLog])] {
        let logs = session.orderedLogs
        var result: [(title: String, logs: [SetLog])] = []
        let warmUp = logs.filter(\.isWarmUp)
        if !warmUp.isEmpty { result.append(("Warm-up", warmUp)) }
        for (index, name) in session.liftNames.enumerated() {
            let sets = logs.filter { !$0.isWarmUp && $0.blockIndex == index }
            if !sets.isEmpty { result.append((name, sets)) }
        }
        return result
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Gym", value: session.gymName)
                LabeledContent("Bar", value: "\(WeightUnit.trimmed(session.barWeight)) \(session.gymUnit.rawValue)")
                if let workout = session.workout {
                    LabeledContent("Workout", value: workout.title)
                }
            }

            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                Section(group.title) {
                    ForEach(group.logs) { log in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("\(log.reps) × \(WeightUnit.trimmed(log.plannedTotal)) \(log.unit.rawValue)")
                                    .font(.headline)
                                Spacer()
                                Text(log.pctText).foregroundStyle(.secondary)
                            }
                            Text(log.perSide.isEmpty
                                 ? "Empty bar"
                                 : log.perSide.map(WeightUnit.trimmed).joined(separator: " + ") + " each side")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(session.createdAt.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }
}
