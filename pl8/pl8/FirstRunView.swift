import SwiftData
import SwiftUI
import PlateKit

/// First run (SPEC 2.2): opening → gym setup, one question per sheet → PRs.
/// In 2D, a card behind the sheet stands in for the room being built.
struct FirstRunView: View {
    var onFinish: () -> Void

    enum Step: Int {
        case opening, name, unit, plates, bar, prChoice, prList
    }

    @Query private var gyms: [Gym]
    @State private var step: Step = .opening
    @State private var editingPR: PRTarget?

    private var gym: Gym? { gyms.first { $0.isCurrent } ?? gyms.first }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("pl8(math)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(Theme.ink)
                if step == .opening {
                    Text("Tap to start").font(.headline).foregroundStyle(Theme.ink)
                } else if let gym {
                    GymPreview(gym: gym, step: step)
                }
            }
            .padding(.top, 60)
            .padding(.horizontal, 16)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if step == .opening { step = .name }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: step)
        .sheet(isPresented: Binding(get: { step != .opening }, set: { _ in })) {
            sheet
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .interactiveDismissDisabled()
        }
    }

    // MARK: - Sheet

    @ViewBuilder
    private var sheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch step {
            case .opening:
                EmptyView()

            case .name:
                question("Where are you training now?")
                if let gym { GymNameField(gym: gym) }
                Spacer(minLength: 0)
                Button("Continue") { step = .unit }
                    .buttonStyle(.bigBlack)
                    .disabled(gym?.name.isEmpty ?? true)

            case .unit:
                question("Is the gym kilos or pounds?")
                if let gym { UnitList(gym: gym) }
                Spacer(minLength: 0)
                Button("Continue") { step = .plates }
                    .buttonStyle(.bigBlack)

            case .plates:
                question("Which plates does your gym have?")
                if let gym {
                    ScrollView { PlateChips(gym: gym).padding(2) }
                }
                Button("Continue") { step = .bar }
                    .buttonStyle(.bigBlack)
                    .disabled(gym?.plateSizes.isEmpty ?? true)

            case .bar:
                question("Which bar do you use?")
                if let gym { BarChips(gym: gym) }
                Spacer(minLength: 0)
                Button("Done") { step = .prChoice }
                    .buttonStyle(.bigBlack)

            case .prChoice:
                question("Add your PRs")
                PRScreenshotPicker(onDone: { count in
                    if count > 0 { step = .prList }
                }) {
                    OptionRow(title: "Upload a screenshot", systemImage: "photo.on.rectangle", tag: "Fastest")
                }
                OptionRow(title: "Scan with the camera", systemImage: "camera", tag: "Soon")
                    .opacity(0.4)
                Button { step = .prList } label: {
                    OptionRow(title: "Type them in", systemImage: "keyboard")
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)

            case .prList:
                question("Your PRs")
                Text("Tap a lift to enter its PR. You can change them any time in the PRs tab.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                PRList(editing: $editingPR)
                Button("Continue") { onFinish() }
                    .buttonStyle(.bigBlack)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(Theme.ink)
        .background(Theme.paper)
        .animation(.snappy, value: step)
    }

    private func question(_ text: String) -> some View {
        Text(text).font(Theme.heading)
    }
}

/// Kilograms / Pounds as a list with a checkmark.
private struct UnitList: View {
    @Bindable var gym: Gym

    var body: some View {
        VStack(spacing: 0) {
            ForEach([WeightUnit.kg, WeightUnit.lb], id: \.self) { unit in
                Button {
                    gym.switchUnit(to: unit)
                } label: {
                    HStack {
                        Text(unit == .kg ? "Kilograms" : "Pounds").font(.title3.weight(.semibold))
                        Spacer()
                        if gym.unit == unit {
                            Image(systemName: "checkmark").font(.title3.weight(.bold))
                        }
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
        .sensoryFeedback(.selection, trigger: gym.unit)
    }
}

/// A big option button with an icon and an optional tag ("Fastest").
private struct OptionRow: View {
    let title: String
    let systemImage: String
    var tag: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage).font(.title3)
            Text(title).font(.headline)
            Spacer()
            if let tag {
                Text(tag.uppercased())
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .foregroundStyle(Theme.paper)
                    .background(Theme.ink)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .foregroundStyle(Theme.ink)
        .background(Theme.paper)
        .overlay(Rectangle().stroke(Theme.ink, lineWidth: 2))
        .contentShape(Rectangle())
    }
}

/// Stands in for the room: each answer shows up as it's given.
private struct GymPreview: View {
    @Bindable var gym: Gym
    let step: FirstRunView.Step

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(gym.name.isEmpty ? "YOUR BOX" : gym.name)
                .font(.system(size: 40, weight: .heavy))
                .foregroundStyle(Theme.paper)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.ink)

            if step.rawValue >= FirstRunView.Step.unit.rawValue {
                Text(gym.unit == .kg ? "Kilograms" : "Pounds").font(.headline)
            }
            if step.rawValue >= FirstRunView.Step.plates.rawValue {
                HStack(spacing: 4) {
                    ForEach(Plate.catalog(gym.unit).filter { gym.plateSizes.contains($0.size) }, id: \.size) { plate in
                        PlateDot(plate: plate)
                    }
                }
            }
            if step.rawValue >= FirstRunView.Step.bar.rawValue {
                Text("Bar \(WeightUnit.trimmed(gym.barWeight)) \(gym.unit.rawValue)").font(.headline)
            }
        }
        .drawer()
        .animation(.snappy, value: step)
    }
}
