import SwiftUI
import PlateKit

/// A test screen for M1: pick a sample workout, set up the gym and PRs, and see every load PlateKit plans.
/// Not the real design (that's M4+); it's here to try the math on the phone.
struct PlateCalculatorView: View {
    @State private var workout = SampleWorkout.all[0]
    @State private var unit: WeightUnit = .lb
    @State private var bar: Double = 45
    @State private var plates: Set<Double> = Set(Plate.catalog(.lb).map(\.size))
    @State private var prs: [String: Double] = SampleWorkout.all[0].prs
    @State private var prUnits: [String: WeightUnit] = [:]

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
            Section("Workout") {
                Picker("Workout", selection: $workout) {
                    ForEach(SampleWorkout.all) { sample in
                        Text(sample.name).tag(sample)
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
        .onChange(of: unit) { _, newUnit in
            bar = Bar.weights(newUnit)[0]
            plates = Set(Plate.catalog(newUnit).map(\.size))
        }
        .onChange(of: workout) { _, newWorkout in
            prs = newWorkout.prs
            prUnits = [:]
        }
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
