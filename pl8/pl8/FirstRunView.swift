import SwiftData
import SwiftUI
import UIKit
import RealityKit
import PlateKit

/// First run (SPEC 2.2): opening → gym setup, one question per drawer → PRs, like the prototype.
/// The room sits above the drawer and builds itself from the answers: the flag, the plate shelf, the bar.
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
    /// The drawer's height, measured, so the room gets the rest of the screen.
    @State private var drawerHeight: CGFloat = 320
    /// The keyboard's height, so the room shows above it and the drawer while you type the name.
    @State private var keyboardHeight: CGFloat = 0

    private var gym: Gym? { gyms.first { $0.isCurrent } ?? gyms.first }

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
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            // The drawer is only as tall as its question; the room fills the rest, a little behind its rough top.
            // During the opening it has the whole screen.
            GeometryReader { geometry in
                RoomStage(station: station, gymName: gym?.name ?? "", unit: gym?.unit ?? .kg,
                          plateSizes: gym?.plateSizes ?? [], barWeight: gym?.barWeight ?? 20,
                          boards: Boards(prs: Planner.boardRows(records)), opening: step == .opening ? opening : nil,
                          tiltable: step == .opening)
                    .frame(height: step == .opening
                           ? geometry.size.height
                           : max(200, geometry.size.height - drawerHeight - max(keyboardHeight, HomeView.bottomInset) + 24))
            }
            .ignoresSafeArea()

            if step == .opening && opening == .title {
                OpeningTitle()
                    .transition(.opacity.animation(.easeOut(duration: 0.55)))
            }
            if step != .opening {
                drawer
                    .id(step)
                    .transition(.move(edge: .bottom))
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { drawerHeight = $0 }
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
    }

    private func go(_ next: Step) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { step = next }
    }

    // MARK: - Drawers (prototype showGym, showPRs, prList)

    @ViewBuilder
    private var drawer: some View {
        switch step {
        case .opening:
            EmptyView()

        case .name:
            // No field on screen: the keyboard types straight onto the flag in the room.
            Drawer {
                if let gym {
                    NameTyper(gym: gym, question: "Where are you training now?") { go(.unit) }
                } else {
                    DrawerHeading(text: "Where are you training now?")
                }
                Button("Continue") { go(.unit) }
                    .buttonStyle(.black)
                    .disabled(gym?.name.isEmpty ?? true)
            }

        case .unit:
            Drawer(back: { go(.name) }) {
                DrawerHeading(text: "Is the gym kilos or pounds?")
                if let gym { UnitList(gym: gym) }
                Button("Continue") { go(.plates) }
                    .buttonStyle(.black)
                    .padding(.top, 16)
            }

        case .plates:
            Drawer(back: { go(.unit) }) {
                DrawerHeading(text: "Which plates does your gym have?")
                if let gym { PlateChips(gym: gym) }
                Button("Continue") { go(.bar) }
                    .buttonStyle(.black)
                    .disabled(gym?.plateSizes.isEmpty ?? true)
                    .padding(.top, 16)
            }

        case .bar:
            Drawer(back: { go(.plates) }) {
                DrawerHeading(text: "Which bar do you use?")
                if let gym { BarList(gym: gym) }
                Button("Done") { go(.prChoice) }
                    .buttonStyle(.black)
                    .padding(.top, 16)
            }

        case .prChoice:
            Drawer {
                DrawerHeading(text: "Add your PRs")
                PRScreenshotPicker(onDone: { count in
                    if count > 0 { go(.prList) }
                }) {
                    OptionRow(title: "Upload a screenshot", icon: .photo, tag: "Fastest")
                }
                OptionRow(title: "Scan with the camera", icon: .camera)
                    .opacity(0.4)
                Button { go(.prList) } label: {
                    OptionRow(title: "Type them in", icon: .keys)
                }
                .buttonStyle(.pressable)
            }

        case .prList:
            Drawer(back: { go(.prChoice) }, action: "Next", onAction: onFinish) {
                PRList()
            }
        }
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

}

/// Kilograms / Pounds as rows with a check (prototype showGym step 1).
private struct UnitList: View {
    @Bindable var gym: Gym

    var body: some View {
        VStack(spacing: 0) {
            ForEach([WeightUnit.kg, WeightUnit.lb], id: \.self) { unit in
                Button { gym.switchUnit(to: unit) } label: {
                    ListRow(label: unit == .kg ? "Kilograms" : "Pounds", checked: gym.unit == unit)
                }
                .buttonStyle(.pressable)
            }
        }
        .sensoryFeedback(.selection, trigger: gym.unit)
    }
}

/// The unit's bars as rows with a check: "20 kg · Olympic bar" (prototype showGym step 3).
private struct BarList: View {
    @Bindable var gym: Gym

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Bar.weights(gym.unit), id: \.self) { weight in
                Button { gym.barWeight = weight } label: {
                    ListRow(label: label(weight), checked: gym.barWeight == weight)
                }
                .buttonStyle(.pressable)
            }
        }
        .sensoryFeedback(.selection, trigger: gym.barWeight)
    }

    private func label(_ weight: Double) -> String {
        let text = "\(WeightUnit.trimmed(weight)) \(gym.unit.rawValue)"
        guard let name = Bar.name(weight, gym.unit) else { return text }
        return "\(text) · \(name) bar"
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
        DrawerHeading(text: question)
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

/// The opening on later launches (SPEC open decision 2: every launch for now): the same title, closed box and
/// opening as the first run, then home.
struct OpeningScreen: View {
    var onDone: () -> Void

    @Query private var gyms: [Gym]
    @Query private var records: [PersonalRecord]
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @State private var opening: OpeningPhase = .title

    private var gym: Gym? { gyms.first { $0.isCurrent } ?? gyms.first }

    var body: some View {
        let today = workouts.first { Calendar.current.isDateInToday($0.date) }
        ZStack {
            Theme.background.ignoresSafeArea()
            RoomStage(station: opening == .title || opening == .closed ? .far : .overview, gymName: gym?.name ?? "",
                      unit: gym?.unit ?? .kg, plateSizes: gym?.plateSizes ?? [], barWeight: gym?.barWeight ?? 20,
                      boards: Boards(prs: Planner.boardRows(records), workout: Planner.boardLines(for: today, gym: gym, records: records)),
                      opening: opening, tiltable: true)
                .ignoresSafeArea()
            if opening == .title {
                OpeningTitle()
                    .transition(.opacity.animation(.easeOut(duration: 0.55)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            switch opening {
            case .title:
                withAnimation { opening = .closed }
            case .closed:
                opening = .opening
                Task {
                    try? await Task.sleep(for: .seconds(2.1))
                    opening = .furnishing
                    try? await Task.sleep(for: .seconds(Double(Opening.furnishTime)))
                    onDone()
                }
            case .opening, .furnishing, .done:
                break
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: opening) { _, new in new == .closed || new == .opening }
    }
}

/// The opening's title (prototype AnimLayer 'open'): "pl8(math)" in cream over the orange, with real plates in the
/// prototype's two tones and rough outline drifting up on both sides, slowly tumbling. Tap anywhere to go on.
struct OpeningTitle: View {
    @State private var stage = TitleStage()
    @AppStorage(MotionSource.settingKey) private var motionEffects = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let cream = Color(Diorama.uiColor(Look.boxLight))

    var body: some View {
        ZStack {
            Theme.background
            // Behind the plates, like the prototype's (its text layer sits under the 3D): they fly past in front.
            Text("pl8(math)")
                .font(Theme.display(39))
                .tracking(4.3)
                .foregroundStyle(cream)
            GeometryReader { geometry in
                // Drawn like the prototype's layer: through the sketch pass, which outlines each plate.
                SketchStageView { stage.build(aspect: Float(geometry.size.width / max(1, geometry.size.height)), sketched: true) }
                    .task { await stage.run(tilting: motionEffects && !reduceMotion) }
            }
        }
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityLabel("pl8(math). Tap to start")
        .accessibilityAddTraits(.isButton)
    }
}

/// The title's plates in 3D: PlateKit's `TitleField` moves them, this places them in front of a camera with the
/// prototype's lens (focal length 0.9 × the screen height).
@MainActor
final class TitleStage {
    private var field = TitleField(count: 24, seed: UInt32.random(in: 1...99_999))
    private var plates: [(entity: Entity, scale: Float)] = []
    private var aspect: Float = 390.0 / 844.0
    private var built = false

    /// - Parameter sketched: drawn through the sketch pass (no orange sky box, no outline strokes of its own).
    func build(aspect: Float, sketched: Bool = false) -> [Entity] {
        self.aspect = aspect
        let root = Entity()
        if !sketched, let sky = try? ModelEntity(mesh: Diorama.meshResource(LowPolyMesh.box(size: [200, 200, 200]).insideOut()),
                                      materials: [Diorama.flat(Diorama.background)]) {
            root.addChild(sky)
        }
        let catalog = Plate.catalog(.kg), still = RoomLayout.Placement(position: .zero, rotationDegrees: 0)
        plates = field.plates.indices.map { i in
            let plate = catalog[i % catalog.count]
            var parts = SessionScene.parts(.init(plate: plate, centre: .zero, axis: .x, turn: 0))
            // The outline about 2.5 points wide on screen, whatever the plate's depth and size (prototype skWidth).
            let item = field.plates[i]
            let scale = item.radius / (TitleStage.halfHeight * 2 * 0.9) / (Float(plate.diameter) / 2)
            let width = 2.5 * item.z / (scale * TitleStage.halfHeight * 2 * 0.9)
            if !sketched {
                parts.append(PropPart(mesh: ScaleScene.outline(parts, seed: UInt32(i) &* 17, width: width, justTheRim: true), tone: .flat(Look.ink), inked: false, casts: false))
            }
            let entity = Entity()
            for child in Diorama.entities(for: SceneBake.bake(parts, placement: still, wall: nil, content: .withoutShadows, light: .animation), duotone: true) {
                entity.addChild(child)
            }
            root.addChild(entity)
            // Its radius on screen at depth 1 over the focal length, in metres at 1 m, against its real radius.
            return (entity, field.plates[i].radius / (TitleStage.halfHeight * 2 * 0.9) / (Float(plate.diameter) / 2))
        }
        place()
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 2 * atan(0.5 / 0.9) * 180 / .pi
        built = true
        return [root, camera]
    }

    static let halfHeight: Float = 422

    /// - Parameter tilting: the plates move with the phone, nearer ones more (the switch in the Gym drawer).
    func run(tilting: Bool) async {
        if tilting { MotionSource.shared.start() }
        defer { if tilting { MotionSource.shared.stop() } }
        var spring = TiltSpring()
        var last = ContinuousClock.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(16))
            let now = ContinuousClock.now
            let dt = min(0.05, Float((now - last) / .seconds(1)))
            if tilting { tilt = spring.step(towards: MotionSource.shared.tilt, dt: dt) }
            if built {
                field.step(dt)
                place()
            }
            last = now
        }
    }

    private var tilt = SIMD2<Float>.zero

    /// Each plate at its spot: across and up by its screen position times its depth, turned by its tumble.
    private func place() {
        for (i, item) in field.plates.enumerated() where i < plates.count {
            let k = item.z / 0.9 * 0.5
            let entity = plates[i].entity
            // Depth: plates nearer than 1.5 m slide with the tilt, farther ones against it.
            let parallax = tilt * (1.5 - item.z) * 0.12
            entity.position = SIMD3(item.u * aspect * k + parallax.x, -item.v * k + parallax.y, -item.z)
            entity.orientation = simd_quatf(angle: item.rotation.x, axis: [1, 0, 0]) * simd_quatf(angle: item.rotation.y, axis: [0, 1, 0])
                * simd_quatf(angle: item.rotation.z, axis: [0, 0, 1])
            entity.scale = SIMD3(repeating: plates[i].scale)
        }
    }
}
