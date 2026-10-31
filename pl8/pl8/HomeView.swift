import SwiftData
import SwiftUI
import UIKit
import PlateKit

/// Home (SPEC 2.4), like the prototype's showHome: the whole room on the screen, floating a little, with a tab bar
/// below. A tab opens its drawer over the room and the camera flies to its station: Train → the whiteboard,
/// PRs → the PR board, Gym → the plate shelf, History → the flag.
struct HomeView: View {
    enum Tab: String, CaseIterable { case train, prs, gym, history }

    @State var open: Tab?

    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query private var gyms: [Gym]
    @Query private var records: [PersonalRecord]
    @State private var activeSession: Session?
    @State private var drawerHeight: CGFloat = 0
    @State private var keyboardHeight: CGFloat = 0
    @State private var picks = 0

    private var gym: Gym? { Gym.current(in: gyms) }
    private var today: Workout? { workouts.first { Calendar.current.isDateInToday($0.date) } }

    private var station: RoomLayout.Station {
        switch open {
        case nil: .overview
        case .train: .board
        case .prs: .pr
        case .gym: .corner
        case .history: .flag
        }
    }

    private var boards: Boards {
        Boards(prs: Planner.boardRows(records), workout: Planner.boardLines(for: today, gym: gym, records: records))
    }

    var body: some View {
        if let session = activeSession {
            SessionView(session: session) {
                withAnimation(.easeInOut(duration: 0.35)) { activeSession = nil; open = nil }
            }
            .transition(.opacity)
        } else {
            home
        }
    }

    private var home: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()
            // The room fills what the drawer leaves free, a little behind its rough top edge.
            GeometryReader { geometry in
                RoomStage(station: station, gymName: gym?.name ?? "", unit: gym?.unit ?? .kg,
                          plateSizes: gym?.plateSizes ?? [], barWeight: gym?.barWeight ?? 20, boards: boards,
                          interactive: open == nil, floating: open == nil, tiltable: true)
                    .frame(height: open == nil
                           ? geometry.size.height
                           : max(220, geometry.size.height - drawerHeight - max(keyboardHeight, Self.bottomInset) + 24))
            }
            .ignoresSafeArea()

            Group {
                if let open {
                    drawer(open)
                        .transition(.move(edge: .bottom))
                } else {
                    TabBar { pick($0) }
                        .transition(.move(edge: .bottom))
                }
            }
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { drawerHeight = $0 }
        }
        .sensoryFeedback(.selection, trigger: picks)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            withAnimation(.snappy) { keyboardHeight = max(0, UIScreen.main.bounds.height - frame.minY) }
        }
    }

    static var bottomInset: CGFloat {
        let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.keyWindow
        return window?.safeAreaInsets.bottom ?? 34
    }

    private func pick(_ tab: Tab?) {
        picks += 1
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { open = tab }
    }

    @ViewBuilder
    private func drawer(_ tab: Tab) -> some View {
        switch tab {
        case .train:
            TrainDrawer(today: today, onBack: { pick(nil) }, onStart: start, onResume: { activeSession = $0 })
        case .prs:
            Drawer(back: { pick(nil) }, action: "Done", onAction: { pick(nil) }) {
                PRList()
            }
        case .gym:
            Drawer(back: { pick(nil) }, action: "Done", onAction: { pick(nil) }, maxHeight: 600) {
                GymDrawerContent()
            }
        case .history:
            Drawer(back: { pick(nil) }) {
                HistoryList()
            }
        }
    }

    private func start(_ workout: Workout) {
        guard let gym else { return }
        let blocks = workout.blocks
        let plan = Planner.plan(blocks: blocks, gym: gym, records: records)
        let session = Session.start(workout: workout, plan: plan, prLifts: Planner.prLifts(blocks: blocks), gym: gym, in: context)
        withAnimation(.easeInOut(duration: 0.35)) { activeSession = session }
    }
}

/// The prototype's tab bar: white with a rough top edge, an icon and a label per tab.
struct TabBar: View {
    var pick: (HomeView.Tab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HomeView.Tab.allCases, id: \.self) { tab in
                Button { pick(tab) } label: {
                    VStack(spacing: 4) {
                        ProtoIcon(kind: icon(tab)).frame(width: 26, height: 26)
                        Text(title(tab)).font(Theme.display(13))
                    }
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .padding(.top, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(title(tab))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .background(RoughRectangle().fill(Theme.paper).padding(.bottom, -60).ignoresSafeArea(edges: .bottom))
    }

    private func title(_ tab: HomeView.Tab) -> String {
        switch tab {
        case .train: "Train"
        case .prs: "PRs"
        case .gym: "Gym"
        case .history: "History"
        }
    }

    private func icon(_ tab: HomeView.Tab) -> ProtoIcon.Kind {
        switch tab {
        case .train: .train
        case .prs: .prs
        case .gym: .gym
        case .history: .history
        }
    }
}

/// Train: today's workout is on the whiteboard → "Ready to lift?"; none yet → "Add today's workout".
struct TrainDrawer: View {
    let today: Workout?
    var onBack: () -> Void
    var onStart: (Workout) -> Void
    var onResume: (Session) -> Void

    var body: some View {
        Drawer(back: onBack) {
            if let today {
                ReadyToLift(workout: today, onStart: onStart, onResume: onResume)
            } else {
                WorkoutChooser()
            }
        }
    }
}

/// History: the saved sessions, newest first; tap one for its detail.
struct HistoryList: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Session.createdAt, order: .reverse) private var sessions: [Session]
    @State private var showing: Session?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DrawerHeading(text: "History")
            if sessions.isEmpty {
                ListRow(label: "No sessions yet")
            }
            ForEach(sessions) { session in
                Button { showing = session } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.createdAt.formatted(date: .abbreviated, time: .shortened)).font(Theme.text(17))
                        Text(Self.summary(session)).font(Theme.text(15)).foregroundStyle(Theme.ink2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
            }
        }
        .sheet(item: $showing) { session in
            NavigationStack { SessionDetailView(session: session) }
        }
    }

    /// "MY BOX · Back Squat · top 180 lb"
    static func summary(_ session: Session) -> String {
        var parts = [session.gymName] + session.liftNames
        if let top = session.heaviestTotal {
            parts.append("top \(WeightUnit.trimmed(top)) \(session.gymUnit.rawValue)")
        }
        return parts.joined(separator: " · ")
    }
}
