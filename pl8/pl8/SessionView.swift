import Foundation
import SwiftData
import SwiftUI
import PlateKit

/// A session (SPEC 2.3), laid out like the prototype's showKit and showSetCard: the room on the whole screen and
/// one frosted card at the bottom — the plate kit, then each set, then stripping the bar and **End session**.
/// Swipe up anywhere for the next card, down for the one before (Will's first class, 2026-10-16: no Done per set,
/// nothing to report). A Plates button over the room goes back to the kit.
struct SessionView: View {
    let session: Session
    var onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @State private var collected: Set<Double> = []
    /// The card in view.
    @State private var current: String
    /// Which way the last page went, so the card slides in from the right side.
    @State private var forward = true
    @State private var jumps = 0
    @State private var endCount = 0

    /// - Parameter startOnFirstSet: open on the first set instead of the kit (the CI's screenshots).
    init(session: Session, startOnFirstSet: Bool = false, onFinish: @escaping () -> Void) {
        self.session = session
        self.onFinish = onFinish
        let first = session.orderedLogs.first.map { "s-\($0.order)" }
        _current = State(initialValue: startOnFirstSet ? (first ?? "kit") : "kit")
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if session.endedAt != nil {
                let heaviest = session.heaviestLog
                SessionOverView(perSide: heaviest?.perSide ?? [], unit: session.gymUnit, barWeight: session.barWeight) { onFinish() }
            } else {
                sessionPage
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.success, trigger: endCount)
        .sensoryFeedback(.selection, trigger: jumps)
        .onAppear {
            // The clock starts when the session opens (SPEC 3.8).
            if session.startedAt == nil {
                session.startedAt = .now
                try? context.save()
            }
        }
    }

    // MARK: - The page

    /// One card; the room shows what it's about.
    private struct PageRow: Identifiable {
        enum Kind { case kit, set(SetLog, label: String, number: Int, of: Int, group: [SetLog], previous: [Double]), end }
        let id: String
        let kind: Kind
        /// The plates on the bar while this card is in view.
        let perSide: [Double]
        /// A pull: the bar is down on the platform.
        var onFloor = false
    }

    private func rows(_ logs: [SetLog]) -> [PageRow] {
        var rows = [PageRow(id: "kit", kind: .kit, perSide: [])]
        for group in groups(logs) {
            let first = group[0]
            let name = session.liftName(for: first.blockIndex).uppercased()
            for (index, log) in group.enumerated() {
                rows.append(PageRow(id: "s-\(log.order)",
                                    kind: .set(log, label: first.isWarmUp ? "WARM-UP · \(name)" : name, number: index + 1,
                                               of: group.count, group: group, previous: previous(log, in: logs)),
                                    perSide: log.perSide,
                                    onFloor: LiftNames.startsOnFloor(session.liftName(for: first.blockIndex))))
            }
        }
        rows.append(PageRow(id: "end", kind: .end, perSide: []))
        return rows
    }

    private var sessionPage: some View {
        let logs = session.orderedLogs
        let rows = rows(logs)
        let top = rows.first { $0.id == current } ?? rows[0]
        let onKit = top.id == "kit"
        return ZStack {
            RoomStage(station: onKit ? .kitFloor : top.onFloor ? .sleeveFloor : .sleeve, gymName: session.gymName, unit: session.gymUnit,
                      plateSizes: session.plateSizes, barWeight: session.barWeight,
                      session: SessionProps(kit: Kit(bar: session.barWeight, loads: logs.map { Load(total: $0.plannedTotal, perSide: $0.perSide) }),
                                            unit: session.gymUnit, barWeight: session.barWeight, perSide: top.perSide,
                                            onFloor: top.onFloor, dim: !onKit))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Back home on the left; on the sets, the prototype's quiet way back to the plate kit on the right.
                HStack {
                    FloatButton(label: "Back", icon: .back) { onFinish() }
                    Spacer()
                    if !onKit {
                        FloatButton(label: "Plates", icon: .plates) { page(to: "kit", in: rows) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 50)
                Spacer()
                card(top, logs: logs, rows: rows)
                    .id(top.id)
                    .transition(.asymmetric(insertion: .move(edge: forward ? .bottom : .top).combined(with: .opacity),
                                            removal: .opacity))
                    .padding(.leading, 10)
                    .padding(.trailing, 12)
                    .padding(.bottom, 2)
            }
        }
        // Swipe up or down anywhere for the next card or the one before.
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 24).onEnded { value in
            let dy = value.translation.height
            guard abs(dy) > 40, abs(dy) > abs(value.translation.width),
                  let index = rows.firstIndex(where: { $0.id == top.id }) else { return }
            let next = min(rows.count - 1, max(0, index + (dy < 0 ? 1 : -1)))
            if next != index { page(to: rows[next].id, in: rows) }
        })
    }

    private func page(to id: String, in rows: [PageRow]) {
        let from = rows.firstIndex { $0.id == current } ?? 0, to = rows.firstIndex { $0.id == id } ?? 0
        forward = to >= from
        jumps += 1
        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { current = id }
    }

    @ViewBuilder
    private func card(_ row: PageRow, logs: [SetLog], rows: [PageRow]) -> some View {
        switch row.kind {
        case .kit:
            kitCard(logs: logs) { page(to: rows.dropFirst().first?.id ?? "end", in: rows) }
        case .set(let log, let label, let number, let count, let group, let previous):
            setCard(log, label: label, number: number, of: count, group: group, previous: previous)
        case .end:
            endCard(logs: logs)
        }
    }

    // MARK: - Plate kit (SPEC 2.3 step 4, prototype showKit)

    /// The kit as chips to tick off as you collect them, then Start session.
    private func kitCard(logs: [SetLog], start: @escaping () -> Void) -> some View {
        let kit = Kit(bar: session.barWeight, loads: logs.map { Load(total: $0.plannedTotal, perSide: $0.perSide) })
        let unit = session.gymUnit
        return FrostedCard(padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)) {
            VStack(alignment: .leading, spacing: 12) {
                if kit.plates.isEmpty {
                    Text("Just the bar").font(Theme.text(15)).frame(maxWidth: .infinity).padding(.vertical, 4)
                } else {
                    Flow {
                        ForEach(kit.plates, id: \.size) { item in
                            let isOn = collected.contains(item.size)
                            Chip(isOn: isOn, action: { toggle(item.size) }) {
                                HStack(spacing: 8) {
                                    if let plate = Plate.find(item.size, unit) { PlateDot(plate: plate, isOn: isOn) }
                                    if isOn { Text("✓").font(Theme.text(14)) }
                                    Text("\(item.count) × \(WeightUnit.trimmed(item.size)) \(unit.rawValue.uppercased())")
                                }
                            }
                        }
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: collected)
                }
                Button("Start session", action: start)
                    .buttonStyle(.black)
            }
        }
    }

    private func toggle(_ size: Double) {
        if collected.contains(size) { collected.remove(size) } else { collected.insert(size) }
    }

    // MARK: - Every set (SPEC 2.3 step 5, prototype showSetCard)

    /// The warm-up, then each lift: runs of logs with the same block and warm-up flag.
    private func groups(_ logs: [SetLog]) -> [[SetLog]] {
        var groups: [[SetLog]] = []
        for log in logs {
            if let last = groups.last?.last, last.blockIndex == log.blockIndex, last.isWarmUp == log.isWarmUp {
                groups[groups.count - 1].append(log)
            } else {
                groups.append([log])
            }
        }
        return groups
    }

    private func previous(_ log: SetLog, in all: [SetLog]) -> [Double] {
        guard let index = all.firstIndex(where: { $0.order == log.order }), index > 0 else { return [] }
        return all[index - 1].perSide
    }

    /// The lift (small caps), "Round 1 of 3", reps and load on the right, the group's sets as a bar, and what to
    /// change on the bar.
    private func setCard(_ log: SetLog, label: String, number: Int, of count: Int, group: [SetLog], previous: [Double]) -> some View {
        let change = SetChange(from: previous, to: log.perSide)
        let total = session.gymUnit.display(log.plannedTotal, in: session.prUnit(for: log.blockIndex))
        return FrostedCard(padding: EdgeInsets(top: 14, leading: 16, bottom: 16, trailing: 16)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(label).sectionLabel().lineLimit(1)
                        Text("\(log.isWarmUp ? "Round" : "Set") \(number) of \(count)")
                            .font(Theme.heading)
                            .tracking(-0.25)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Text("\(log.reps) \(log.reps == 1 ? "rep" : "reps") · \(total)")
                        .font(Theme.text(17))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    ForEach(group, id: \.order) { other in
                        Capsule()
                            .fill(other.order <= log.order ? Theme.ink : Color.black.opacity(0.12))
                            .frame(height: 7)
                    }
                }
                Text(change.text).font(Theme.text(15)).foregroundStyle(Theme.ink2).lineLimit(2)
            }
        }
    }

    /// After the last set: everything comes off, then End session.
    private func endCard(logs: [SetLog]) -> some View {
        let last = logs.last?.perSide ?? []
        return FrostedCard(padding: EdgeInsets(top: 14, leading: 16, bottom: 16, trailing: 16)) {
            VStack(alignment: .leading, spacing: 12) {
                Text(last.isEmpty ? "Put the bar back" : SetChange(from: last, to: []).text + ", then put the bar back")
                    .font(Theme.text(17))
                    .lineLimit(2)
                Button("End session") { endSession() }
                    .buttonStyle(.black)
            }
        }
    }

    /// Saves the session to history with its planned loads (SPEC 3.8).
    private func endSession() {
        let now = Date.now
        for log in session.setLogs where log.checkedAt == nil { log.checkedAt = now }
        if session.startedAt == nil { session.startedAt = now }
        session.endedAt = now
        try? context.save()
        endCount += 1
    }
}

/// The prototype's floating card over the room: frosted (white at 78 % over a blur), 10 pt corners.
struct FrostedCard<Content: View>: View {
    var padding: EdgeInsets
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Theme.ink)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(white: 249 / 255).opacity(0.78))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
    }
}

/// A small frosted button over the room with a rough edge (the prototype's Plates button).
struct FloatButton: View {
    let label: String
    let icon: ProtoIcon.Kind
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ProtoIcon(kind: icon).frame(width: 16, height: 16)
                Text(label).font(Theme.display(15))
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(RoughRectangle().fill(Theme.float))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }
}
