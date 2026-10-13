import PhotosUI
import SwiftUI
import UIKit
import PlateKit

/// A test screen for M1–M2: read a workout screenshot (or pick a sample), set up the gym and PRs,
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

    // Gym
    @State private var unit: WeightUnit = .lb
    @State private var bar: Double = 45
    @State private var plates: Set<Double> = Set(Plate.catalog(.lb).map(\.size))

    // PRs
    @State private var prs: [String: Double] = SampleWorkout.all[0].prs
    @State private var prUnits: [String: WeightUnit] = [:]

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
        let gym = GymSetup(unit: unit, plateSizes: Array(plates), barWeight: bar)
        let lifts = workout.lifts.map { lift in
            LiftInput(
                name: lift.name,
                pr: prs[lift.prLift] ?? 0,
                prUnit: prUnits[lift.prLift] ?? .kg,
                sets: lift.sets
            )
        }
        return SessionPlan(gym: gym, lifts: lifts)
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
                Picker("Units", selection: $unit) {
                    Text("Kilograms").tag(WeightUnit.kg)
                    Text("Pounds").tag(WeightUnit.lb)
                }
                .pickerStyle(.segmented)

                Picker("Bar", selection: $bar) {
                    ForEach(Bar.weights(unit), id: \.self) { weight in
                        Text(weightText(weight)).tag(weight)
                    }
                }

                ForEach(Plate.catalog(unit), id: \.size) { plate in
                    Toggle(isOn: plateBinding(plate.size)) {
                        HStack {
                            Circle()
                                .fill(Color(hex: plate.colorHex))
                                .overlay(Circle().stroke(.secondary, lineWidth: 0.5))
                                .frame(width: 12 + 16 * plate.diameter, height: 12 + 16 * plate.diameter)
                            Text(weightText(plate.size))
                        }
                    }
                }
            }

            Section("PRs") {
                ForEach(workout.prLifts, id: \.self) { lift in
                    HStack {
                        Text(lift)
                        Spacer()
                        TextField("PR", value: prBinding(lift), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Picker("Unit", selection: prUnitBinding(lift)) {
                            Text("kg").tag(WeightUnit.kg)
                            Text("lb").tag(WeightUnit.lb)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 90)
                    }
                }
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
        .onChange(of: unit) { _, newUnit in
            bar = Bar.weights(newUnit)[0]
            plates = Set(Plate.catalog(newUnit).map(\.size))
        }
        .onChange(of: workoutID) { _, _ in
            // Sample PRs fill in; PRs you typed for other lifts stay.
            prs = workout.prs.merging(prs) { sample, _ in sample }
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

    private func plateBinding(_ size: Double) -> Binding<Bool> {
        Binding(
            get: { plates.contains(size) },
            set: { isOn in
                if isOn { plates.insert(size) } else { plates.remove(size) }
            }
        )
    }

    private func prBinding(_ lift: String) -> Binding<Double> {
        Binding(get: { prs[lift] ?? 0 }, set: { prs[lift] = $0 })
    }

    private func prUnitBinding(_ lift: String) -> Binding<WeightUnit> {
        Binding(get: { prUnits[lift] ?? .kg }, set: { prUnits[lift] = $0 })
    }

    private func answerBinding(_ index: Int) -> Binding<String> {
        Binding(get: { percentAnswers[index] ?? "" }, set: { percentAnswers[index] = $0 })
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
