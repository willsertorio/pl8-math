import Foundation
import SwiftData
import SwiftUI
import PlateKit

/// "Ready to lift?" (SPEC 2.2 step 3), like the prototype's wodReady: the plan is on the whiteboard in the room;
/// anything missing is asked first (a PR, a %), then Start training · Edit · Cancel. With a session already under
/// way: Back to the set.
struct ReadyToLift: View {
    let workout: Workout
    var onStart: (Workout) -> Void
    var onResume: (Session) -> Void = { _ in }

    @Environment(\.modelContext) private var context
    @Query private var records: [PersonalRecord]
    @State private var prValues: [String: Double] = [:]
    @State private var prUnits: [String: WeightUnit] = [:]
    @State private var percents: [Int: String] = [:]
    @State private var showEdit = false
    @State private var warned = false
    @State private var confirmCancel = false

    var body: some View {
        let blocks = workout.blocks
        let missingPRs = Planner.missingPRs(blocks: blocks, records: records)
        let missingPercents = blocks.indices.filter { blocks[$0].pctMissing }
        let isReady = !blocks.isEmpty && missingPRs.isEmpty && missingPercents.isEmpty
        let unfinished = workout.sessions?.first { $0.endedAt == nil }
        VStack(alignment: .leading, spacing: 10) {
            ForEach(missingPercents, id: \.self) { index in
                let block = blocks[index]
                VStack(alignment: .leading, spacing: 10) {
                    Text("What % for \(block.letter) · \(block.name)?").font(Theme.display(17))
                    if let rpe = block.rpe, let suggested = block.suggestedTarget {
                        Text("RPE \(WeightUnit.trimmed(rpe))/10 → \(suggested.text)").font(Theme.text(15))
                    }
                    HStack(spacing: 8) {
                        TextField("83-85, 80 or 80+", text: percentBinding(index, block: block))
                            .textFieldStyle(OutlineFieldStyle(size: 20))
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.soft))
                            .keyboardType(.numbersAndPunctuation)
                        Button("OK") { answerPercent(index, block: block) }
                            .buttonStyle(.black)
                            .frame(width: 64)
                            .disabled(Target(parsing: answer(index, block: block)) == nil)
                    }
                }
                .padding(.bottom, 12)
            }

            ForEach(missingPRs, id: \.self) { lift in
                VStack(alignment: .leading, spacing: 10) {
                    Text("What's your \(lift) PR?").font(Theme.display(17))
                    HStack(spacing: 8) {
                        TextField("PR", value: prBinding(lift), format: .number)
                            .textFieldStyle(OutlineFieldStyle(size: 20))
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.soft))
                            .keyboardType(.decimalPad)
                        Segmented(options: [(WeightUnit.kg, "kg"), (.lb, "lb")], selection: unitBinding(lift))
                            .frame(width: 100)
                    }
                    Button("Save PR") { savePR(lift) }
                        .buttonStyle(.black)
                        .disabled((prValues[lift] ?? 0) <= 0)
                }
                .padding(.bottom, 12)
            }

            Text("Ready to lift?")
                .font(Theme.heading)
                .tracking(-0.25)
                .padding(.horizontal, 4)
                .padding(.top, 2)
                .padding(.bottom, 6)
            if let unfinished {
                Button("Back to the set") { onResume(unfinished) }
                    .buttonStyle(.black)
            } else {
                Button("Start training") { onStart(workout) }
                    .buttonStyle(.black)
                    .disabled(!isReady)
            }
            HStack(spacing: 10) {
                Button("Edit") { showEdit = true }
                    .buttonStyle(.soft)
                Button("Cancel") { confirmCancel = true }
                    .buttonStyle(.soft)
            }
        }
        .sheet(isPresented: $showEdit) {
            EditWorkoutView(workout: workout)
        }
        .confirmationDialog("Discard today's workout?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Discard", role: .destructive) {
                context.delete(workout)
                try? context.save()
            }
        }
        .sensoryFeedback(.warning, trigger: warned)
        .onAppear {
            if !isReady { warned = true }
        }
    }

    /// What's typed, or the RPE suggestion before anything is typed.
    private func answer(_ index: Int, block: StrengthBlock) -> String {
        percents[index] ?? block.suggestedTarget.map { $0.text.replacingOccurrences(of: "%", with: "") } ?? ""
    }

    private func percentBinding(_ index: Int, block: StrengthBlock) -> Binding<String> {
        Binding(get: { answer(index, block: block) }, set: { percents[index] = $0 })
    }

    private func prBinding(_ lift: String) -> Binding<Double?> {
        Binding(get: { prValues[lift] }, set: { prValues[lift] = $0 })
    }

    private func unitBinding(_ lift: String) -> Binding<WeightUnit> {
        Binding(get: { prUnits[lift] ?? .kg }, set: { prUnits[lift] = $0 })
    }

    /// Saves the answer into the workout, for every unread set of that block.
    private func answerPercent(_ index: Int, block: StrengthBlock) {
        guard let target = Target(parsing: answer(index, block: block)) else { return }
        var updated = workout.blocks
        guard updated.indices.contains(index) else { return }
        updated[index] = updated[index].fillingMissingPercent(with: target)
        workout.blocks = updated
        percents[index] = nil
        try? context.save()
    }

    /// "What's your Snatch PR?" is saved to PRs (SPEC 2.2).
    private func savePR(_ lift: String) {
        guard let value = prValues[lift], value > 0 else { return }
        let unit = prUnits[lift] ?? .kg
        if let record = Planner.record(for: lift, in: records) {
            record.update(value: value, unit: unit)
        } else {
            let record = PersonalRecord(lift: lift)
            context.insert(record)
            record.update(value: value, unit: unit)
        }
        try? context.save()
    }
}

/// Edit the plan: remove a lift or change a lift's % for every set.
struct EditWorkoutView: View {
    let workout: Workout

    @Query(sort: \PersonalRecord.lift) private var records: [PersonalRecord]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var blocks: [StrengthBlock] = []
    @State private var percents: [Int: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                    Section("\(block.letter) · \(block.name)") {
                        Text("\(block.sets.count) × \(block.sets.first?.reps ?? 0) · " +
                             (block.pctMissing ? "% missing" : block.sets.compactMap { $0.target?.text }.joined(separator: ", ")))
                            .foregroundStyle(Theme.ink)
                        HStack {
                            TextField("New %: 75-78, 80 or 80+", text: Binding(
                                get: { percents[index] ?? "" },
                                set: { percents[index] = $0 }
                            ))
                            .keyboardType(.numbersAndPunctuation)
                            Button("Apply") {
                                if let target = Target(parsing: percents[index] ?? "") {
                                    blocks[index] = blocks[index].settingPercent(target)
                                    percents[index] = nil
                                }
                            }
                            .disabled(Target(parsing: percents[index] ?? "") == nil)
                        }
                        Picker("Based on", selection: Binding(
                            get: { blocks[index].prLift },
                            set: { blocks[index] = blocks[index].settingPRLift($0) }
                        )) {
                            ForEach(prLiftChoices(including: block.prLift), id: \.self) { lift in
                                Text("\(lift) PR").tag(lift)
                            }
                        }
                        Button("Remove this lift", role: .destructive) {
                            blocks.remove(at: index)
                            percents = [:]
                        }
                    }
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        workout.blocks = blocks
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .onAppear { blocks = workout.blocks }
        }
    }

    /// Every saved PR lift, plus the block's own if it isn't saved yet.
    private func prLiftChoices(including lift: String) -> [String] {
        let saved = records.map(\.lift)
        return saved.contains(lift) ? saved : [lift] + saved
    }
}
