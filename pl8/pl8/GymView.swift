import SwiftData
import SwiftUI
import PlateKit

/// The Gym drawer, like the prototype's showGymHome: your gyms as chips (tap to switch, + Add gym, remove the
/// current one), then its name, units, plates and bar. The room follows as you change them (SPEC 2.4).
struct GymDrawerContent: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Gym.name) private var gyms: [Gym]
    @AppStorage("hasFinishedFirstRun") private var hasFinishedFirstRun = true
    @AppStorage("didSeedDefaults") private var didSeedDefaults = true
    @State private var confirmRemove = false
    @State private var confirmReplay = false

    private var current: Gym? { Gym.current(in: gyms) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GymLabel(text: "Gyms")
            WrapFlow {
                ForEach(gyms) { gym in
                    Chip(isOn: gym.id == current?.id, action: { switchTo(gym) }) {
                        Text(gym.name.isEmpty ? "New gym" : gym.name)
                    }
                }
                Chip(isOn: false, action: addGym) { Text("+ Add gym") }
            }
            if gyms.count > 1 {
                Button("Remove \(current?.name.isEmpty == false ? current!.name : "this gym")") { confirmRemove = true }
                    .font(Theme.display(15))
                    .foregroundStyle(Color(hex: "#D70015"))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                    .padding(.top, 10)
            }
            if let current {
                GymSetupForm(gym: current)
            }
            MotionToggle()
                .padding(.top, 18)
            Button("Replay the first run") { confirmReplay = true }
                .font(Theme.display(15))
                .foregroundStyle(Color(hex: "#D70015"))
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .padding(.top, 24)
        }
        .sensoryFeedback(.selection, trigger: current?.id)
        .confirmationDialog("Remove \(current?.name ?? "this gym")?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { removeCurrent() }
        }
        .confirmationDialog("Replay the first run?", isPresented: $confirmReplay, titleVisibility: .visible) {
            Button("Erase everything and replay", role: .destructive) {
                // A clean start: no gym, PRs, workouts or history left from before.
                DataCleanup.eraseEverything(in: context)
                didSeedDefaults = false
                hasFinishedFirstRun = false
            }
        } message: {
            Text("Your gym, PRs, workouts and history are deleted.")
        }
    }

    private func switchTo(_ gym: Gym) {
        gym.makeCurrent()
        try? context.save()
    }

    private func addGym() {
        let gym = Gym(name: "", unit: current?.unit ?? .lb)
        context.insert(gym)
        switchTo(gym)
    }

    private func removeCurrent() {
        guard let current, gyms.count > 1 else { return }
        let next = gyms.first { $0.id != current.id }
        context.delete(current)
        next?.makeCurrent()
        try? context.save()
    }
}

/// The Gym drawer's small headings: 15 pt bold, 18 pt of air above (prototype label()).
struct GymLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.display(15))
            .padding(.horizontal, 4)
            .padding(.top, 18)
            .padding(.bottom, 8)
    }
}

/// Name, units, plates and bar of one gym; changes save as you make them.
struct GymSetupForm: View {
    @Bindable var gym: Gym

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GymLabel(text: "Name")
            GymNameField(gym: gym)
            GymLabel(text: "Units")
            Segmented(options: [(WeightUnit.kg, "Kilograms"), (.lb, "Pounds")],
                      selection: Binding(get: { gym.unit }, set: { gym.switchUnit(to: $0) }))
                .sensoryFeedback(.selection, trigger: gym.unit)
            GymLabel(text: "Plates")
            PlateChips(gym: gym)
            GymLabel(text: "Bar")
            BarChips(gym: gym)
        }
    }
}

/// The gym's name: uppercase, up to 8 letters; the flag follows as you type.
struct GymNameField: View {
    @Bindable var gym: Gym

    var body: some View {
        TextField("Add a name", text: Binding(
            get: { gym.name },
            set: { gym.name = GymSetup.normalizedName($0) }
        ))
        .textFieldStyle(OutlineFieldStyle(size: 20))
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()
    }
}

/// One chip per plate size, with a colour dot sized by its diameter; each toggle pops its pile on or off.
struct PlateChips: View {
    @Bindable var gym: Gym

    var body: some View {
        WrapFlow {
            ForEach(Plate.catalog(gym.unit), id: \.size) { plate in
                let isOn = gym.plateSizes.contains(plate.size)
                Chip(isOn: isOn, action: { gym.setPlate(plate.size, isOn: !isOn) }) {
                    HStack(spacing: 8) {
                        PlateDot(plate: plate, isOn: isOn)
                        Text("\(WeightUnit.trimmed(plate.size)) \(gym.unit.rawValue)")
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: gym.plateSizes)
    }
}

/// The unit's bars as chips: "20 kg · Olympic".
struct BarChips: View {
    @Bindable var gym: Gym

    var body: some View {
        WrapFlow {
            ForEach(Bar.weights(gym.unit), id: \.self) { weight in
                Chip(isOn: gym.barWeight == weight, action: { gym.barWeight = weight }) {
                    Text(label(weight))
                }
            }
        }
        .sensoryFeedback(.selection, trigger: gym.barWeight)
    }

    private func label(_ weight: Double) -> String {
        let text = "\(WeightUnit.trimmed(weight)) \(gym.unit.rawValue)"
        guard let name = Bar.name(weight, gym.unit) else { return text }
        return "\(text) · \(name)"
    }
}


/// The switch for the "move with the phone" effects (Will's test, 2026-10-19).
struct MotionToggle: View {
    @AppStorage(MotionSource.settingKey) private var motionEffects = true

    var body: some View {
        Toggle(isOn: $motionEffects) {
            Text("Move with the phone").font(Theme.text(17))
        }
        .tint(Theme.ink)
        .padding(.horizontal, 4)
        .sensoryFeedback(.selection, trigger: motionEffects)
    }
}
