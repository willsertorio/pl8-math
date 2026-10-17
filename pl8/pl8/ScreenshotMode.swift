import Foundation
import SwiftData
import SwiftUI
import PlateKit

/// For the automatic checks (.github/workflows/ci.yml): launched with `-pl8Shot <screen>`, the app fills an
/// in-memory store with demo data and opens that one screen, so the Simulator can take its picture.
/// Screens: `room-<station>` (overview, corner, nameFlag, flag, bar, pr, board, kit, setv), `firstrun-name`,
/// `firstrun-plates`, `session` (the kit), `session-sets` (the first set), `session-pull` (a deadlift set, bar on the floor), `opening-title`, `opening-box` (the closed
/// box), `session-over` (the scale), `home`, `tab-<train|prs|gym|history>` (home with that drawer open).
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

    var body: some View {
        Group {
            if !seeded {
                Theme.background.ignoresSafeArea()
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
            } else if shot == "session-over" {
                SessionOverView(perSide: [25, 20, 2.5], unit: .kg, barWeight: 20) {}
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
