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

    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @AppStorage("hasFinishedFirstRun") private var hasFinishedFirstRun = true
    @State private var sheet: TrainSheet?
    @State private var started: Workout?

    private var today: Workout? {
        workouts.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let today {
                        Whiteboard(blocks: today.blocks, title: "Today")
                        Button("Start training") { sheet = .ready(today) }
                            .buttonStyle(.bigBlack)
                        Button("Add a different workout") { sheet = .add }
                            .buttonStyle(.black)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today").font(Theme.heading)
                            Text("No workout yet. Scan the whiteboard, upload a screenshot, or type it in.")
                                .foregroundStyle(.secondary)
                            Button("Add today's workout") { sheet = .add }
                                .buttonStyle(.bigBlack)
                        }
                        .drawer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        NavigationLink("Test screen") { PlateCalculatorView() }
                        Button("Replay the first run") { hasFinishedFirstRun = false }
                    }
                    .font(.subheadline.weight(.semibold))
                    .tint(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Train")
            .navigationDestination(item: $started) { workout in
                PlanView(workout: workout)
            }
            .sheet(item: $sheet) { item in
                switch item {
                case .add:
                    AddWorkoutSheet { workout in sheet = .ready(workout) }
                case .ready(let workout):
                    ReadyToLiftSheet(workout: workout) { workout in
                        sheet = nil
                        started = workout
                    }
                }
            }
        }
    }
}
