import SwiftData
import SwiftUI
import PlateKit

/// First run (SPEC 2.2): opening → gym setup, one question per sheet → PRs.
/// The room sits above the sheet and builds itself from the answers: the flag, the plate shelf, the bar.
struct FirstRunView: View {
    var onFinish: () -> Void

    enum Step: Int {
        case opening, name, unit, plates, bar, prChoice, prList
    }

    @Query private var gyms: [Gym]
    @State private var step: Step = .opening
    @State private var editingPR: PRTarget?

    private var gym: Gym? { gyms.first { $0.isCurrent } ?? gyms.first }

    /// Where each question looks in the room (SPEC 2.1, 2.2).
    private var station: RoomLayout.Station {
        switch step {
        case .opening: .overview
        case .name: .nameFlag
        case .unit, .plates: .corner
        case .bar: .bar
        case .prChoice, .prList: .pr
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            if step == .opening {
                VStack(spacing: 24) {
                    Text("pl8(math)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Tap to start").font(.headline).foregroundStyle(Theme.ink)
                }
                .padding(.top, 60)
                .padding(.horizontal, 16)
            } else {
                // The sheet covers the bottom half; the room fills the top.
                GeometryReader { geometry in
                    RoomStage(station: station, gymName: gym?.name ?? "", unit: gym?.unit ?? .kg,
                              plateSizes: gym?.plateSizes ?? [], barWeight: gym?.barWeight ?? 20)
                        .frame(height: geometry.size.height * 0.55)
                }
                .ignoresSafeArea(edges: .top)
            }
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
