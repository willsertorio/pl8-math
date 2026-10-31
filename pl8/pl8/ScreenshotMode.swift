import Foundation
import SwiftData
import SwiftUI
import UIKit
import PlateKit

/// For the automatic checks (.github/workflows/ci.yml): launched with `-pl8Shot <screen>`, the app fills an
/// in-memory store with demo data and opens that one screen, so the Simulator can take its picture.
/// Screens: `room-<station>` (overview, corner, nameFlag, flag, bar, pr, board, kit, setv), `firstrun-name`,
/// `firstrun-plates`, `session` (the kit), `session-sets` (the first set), `session-pull` (a deadlift set, bar on the floor), `opening-title`, `opening-box` (the closed
/// box), `session-over` (the scale), `session-over-drag` (its bar and top plate pulled off), `home`, `tab-<train|prs|gym|history>` (home with that drawer open).
enum ScreenshotMode {
    static let shot: String? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-pl8Shot"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }()
}

struct ScreenshotHost: View {
    let shot: String
    @Environment(\.modelContext) private var context
    @State private var session: Session?
    @State private var seeded = false
    @State private var scaleStage = ScaleStage()

    var body: some View {
        Group {
            if !seeded {
                Theme.background.ignoresSafeArea()
            } else if shot.hasPrefix("flow-") {
                FlowRoot(start: Self.flowStart(shot), configure: { Self.configure($0, shot: shot) })
            } else if shot.hasPrefix("room-"), let station = RoomLayout.Station(rawValue: String(shot.dropFirst(5))) {
                NavigationStack { Room3DView(station: station) }
            } else if shot == "opening-title" {
                FirstRunView(startAt: .opening) {}
            } else if shot == "opening-box" {
                FirstRunView(startAt: .opening, openingAt: .closed) {}
            } else if shot == "home" {
                HomeView()
            } else if shot.hasPrefix("tab-"), let tab = HomeView.Tab(rawValue: String(shot.dropFirst(4))) {
                HomeView(open: tab)
            } else if shot == "session-over" || shot == "session-over-drag" {
                SessionOverView(perSide: [25, 20, 2.5], unit: .kg, barWeight: 20, stage: scaleStage) {}
                    .task { if shot == "session-over-drag" { await Self.dragScale(scaleStage) } }
            } else if shot == "firstrun-name" {
                FirstRunView(startAt: .name) {}
            } else if shot == "firstrun-plates" {
                FirstRunView(startAt: .plates) {}
            } else if shot.hasPrefix("session"), let session {
                NavigationStack { SessionView(session: session, startOnFirstSet: shot != "session") {} }
            } else {
                Text("Unknown screen: \(shot)")
            }
        }
        .task {
            seed()
            seeded = true
        }
    }

    /// The Flow's screens (SPEC 2.0): `flow-<step>`, plus states — `flow-plates-ticked`, `flow-sets-last`,
    /// `flow-menu-<train|prs|gym>` (that item awake), `flow-menu-at-<prs|gym>` (at rest on it).
    static func flowStart(_ shot: String) -> Flow.Step {
        let name = String(shot.dropFirst(5)).components(separatedBy: "-").first ?? ""
        if name == "prDial" { return .prDial }
        if name == "reading" { return .wod }
        if name.hasPrefix("menu") { return .menu }
        if name.hasPrefix("sets") { return .sets }
        if name.hasPrefix("plates") { return .plates }
        return Flow.Step(rawValue: name) ?? .name
    }

    static func configure(_ flow: Flow, shot: String) {
        flow.perf = FlowPerf()
        if [.kit, .sets, .done].contains(flowStart(shot)) {
            flow.plan = flow.data.startSession()
            flow.lastPlan = flow.plan
        }
        if shot == "flow-sets-last", let plan = flow.plan {
            flow.setIndex = plan.sets.count - 1
            flow.doneSets = Set(0..<(plan.sets.count - 1))
        }
        // An empty board, so a tap asks for a screenshot (flow-wod-unread).
        if shot == "flow-wod-unread" { flow.data.wipeBoard() }
        if shot.hasPrefix("flow-menu-") { flow.menuActive = ["back": "prs", "delete": "gym", "add": "gym"][String(shot.dropFirst(10))] ?? String(shot.dropFirst(10)) }
        // The menu at rest on My PRs or the gym, nothing awake; or just opened, the board rolling in.
        if let at = ["flow-menu-at-prs": Float(1), "flow-menu-at-gym": 2, "flow-menu-roll": 0][shot] {
            flow.menuPosition = at
            flow.menuActive = nil
        }
        script(flow, shot: shot)
        if shot == "flow-plates-ticked" {
            Task { @MainActor in
                while flow.t < 3.5 { try? await Task.sleep(for: .milliseconds(15)) }
                for (row, yes) in [true, true, false, true, true, false, true].enumerated() { flow.debugDecide?(row * 2 + (yes ? 0 : 1)) }
            }
        }
    }

    /// Gestures replayed by a script, so the CI sees the interactions work: `flow-name-locked` (both dials tapped →
    /// the units question), `flow-unit-abduct` (KG dropped on the scale, frozen mid-abduction), `flow-plates-stroke`
    /// (a stroke down the YES column, held), `flow-plates-done` (released → the bar question),
    /// `flow-kit-down` / `flow-kit-up` (drag previews, held), `flow-sets-drag` (the card half-way to the next set),
    /// `flow-menu-back` (an awake item pulled half-way back), `flow-menu-delete` (holding the gym → the alert),
    /// `flow-wod-unread` / `flow-prs-unread` (a screenshot that can't be read → question marks).
    static func script(_ flow: Flow, shot: String) {
        // Times are on the Flow's own clock: the CI's Simulator draws slowly, so its clock runs behind the wall's.
        func at(_ seconds: Double, _ action: @escaping @MainActor () -> Void) {
            Task { @MainActor in
                while flow.t < seconds { try? await Task.sleep(for: .milliseconds(15)) }
                action()
            }
        }
        /// A finger drag from a to b over `duration`, then still for `hold`, released or held.
        func drag(_ a: @escaping @MainActor () -> CGPoint, by delta: CGPoint, at start: Double, duration: Double = 0.6,
                  hold: Double = 0, release: Bool) {
            at(start) {
                let from = a(), t0 = flow.t
                flow.pointerDown(from)
                Task { @MainActor in
                    var last = 0.0
                    while last < 1 {
                        try? await Task.sleep(for: .milliseconds(15))
                        last = min(1, (flow.t - t0) / duration)
                        flow.pointerMove(CGPoint(x: from.x + delta.x * CGFloat(last), y: from.y + delta.y * CGFloat(last)))
                    }
                    let end = CGPoint(x: from.x + delta.x, y: from.y + delta.y)
                    while flow.t < t0 + duration + hold { try? await Task.sleep(for: .milliseconds(15)) }
                    if release { flow.pointerUp(end) }
                }
            }
        }
        func tap(_ p: @escaping @MainActor () -> CGPoint, at time: Double) {
            at(time) { let q = p(); flow.pointerDown(q); flow.pointerUp(q) }
        }
        let project = { (p: SIMD3<Float>) in flow.project(p) ?? .zero }
        switch shot {
        case "flow-name-locked":
            tap({ project([-0.62, -0.45, 0.95]) }, at: 3.0)
            tap({ project([0.62, -0.45, 0.95]) }, at: 3.6)
        case "flow-unit-abduct":
            // KG picked up and carried over the scale (the finger aims at the carrying height), held still, let go,
            // then frozen a second later, like the prototype's 02b.
            at(5.0) {
                let from = project([-0.95, 0.39, -0.55]), to = project([0, 0.94, 1.55])
                drag({ from }, by: CGPoint(x: to.x - from.x, y: to.y - from.y), at: 0, duration: 0.6, hold: 0.4, release: true)
            }
            at(7.0) { flow.frozen = true }
        case "flow-plates-stroke", "flow-plates-done":
            // Down the YES column from the first row's middle (the rows run 272–800 since v2).
            let from = { flow.screen(262, 272 + 528 / 10 * 0.5) }
            drag(from, by: CGPoint(x: 0, y: 528 * 0.9 * flow.layoutScale), at: 3.5, duration: 1.0, release: shot == "flow-plates-done")
            if shot == "flow-plates-stroke" { at(4.6) { flow.frozen = true } }
        case "flow-kit-down", "flow-kit-up":
            // As far as the prototype's 07c / 07d: 200 points down, 260 up.
            let down = shot == "flow-kit-down"
            drag({ flow.screen(195, down ? 150 : 600) }, by: CGPoint(x: 0, y: (down ? 200 : -260) * flow.layoutScale), at: 4.0,
                 duration: 0.5, release: false)
            at(4.7) { flow.frozen = true }
        case "flow-sets-drag":
            drag({ flow.screen(195, 300) }, by: CGPoint(x: 0, y: -120 * flow.layoutScale), at: 2.0, duration: 0.5, release: false)
            at(2.7) { flow.frozen = true }
        case "flow-menu-back":
            drag({ flow.screen(195, 600) }, by: CGPoint(x: 0, y: -160 * flow.layoutScale), at: 2.0, duration: 0.5, release: false)
            at(2.7) { flow.frozen = true }
        case "flow-menu-add":
            // Swiped along the row of gyms to its last slot, the empty one to tap for a new gym.
            drag({ project([0, 0.5, 0]) }, by: CGPoint(x: -220 * flow.layoutScale, y: 0), at: 2.5, duration: 0.4, release: true)
        case "flow-menu-roll":
            at(0.5) { flow.frozen = true }
        case "flow-reading":
            // The loader over the board, as after picking a workout's screenshot.
            at(2.0) { flow.readingText = "Reading your workout…" }
        case "flow-menu-delete":
            at(2.0) { flow.pointerDown(project([0, 0.5, 0])) }
        case "flow-wod-unread", "flow-prs-unread":
            // The empty board (or the open notebook) tapped, and a picture with nothing to read handed in as if picked
            // (before the picker can show): question marks on the board or the page.
            let wod = shot == "flow-wod-unread"
            at(wod ? 4.0 : 4.5) {
                let q = project(wod ? [0, 1.23, 0] : [0.3, 0.2, 0])
                flow.pointerDown(q)
                flow.pointerUp(q)
                guard let request = flow.photoRequest else { return }
                flow.photoRequest = nil
                request.picked(UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { context in
                    UIColor.white.setFill()
                    context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
                })
            }
        default:
            break
        }
    }

    /// `session-over-drag`: once the scale's things can be grabbed, the bar flung off to the side (it falls away),
    /// then the top plate lifted and held in the air: the screen reads what's left on the platform (92.5).
    static func dragScale(_ stage: ScaleStage) async {
        while !stage.draggable { try? await Task.sleep(for: .milliseconds(50)) }
        try? await Task.sleep(for: .seconds(1))
        func pull(_ index: Int, by delta: CGPoint, steps: Int, release: Bool) async {
            guard let from = stage.screenPoint(ofDrop: index), stage.grab(at: from) else { return }
            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(20))
                let u = CGFloat(step) / CGFloat(steps)
                stage.drag(to: CGPoint(x: from.x + delta.x * u, y: from.y + delta.y * u))
            }
            if release { stage.release() }
        }
        let bar = 6, topPlate = 5
        await pull(bar, by: CGPoint(x: -340, y: -60), steps: 15, release: true)
        try? await Task.sleep(for: .seconds(2))
        await pull(topPlate, by: CGPoint(x: -90, y: -190), steps: 30, release: false)
    }

    /// Gym "79" in kg with every plate and the 20 kg bar, four PRs, and today's workout (Fixtures 01/10).
    private func seed() {
        let gym = Gym(name: "79", unit: .kg)
        context.insert(gym)
        for (lift, value) in [("Back Squat", 120.0), ("Snatch", 75), ("Clean", 95), ("Deadlift", 170)] {
            let record = PersonalRecord(lift: lift)
            context.insert(record)
            record.update(value: value, unit: .kg)
        }
        let text = shot == "session-pull" ? """
        A. Deadlift
        3 Deadlift @75% 1RM Deadlift
        3 Deadlift @80% 1RM Deadlift
        """ : """
        A. Back Squat
        3 Back Squat @75-78% 1RM Back Squat
        3 Back Squat @75-78% 1RM Back Squat
        3 Back Squat @78-80% 1RM Back Squat
        3 Back Squat @78-80% 1RM Back Squat
        3 Back Squat @80%+ 1RM Back Squat
        """
        let blocks = WorkoutParser.parse(text)
        let workout = Workout(sourceText: text, blocks: blocks)
        context.insert(workout)
        try? context.save()
        if shot.hasPrefix("session") {
            let records = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
            let plan = Planner.plan(blocks: blocks, gym: gym, records: records)
            session = Session.start(workout: workout, plan: plan, prLifts: Planner.prLifts(blocks: blocks), gym: gym, in: context)
        }
    }
}
