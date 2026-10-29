import SwiftData
import SwiftUI
import PlateKit

/// The app (SPEC 2.0): the opening on every launch, then the Flow — the first run's questions, or the menu once
/// you've lifted.
struct RootView: View {
    @Environment(\.modelContext) private var context
    /// Default data is created once, so deleting it doesn't bring it back.
    @AppStorage("didSeedDefaults") private var didSeedDefaults = false
    @State private var opened = false

    var body: some View {
        Group {
            if opened {
                FlowRoot(start: FlowRoot.startStep(context))
                    .transition(.opacity)
            } else {
                // The opening plays on every launch for now (SPEC open decision 2). Tap → the Flow.
                FlowOpening { withAnimation(.easeInOut(duration: 0.35)) { opened = true } }
            }
        }
        .task {
            seedIfNeeded()
            DataCleanup.mergeDuplicatePRs(in: context)
        }
    }

    /// The default PR list with no values (SPEC Part 4). The gym is made by the Flow.
    private func seedIfNeeded() {
        guard !didSeedDefaults else { return }
        let existing = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        for lift in LiftNames.defaultPRLifts where Planner.record(for: lift, in: existing) == nil {
            context.insert(PersonalRecord(lift: lift))
        }
        try? context.save()
        didSeedDefaults = true
    }
}

/// The Flow's opening (prototype closeOpening): the title over the orange; a tap starts the questions.
struct FlowOpening: View {
    var onDone: () -> Void

    var body: some View {
        OpeningTitle()
            .contentShape(Rectangle())
            .onTapGesture { onDone() }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("pl8(math). Tap to start")
    }
}

/// Holds the Flow for the app's lifetime and starts it at the right question.
struct FlowRoot: View {
    let start: Flow.Step
    var configure: (Flow) -> Void = { _ in }
    @Environment(\.modelContext) private var context
    @State private var flow: Flow?

    var body: some View {
        ZStack {
            Color(rgb: FlowLook.orange).ignoresSafeArea()
            if let flow { FlowView(flow: flow) }
        }
        .task {
            guard flow == nil else { return }
            let made = Flow(data: FlowData(context: context))
            flow = made
            // The stage needs its size before the first question frames its camera.
            try? await Task.sleep(for: .milliseconds(50))
            made.mode = start == .menu ? .menu : .firstRun
            made.again = start == .menu || UserDefaults.standard.bool(forKey: Flow.liftedKey)
            configure(made)
            made.go(start)
        }
    }

    /// Where a launch starts: the menu once a session has been lifted (here or with the screens before the Flow),
    /// the workout once the gym is set up, otherwise the first question.
    static func startStep(_ context: ModelContext) -> Flow.Step {
        var ended = FetchDescriptor<Session>(predicate: #Predicate { $0.endedAt != nil })
        ended.fetchLimit = 1
        if UserDefaults.standard.bool(forKey: Flow.liftedKey) || ((try? context.fetchCount(ended)) ?? 0) > 0 { return .menu }
        if UserDefaults.standard.bool(forKey: Flow.setUpKey) { return .wod }
        return .name
    }
}
