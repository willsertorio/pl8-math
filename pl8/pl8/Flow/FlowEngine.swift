import Combine
import Metal
import RealityKit
import SwiftUI
import UIKit
import PlateKit

/// The Flow (design/flow-handoff, SPEC 2.0): one question at a time with a small 3D object under it, then the
/// menu. Built like the prototype's Flow (one class, `fl*` methods, a scene that's cleared for every question),
/// on RealityKit: an `ARView` without AR, transparent over the SwiftUI background, with the prototype's sketch
/// pass as a Metal post-process (FlowSketch.metal).
///
/// This file is the stage: the view, the camera, the frame loop, tweens and timers, the pan between questions
/// and the finger. Each question lives in its own file as an extension.
@MainActor @Observable
final class Flow {
    enum Step: String { case name, unit, plates, bar, prs, prDial, wod, kit, sets, done, menu }
    /// The prototype's flMode: first run, the menu, or editing something from the gym room.
    enum Mode { case firstRun, menu, gym }

    // MARK: - What SwiftUI shows

    var step: Step = .name
    /// The question, word by word; `shown` words are visible.
    var question: [String] = []
    var shown = 0
    /// The world has moved up by this many points (flPanSet): the question and the screen's UI move with it.
    var pan: CGFloat = 0
    /// The screen's UI alone moves this much more, the 3D doesn't (the sets' drag back toward the kit).
    var uiPan: CGFloat = 0
    /// The step's own UI takes touches (not while a pan takes it away).
    var uiInteractive = true
    /// The light grid background (the kit and sets), else orange.
    var alt = false
    /// The rough edges are on.
    var rough = true
    /// The grid's offset, so it moves with the pan.
    var gridY: CGFloat = 0
    /// While dragging from the kit back to the board, the background blends to the board's.
    var backgroundOverride: Color?
    /// The screen's own UI (cards, labels, boxes) fades during some camera moves.
    var uiOpacity: Double = 1
    /// Text under 3D objects (bar weights, menu items), already projected to the screen.
    var labels: [FlowLabel] = []
    var viewSize = CGSize(width: 393, height: 852)
    /// "Reading your workout…": the white screen with a spinning plate.
    var readingText: String?
    var alert: FlowAlert?
    /// Asking the photo library for a picture (the system picker).
    var photoRequest: FlowPhotoRequest?
    // Haptics, as counters SwiftUI's .sensoryFeedback watches.
    var selectionTicks = 0
    var lightTicks = 0
    var successTicks = 0
    var warningTicks = 0
    /// The user flipped the step's default look (the W and C keys in the prototype).
    var userRough = false
    var userBackground = false

    // MARK: - The stage

    @ObservationIgnored let arView: ARView
    @ObservationIgnored let anchor = AnchorEntity(world: .zero)
    /// Everything the current question adds (flAdd); cleared between questions.
    @ObservationIgnored let scene = Entity()
    @ObservationIgnored let camera = PerspectiveCamera()
    @ObservationIgnored let sketch = SketchPass()
    @ObservationIgnored var cam = FlowCam(position: [0, 0, 10], target: .zero, fov: 35)
    /// The flow's clock, seconds.
    @ObservationIgnored var t: Double = 0
    @ObservationIgnored var tick: ((Float, Double) -> Void)?
    @ObservationIgnored var tweens: [FlowTween] = []
    @ObservationIgnored var timers: [FlowTimer] = []
    @ObservationIgnored var nextTimer = 0
    @ObservationIgnored var subscriptions: [any Cancellable] = []
    @ObservationIgnored var stepSubscriptions: [any Cancellable] = []
    @ObservationIgnored var mode: Mode = .firstRun
    /// The data behind the flow (gym, PRs, plan).
    @ObservationIgnored var data: FlowData

    // The finger (flBindPointer).
    @ObservationIgnored var hit: ((CGPoint) -> FlowDrag?)?
    @ObservationIgnored var drag: FlowDrag?
    @ObservationIgnored var down: (point: CGPoint, time: Double)?
    @ObservationIgnored var onSwipe: (() -> Void)?
    @ObservationIgnored var onSwipeDown: (() -> Void)?
    @ObservationIgnored var onTap: ((CGPoint) -> Void)?
    /// A swipe up goes back to the menu, following the finger (flPanBackBind).
    @ObservationIgnored var panBack = false
    @ObservationIgnored var panBackDrag: PanDrag?
    @ObservationIgnored var panning = false
    @ObservationIgnored var panIn: CGFloat?
    /// Go straight to the next step without a pan (after a zoom).
    @ObservationIgnored var direct = false
    /// The model says what the question is answering (an edit from the gym room goes back to the menu).
    @ObservationIgnored var editOne = false
    @ObservationIgnored var fromMenu = false
    @ObservationIgnored var fromKit = false
    /// Where the PR dial goes when it's done (flPrRet).
    @ObservationIgnored var prReturn: Step?
    /// The workout has been read again after the first session ("What are we doing today?").
    @ObservationIgnored var again = false
    @ObservationIgnored var dustCache: Entity?
    /// The session being lifted (the prototype's plan), the set in view and which sets are done.
    @ObservationIgnored var plan: FlowPlan?
    @ObservationIgnored var setIndex = 0
    @ObservationIgnored var doneSets: Set<Int> = []
    /// The kit chips ticked off.
    var collected: Set<Double> = []
    /// Coming back up from the sets: the kit is laid out as it was, already resting.
    @ObservationIgnored var kitPlaced = false
    @ObservationIgnored var kitItems: [FlowKitPlate] = []
    /// The bar during the sets, the camera's pan back toward the kit, and the kit seen coming from above.
    @ObservationIgnored var barState: FlowBarState?
    @ObservationIgnored var setsPan: (up: SIMD3<Float>, worldPerPoint: Float, px: CGFloat)?
    @ObservationIgnored var setsProxy: (entity: Entity, kit: FlowCam, up: SIMD3<Float>, worldPerPoint: Float, height: CGFloat)?
    /// The session the scale weighs.
    @ObservationIgnored var lastPlan: FlowPlan?
    /// For the CI's pictures: time stands still.
    @ObservationIgnored var frozen = false
    /// Made under the opening and not started yet: the stage is ready, the sketch pass rests.
    @ObservationIgnored var waiting = false
    /// For the CI: where the time goes.
    @ObservationIgnored var perf: FlowPerf?
    @ObservationIgnored var relightTime = 0.0
    /// For the CI's pictures: ticks a checklist box as if drawn.
    @ObservationIgnored var debugDecide: ((Int) -> Void)?
    /// The menu: where the carousel is, which item is awake.
    @ObservationIgnored var menuPosition: Float = 0
    @ObservationIgnored var menuActive: String?
    /// Effects.
    @ObservationIgnored var trauma: Float = 0
    @ObservationIgnored var fovKick: Float = 0
    @ObservationIgnored var dust: [FlowDust] = []
    @ObservationIgnored var sparkles: [FlowSparkle] = []
    @ObservationIgnored var squashes: [ObjectIdentifier: FlowSquash] = [:]
    @ObservationIgnored var hitSizes: [ObjectIdentifier: SIMD3<Float>] = [:]
    @ObservationIgnored var shaded: [FlowShadedModel] = []
    @ObservationIgnored var meshCache: [Int: MeshResource] = [:]
    /// Where the next frame's re-lighting starts, so every model gets its turn.
    @ObservationIgnored var reshadeCursor = 0
    /// Palette colours waiting to go to the GPU this frame.
    @ObservationIgnored var paletteUploads: [ObjectIdentifier: (texture: LowLevelTexture, bytes: [UInt8], width: Int, height: Int)] = [:]
    @ObservationIgnored var textures: [FlowPicture: TextureResource] = [:]
    @ObservationIgnored var physics: FlowPhysicsWorld?
    @ObservationIgnored var lastClick: Double = -1

    init(data: FlowData) {
        self.data = data
        arView = ARView(frame: CGRect(x: 0, y: 0, width: 393, height: 852), cameraMode: .nonAR, automaticallyConfigureSession: false)
        Self.configure(arView, pass: sketch)
        arView.scene.addAnchor(anchor)
        anchor.addChild(scene)
        camera.camera.fieldOfViewInDegrees = 35
        camera.camera.near = 0.1
        camera.camera.far = 100
        anchor.addChild(camera)
        subscriptions.append(arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.frame(Float(event.deltaTime))
        })
    }

    /// No AR, a clear background (the SwiftUI one shows through), no effects of its own, the sketch pass after.
    static func configure(_ view: ARView, pass: SketchPass) {
        view.environment.background = .color(.clear)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain, .disableGroundingShadows,
                              .disableAREnvironmentLighting, .disableHDR]
        view.isMultipleTouchEnabled = false
        view.isUserInteractionEnabled = false
        let callbacks = SketchPass.callbacks(pass)
        view.renderCallbacks.prepareWithDevice = callbacks.prepare
        view.renderCallbacks.postProcess = callbacks.post
    }

    // MARK: - The frame

    private func frame(_ delta: Float) {
        // For the CI's pictures of a moment mid-animation: everything stops, the picture stays.
        if frozen { return }
        let began = perf == nil ? 0 : CACurrentMediaTime()
        let dt = min(0.05, max(0, delta))
        t += Double(dt)
        tick?(dt, t)
        runTweens(Double(dt))
        runTimers()
        dustTick(dt)
        sparkleTick(dt)
        squashTick(dt)
        physics?.step(dt, flow: self)
        let relit = perf == nil ? 0 : CACurrentMediaTime()
        reshade()
        if perf != nil { relightTime = CACurrentMediaTime() - relit }
        applyCamera(dt)
        perf?.frame(interval: Double(delta), work: CACurrentMediaTime() - began, relight: relightTime, step: step.rawValue)
    }

    /// Where the camera is now, with the pan (not the shake): what labels and rays use.
    var liveCamera: FlowCam {
        var c = cam
        let geo = panGeometry()
        let shift = geo.up * Float(-pan) * geo.worldPerPoint
        c.position += shift
        c.target += shift
        return c
    }

    private func applyCamera(_ dt: Float) {
        var c = liveCamera
        // Impacts kick the camera (flCamFx): trauma² × 0.1, decaying.
        let s = trauma * trauma * FlowPhysics.shake
        if s > 0.0001 {
            let time = Float(t), k = 0.05 * s
            let off = SIMD3<Float>((sin(time * 31) * 0.7 + sin(time * 17.3 + 0.7) * 0.3) * k,
                                   (sin(time * 37.7 + 1.3) * 0.7 + sin(time * 13.1 + 2.2) * 0.3) * k,
                                   sin(time * 29.3 + 2.1) * k * 0.4)
            c.position += off
            c.target += off
        }
        trauma = max(0, trauma - dt * 2.6)
        let kick = fovKick
        fovKick = kick * exp(-7 * dt)
        camera.transform = Transform(matrix: c.matrix)
        camera.camera.fieldOfViewInDegrees = c.fov * (1 - kick)
        sketch.pointsWide = Float(max(1, viewSize.width))
        sketch.on = rough && !waiting
    }

    func setCamera(_ position: SIMD3<Float>, _ target: SIMD3<Float>, fov: Float = 35) {
        cam = FlowCam(position: position, target: target, fov: fov)
    }

    // MARK: - Tweens and timers (flAnim, flLater)

    func anim(_ duration: Double, _ fn: @escaping (Double) -> Void, done: (() -> Void)? = nil) {
        tweens.append(FlowTween(duration: duration, fn: fn, done: done))
    }

    private func runTweens(_ dt: Double) {
        guard !tweens.isEmpty else { return }
        // Tweens survive a scene change made from inside a tween's own callback (flTween, round 7).
        let list = tweens
        let mark = UUID()
        tweenMark = mark
        tweens = []
        let keep = list.filter { tween in
            tween.t += dt
            let u = min(1, tween.t / max(0.0001, tween.duration))
            tween.fn(u)
            if u >= 1 { tween.done?(); return false }
            return true
        }
        if tweenMark == mark { tweens = keep + tweens }
    }
    @ObservationIgnored private var tweenMark = UUID()
    /// Bumped each time a question is cleared: work that finishes later (a photo read) checks it's still wanted.
    @ObservationIgnored private(set) var clearings = 0

    @discardableResult
    func later(_ seconds: Double, _ fn: @escaping () -> Void) -> Int {
        nextTimer += 1
        timers.append(FlowTimer(id: nextTimer, at: t + seconds, fn: fn))
        return nextTimer
    }

    func cancelTimer(_ id: Int?) {
        guard let id else { return }
        timers.removeAll { $0.id == id }
    }

    private func runTimers() {
        guard timers.contains(where: { $0.at <= t }) else { return }
        let due = timers.filter { $0.at <= t }.sorted { $0.at < $1.at }
        timers.removeAll { $0.at <= t }
        let generation = clearings
        // A timer that changes the question clears the rest of the old question's timers.
        for timer in due where clearings == generation { timer.fn() }
    }

    // MARK: - The question (flSay)

    /// Shows `text` word by word at the spoken pace; `then` runs when the sentence is done.
    func say(_ text: String, then: (() -> Void)? = nil) {
        let reveal = FlowText.schedule(text)
        question = reveal.words.map(\.word)
        shown = 0
        for (index, word) in reveal.words.enumerated() {
            later(word.at) { [weak self] in self?.shown = max(self?.shown ?? 0, index + 1) }
        }
        later(reveal.total) { then?() }
    }

    // MARK: - Clearing between questions (flClear)

    func clear() {
        for child in Array(scene.children) { child.removeFromParent() }
        tick = nil; drag = nil; hit = nil; onSwipe = nil; onTap = nil; onSwipeDown = nil
        tweens = []; timers = []
        tweenMark = UUID()
        clearings += 1
        question = []; shown = 0
        labels = []
        dust = []; sparkles = []; squashes = [:]; hitSizes = [:]
        shaded.removeAll { $0.model.scene == nil }
        physics = nil
        stepSubscriptions = []
        resetStepUI()
    }

    // MARK: - The pan between questions (flPanTo, flGo)

    /// How far one point on screen is in the world, at the depth the camera looks at, and the camera's up.
    /// The questions whose object sits under the question (CHANGES-v2 §3).
    static let loweredSteps: Set<Step> = [.name, .unit, .bar, .prs, .prDial, .wod]
    /// How much lower the question sits than in the first handoff, in the prototype's points.
    static let questionDrop: Float = 150 - 92

    /// `view` seen 58 points lower on screen: the camera and its target moved up along the camera's own up by
    /// the world distance that 58 points cover at the target's depth (CHANGES-v2 §3).
    func lowered(_ view: FlowCam) -> FlowCam {
        let distance = simd_length(view.position - view.target)
        let shift = view.basis.up * (Self.questionDrop * 2 * distance * tan(view.fov * .pi / 360) / 844)
        var moved = view
        moved.position += shift
        moved.target += shift
        return moved
    }

    func panGeometry() -> (up: SIMD3<Float>, height: CGFloat, worldPerPoint: Float) {
        let basis = cam.basis
        let distance = simd_length(cam.position - cam.target)
        let height = max(1, viewSize.height)
        return (basis.up, height, 2 * distance * tan(cam.fov * .pi / 360) / Float(height))
    }

    /// Leaving a question: the camera travels down one screen (ease-in), then the next question is built one
    /// screen below and the camera settles onto it (ease-out), as one continuous move.
    func panTo(_ next: Step) {
        guard !panning else { return }
        var target = next
        // An edit opened from the gym room changes one thing, then goes straight back to the menu.
        if editOne && next != .menu && step != .prDial && step != .menu { target = .menu; mode = .menu }
        if direct { direct = false; go(target); return }
        panning = true
        hit = nil; onTap = nil; onSwipe = nil; onSwipeDown = nil; drag = nil
        physics?.grab = nil
        uiInteractive = false
        let height = panGeometry().height, grid0 = gridY
        anim(FlowPan.outDuration, { [weak self] u in
            guard let self else { return }
            let px = height * CGFloat(FlowPan.out(u))
            self.pan = px
            self.gridY = grid0 - px
        }, done: { [weak self] in
            guard let self else { return }
            self.panning = false
            self.panIn = grid0 - height
            self.go(target)
        })
    }

    /// Builds a question. Arriving from a pan, it starts one screen below and slides up into place.
    func go(_ next: Step) {
        clear()
        panning = false
        step = next
        pan = 0
        uiPan = 0
        uiInteractive = true
        applyStyle()
        let building = CACurrentMediaTime()
        defer { perf?.event("build \(next.rawValue)", ms: (CACurrentMediaTime() - building) * 1000) }
        switch next {
        case .name: stepName()
        case .unit: stepUnit()
        case .plates: stepPlates()
        case .bar: stepBar()
        case .prs: stepPRs()
        case .prDial: stepPRDial(0)
        case .wod: stepWod()
        case .kit: stepKit()
        case .sets: stepSets()
        case .done: stepDone()
        case .menu: stepMenu()
        }
        // v2: the question sits lower (150 points, was 92), so its object moves down by the same 58 (flQShift).
        if Self.loweredSteps.contains(next) { cam = lowered(cam) }
        fromMenu = false; fromKit = false
        panBack = (mode == .menu || mode == .gym) && [.wod, .prs, .name, .unit, .plates, .bar].contains(next)
        if let grid0 = panIn {
            panIn = nil
            let height = panGeometry().height
            let at: (Double) -> Void = { [weak self] u in
                guard let self else { return }
                let r = CGFloat(-FlowPan.into(u))
                self.pan = -height * r
                self.gridY = grid0 - height * (1 - r)
            }
            at(0)
            anim(FlowPan.inDuration, at, done: { [weak self] in
                guard let self else { return }
                self.pan = 0
                self.gridY = (self.gridY.truncatingRemainder(dividingBy: 26) + 26).truncatingRemainder(dividingBy: 26)
            })
        }
    }

    /// The step's default look, flipped by the user's toggles (flStyleFor, flApplyStyle): the kit and the sets are
    /// smooth on the light grid; everything else is rough on orange.
    func applyStyle() {
        let base = step == .kit || step == .sets
        alt = base != userBackground
        rough = !(base != userRough)
    }

    /// Ink on this background: light on orange, dark on the light grid (flInk).
    var ink: RGB { alt ? FlowLook.dark : FlowLook.light }
    var inkColor: Color { Color(rgb: ink) }

    func toggleRough() { userRough.toggle(); applyStyle(); successTicks += 1; checkSound() }
    func toggleBackground() { userBackground.toggle(); applyStyle(); successTicks += 1; checkSound() }

    // MARK: - The finger (flBindPointer, flPanBackBind)

    func pointerDown(_ point: CGPoint) {
        lastPoint = point
        // Nothing to touch while a photo is being read.
        if readingText != nil || photoRequest != nil { down = nil; drag = nil; panBackDrag = nil; return }
        touchID += 1
        down = (point, t)
        drag = nil
        if !panning, let hit, let found = hit(point) { drag = found }
        if panBack && drag == nil && !panning {
            panBackDrag = PanDrag(start: point, px: 0, grid0: gridY, on: false)
        } else {
            panBackDrag = nil
        }
    }

    func pointerMove(_ point: CGPoint) {
        lastPoint = point
        guard down != nil else { return }
        drag?.move?(point)
        if var back = panBackDrag, panBack {
            let dy = point.y - back.start.y, dx = point.x - back.start.x
            if !back.on {
                if -dy > FlowPan.startDistance && -dy > abs(dx) * 1.3 { back.on = true } else { panBackDrag = back; return }
            }
            back.px = max(0, -dy - FlowPan.startDistance)
            panBackDrag = back
            panLive(back)
        }
    }

    func pointerUp(_ point: CGPoint) {
        defer { down = nil }
        if let back = panBackDrag, back.on {
            panBackDrag = nil
            if FlowPan.commits(dragged: back.px) { panFinish(back) } else {
                let p0 = back.px
                anim(FlowPan.springBackDuration, { [weak self] u in
                    var b = back; b.px = FlowPan.springBack(from: p0, at: u); self?.panLive(b)
                })
            }
            drag = nil
            return
        }
        panBackDrag = nil
        guard let down else { return }
        let dx = point.x - down.point.x, dy = point.y - down.point.y
        let tap = hypot(dx, dy) < 8 && t - down.time < 0.45
        if let current = drag { drag = nil; current.up?(point, tap); return }
        if let onSwipe, dy < -55 && abs(dx) < abs(dy) { lightTicks += 1; onSwipe(); return }
        if let onSwipeDown, dy > 55 && abs(dx) < abs(dy) { lightTicks += 1; onSwipeDown(); return }
        if tap, let onTap { onTap(point) }
    }

    /// The system took the touch away (a call, Control Centre): finish it like a lift-off that isn't a tap.
    func pointerCancel() {
        // Asked when SwiftUI's touch state resets, which also happens at a normal lift-off: wait a turn, and only
        // finish a touch that onEnded didn't.
        let touch = touchID
        DispatchQueue.main.async { [weak self] in
            guard let self, self.touchID == touch, self.down != nil else { return }
            self.finishCancelled()
        }
    }

    private func finishCancelled() {
        let point = lastPoint
        if let back = panBackDrag, back.on {
            let p0 = back.px
            anim(FlowPan.springBackDuration, { [weak self] u in
                var b = back; b.px = FlowPan.springBack(from: p0, at: u); self?.panLive(b)
            })
        }
        panBackDrag = nil
        let current = drag
        drag = nil
        down = nil
        current?.up?(point, false)
    }
    @ObservationIgnored var lastPoint = CGPoint.zero
    @ObservationIgnored var touchID = 0

    func panLive(_ back: PanDrag) {
        pan = back.px
        gridY = back.grid0 - back.px
    }

    func panFinish(_ back: PanDrag) {
        let height = panGeometry().height, p0 = back.px
        panning = true
        hit = nil; onTap = nil; onSwipe = nil; panBack = false
        anim(FlowPan.finishDuration(from: p0, height: height), { [weak self] u in
            var b = back; b.px = FlowPan.finish(from: p0, height: height, at: u); self?.panLive(b)
        }, done: { [weak self] in
            guard let self else { return }
            self.panning = false
            self.checkSound()
            self.mode = .menu
            self.panIn = back.grid0 - height
            self.go(.menu)
        })
    }

    /// A swipe up that the step itself recognised (the plates checklist's stroke) goes back to the menu.
    func panBackGo() { panFinish(PanDrag(start: .zero, px: 0, grid0: gridY, on: true)) }

    // MARK: - Screen ↔ world

    /// A world point on the screen, in points (with the pan, as the prototype's labels).
    func project(_ p: SIMD3<Float>) -> CGPoint? {
        let c = liveCamera, basis = c.basis
        let v = p - c.position
        let z = simd_dot(v, basis.forward)
        guard z > 0.001 else { return nil }
        let f = 1 / tan(c.fov * .pi / 360), aspect = Float(viewSize.width / max(1, viewSize.height))
        let nx = simd_dot(v, basis.right) / z * f / aspect, ny = simd_dot(v, basis.up) / z * f
        return CGPoint(x: CGFloat((nx + 1) / 2) * viewSize.width, y: CGFloat((1 - ny) / 2) * viewSize.height)
    }

    /// The ray from the camera through a point on the screen.
    func ray(_ point: CGPoint) -> FlowRay {
        let c = liveCamera, basis = c.basis
        let tanHalf = tan(c.fov * .pi / 360), aspect = Float(viewSize.width / max(1, viewSize.height))
        let nx = Float(point.x / max(1, viewSize.width)) * 2 - 1, ny = 1 - Float(point.y / max(1, viewSize.height)) * 2
        let direction = simd_normalize(basis.forward + basis.right * (nx * tanHalf * aspect) + basis.up * (ny * tanHalf))
        return FlowRay(origin: c.position, direction: direction)
    }

    /// Where the ray through `point` meets the plane `normal · p = constant` (flPlane).
    func onPlane(_ point: CGPoint, normal: SIMD3<Float>, constant: Float) -> SIMD3<Float>? {
        let r = ray(point)
        let denominator = simd_dot(normal, r.direction)
        guard abs(denominator) > 1e-5 else { return nil }
        let distance = (constant - simd_dot(normal, r.origin)) / denominator
        return distance > 0 ? r.origin + r.direction * distance : nil
    }

    /// Does the finger at `point` touch `entity` or anything in it (models and hit boxes)?
    func touches(_ point: CGPoint, _ entity: Entity) -> Bool { hitDistance(ray(point), entity) != nil }

    func hitDistance(_ r: FlowRay, _ entity: Entity) -> Float? {
        guard entity.isEnabled else { return nil }
        var best: Float?
        func consider(_ d: Float?) { if let d, d < (best ?? .infinity) { best = d } }
        if let model = entity as? ModelEntity, let mesh = model.model?.mesh, entity.scale(relativeTo: nil).x > 0.001 {
            consider(Self.boxHit(r, entity, mesh.bounds.min, mesh.bounds.max))
        }
        if let size = hitSizes[ObjectIdentifier(entity)] {
            consider(Self.boxHit(r, entity, -size / 2, size / 2))
        }
        for child in entity.children { consider(hitDistance(r, child)) }
        return best
    }

    /// Ray against a box in an entity's own space.
    static func boxHit(_ r: FlowRay, _ entity: Entity, _ lo: SIMD3<Float>, _ hi: SIMD3<Float>) -> Float? {
        let inverse = entity.transformMatrix(relativeTo: nil).inverse
        let o4 = inverse * SIMD4(r.origin, 1), d4 = inverse * SIMD4(r.direction, 0)
        let o = SIMD3(o4.x, o4.y, o4.z), d = SIMD3(d4.x, d4.y, d4.z)
        var tMin: Float = 0, tMax: Float = .infinity
        for axis in 0..<3 {
            if abs(d[axis]) < 1e-8 {
                if o[axis] < lo[axis] || o[axis] > hi[axis] { return nil }
            } else {
                var t1 = (lo[axis] - o[axis]) / d[axis], t2 = (hi[axis] - o[axis]) / d[axis]
                if t1 > t2 { swap(&t1, &t2) }
                tMin = max(tMin, t1); tMax = min(tMax, t2)
                if tMin > tMax { return nil }
            }
        }
        // The map to local space is linear, so the ray's parameter is still the world distance.
        return tMin
    }

    // MARK: - Adding things (flAdd)

    @discardableResult
    func add(_ entity: Entity, to parent: Entity? = nil) -> Entity {
        (parent ?? scene).addChild(entity)
        return entity
    }

    /// popIn: grows from nothing with a little overshoot.
    func popIn(_ entity: Entity, delay: Double = 0, to size: Float = 1) {
        entity.scale = SIMD3(repeating: 0.0001)
        later(delay) { [weak self] in
            self?.anim(0.5) { u in entity.scale = SIMD3(repeating: max(0.0001, size * Float(Ease.outBack(u, 1.7)))) }
        }
    }

    /// The step's own observable UI goes back to nothing (each step file has its state).
    private func resetStepUI() {
        platesUI = nil
        prDialUI = nil
        kitUI = nil
        setsUI = nil
        menuUI = nil
        backgroundOverride = nil
        uiOpacity = 1
    }

    // Per-step UI states (each step's file defines what's in them).
    var platesUI: PlatesUI?
    var prDialUI: PRDialUI?
    var kitUI: KitUI?
    var setsUI: SetsUI?
    var menuUI: MenuUI?
}

// MARK: - Small types

struct FlowCam {
    var position: SIMD3<Float>
    var target: SIMD3<Float>
    var fov: Float

    /// Like three.js lookAt with up (0, 1, 0).
    var basis: (forward: SIMD3<Float>, right: SIMD3<Float>, up: SIMD3<Float>) {
        let forward = simd_normalize(target - position)
        var right = simd_cross(forward, [0, 1, 0])
        if simd_length(right) < 1e-5 { right = [1, 0, 0] }
        right = simd_normalize(right)
        return (forward, right, simd_cross(right, forward))
    }

    /// The camera's transform: RealityKit cameras look down −Z.
    var matrix: simd_float4x4 {
        let b = basis
        return simd_float4x4(SIMD4(b.right, 0), SIMD4(b.up, 0), SIMD4(-b.forward, 0), SIMD4(position, 1))
    }
}

struct FlowRay {
    let origin: SIMD3<Float>
    let direction: SIMD3<Float>

    func closestPoint(to p: SIMD3<Float>) -> SIMD3<Float> {
        origin + direction * max(0, simd_dot(p - origin, direction))
    }

    func distance(to p: SIMD3<Float>) -> Float { simd_length(p - closestPoint(to: p)) }
}

struct FlowDrag {
    var move: ((CGPoint) -> Void)?
    var up: ((CGPoint, Bool) -> Void)?
}

struct PanDrag {
    var start: CGPoint
    var px: CGFloat
    var grid0: CGFloat
    var on: Bool
}

final class FlowTween {
    let duration: Double
    var t = 0.0
    let fn: (Double) -> Void
    let done: (() -> Void)?

    init(duration: Double, fn: @escaping (Double) -> Void, done: (() -> Void)?) {
        self.duration = duration
        self.fn = fn
        self.done = done
    }
}

struct FlowTimer {
    let id: Int
    let at: Double
    let fn: () -> Void
}

struct FlowLabel: Identifiable, Equatable {
    let id: Int
    var text: String
    var point: CGPoint
    var opacity: Double
}

struct FlowAlert: Identifiable {
    struct Button {
        let label: String
        var destructive = false
        var action: (() -> Void)?
    }
    let id = UUID()
    let title: String
    let message: String
    let buttons: [Button]
}

struct FlowPhotoRequest: Identifiable {
    enum Kind { case workout, prs }
    let id = UUID()
    let kind: Kind
    let picked: (UIImage) -> Void
}

extension Color {
    init(rgb: RGB) { self.init(red: Double(rgb.r), green: Double(rgb.g), blue: Double(rgb.b)) }
}

extension RGB {
    var uiColor: UIColor { UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1) }
}

// MARK: - The sketch pass

/// The rough-edge pass (FlowSketch.metal). ARView runs it while it renders, so it keeps its own state.
nonisolated final class SketchPass: @unchecked Sendable {
    /// ARView calls these while it renders: made here, outside the main actor, so they aren't tied to it.
    static func callbacks(_ pass: SketchPass) -> (prepare: (MTLDevice) -> Void, post: (ARView.PostProcessContext) -> Void) {
        ({ device in pass.prepare(device) }, { context in pass.run(context) })
    }

    struct Params {
        var size: SIMD2<Float> = .zero
        var scale: Float = 3
        var on: Float = 1
        var ink: SIMD4<Float> = .zero
        var width: Float = 2.2
        var rough: Float = 5
        var freq: Float = 0.03
        var grain: Float = 0.4
        var seed: Float = 0
        var pad0: Float = 0, pad1: Float = 0, pad2: Float = 0
    }

    private let lock = NSLock()
    private var pipeline: MTLComputePipelineState?
    private var _on = true
    private var _pointsWide: Float = 393

    var on: Bool {
        get { lock.withLock { _on } }
        set { lock.withLock { _on = newValue } }
    }

    var pointsWide: Float {
        get { lock.withLock { _pointsWide } }
        set { lock.withLock { _pointsWide = newValue } }
    }

    func prepare(_ device: MTLDevice) {
        guard let library = device.makeDefaultLibrary(), let function = library.makeFunction(name: "flowSketch") else { return }
        pipeline = try? device.makeComputePipelineState(function: function)
    }

    func run(_ context: ARView.PostProcessContext) {
        let source = context.sourceColorTexture, target = context.targetColorTexture
        guard let pipeline, let encoder = context.commandBuffer.makeComputeCommandEncoder() else {
            if let blit = context.commandBuffer.makeBlitCommandEncoder() {
                blit.copy(from: source, to: target)
                blit.endEncoding()
            }
            return
        }
        var params = Params()
        params.size = [Float(target.width), Float(target.height)]
        params.scale = Float(target.width) / max(1, pointsWide)
        params.on = on ? 1 : 0
        // The ink in the texture's own space: display values for plain 8-bit formats, linear for sRGB and float.
        let displayEncoded: Set<MTLPixelFormat> = [.bgra8Unorm, .rgba8Unorm, .bgra10_xr, .bgr10_xr, .rgb10a2Unorm]
        let dark = FlowLook.dark
        params.ink = displayEncoded.contains(target.pixelFormat) ? SIMD4(dark.r, dark.g, dark.b, 1) : SIMD4(dark.linear, 1)
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(target, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<Params>.stride, index: 0)
        let w = pipeline.threadExecutionWidth, h = max(1, pipeline.maxTotalThreadsPerThreadgroup / w)
        encoder.dispatchThreads(MTLSize(width: target.width, height: target.height, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: w, height: h, depth: 1))
        encoder.endEncoding()
    }
}
