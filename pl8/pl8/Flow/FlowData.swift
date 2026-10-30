import Foundation
import SwiftData
import UIKit
import PlateKit

/// What the Flow reads and writes: the gyms, the PRs, the board's workout and the session, in SwiftData
/// (SPEC Part 4). The prototype keeps this in `this.d`; here it's the app's real data.
@MainActor
final class FlowData {
    let context: ModelContext
    private(set) var gyms: [Gym] = []
    /// The workout on the board, and the session being lifted.
    var workout: Workout?
    var session: Session?
    /// The PR dial works in this unit until switched (the prototype's prUnit).
    var prUnit: WeightUnit?

    init(context: ModelContext) {
        self.context = context
        reload()
        workout = latestWorkout()
    }

    // MARK: - Gyms

    func reload() {
        gyms = ((try? context.fetch(FetchDescriptor<Gym>())) ?? []).sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) }
        if gyms.isEmpty {
            let gym = Gym(name: "", unit: .kg)
            context.insert(gym)
            gyms = [gym]
            save()
        }
        // Kept per phone (Gym.current); the first time, from the old flag on the gym.
        Gym.current(in: gyms)?.makeCurrent()
    }

    var gymIndex: Int { Gym.current(in: gyms).flatMap { current in gyms.firstIndex { $0 === current } } ?? 0 }
    var gym: Gym { gyms[gymIndex] }

    var name: String {
        get { gym.name }
        set { gym.name = String(GymSetup.normalizedName(newValue).prefix(2)); save() }
    }

    var unit: WeightUnit { gym.unit }

    func setUnit(_ unit: WeightUnit) {
        gym.switchUnit(to: unit)
        save()
    }

    /// Which plate sizes the gym has, in its unit.
    var owned: [Double] {
        get { gym.plateSizes }
        set { gym.plateSizes = newValue.sorted(by: >); gym.remember(); save() }
    }

    var bar: Double {
        get { gym.barWeight }
        set { gym.barWeight = newValue; gym.remember(); save() }
    }

    func makeCurrent(_ index: Int) {
        guard gyms.indices.contains(index) else { return }
        gyms[index].makeCurrent()
    }

    /// A new, empty gym at the end of the row, made current (set up through name → units → plates → bar).
    func addGym() {
        let gym = Gym(name: "", unit: self.gym.unit)
        gym.sortIndex = (gyms.map(\.sortIndex).max() ?? 0) + 1
        gym.plateSizes = []
        context.insert(gym)
        gyms.append(gym)
        makeCurrent(gyms.count - 1)
        Analytics.send(.gymAdded)
    }

    /// The last gym can't go.
    func deleteGym(at index: Int) {
        guard gyms.count > 1, gyms.indices.contains(index) else { return }
        Analytics.send(.gymDeleted)
        let gone = gyms.remove(at: index)
        context.delete(gone)
        makeCurrent(max(0, index - 1))
    }

    // MARK: - PRs

    /// The PR list in the prototype's order (the default lifts first), with what's known.
    var records: [PersonalRecord] {
        let all = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        var list: [PersonalRecord] = []
        for lift in LiftNames.defaultPRLifts {
            if let record = Planner.record(for: lift, in: all) {
                list.append(record)
            } else {
                let record = PersonalRecord(lift: lift)
                context.insert(record)
                list.append(record)
            }
        }
        return list + all.filter { record in !list.contains { $0 === record } }
    }

    /// "Back Squat  140 kg" for each PR with a value: the notebook's page.
    var prRows: [String] {
        records.compactMap { record in
            guard let value = record.value, value > 0 else { return nil }
            return "\(LiftNames.sentenceCase(record.lift))  \(WeightUnit.trimmed(value)) \(record.unit.rawValue)"
        }
    }

    func setPR(_ record: PersonalRecord, value: Double, unit: WeightUnit) {
        if record.value != value || record.unit != unit { record.update(value: value, unit: unit) }
        save()
    }

    /// The one-time "Read it in the cloud?" question; the Flow shows it.
    var askCloudConsent: () async -> Bool = { false }
    /// How the last photo was read (the analytics `photo_read` event).
    private(set) var lastRead: (kind: ReadResult.Kind, stage: PhotoReader.Stage, milliseconds: Int)?

    /// Reads a PR screenshot into the PRs, in stages (PhotoReader); true when it found any.
    func readPRs(_ image: UIImage) async -> Bool {
        let read = await PhotoReader.prs(image, unit: unit, consent: askCloudConsent)
        lastRead = (kind: ReadResult.Kind.prs, stage: read.stage, milliseconds: read.milliseconds)
        var entries = read.entries
        if PRParser.needsUnit(entries) { entries = PRParser.assumingUnit(unit, for: entries) }
        guard !entries.isEmpty else { return false }
        let all = records
        for entry in entries {
            let record = Planner.record(for: entry.lift, in: all) ?? {
                let new = PersonalRecord(lift: entry.lift)
                context.insert(new)
                return new
            }()
            setPR(record, value: entry.value, unit: entry.unit ?? unit)
        }
        return true
    }

    // MARK: - The workout and the session

    /// The newest workout not wiped off the board.
    func latestWorkout() -> Workout? {
        var descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.clearedAt == nil },
                                                  sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Reads a workout screenshot onto the board, in stages (PhotoReader); true when it found a lift.
    func readWorkout(_ image: UIImage) async -> Bool {
        let read = await PhotoReader.workout(image, unit: unit, consent: askCloudConsent)
        lastRead = (kind: ReadResult.Kind.workout, stage: read.stage, milliseconds: read.milliseconds)
        guard !read.blocks.isEmpty else { return false }
        let workout = Workout(sourceText: read.text, blocks: read.blocks)
        context.insert(workout)
        save()
        self.workout = workout
        return true
    }

    /// Wiped off the board: the board is clean until the next upload, also after the app restarts (it used to come
    /// back). The workout stays for the sessions lifted from it.
    func wipeBoard() {
        Analytics.send(.boardWiped)
        workout?.clearedAt = .now
        save()
        workout = nil
    }

    /// The board's lines (flDrawBoard): "A. BACK SQUAT", "5 × 5 @ 75%", "→ 100 kg".
    var boardLines: [FlowBoardLine]? {
        guard let workout else { return nil }
        let blocks = workout.blocks
        let plan = Planner.plan(blocks: blocks, gym: gym, records: records)
        let records = plan.setRecords
        let letters = Array("ABCDEFGH")
        return plan.lifts.prefix(4).enumerated().map { index, lift in
            let reps = lift.sets.map(\.reps)
            var format = Set(reps).count == 1 ? "\(reps.count) × \(reps[0])" : reps.map(String.init).joined(separator: "-")
            if let pct = records.first(where: { $0.blockIndex == index && !$0.isWarmUp })?.pctText, !pct.isEmpty { format += " @ \(pct)" }
            let load = lift.sets.first.map { plan.displayTotal($0) } ?? ""
            return FlowBoardLine(title: "\(letters[min(index, 7)]). \(lift.name.uppercased())", format: format, load: "→ \(load)")
        }
    }

    /// Starts lifting what's on the board: a new session with every planned set.
    func startSession() -> FlowPlan? {
        guard let workout else { return nil }
        let blocks = workout.blocks
        let all = records
        let plan = Planner.plan(blocks: blocks, gym: gym, records: all)
        guard !plan.setRecords.isEmpty else { return nil }
        let session = Session.start(workout: workout, plan: plan, prLifts: Planner.prLifts(blocks: blocks), gym: gym, in: context)
        session.startedAt = .now
        self.session = session
        save()
        Analytics.send(.sessionStarted(setsTotal: plan.setRecords.count))
        return FlowPlan(session: session)
    }

    func endSession() {
        guard let session else { return }
        let now = Date.now
        for log in session.setLogs ?? [] where log.checkedAt == nil { log.checkedAt = now }
        session.endedAt = now
        save()
    }

    func save() { try? context.save() }
}

/// A session as the Flow's kit and sets show it (the prototype's plan: groups, flat sets, kit).
struct FlowPlan {
    struct Set {
        /// "WARM-UP · BACK SQUAT" small; "Set 2 of 5" big; "5 reps · 100 kg".
        let group: String
        let label: String
        let reps: Int
        let total: Double
        let totalText: String
        let perSide: [Double]
        let onFloor: Bool
        let groupIndex: Int
    }

    let unit: WeightUnit
    let bar: Double
    let sets: [Set]
    /// (size, count both sides), heaviest first.
    let kit: [(Double, Int)]
    /// The heaviest set, for the scale.
    var heaviest: Set? { sets.max { $0.total < $1.total } }

    init(session: Session) {
        unit = session.gymUnit
        bar = session.barWeight
        let logs = session.orderedLogs
        var groups: [[SetLog]] = []
        for log in logs {
            if let last = groups.last?.last, last.blockIndex == log.blockIndex, last.isWarmUp == log.isWarmUp {
                groups[groups.count - 1].append(log)
            } else {
                groups.append([log])
            }
        }
        let firstLift = logs.first { !$0.isWarmUp }.map { session.liftName(for: $0.blockIndex) } ?? session.liftName(for: 0)
        var sets: [Set] = []
        for (g, group) in groups.enumerated() {
            let first = group[0], name = session.liftName(for: first.blockIndex)
            for (i, log) in group.enumerated() {
                let total = session.gymUnit.display(log.plannedTotal, in: session.prUnit(for: log.blockIndex))
                sets.append(Set(group: first.isWarmUp ? "Warm-up · \(firstLift)" : name,
                                label: "\(first.isWarmUp ? "Round" : "Set") \(i + 1) of \(group.count)",
                                reps: log.reps, total: log.plannedTotal,
                                totalText: "\(log.reps) \(log.reps == 1 ? "rep" : "reps") · \(total)",
                                perSide: log.perSide, onFloor: LiftNames.startsOnFloor(name), groupIndex: g))
            }
        }
        self.sets = sets
        kit = Kit(bar: session.barWeight, loads: logs.map { Load(total: $0.plannedTotal, perSide: $0.perSide) }).plates.map { ($0.size, $0.count) }
    }
}
