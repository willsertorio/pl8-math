import SwiftData
import SwiftUI
import UIKit
import PlateKit

/// First run (SPEC 2.2): opening → gym setup, one question per sheet → PRs.
/// The room sits above the sheet and builds itself from the answers: the flag, the plate shelf, the bar.
struct FirstRunView: View {
    var onFinish: () -> Void

    enum Step: Int {
        case opening, name, unit, plates, bar, prChoice, prList
    }

    @Query private var gyms: [Gym]
    @Query private var records: [PersonalRecord]
    @State private var step: Step

    /// Where the opening is, while `step` is `.opening`.
    @State private var opening: OpeningPhase

    /// - Parameter openingAt: where the opening starts (the CI's screenshots of the closed box).
    init(startAt step: Step = .opening, openingAt: OpeningPhase = .title, onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        _step = State(initialValue: step)
        _opening = State(initialValue: step == .opening ? openingAt : .done)
    }
    /// The sheet's height, measured from its content, so the room gets the rest of the screen.
    @State private var sheetHeight: CGFloat = 320
    /// The keyboard's height, so the room shows above it and the sheet while you type the name.
    @State private var keyboardHeight: CGFloat = 0
    @State private var editingPR: PRTarget?

    private var gym: Gym? { gyms.first { $0.isCurrent } ?? gyms.first }

    /// The PR list can grow long, so it keeps the half/full sheet; every other question fits its content.
    private var fitsContent: Bool { step != .prList }

    /// How much of a screen `height` tall the sheet covers.
    private func visibleSheet(of height: CGFloat) -> CGFloat {
        fitsContent ? sheetHeight : height / 2
    }

    /// Where each question looks in the room (SPEC 2.1, 2.2).
    private var station: RoomLayout.Station {
        switch step {
        case .opening: opening == .title || opening == .closed ? .far : .overview
        case .name: .nameFlag
        case .unit, .plates: .corner
        case .bar: .bar
        case .prChoice, .prList: .pr
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            // The sheet is only as tall as its question; the room fills the rest, a little behind the sheet's
            // rounded top. During the opening it has the whole screen.
            GeometryReader { geometry in
                RoomStage(station: station, gymName: gym?.name ?? "", unit: gym?.unit ?? .kg,
                          plateSizes: gym?.plateSizes ?? [], barWeight: gym?.barWeight ?? 20,
                          boards: Boards(prs: Planner.boardRows(records)), opening: step == .opening ? opening : nil)
                    .frame(height: step == .opening
                           ? geometry.size.height
                           : max(200, geometry.size.height - keyboardHeight - visibleSheet(of: geometry.size.height) + 24))
            }
            .ignoresSafeArea()

            if step == .opening && opening == .title {
                OpeningTitle()
                    .transition(.opacity.animation(.easeOut(duration: 0.55)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { tapDuringOpening() }
        .sensoryFeedback(.impact(weight: .light), trigger: step)
        .sensoryFeedback(.impact(weight: .light), trigger: opening) { _, new in new == .closed || new == .opening }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            withAnimation(.snappy) { keyboardHeight = max(0, UIScreen.main.bounds.height - frame.minY) }
        }
        .sheet(isPresented: Binding(get: { step != .opening }, set: { _ in })) {
            sheet
                .presentationDetents(fitsContent ? [.height(sheetHeight)] : [.medium, .large])
                .presentationBackgroundInteraction(.enabled)
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
                // No field on screen: the keyboard types straight onto the flag in the room.
                if let gym {
                    NameTyper(gym: gym, question: "Where are you training now?") { step = .unit }
                } else {
                    question("Where are you training now?")
                }
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
                    PlateChips(gym: gym).padding(2)
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
                PRList(editing: $editingPR)
                Button("Continue") { onFinish() }
                    .buttonStyle(.bigBlack)
            }
        }
        .padding(20)
        .padding(.top, 8)
        .fixedSize(horizontal: false, vertical: fitsContent)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { height in
            if fitsContent { sheetHeight = height }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(Theme.ink)
        .background(Theme.paper)
        .animation(.snappy, value: step)
    }

    /// Title → tap → the closed box → tap → it opens, the furniture comes in, and the setup starts (SPEC 2.2 step 0).
    private func tapDuringOpening() {
        guard step == .opening else { return }
        switch opening {
        case .title:
            withAnimation { opening = .closed }
        case .closed:
            opening = .opening
            Task {
                try? await Task.sleep(for: .seconds(2.1))              // the box opens while the camera drifts in
                opening = .furnishing
                try? await Task.sleep(for: .seconds(Double(Opening.furnishTime)))
                opening = .done
                step = .name
            }
        case .opening, .furnishing, .done:
            break
        }
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

/// The gym's name, typed with no field on screen: it shows on the flag. The field keeps its own focus (focus
/// doesn't carry into a sheet from the view that presents it). It asks for the keyboard at once, and again as the
/// sheet settles in case it wasn't ready; tapping the question brings the keyboard back.
private struct NameTyper: View {
    @Bindable var gym: Gym
    let question: String
    var onSubmit: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        Text(question)
            .font(Theme.heading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
            .background(alignment: .topLeading) { field }
    }

    private var field: some View {
        TextField("", text: Binding(get: { gym.name }, set: { gym.name = GymSetup.normalizedName($0) }))
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .focused($focused)
            .submitLabel(.continue)
            .onSubmit { if !gym.name.isEmpty { onSubmit() } }
            .frame(width: 2, height: 2)
            .opacity(0.02)
            .accessibilityLabel("Box name")
            .onAppear { focused = true }
            .task {
                for delay in [150, 400] {
                    try? await Task.sleep(for: .milliseconds(delay))
                    if !focused { focused = true }
                }
            }
    }
}

/// The opening's title (prototype AnimLayer 'open'): "pl8(math)" in cream over the orange, with plates drifting
/// up behind it, slowly turning. Tap anywhere to go on.
private struct OpeningTitle: View {
    private struct Drifter {
        let plate: Plate
        let x: Double, speed: Double, phase: Double, spin: Double, size: Double
    }

    private let drifters: [Drifter] = {
        var seed: UInt64 = 7
        func random() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(1 << 31)
        }
        let plates = Plate.catalog(.kg)
        return (0..<24).map { i in
            Drifter(plate: plates[i % plates.count], x: random(), speed: 0.035 + random() * 0.04, phase: random(),
                    spin: 0.3 + random() * 0.9, size: 0.6 + random() * 0.6)
        }
    }()

    private let ink = Color(Diorama.uiColor(Look.boxDark)), cream = Color(Diorama.uiColor(Look.boxLight))

    var body: some View {
        ZStack {
            Theme.background
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for d in drifters {
                        let travel = (d.phase + t * d.speed).truncatingRemainder(dividingBy: 1)
                        let diameter = size.width * 0.32 * d.plate.diameter / 0.45 * d.size
                        let y = size.height + diameter - travel * (size.height + diameter * 2)
                        let x = d.x * size.width + sin(t * 0.4 + d.phase * 6) * 18
                        let squash = max(0.12, abs(cos(t * d.spin + d.phase * 6)))
                        let rect = CGRect(x: x - diameter * squash / 2, y: y - diameter / 2, width: diameter * squash, height: diameter)
                        context.fill(Path(ellipseIn: rect), with: .color(Color(hex: d.plate.colorHex)))
                        context.stroke(Path(ellipseIn: rect), with: .color(ink), lineWidth: 2)
                        let hub = rect.insetBy(dx: rect.width * 0.4, dy: rect.height * 0.4)
                        context.fill(Path(ellipseIn: hub), with: .color(cream))
                    }
                }
            }
            Text("pl8(math)")
                .font(.system(size: 54, weight: .black))
                .tracking(4)
                .foregroundStyle(cream)
        }
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityLabel("pl8(math). Tap to start")
        .accessibilityAddTraits(.isButton)
    }
}
