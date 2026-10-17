import SwiftData
import SwiftUI
import PlateKit

/// The room on top of a tab (SPEC 2.1, 2.4): it looks at that tab's station and shows your gym, PRs and today's
/// workout live. Drag to go round, pinch to zoom. Every header shares one bake of the room (`RoomTemplate`).
struct RoomHeader: View {
    let station: RoomLayout.Station

    @Query private var gyms: [Gym]
    @Query private var records: [PersonalRecord]
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    private var gym: Gym? { gyms.first(where: { $0.isCurrent }) ?? gyms.first }

    private var boards: Boards {
        let today = workouts.first { Calendar.current.isDateInToday($0.date) }
        return Boards(prs: Planner.boardRows(records), workout: Planner.boardLines(for: today, gym: gym, records: records))
    }

    var body: some View {
        RoomStage(station: station, gymName: gym?.name ?? "", unit: gym?.unit ?? .kg,
                  plateSizes: gym?.plateSizes ?? [], barWeight: gym?.barWeight ?? 20, boards: boards, interactive: true)
            .containerRelativeFrame(.vertical) { length, _ in length * 0.4 }
            .clipped()
    }
}
