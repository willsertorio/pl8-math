import SwiftData
import SwiftUI
import PlateKit

/// Home: Train · PRs · Gym · History (SPEC 2.4).
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var gyms: [Gym]
    /// Default data is created once, so deleting it doesn't bring it back.
    @AppStorage("didSeedDefaults") private var didSeedDefaults = false

    var body: some View {
        TabView {
            TrainView()
                .tabItem { Label("Train", systemImage: "figure.strengthtraining.traditional") }
            PRsView()
                .tabItem { Label("PRs", systemImage: "trophy") }
            GymView()
                .tabItem { Label("Gym", systemImage: "dumbbell") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
        }
        .tint(Theme.ink)
        .task { seedIfNeeded() }
    }

    /// One gym with every plate and the default PR list with no values (SPEC Part 4).
    private func seedIfNeeded() {
        guard !didSeedDefaults else { return }
        if gyms.isEmpty {
            context.insert(Gym(name: "MY BOX", unit: .lb))
        }
        let existing = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        for lift in LiftNames.defaultPRLifts where !existing.contains(where: { $0.lift == lift }) {
            context.insert(PersonalRecord(lift: lift))
        }
        try? context.save()
        didSeedDefaults = true
    }
}
