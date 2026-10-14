import Foundation
import SwiftData
import SwiftUI
import PlateKit

/// A session (SPEC 2.3): the plate kit to collect, then set by set with Done.
struct SessionView: View {
    let session: Session
    var onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @State private var showKit: Bool
    @State private var collected: Set<Double> = []
    @State private var barCollected = false
    @State private var doneCount = 0

    init(session: Session, onFinish: @escaping () -> Void) {
        self.session = session
        self.onFinish = onFinish
        // A fresh session opens on the kit; a resumed one goes straight to the next set.
        _showKit = State(initialValue: !session.setLogs.contains { $0.checkedAt != nil })
    }

    var body: some View {
        let logs = session.orderedLogs
        let cursor = SessionCursor(items: logs.map {
            SessionCursor.Item(blockIndex: $0.blockIndex, isWarmUp: $0.isWarmUp, isDone: $0.checkedAt != nil)
        })

        ZStack {
            Theme.background.ignoresSafeArea()
            if showKit {
                kitView(logs: logs, hasStarted: logs.contains { $0.checkedAt != nil })
            } else if let index = cursor.current {
                setView(logs: logs, cursor: cursor, index: index)
            } else {
                finishedView
            }
        }
        .navigationTitle(session.gymName)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: doneCount)
    }

    // MARK: - Plate kit (SPEC 2.3 step 4)

    private func kitView(logs: [SetLog], hasStarted: Bool) -> some View {
        let kit = Kit(bar: session.barWeight, loads: logs.map { Load(total: $0.plannedTotal, perSide: $0.perSide) })
        let unit = session.gymUnit
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
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

                Button(hasStarted ? "Back to the set" : "Start session") { showKit = false }
                    .buttonStyle(.bigBlack)
            }
            .padding(16)
        }
    }

    private func toggle(_ size: Double) {
        if collected.contains(size) { collected.remove(size) } else { collected.insert(size) }
    }

    // MARK: - Set by set (SPEC 2.3 step 5)

    private func setView(logs: [SetLog], cursor: SessionCursor, index: Int) -> some View {
        let log = logs[index]
        let position = cursor.position(of: index)
        let liftName = session.liftName(for: log.blockIndex).uppercased()
        let previous = index > 0 ? logs[index - 1].perSide : []
        let change = SetChange(from: previous, to: log.perSide)
        let total = session.gymUnit.display(log.plannedTotal, in: session.prUnit(for: log.blockIndex))

        return VStack(spacing: 16) {
            BarDiagram(perSide: log.perSide, unit: session.gymUnit)
                .frame(height: 180)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 12) {
                Text(log.isWarmUp ? "WARM-UP · \(liftName)" : liftName).sectionLabel()

                HStack(alignment: .firstTextBaseline) {
                    Text("\(log.isWarmUp ? "Round" : "Set") \(position.number) of \(position.count)")
                    Spacer()
                    Text("\(log.reps) \(log.reps == 1 ? "rep" : "reps")")
                }
                .font(.system(size: 36, weight: .bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

                Text("\(total) · \(log.pctText)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(platesText(log.perSide)).font(.subheadline)

                Text(change.text).font(.headline)

                HStack(spacing: 6) {
                    ForEach(cursor.group(of: index), id: \.self) { item in
                        Circle()
                            .fill(dotColor(item: item, current: index, cursor: cursor))
                            .overlay(Circle().stroke(Theme.ink, lineWidth: 1.5))
                            .frame(width: 12, height: 12)
                    }
                }

                Button("Done") { markDone(log, isLastSet: cursor.items.count - 1 == cursor.items.filter(\.isDone).count) }
                    .buttonStyle(.bigBlack)

                Button("Plates") { showKit = true }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .drawer()
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .animation(.snappy, value: index)
    }

    private func dotColor(item: Int, current: Int, cursor: SessionCursor) -> Color {
        if cursor.items[item].isDone { return Color(hex: "#2E8A4B") }
        return item == current ? Theme.ink : Theme.paper
    }

    private func platesText(_ perSide: [Double]) -> String {
        if perSide.isEmpty { return "Empty bar" }
        return perSide.map(WeightUnit.trimmed).joined(separator: " + ") + " \(session.gymUnit.rawValue) each side"
    }

    /// Checks the set off; the first check starts the clock and the last one stops it (SPEC 3.8).
    private func markDone(_ log: SetLog, isLastSet: Bool) {
        let now = Date.now
        log.checkedAt = now
        if session.startedAt == nil { session.startedAt = now }
        if isLastSet { session.endedAt = now }
        try? context.save()
        doneCount += 1
    }

    // MARK: - Finished

    private var finishedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session done").font(Theme.heading)
            if let start = session.startedAt, let end = session.endedAt {
                Text("\(Duration.seconds(end.timeIntervalSince(start)).formatted(.time(pattern: .hourMinute))) from first to last set")
                    .foregroundStyle(.secondary)
            }
            if let top = session.heaviestTotal {
                Text("Heaviest set: \(WeightUnit.trimmed(top)) \(session.gymUnit.rawValue)").font(.headline)
            }
            Button("Finish") { onFinish() }
                .buttonStyle(.bigBlack)
        }
        .drawer()
        .padding(16)
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
