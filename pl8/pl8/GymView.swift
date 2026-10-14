import SwiftData
import SwiftUI
import PlateKit

/// Gym tab: gyms as chips (switch, add, remove), then the current gym's name, units, plates and bar (SPEC 2.4).
struct GymView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Gym.name) private var gyms: [Gym]
    @State private var confirmRemove = false

    private var current: Gym? { gyms.first { $0.isCurrent } ?? gyms.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Gyms").sectionLabel()
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(gyms) { gym in
                                    Chip(isOn: gym.id == current?.id, action: { switchTo(gym) }) {
                                        Text(gym.name.isEmpty ? "—" : gym.name)
                                    }
                                    .fixedSize()
                                }
                                Chip(isOn: false, action: addGym) {
                                    Label("Add gym", systemImage: "plus")
                                }
                                .fixedSize()
                            }
                            .padding(2)
                        }
                        if gyms.count > 1 {
                            Button("Remove this gym", role: .destructive) { confirmRemove = true }
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .drawer()

                    if let current {
                        GymSetupForm(gym: current)
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Gym")
            .sensoryFeedback(.selection, trigger: current?.id)
            .confirmationDialog("Remove \(current?.name ?? "this gym")?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Remove", role: .destructive) { removeCurrent() }
            }
        }
    }

    private func switchTo(_ gym: Gym) {
        for other in gyms { other.isCurrent = (other.id == gym.id) }
        try? context.save()
    }

    private func addGym() {
        let gym = Gym(name: "GYM \(gyms.count + 1)", unit: current?.unit ?? .lb)
        context.insert(gym)
        switchTo(gym)
    }

    private func removeCurrent() {
        guard let current, gyms.count > 1 else { return }
        let next = gyms.first { $0.id != current.id }
        context.delete(current)
        next?.isCurrent = true
        try? context.save()
    }
}

/// Name, units, plates and bar of one gym; changes save as you make them.
struct GymSetupForm: View {
    @Bindable var gym: Gym

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Name").sectionLabel()
                TextField("BOX NAME", text: Binding(
                    get: { gym.name },
                    set: { gym.name = GymSetup.normalizedName($0) }
                ))
                .textFieldStyle(OutlineFieldStyle())
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                Text("Up to \(GymSetup.maxNameLength) letters.").font(.footnote).foregroundStyle(.secondary)
            }
            .drawer()

            VStack(alignment: .leading, spacing: 10) {
                Text("Units").sectionLabel()
                Picker("Units", selection: Binding(get: { gym.unit }, set: { gym.switchUnit(to: $0) })) {
                    Text("Kilograms").tag(WeightUnit.kg)
                    Text("Pounds").tag(WeightUnit.lb)
                }
                .pickerStyle(.segmented)
                .sensoryFeedback(.selection, trigger: gym.unit)
            }
            .drawer()

            VStack(alignment: .leading, spacing: 10) {
                Text("Plates").sectionLabel()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
                    ForEach(Plate.catalog(gym.unit), id: \.size) { plate in
                        let isOn = gym.plateSizes.contains(plate.size)
                        Chip(isOn: isOn, action: { gym.setPlate(plate.size, isOn: !isOn) }) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(hex: plate.colorHex))
                                    .overlay(Circle().stroke(isOn ? Theme.paper : Theme.ink, lineWidth: 1))
                                    .frame(width: 8 + 14 * plate.diameter, height: 8 + 14 * plate.diameter)
                                Text(WeightUnit.trimmed(plate.size))
                            }
                        }
                    }
                }
                .sensoryFeedback(.impact(weight: .light), trigger: gym.plateSizes)
            }
            .drawer()

            VStack(alignment: .leading, spacing: 10) {
                Text("Bar").sectionLabel()
                HStack(spacing: 8) {
                    ForEach(Bar.weights(gym.unit), id: \.self) { weight in
                        Chip(isOn: gym.barWeight == weight, action: { gym.barWeight = weight }) {
                            Text("\(WeightUnit.trimmed(weight)) \(gym.unit.rawValue)")
                        }
                    }
                }
                .sensoryFeedback(.selection, trigger: gym.barWeight)
            }
            .drawer()
        }
    }
}
