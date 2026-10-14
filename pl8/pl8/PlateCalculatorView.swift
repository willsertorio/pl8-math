import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import PlateKit

/// A test screen for M1–M3: read a workout screenshot (or pick a sample), set up the gym and PRs,
/// and see every load PlateKit plans. Not the real design (that's M4+).
struct PlateCalculatorView: View {
    // Workout
    @State private var workoutID = SampleWorkout.all[0].id
    @State private var photo: PhotosPickerItem?
    @State private var isReading = false
    @State private var readText: String?
    @State private var readError: String?
    @State private var blocks: [StrengthBlock] = []
    @State private var percentAnswers: [Int: String] = [:]

    // Saved data (SwiftData)
    @Environment(\.modelContext) private var context
    @Query private var gyms: [Gym]
    @Query private var records: [PersonalRecord]
    @State private var editingPR: EditingPR?

    private var gym: Gym? { gyms.first { $0.isCurrent } ?? gyms.first }
    private var unit: WeightUnit { gym?.unit ?? .lb }

    /// The saved PR for a lift, matching names the same way the parser does.
    private func record(for lift: String) -> PersonalRecord? {
        let name = LiftNames.canonical(lift)
        return records.first { $0.lift == name }
    }

    /// Blocks with the user's answers for any hidden %.
    private var answeredBlocks: [StrengthBlock] {
        blocks.enumerated().map { index, block in
            guard block.pctMissing, let target = Target(parsing: percentAnswers[index] ?? "") else { return block }
            return block.fillingMissingPercent(with: target)
        }
    }

    private var workouts: [SampleWorkout] {
        blocks.isEmpty ? SampleWorkout.all : [SampleWorkout.fromScreenshot(answeredBlocks)] + SampleWorkout.all
    }

    private var workout: SampleWorkout {
        workouts.first { $0.id == workoutID } ?? SampleWorkout.all[0]
    }

    private var plan: SessionPlan {
        let lifts = workout.lifts.map { lift in
            let saved = record(for: lift.prLift)
            return LiftInput(
                name: lift.name,
                pr: saved?.value ?? 0,
                prUnit: saved?.unit ?? .kg,
                sets: lift.sets
            )
        }
        return SessionPlan(gym: gym?.setup ?? GymSetup(unit: .lb), lifts: lifts)
    }

    var body: some View {
        let plan = plan
        Form {
            screenshotSection

            Section("Workout") {
                Picker("Workout", selection: $workoutID) {
                    ForEach(workouts) { sample in
                        Text(sample.name).tag(sample.id)
                    }
                }
            }

            Section("Gym") {
                if let gym {
                    GymEditor(gym: gym)
                }
            }

            Section {
                ForEach(workout.prLifts, id: \.self) { lift in
                    let saved = record(for: lift)
                    Button {
                        editingPR = EditingPR(lift: lift)
                    } label: {
                        LabeledContent(lift) {
                            if let saved, let value = saved.value {
                                Text("\(WeightUnit.trimmed(value)) \(saved.unit.rawValue)")
                            } else {
                                Text("Add PR").foregroundStyle(.orange)
                            }
                        }
                    }
                    .tint(.primary)
                }
            } header: {
                Text("PRs")
            } footer: {
                Text("Tap a PR to change it. Earlier values are kept.")
            }

            Section("Plate kit") {
                LabeledContent("Bar", value: weightText(plan.kit.bar))
                ForEach(plan.kit.plates, id: \.size) { item in
                    LabeledContent(weightText(item.size), value: "× \(item.count)")
                }
            }

            Section("Warm-up") {
                ForEach(plan.warmUp, id: \.round.number) { set in
                    SetRow(
                        title: "\(set.round.label) · \(set.reps) reps",
                        total: unit.display(set.load.total, in: plan.lifts.first?.prUnit ?? unit),
                        detail: set.round.percentText,
                        plates: platesText(set.load.perSide),
                        change: set.change.text
                    )
                }
            }

            ForEach(Array(plan.lifts.enumerated()), id: \.offset) { _, lift in
                Section(lift.name) {
                    ForEach(lift.sets, id: \.number) { set in
                        SetRow(
                            title: "Set \(set.number) · \(set.reps) \(set.reps == 1 ? "rep" : "reps")",
                            total: plan.displayTotal(set),
                            detail: set.target.text,
                            plates: platesText(set.load.perSide),
                            change: set.change.text,
                            warning: set.load.isLighterThanBar ? "Lighter than the bar" : nil
                        )
                    }
                }
            }

            Section {
            } footer: {
                Text("PlateKit \(PlateKit.version)")
            }
        }
        .navigationTitle("Plate math")
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.success, trigger: blocks)
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task { await read(item) }
        }
        .sheet(item: $editingPR) { item in
            PREditor(lift: item.lift, record: record(for: item.lift))
        }
        .task {
            seedIfNeeded()
        }
    }

    // MARK: - Screenshot

    @ViewBuilder
    private var screenshotSection: some View {
        Section("Screenshot") {
            PhotosPicker(selection: $photo, matching: .images) {
                Label("Upload a screenshot", systemImage: "photo.on.rectangle")
            }

            if isReading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Reading…")
                }
            }

            if let readError {
                Text(readError).foregroundStyle(.orange)
            }

            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                VStack(alignment: .leading, spacing: 4) {
                    Text(blockTitle(block)).font(.headline)
                    if let note = block.note {
                        Text(note).font(.footnote).foregroundStyle(.secondary)
                    }
                    if block.pctMissing {
                        TextField("What % for \(block.name)?", text: answerBinding(index))
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(.roundedBorder)
                        if let answer = percentAnswers[index], !answer.isEmpty, Target(parsing: answer) == nil {
                            Text("Try 83-85, 80 or 80+").font(.footnote).foregroundStyle(.orange)
                        }
                    } else {
                        Text(block.sets.compactMap { $0.target?.text }.joined(separator: ", "))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }

            if let readText {
                DisclosureGroup("Text Vision read") {
                    Text(readText)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    Button("Copy text") {
                        UIPasteboard.general.string = readText
                    }
                }
            }
        }
    }

    private func read(_ item: PhotosPickerItem) async {
        isReading = true
        readError = nil
        defer { isReading = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                readError = "Couldn't open that image."
                return
            }
            let text = try await TextReader.lines(in: data).joined(separator: "\n")
            readText = text
            percentAnswers = [:]
            blocks = WorkoutParser.parse(text)
            if blocks.isEmpty {
                readError = "No strength work found in that screenshot."
            } else {
                workoutID = SampleWorkout.screenshotID
            }
        } catch {
            readError = "Couldn't read that image: \(error.localizedDescription)"
        }
    }

    /// "D · After Party · Back Squat · EMOM · 5 × 2"
    private func blockTitle(_ block: StrengthBlock) -> String {
        let reps = block.sets.first?.reps ?? 0
        let parts: [String?] = [block.letter, block.label, block.name, block.format, "\(block.sets.count) × \(reps)"]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: - Helpers

    private func weightText(_ weight: Double) -> String {
        "\(WeightUnit.trimmed(weight)) \(unit.rawValue)"
    }

    private func platesText(_ perSide: [Double]) -> String {
        if perSide.isEmpty { return "Empty bar" }
        return perSide.map(WeightUnit.trimmed).joined(separator: " + ") + " \(unit.rawValue) each side"
    }

    /// First launch: one gym with every plate, and the default PR list with no values yet.
    private func seedIfNeeded() {
        if gyms.isEmpty {
            context.insert(Gym(name: "MY BOX", unit: .lb))
        }
        if records.isEmpty {
            for lift in LiftNames.defaultPRLifts {
                context.insert(PersonalRecord(lift: lift))
            }
        }
        try? context.save()
    }

    private func answerBinding(_ index: Int) -> Binding<String> {
        Binding(get: { percentAnswers[index] ?? "" }, set: { percentAnswers[index] = $0 })
    }
}

/// Which PR the editor sheet is open for.
private struct EditingPR: Identifiable {
    let lift: String
    var id: String { lift }
}

/// The gym's name, units, bar and plates, saved as you change them.
private struct GymEditor: View {
    @Bindable var gym: Gym

    var body: some View {
        TextField("Gym name", text: Binding(
            get: { gym.name },
            set: { gym.name = GymSetup.normalizedName($0) }
        ))
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()

        Picker("Units", selection: Binding(get: { gym.unit }, set: { gym.switchUnit(to: $0) })) {
            Text("Kilograms").tag(WeightUnit.kg)
            Text("Pounds").tag(WeightUnit.lb)
        }
        .pickerStyle(.segmented)

        Picker("Bar", selection: $gym.barWeight) {
            ForEach(Bar.weights(gym.unit), id: \.self) { weight in
                Text("\(WeightUnit.trimmed(weight)) \(gym.unit.rawValue)").tag(weight)
            }
        }

        ForEach(Plate.catalog(gym.unit), id: \.size) { plate in
            Toggle(isOn: Binding(
                get: { gym.plateSizes.contains(plate.size) },
                set: { gym.setPlate(plate.size, isOn: $0) }
            )) {
                HStack {
                    Circle()
                        .fill(Color(hex: plate.colorHex))
                        .overlay(Circle().stroke(.secondary, lineWidth: 0.5))
                        .frame(width: 12 + 16 * plate.diameter, height: 12 + 16 * plate.diameter)
                    Text("\(WeightUnit.trimmed(plate.size)) \(gym.unit.rawValue)")
                }
            }
        }
    }
}

/// Sheet to enter or change one PR. Saving keeps the old value in its history.
private struct PREditor: View {
    let lift: String
    let record: PersonalRecord?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var value: Double?
    @State private var unit: WeightUnit = .kg

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("PR", value: $value, format: .number)
                        .keyboardType(.decimalPad)
                    Picker("Unit", selection: $unit) {
                        Text("kg").tag(WeightUnit.kg)
                        Text("lb").tag(WeightUnit.lb)
                    }
                    .pickerStyle(.segmented)
                }

                if let record, !record.history.isEmpty {
                    Section("Earlier") {
                        ForEach(record.history.sorted { $0.date > $1.date }) { entry in
                            LabeledContent(
                                "\(WeightUnit.trimmed(entry.value)) \(entry.unit.rawValue)",
                                value: entry.date.formatted(date: .abbreviated, time: .shortened)
                            )
                        }
                    }
                }
            }
            .navigationTitle("\(lift) PR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled((value ?? 0) <= 0)
                }
            }
            .onAppear {
                value = record?.value
                unit = record?.unit ?? .kg
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard let value, value > 0 else { return }
        if let record {
            if record.value != value || record.unit != unit {
                record.update(value: value, unit: unit)
            }
        } else {
            let newRecord = PersonalRecord(lift: lift)
            context.insert(newRecord)
            newRecord.update(value: value, unit: unit)
        }
        try? context.save()
    }
}

/// One set: title and total on top, then the % and plates, then what to change.
private struct SetRow: View {
    let title: String
    let total: String
    let detail: String
    let plates: String
    let change: String
    var warning: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                Spacer()
                Text(total).font(.headline).monospacedDigit()
            }
            Text("\(detail) · \(plates)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(change).font(.footnote)
            if let warning {
                Text(warning).font(.footnote).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}

private extension Color {
    /// "#D3262E" → Color.
    init(hex: String) {
        let value = UInt64(hex.dropFirst(), radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

#Preview {
    NavigationStack {
        PlateCalculatorView()
    }
}
