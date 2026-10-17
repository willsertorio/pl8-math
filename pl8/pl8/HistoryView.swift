import SwiftData
import SwiftUI
import PlateKit

/// History tab: saved sessions, newest first → detail.
struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Session.createdAt, order: .reverse) private var sessions: [Session]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RoomHeader(station: .overview)
                Group {
                    if sessions.isEmpty {
                        ContentUnavailableView("No sessions yet", systemImage: "clock")
                    } else {
                        List {
                            ForEach(sessions) { session in
                                NavigationLink {
                                    SessionDetailView(session: session)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.headline)
                                        Text(summary(session))
                                            .font(.subheadline)
                                            .foregroundStyle(Theme.ink)
                                    }
                                }
                                .listRowBackground(Theme.paper)
                            }
                            .onDelete { offsets in
                                for index in offsets { context.delete(sessions[index]) }
                                try? context.save()
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .background(Theme.background)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// "MY BOX · Back Squat · top 180 lb"
    private func summary(_ session: Session) -> String {
        var parts = [session.gymName] + session.liftNames
        if let top = session.heaviestTotal {
            parts.append("top \(WeightUnit.trimmed(top)) \(session.gymUnit.rawValue)")
        }
        return parts.joined(separator: " · ")
    }
}
