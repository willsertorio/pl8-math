import SwiftData
import SwiftUI
import PlateKit

/// Home: Train · PRs · Gym · History (SPEC 2.4).
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var gyms: [Gym]
    /// Default data is created once, so deleting it doesn't bring it back.
    @AppStorage("didSeedDefaults") private var didSeedDefaults = false
    @AppStorage("hasFinishedFirstRun") private var hasFinishedFirstRun = false

    var body: some View {
        Group {
            if hasFinishedFirstRun {
                HomeTabs()
            } else {
                FirstRunView { hasFinishedFirstRun = true }
            }
        }
        .onChange(of: hasFinishedFirstRun) { seedIfNeeded() }
        .task {
            RoomTemplate.warmUp()                     // the room's bake starts at launch, before the first stage needs it
            seedIfNeeded()
            DataCleanup.mergeDuplicatePRs(in: context)
        }
    }

    /// One unnamed gym with every plate (named in the first run) and the default PR list with no values (SPEC Part 4).
    private func seedIfNeeded() {
        guard !didSeedDefaults else { return }
        if gyms.isEmpty {
            context.insert(Gym(name: "", unit: .lb))
        }
        let existing = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        for lift in LiftNames.defaultPRLifts where Planner.record(for: lift, in: existing) == nil {
            context.insert(PersonalRecord(lift: lift))
        }
        try? context.save()
        didSeedDefaults = true
    }
}

/// The four tabs, each with the room on top looking at its station.
struct HomeTabs: View {
    enum Tab: String { case train, prs, gym, history }
    @State var selection: Tab = .train

    var body: some View {
        TabView(selection: $selection) {
            TrainView()
                .tabItem { Label("Train", systemImage: "figure.strengthtraining.traditional") }
                .tag(Tab.train)
            PRsView()
                .tabItem { Label("PRs", systemImage: "trophy") }
                .tag(Tab.prs)
            GymView()
                .tabItem { Label("Gym", systemImage: "dumbbell") }
                .tag(Tab.gym)
            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
                .tag(Tab.history)
        }
        .tint(Theme.ink)
    }
}
