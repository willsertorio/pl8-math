import Foundation
import SwiftData
import SwiftUI
import PlateKit

/// A session (SPEC 2.3): one scrolling page — the plate kit at the top, then every set in order with its bar
/// and what to put on or take off, then stripping the bar and **End session**. Two buttons at the top jump
/// between the kit and the sets. Nothing to tick off set by set, nothing to report (Will's first class, 2026-10-16).
struct SessionView: View {
    let session: Session
    var onFinish: () -> Void


    @Environment(\.modelContext) private var context
    @State private var collected: Set<Double> = []
    @State private var barCollected = false
    /// The row at the top of the scroll.
    @State private var topRow: String?

    /// - Parameter startOnFirstSet: open on the first set instead of the kit (the CI's screenshots).
    init(session: Session, startOnFirstSet: Bool = false, onFinish: @escaping () -> Void) {
        self.session = session
        self.onFinish = onFinish
        let first = session.orderedLogs.first.map { "s-\($0.order)" }
        _topRow = State(initialValue: startOnFirstSet ? first : "kit")
    }
    @State private var jumps = 0
    @State private var endCount = 0

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if session.endedAt != nil {
                finishedView
            } else {
                sessionPage
            }
        }
        // Just Back on top: no title, no tab bar while you train.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sensoryFeedback(.success, trigger: endCount)
        .onAppear {
            // The clock starts when the session opens (SPEC 3.8).
            if session.startedAt == nil {
                session.startedAt = .now
                try? context.save()
            }
        }
    }

    // MARK: - The page

    /// One card on the page; the room shows what the card in view is about.
    private struct PageRow: Identifiable {
        enum Kind { case kit, set(SetLog, label: String, number: Int, of: Int, previous: [Double]), end }
        let id: String
        let kind: Kind
        /// The plates on the bar while this card is in view.
        let perSide: [Double]
    }

    private func rows(_ logs: [SetLog]) -> [PageRow] {
        var rows = [PageRow(id: "kit", kind: .kit, perSide: [])]
        for group in groups(logs) {
            let first = group[0]
            let name = session.liftName(for: first.blockIndex).uppercased()
            for (index, log) in group.enumerated() {
                rows.append(PageRow(id: "s-\(log.order)",
                                    kind: .set(log, label: first.isWarmUp ? "WARM-UP · \(name)" : name, number: index + 1,
                                               of: group.count, previous: previous(log, in: logs)),
                                    perSide: log.perSide))
            }
        }
        rows.append(PageRow(id: "end", kind: .end, perSide: []))
        return rows
    }

    /// The room on 80 % of the screen, following the card in view: the kit on the floor, or the sleeve with that
    /// set's plates. Below, one card at a time; swipe up for the next.
    private var sessionPage: some View {
        let logs = session.orderedLogs
        let rows = rows(logs)
        let top = rows.first { $0.id == (topRow ?? "kit") } ?? rows[0]
        let onKit = top.id == "kit"
        let firstSet = rows.dropFirst().first?.id ?? "end"
        return VStack(spacing: 0) {
            RoomStage(station: onKit ? .kitFloor : .sleeve, gymName: session.gymName, unit: session.gymUnit,
                      plateSizes: session.plateSizes, barWeight: session.barWeight,
                      session: SessionProps(kit: Kit(bar: session.barWeight, loads: logs.map { Load(total: $0.plannedTotal, perSide: $0.perSide) }),
                                            unit: session.gymUnit, barWeight: session.barWeight, perSide: top.perSide))
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 8) {
                        Chip(isOn: onKit, action: { jump(to: "kit") }) { Text("Plate kit") }.fixedSize()
                        Chip(isOn: !onKit, action: { jump(to: firstSet) }) { Text("Sets") }.fixedSize()
                    }
                    .padding(12)
                    .sensoryFeedback(.selection, trigger: jumps)
                }
                .containerRelativeFrame(.vertical) { length, _ in length * 0.8 }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { row in
                        rowView(row, logs: logs)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .containerRelativeFrame(.vertical)
                            .id(row.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $topRow)
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private func rowView(_ row: PageRow, logs: [SetLog]) -> some View {
        switch row.kind {
        case .kit: kitCard(logs: logs)
        case .set(let log, let label, let number, let count, let previous):
            setCard(log, label: label, number: number, of: count, previous: previous)
        case .end: endCard(logs: logs)
        }
    }

    private func jump(to id: String) {
        jumps += 1
        withAnimation(.snappy) { topRow = id }
    }

    // MARK: - Plate kit (SPEC 2.3 step 4)

    /// The kit as one row of chips to tick off as you collect them.
    private func kitCard(logs: [SetLog]) -> some View {
        let kit = Kit(bar: session.barWeight, loads: logs.map { Load(total: $0.plannedTotal, perSide: $0.perSide) })
        let unit = session.gymUnit
        return VStack(alignment: .leading, spacing: 8) {
            Text("Plate kit").sectionLabel()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(isOn: barCollected, action: { barCollected.toggle() }) {
                        Text("BAR \(WeightUnit.trimmed(kit.bar)) \(unit.rawValue.uppercased())")
                    }
                    .fixedSize()
                    ForEach(kit.plates, id: \.size) { item in
                        let isOn = collected.contains(item.size)
                        Chip(isOn: isOn, action: { toggle(item.size) }) {
                            HStack(spacing: 6) {
                                if let plate = Plate.find(item.size, unit) {
                                    PlateDot(plate: plate, outline: isOn ? Theme.paper : Theme.ink)
                                }
                                Text("\(item.count) × \(WeightUnit.trimmed(item.size)) \(unit.rawValue.uppercased())")
                            }
                        }
                        .fixedSize()
                    }
                }
                .padding(2)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: collected)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .drawer()
    }

    private func toggle(_ size: Double) {
        if collected.contains(size) { collected.remove(size) } else { collected.insert(size) }
    }

    // MARK: - Every set (SPEC 2.3 step 5)

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

    /// Text only: the bar in the room shows the plates.
    private func setCard(_ log: SetLog, label: String, number: Int, of count: Int, previous: [Double]) -> some View {
        let change = SetChange(from: previous, to: log.perSide)
        let total = session.gymUnit.display(log.plannedTotal, in: session.prUnit(for: log.blockIndex))
        return VStack(alignment: .leading, spacing: 4) {
            Text(label).sectionLabel()
            HStack(alignment: .firstTextBaseline) {
                Text("\(log.isWarmUp ? "Round" : "Set") \(number) of \(count)")
                Spacer()
                Text("\(log.reps) \(log.reps == 1 ? "rep" : "reps")")
            }
            .font(.system(size: 26, weight: .bold))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            Text("\(total) · \(log.pctText)").font(.headline)
            Text(change.text).font(.subheadline.weight(.semibold)).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .drawer()
    }

    /// After the last set: everything comes off, then End session.
    private func endCard(logs: [SetLog]) -> some View {
        let last = logs.last?.perSide ?? []
        return VStack(alignment: .leading, spacing: 8) {
            Text(last.isEmpty ? "Put the bar back" : SetChange(from: last, to: []).text + ", then put the bar back")
                .font(.headline)
                .lineLimit(2)
            Button("End session") { endSession() }
                .buttonStyle(.bigBlack)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .drawer()
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

    // MARK: - Finished (SPEC 2.3 step 7)

    private var finishedView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Session done").font(Theme.heading)
                    if let duration = session.duration {
                        Text("\(Duration.seconds(duration).formatted(.time(pattern: .hourMinute))) in the box")
                            .foregroundStyle(Theme.ink)
                    }
                }
                .drawer()

                // The "scale": the session's heaviest set, its plates and bar, and the total.
                if let heaviest = session.heaviestLog {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Heaviest set").sectionLabel()
                        BarDiagram(perSide: heaviest.perSide, unit: session.gymUnit)
                            .frame(height: 140)
                        Text(session.gymUnit.display(heaviest.liftedTotal, in: session.prUnit(for: heaviest.blockIndex)))
                            .font(.system(size: 40, weight: .bold))
                        Text("\(session.liftName(for: heaviest.blockIndex)) · \(heaviest.reps) \(heaviest.reps == 1 ? "rep" : "reps")")
                            .font(.headline)
                        Text(heaviest.perSide.isEmpty
                             ? "Empty bar"
                             : heaviest.perSide.map(WeightUnit.trimmed).joined(separator: " + ")
                                + " \(session.gymUnit.rawValue) each side + \(WeightUnit.trimmed(session.barWeight)) \(session.gymUnit.rawValue) bar")
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                    }
                    .drawer()
                }

                Button("Finish") { onFinish() }
                    .buttonStyle(.bigBlack)
            }
            .padding(16)
        }
    }
}

/// One side of the bar in 2D: the plates on the sleeve, sized and coloured like the real ones.
struct BarDiagram: View {
    let perSide: [Double]
    let unit: WeightUnit

    private struct Slot: Identifiable {
        let id: String
        let plate: Plate?
    }

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let slots = perSide.enumerated().map { index, size in
                Slot(id: "\(index)-\(size)", plate: Plate.find(size, unit))
            }
            HStack(spacing: 0) {
                Rectangle().fill(Color.gray).frame(width: 70, height: 10)
                Rectangle().fill(Theme.ink).frame(width: 10, height: 34)
                HStack(spacing: 2) {
                    ForEach(slots) { slot in
                        Rectangle()
                            .fill(Color(hex: slot.plate?.colorHex ?? "#888888"))
                            .overlay(Rectangle().stroke(Theme.ink, lineWidth: 2))
                            .frame(
                                width: max(10, (slot.plate?.thickness ?? 0.02) * 500),
                                height: height * (slot.plate?.diameter ?? 0.2) / 0.45
                            )
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                Rectangle().fill(Color.gray).frame(height: 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.snappy, value: perSide)
        }
        .accessibilityElement()
        .accessibilityLabel(perSide.isEmpty ? "Empty bar" : "Plates each side: " + perSide.map(WeightUnit.trimmed).joined(separator: ", "))
    }
}
