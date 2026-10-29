import PhotosUI
import RealityKit
import SwiftData
import SwiftUI
import UIKit
import PlateKit

/// The Flow's screen (SPEC 2.0): the background, the 3D stage over it, the question at the top, and the step's
/// own UI. The finger goes to the stage unless it lands on a button.
struct FlowView: View {
    @State var flow: Flow
    @State private var photoItem: PhotosPickerItem?
    /// Resets when the touch ends or is cancelled: a cancel (no onEnded) still lets go of what was held.
    @GestureState private var touching = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                FlowBackground(flow: flow)
                FlowStageView(flow: flow)
                    .allowsHitTesting(false)
                FlowQuestion(flow: flow)
                    .offset(y: -flow.pan - flow.uiPan)
                    .allowsHitTesting(false)
                FlowLabels(flow: flow)
                    .offset(y: -flow.pan - flow.uiPan)
                    .allowsHitTesting(false)
                stepUI
                    .offset(y: -flow.pan - flow.uiPan)
                    .opacity(flow.uiOpacity)
                    .allowsHitTesting(flow.uiInteractive)
                styleToggles
                if let text = flow.readingText { FlowReading(text: text, unit: flow.data.unit) }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .coordinateSpace(.named("flow"))
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("flow"))
                .updating($touching) { _, state, _ in state = true }
                .onChanged { value in
                    if flow.down == nil { flow.pointerDown(value.startLocation) }
                    if value.location != value.startLocation { flow.pointerMove(value.location) }
                }
                .onEnded { value in
                    if flow.down == nil { flow.pointerDown(value.startLocation) }
                    flow.pointerUp(value.location)
                })
            .onChange(of: touching) { _, now in if !now { flow.pointerCancel() } }
            .onAppear { flow.viewSize = geometry.size }
            .onChange(of: geometry.size) { _, size in flow.viewSize = size }
        }
        .ignoresSafeArea()
        .statusBarHidden(false)
        .sensoryFeedback(.selection, trigger: flow.selectionTicks)
        .sensoryFeedback(.impact(weight: .light), trigger: flow.lightTicks)
        .sensoryFeedback(.success, trigger: flow.successTicks)
        .sensoryFeedback(.warning, trigger: flow.warningTicks)
        .alert(flow.alert?.title ?? "", isPresented: Binding(get: { flow.alert != nil }, set: { if !$0 { flow.alert = nil } }),
               presenting: flow.alert) { alert in
            ForEach(Array(alert.buttons.enumerated()), id: \.offset) { _, button in
                Button(button.label, role: button.destructive ? .destructive : (alert.buttons.count > 1 && !button.destructive ? .cancel : nil)) {
                    button.action?()
                }
            }
        } message: { alert in
            Text(alert.message)
        }
        .photosPicker(isPresented: Binding(get: { flow.photoRequest != nil }, set: { if !$0 && photoItem == nil { flow.photoRequest = nil } }),
                      selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item, let request = flow.photoRequest else { return }
            photoItem = nil
            flow.photoRequest = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    request.picked(image)
                }
            }
        }
    }

    @ViewBuilder
    private var stepUI: some View {
        switch flow.step {
        case .plates: PlatesOverlay(flow: flow)
        case .prDial: PRDialOverlay(flow: flow)
        case .kit: KitOverlay(flow: flow)
        case .sets: SetsOverlay(flow: flow)
        case .done:
            if let heaviest = flow.lastPlan?.heaviest, let plan = flow.lastPlan {
                SessionOverView(perSide: heaviest.perSide, unit: plan.unit, barWeight: plan.bar) { flow.closeScale() }
            } else {
                SessionOverView(perSide: [], unit: flow.data.unit, barWeight: flow.data.bar) { flow.closeScale() }
            }
        default: Color.clear.allowsHitTesting(false)
        }
    }

    /// Double-tap where the clock is for rough edges, where the battery is for the background (the prototype's
    /// phone shortcuts for its W and C keys).
    private var styleToggles: some View {
        VStack {
            HStack {
                Color.clear.frame(width: 110, height: 54).contentShape(Rectangle()).onTapGesture(count: 2) { flow.toggleRough() }
                Spacer()
                Color.clear.frame(width: 110, height: 54).contentShape(Rectangle()).onTapGesture(count: 2) { flow.toggleBackground() }
            }
            Spacer()
        }
    }
}

/// The ARView the stage draws into.
struct FlowStageView: UIViewRepresentable {
    let flow: Flow

    func makeUIView(context: Context) -> ARView { flow.arView }
    func updateUIView(_ view: ARView, context: Context) {}
}

/// Orange for questions, the menu and the scale; the light studio colour with a fine grid for the kit and sets.
struct FlowBackground: View {
    let flow: Flow

    var body: some View {
        ZStack {
            if let colour = flow.backgroundOverride {
                colour
            } else if flow.alt {
                Color(rgb: FlowLook.light)
                // CSS radial-gradient(ellipse at 50% 55%, white .55, transparent 70%): farthest-corner, so the
                // ellipse reaches 0 at 0.7 × √2 × (half the width, 55 % of the height).
                let size = flow.viewSize, rx = 0.7 * 2.squareRoot() * size.width / 2, ry = 0.7 * 2.squareRoot() * size.height * 0.55
                RadialGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0)], center: UnitPoint(x: 0.5, y: 0.55),
                               startRadius: 0, endRadius: rx)
                    .scaleEffect(x: 1, y: ry / max(1, rx), anchor: UnitPoint(x: 0.5, y: 0.55))
                FlowGrid(offset: flow.gridY)
            } else {
                Color(rgb: FlowLook.orange)
            }
        }
        .ignoresSafeArea()
    }
}

/// 26 pt grid lines at rgba(108, 55, 19, 0.09), moving with the pan.
struct FlowGrid: View {
    let offset: CGFloat

    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 26, colour = Color(red: 108 / 255, green: 55 / 255, blue: 19 / 255).opacity(0.09)
            let dy = (offset.truncatingRemainder(dividingBy: step) + step).truncatingRemainder(dividingBy: step)
            // The prototype's tile is centred across and offset by the pan down: lines at x = (w − 26)/2 + 26k.
            let x0 = ((size.width - step) / 2).truncatingRemainder(dividingBy: step), y0 = dy
            var path = Path()
            var x = x0 - step
            while x < size.width + step { path.addRect(CGRect(x: x, y: 0, width: 1, height: size.height)); x += step }
            var y = y0 - step
            while y < size.height + step { path.addRect(CGRect(x: 0, y: y, width: size.width, height: 1)); y += step }
            context.fill(path, with: .color(colour))
        }
    }
}

/// The question: centred at the top, 30 pt, words appearing one by one (hidden words keep their place).
struct FlowQuestion: View {
    let flow: Flow

    var body: some View {
        let k = flow.viewSize.height / 844
        VStack(spacing: 0) {
            QuestionLabel(words: flow.question, shown: flow.shown, colour: flow.ink.uiColor)
                .padding(.horizontal, 28)
                .padding(.top, 92 * k)
            Spacer()
        }
        .accessibilityElement()
        .accessibilityLabel(flow.question.joined(separator: " "))
    }
}

/// UILabel with the prototype's exact line height (1.1) and tracking (−0.01 em).
struct QuestionLabel: UIViewRepresentable {
    let words: [String]
    let shown: Int
    let colour: UIColor

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.attributedText = attributed
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let width = proposal.width ?? 334
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitted.height)
    }

    var attributed: NSAttributedString {
        let font = UIFont(name: "SpaceGrotesk-Bold", size: 30) ?? .boldSystemFont(ofSize: 30)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.minimumLineHeight = 33
        paragraph.maximumLineHeight = 33
        let text = NSMutableAttributedString()
        for (i, word) in words.enumerated() {
            text.append(NSAttributedString(string: word + (i < words.count - 1 ? " " : ""), attributes: [
                .font: font, .kern: -0.3, .paragraphStyle: paragraph,
                .foregroundColor: i < shown ? colour : UIColor.clear,
                .baselineOffset: (33 - font.lineHeight) / 4,
            ]))
        }
        return text
    }
}

/// Labels under 3D objects (22 pt, ink), placed by the stage every frame.
struct FlowLabels: View {
    let flow: Flow

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(flow.labels) { label in
                Text(label.text)
                    .font(.custom("SpaceGrotesk-Bold", size: 22))
                    .foregroundStyle(flow.inkColor)
                    .fixedSize()
                    .position(label.point)
                    .opacity(label.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// "Reading your workout…": a white veil and a spinning plate; the words are for VoiceOver.
struct FlowReading: View {
    let text: String
    let unit: WeightUnit
    @State private var stage = ReadingPlateStage()

    var body: some View {
        ZStack {
            Color.white.opacity(0.8)
            SketchStageView { stage.build(unit: unit) }
                .frame(width: 168, height: 168)
                .task { await stage.run() }
        }
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityLabel(text)
    }
}

/// The loader (the prototype's spinPlate): the heaviest bumper, two-tone and sketched like the title's plates,
/// spinning like a coin, tipped toward you and wobbling a little.
@MainActor
final class ReadingPlateStage {
    private let spin = Entity()
    private let tip = Entity()

    func build(unit: WeightUnit) -> [Entity] {
        guard let plate = Plate.catalog(unit).first else { return [] }
        let parts = SessionScene.parts(.init(plate: plate, centre: .zero, axis: .y, turn: 0))
        let still = RoomLayout.Placement(position: .zero, rotationDegrees: 0)
        for child in Diorama.entities(for: SceneBake.bake(parts, placement: still, wall: nil, content: .withoutShadows, light: .animation),
                                      duotone: true) {
            tip.addChild(child)
        }
        spin.addChild(tip)
        pose(0)
        // The prototype's camera: 30°, 1.12 m back.
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 30
        camera.position = [0, 0, 1.12]
        return [spin, camera]
    }

    func run() async {
        let start = ContinuousClock.now
        while !Task.isCancelled {
            pose(Float((ContinuousClock.now - start) / .seconds(1)))
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    private func pose(_ t: Float) {
        spin.orientation = simd_quatf(angle: t * 5.2, axis: [0, 1, 0])
        tip.orientation = simd_quatf(angle: .pi / 2 + 0.38 + sin(t * 2.6) * 0.1, axis: [1, 0, 0])
    }
}

extension Flow {
    /// The prototype's layout is for a 390 × 844 screen: its pixels, here, scaled by height around the centre
    /// like the 3D (a vertical field of view).
    var layoutScale: CGFloat { viewSize.height / 844 }

    func screen(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: viewSize.width / 2 + (x - 195) * layoutScale, y: y * layoutScale)
    }

    /// Asks for a photo (flPickPhoto), then shows the reading veil for at least 3 s while `read` works.
    func pickPhoto(_ kind: FlowPhotoRequest.Kind, reading text: String, read: @escaping (UIImage) async -> Bool, then: @escaping (Bool) -> Void) {
        photoRequest = FlowPhotoRequest(kind: kind) { [weak self] image in
            guard let self else { return }
            self.readingText = text
            let started = self.t, question = self.clearings
            Task { @MainActor in
                let ok = await read(image)
                let wait = max(0, 3 - (self.t - started))
                try? await Task.sleep(for: .seconds(wait))
                self.readingText = nil
                if ok { self.buzz(.success) } else { self.buzz(.warning) }
                // Only if the same question is still on screen.
                if self.clearings == question { then(ok) }
            }
        }
    }
}
