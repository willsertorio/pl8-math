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
    @State private var openedThisLaunch = false

    var body: some View {
        Group {
            if hasFinishedFirstRun {
                if openedThisLaunch {
                    HomeView()
                } else {
                    // The opening plays on every launch for now (SPEC open decision 2).
                    OpeningScreen { withAnimation(.easeInOut(duration: 0.4)) { openedThisLaunch = true } }
                }
            } else {
                FirstRunView {
                    openedThisLaunch = true            // it just played the opening
                    hasFinishedFirstRun = true
                }
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
