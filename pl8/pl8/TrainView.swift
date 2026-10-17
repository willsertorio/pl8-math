import SwiftData
import SwiftUI

/// Train tab (SPEC 2.4): today's whiteboard, or "Add today's workout".
struct TrainView: View {
    private enum TrainSheet: Identifiable {
        case add
        case ready(Workout)

        var id: String {
            switch self {
            case .add: "add"
            case .ready(let workout): workout.id.uuidString
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query private var gyms: [Gym]
    @Query private var records: [PersonalRecord]
    @AppStorage("hasFinishedFirstRun") private var hasFinishedFirstRun = true
    @AppStorage("didSeedDefaults") private var didSeedDefaults = true
    @State private var confirmReplay = false
    @State private var sheet: TrainSheet?
    @State private var activeSession: Session?

    private var today: Workout? {
        workouts.first { Calendar.current.isDateInToday($0.date) }
    }

    private var gym: Gym? { gyms.first { $0.isCurrent } ?? gyms.first }

    /// Today's session that isn't finished yet, to resume.
    private func unfinishedSession(of workout: Workout) -> Session? {
        workout.sessions.first { $0.endedAt == nil }
    }

    private func start(_ workout: Workout) {
        guard let gym else { return }
        let blocks = workout.blocks
        let plan = Planner.plan(blocks: blocks, gym: gym, records: records)
        activeSession = Session.start(workout: workout, plan: plan, prLifts: Planner.prLifts(blocks: blocks),
                                      gym: gym, in: context)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let today {
                        Whiteboard(blocks: today.blocks, title: "Today")
                        if let session = unfinishedSession(of: today) {
                            Button("Resume session") { activeSession = session }
                                .buttonStyle(.bigBlack)
                        } else {
                            Button("Start training") { sheet = .ready(today) }
                                .buttonStyle(.bigBlack)
                        }
                        Button("Add a different workout") { sheet = .add }
                            .buttonStyle(.black)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today").font(Theme.heading)
                            Button("Add today's workout") { sheet = .add }
                                .buttonStyle(.bigBlack)
                        }
                        .drawer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        NavigationLink("Test screen") { PlateCalculatorView() }
                        NavigationLink("3D test (M5)") { Spike3DView() }
                        NavigationLink("3D room (M6)") { Room3DView() }
                        Button("Replay the first run") { confirmReplay = true }
                            .confirmationDialog("Replay the first run?", isPresented: $confirmReplay, titleVisibility: .visible) {
                                Button("Erase everything and replay", role: .destructive) {
                                    // A clean start: no gym, PRs, workouts or history left from before.
                                    DataCleanup.eraseEverything(in: context)
                                    didSeedDefaults = false
                                    hasFinishedFirstRun = false
                                }
                            } message: {
                                Text("Your gym, PRs, workouts and history are deleted.")
                            }
                    }
                    .font(.subheadline.weight(.semibold))
                    .tint(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Train")
            .navigationDestination(item: $activeSession) { session in
                SessionView(session: session) { activeSession = nil }
            }
            .sheet(item: $sheet) { item in
                switch item {
                case .add:
                    AddWorkoutSheet { workout in sheet = .ready(workout) }
                case .ready(let workout):
                    ReadyToLiftSheet(workout: workout) { workout in
                        sheet = nil
                        start(workout)
                    }
                }
            }
        }
    }
}
