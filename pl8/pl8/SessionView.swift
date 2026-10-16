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

    private enum Anchor: Hashable { case kit, sets }

    @Environment(\.modelContext) private var context
    @State private var collected: Set<Double> = []
    @State private var barCollected = false
    @State private var jump: Anchor?
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
        .navigationTitle(session.gymName)
        .navigationBarTitleDisplayMode(.inline)
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

    private var sessionPage: some View {
        let logs = session.orderedLogs
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    kitCard(logs: logs).id(Anchor.kit)
                    Text("Sets").font(Theme.heading).padding(.top, 8).id(Anchor.sets)
                    ForEach(groups(logs), id: \.first!.order) { group in
                        groupView(group, all: logs)
                    }
                    stripCard(logs: logs)
                    Button("End session") { endSession() }
                        .buttonStyle(.bigBlack)
                        .padding(.top, 8)
                }
                .padding(16)
            }
            .safeAreaInset(edge: .top) {
                HStack(spacing: 8) {
                    Chip(isOn: false, action: { jump = .kit; jumps += 1 }) { Text("Plate kit") }.fixedSize()
                    Chip(isOn: false, action: { jump = .sets; jumps += 1 }) { Text("Sets") }.fixedSize()
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.background)
                .sensoryFeedback(.selection, trigger: jumps)
            }
            .onChange(of: jump) { _, target in
                guard let target else { return }
                withAnimation(.snappy) { proxy.scrollTo(target, anchor: .top) }
                jump = nil
            }
        }
    }

    // MARK: - Plate kit (SPEC 2.3 step 4)

    private func kitCard(logs: [SetLog]) -> some View {
        let kit = Kit(bar: session.barWeight, loads: logs.map { Load(total: $0.plannedTotal, perSide: $0.perSide) })
        let unit = session.gymUnit
        return VStack(alignment: .leading, spacing: 12) {
            Text("Plate kit").font(Theme.heading)
            Text("Take these from the rack. Tap each one as you collect it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                Chip(isOn: barCollected, action: { barCollected.toggle() }) {
                    Text("BAR \(WeightUnit.trimmed(kit.bar)) \(unit.rawValue.uppercased())")
                }
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
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: collected)
        }
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

    private func groupView(_ group: [SetLog], all: [SetLog]) -> some View {
        let first = group[0]
        let name = session.liftName(for: first.blockIndex).uppercased()
        return VStack(alignment: .leading, spacing: 10) {
            Text(first.isWarmUp ? "WARM-UP · \(name)" : name).sectionLabel()
            ForEach(Array(group.enumerated()), id: \.element.order) { index, log in
                setCard(log, number: index + 1, of: group.count, previous: previous(log, in: all))
            }
        }
    }

    private func previous(_ log: SetLog, in all: [SetLog]) -> [Double] {
        guard let index = all.firstIndex(where: { $0.order == log.order }), index > 0 else { return [] }
        return all[index - 1].perSide
    }

    private func setCard(_ log: SetLog, number: Int, of count: Int, previous: [Double]) -> some View {
        let change = SetChange(from: previous, to: log.perSide)
        let total = session.gymUnit.display(log.plannedTotal, in: session.prUnit(for: log.blockIndex))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(log.isWarmUp ? "Round" : "Set") \(number) of \(count)")
                Spacer()
                Text("\(log.reps) \(log.reps == 1 ? "rep" : "reps")")
            }
            .font(.system(size: 28, weight: .bold))
            .minimumScaleFactor(0.6)
            .lineLimit(1)

            Text("\(total) · \(log.pctText)")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(change.text).font(.headline)

            BarDiagram(perSide: log.perSide, unit: session.gymUnit)
                .frame(height: 90)

            Text(platesText(log.perSide)).font(.subheadline)
        }
        .drawer()
    }

    /// After the last set: everything comes off.
    private func stripCard(logs: [SetLog]) -> some View {
        let last = logs.last?.perSide ?? []
        return VStack(alignment: .leading, spacing: 8) {
            Text("Done lifting").sectionLabel()
            Text(last.isEmpty ? "Put the bar back" : SetChange(from: last, to: []).text + ", then put the bar back")
                .font(.headline)
        }
        .drawer()
    }

    private func platesText(_ perSide: [Double]) -> String {
        if perSide.isEmpty { return "Empty bar" }
        return perSide.map(WeightUnit.trimmed).joined(separator: " + ") + " \(session.gymUnit.rawValue) each side"
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
                            .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
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
