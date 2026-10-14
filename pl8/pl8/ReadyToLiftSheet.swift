import SwiftData
import SwiftUI
import PlateKit

/// "Ready to lift?" (SPEC 2.2 step 3): the whiteboard, any missing PR or %, then Start · Edit · Cancel.
struct ReadyToLiftSheet: View {
    let workout: Workout
    var onStart: (Workout) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Whiteboard(blocks: blocks)

                    ForEach(missingPercents, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("What % for \(blocks[index].name)?").font(.headline)
                            HStack(spacing: 8) {
                                TextField("83-85, 80 or 80+", text: percentBinding(index))
                                    .textFieldStyle(OutlineFieldStyle())
                                    .keyboardType(.numbersAndPunctuation)
                                Button("OK") { answerPercent(index) }
                                    .buttonStyle(.black)
                                    .frame(width: 64)
                                    .disabled(Target(parsing: percents[index] ?? "") == nil)
                            }
                        }
                        .drawer()
                    }

                    ForEach(missingPRs, id: \.self) { lift in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("What's your \(lift) PR?").font(.headline)
                            HStack(spacing: 8) {
                                TextField("PR", value: prBinding(lift), format: .number)
                                    .textFieldStyle(OutlineFieldStyle())
                                    .keyboardType(.decimalPad)
                                Picker("Unit", selection: unitBinding(lift)) {
                                    Text("kg").tag(WeightUnit.kg)
                                    Text("lb").tag(WeightUnit.lb)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 100)
                            }
                            Button("Save PR") { savePR(lift) }
                                .buttonStyle(.black)
                                .disabled((prValues[lift] ?? 0) <= 0)
                        }
                        .drawer()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ready to lift?").font(Theme.heading)
                        Button("Start training") { onStart(workout) }
                            .buttonStyle(.bigBlack)
                            .disabled(!isReady)
                        HStack(spacing: 8) {
                            Button("Edit") { showEdit = true }
                                .buttonStyle(.black)
                            Button("Cancel") { confirmCancel = true }
                                .buttonStyle(.black)
                        }
                    }
                    .drawer()
                }
                .padding(16)
            }
            .background(Theme.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showEdit) {
            EditWorkoutView(workout: workout)
        }
        .confirmationDialog("Discard today's workout?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Discard", role: .destructive) {
                context.delete(workout)
                try? context.save()
                dismiss()
            }
        }
        .sensoryFeedback(.warning, trigger: warned)
        .onAppear {
            if !isReady { warned = true }
        }
    }

    private func percentBinding(_ index: Int) -> Binding<String> {
        Binding(get: { percents[index] ?? "" }, set: { percents[index] = $0 })
    }

    private func prBinding(_ lift: String) -> Binding<Double?> {
        Binding(get: { prValues[lift] }, set: { prValues[lift] = $0 })
    }

    private func unitBinding(_ lift: String) -> Binding<WeightUnit> {
        Binding(get: { prUnits[lift] ?? .kg }, set: { prUnits[lift] = $0 })
    }

    /// Saves the answer into the workout, for every unread set of that block.
    private func answerPercent(_ index: Int) {
        guard let target = Target(parsing: percents[index] ?? "") else { return }
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
                            .foregroundStyle(.secondary)
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
}
