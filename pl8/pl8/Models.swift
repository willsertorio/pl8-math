import Foundation
import SwiftData
import PlateKit

// The saved data, version 2 (SchemaVersions.swift): ready for iCloud, so every property has a default or can be
// empty, and every relationship can be empty and has an inverse (docs/DATA-AND-SERVICES.md §1).

/// A gym's setup (SPEC Part 4). The rules live in PlateKit; this is what gets saved.
@Model
final class Gym {
    var id = UUID()
    /// Uppercase, up to 8 characters.
    var name: String = ""
    var unit: WeightUnit = WeightUnit.kg
    /// Heaviest first. Which sizes the gym has, not how many.
    var plateSizes: [Double] = []
    var barWeight: Double = 20
    /// Until 2026-10-30 the current gym was marked here; now it's per phone (`Gym.current`), read from here once.
    var isCurrent: Bool = false
    var placeID: String?
    /// What the gym has in each unit, kept when you switch (the Flow: a gym is { name, unit, plates[unit], bar[unit] }).
    /// Nil until that unit has been set up.
    var kgPlates: [Double]?
    var lbPlates: [Double]?
    var kgBar: Double?
    var lbBar: Double?
    /// Its place in the row of gyms.
    var sortIndex: Int = 0

    init(name: String, unit: WeightUnit) {
        let defaults = GymSetup(unit: unit)
        self.name = GymSetup.normalizedName(name)
        self.unit = unit
        self.plateSizes = defaults.plateSizes
        self.barWeight = defaults.barWeight
    }

    /// What PlateKit needs to plan loads.
    var setup: GymSetup {
        GymSetup(unit: unit, plateSizes: plateSizes, barWeight: barWeight)
    }

    /// A new unit brings what the gym had in that unit before, or that unit's plates and bar.
    func switchUnit(to newUnit: WeightUnit) {
        guard newUnit != unit else { return }
        remember()
        let defaults = GymSetup(unit: newUnit)
        unit = newUnit
        plateSizes = (newUnit == .kg ? kgPlates : lbPlates) ?? defaults.plateSizes
        barWeight = (newUnit == .kg ? kgBar : lbBar) ?? defaults.barWeight
    }

    func setPlate(_ size: Double, isOn: Bool) {
        var sizes = plateSizes.filter { $0 != size }
        if isOn { sizes.append(size) }
        plateSizes = sizes.sorted(by: >)
        remember()
    }

    /// Keeps this unit's plates and bar for when the gym switches back.
    func remember() {
        switch unit {
        case .kg: kgPlates = plateSizes; kgBar = barWeight
        case .lb: lbPlates = plateSizes; lbBar = barWeight
        }
    }

    /// Which gym is current belongs to the phone, not to iCloud (docs/DATA-AND-SERVICES.md §1): its id is kept in
    /// UserDefaults. Before that it was a flag on the gym, still read when nothing is kept yet.
    static let currentKey = "currentGymID"

    static func current(in gyms: [Gym]) -> Gym? {
        let id = UserDefaults.standard.string(forKey: currentKey)
        return gyms.first { $0.id.uuidString == id } ?? gyms.first(where: \.isCurrent) ?? gyms.first
    }

    func makeCurrent() { UserDefaults.standard.set(id.uuidString, forKey: Self.currentKey) }
}

/// A PR. It keeps the unit it was entered in; earlier values go to `history`.
@Model
final class PersonalRecord {
    var id = UUID()
    /// Canonical lift name, e.g. "Back Squat".
    var lift: String = ""
    /// Nil until the user enters it.
    var value: Double?
    var unit: WeightUnit = WeightUnit.kg
    var updatedAt: Date = Date.now
    @Relationship(deleteRule: .cascade, inverse: \PRHistory.record)
    var history: [PRHistory]? = []

    init(lift: String, value: Double? = nil, unit: WeightUnit = .kg) {
        self.lift = LiftNames.canonical(lift)
        self.value = value
        self.unit = unit
        self.updatedAt = .now
    }

    /// Saves a new value; the old one (if any) is kept in history.
    func update(value newValue: Double, unit newUnit: WeightUnit) {
        if let oldValue = value {
            history = (history ?? []) + [PRHistory(value: oldValue, unit: unit, date: updatedAt)]
        }
        value = newValue
        unit = newUnit
        updatedAt = .now
    }
}

/// An earlier value of a PR.
@Model
final class PRHistory {
    var value: Double = 0
    var unit: WeightUnit = WeightUnit.kg
    var date: Date = Date.now
    var record: PersonalRecord?

    init(value: Double, unit: WeightUnit, date: Date) {
        self.value = value
        self.unit = unit
        self.date = date
    }
}

/// A workout read from a screenshot (or typed), with its strength blocks (SPEC Part 4).
@Model
final class Workout {
    var id = UUID()
    var date: Date = Date.now
    /// The text the blocks were read from.
    var sourceText: String = ""
    /// The blocks, saved as JSON so SwiftData only stores plain data. Use `blocks` instead.
    var blocksData: Data = Data()
    @Relationship(deleteRule: .nullify, inverse: \Session.workout)
    var sessions: [Session]? = []
    /// When it was wiped off the board: the board stays clean, the sessions keep their workout.
    var clearedAt: Date?

    init(sourceText: String, blocks: [StrengthBlock], date: Date = .now) {
        self.date = date
        self.sourceText = sourceText
        self.blocksData = (try? JSONEncoder().encode(blocks)) ?? Data()
    }

    /// Decoded once per change: screens read this many times while you type.
    var blocks: [StrengthBlock] {
        get { BlockCache.blocks(for: blocksData) }
        set { blocksData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    /// "14 Oct, 09:12 · Split Jerk"
    var title: String {
        let lifts = blocks.map(\.name).reduce(into: [String]()) { names, name in
            if !names.contains(name) { names.append(name) }
        }
        return "\(date.formatted(.dateTime.day().month().hour().minute())) · \(lifts.joined(separator: ", "))"
    }
}

/// Decoded blocks by their saved JSON, so the same data is only decoded once.
private enum BlockCache {
    private static var decoded: [Data: [StrengthBlock]] = [:]

    static func blocks(for data: Data) -> [StrengthBlock] {
        if let blocks = decoded[data] { return blocks }
        // `repaired()` fixes blocks saved by older parser versions (e.g. a ")" PR).
        let blocks = ((try? JSONDecoder().decode([StrengthBlock].self, from: data)) ?? []).map { $0.repaired() }
        if decoded.count > 100 { decoded.removeAll() }
        decoded[data] = blocks
        return blocks
    }
}

/// One training session: a snapshot of the gym and every planned set (SPEC Part 4).
@Model
final class Session {
    var id = UUID()
    var createdAt: Date = Date.now
    var workout: Workout?
    /// Lift names by block index, so history reads well even if the workout is deleted.
    var liftNames: [String] = []
    /// Each lift's PR unit by block index: totals are shown in it (SPEC 3.2).
    var prUnits: [WeightUnit] = []
    /// The PR each lift is based on, by block index (e.g. "Snatch" for Snatch Pull + Snatch), for the new-PR check.
    var prLifts: [String] = []

    // Gym snapshot: later changes to the gym don't change history.
    var gymName: String = ""
    var gymUnit: WeightUnit = WeightUnit.kg
    var barWeight: Double = 20
    var plateSizes: [Double] = []

    /// Set when the first and last sets are checked (M4).
    var startedAt: Date?
    var endedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \SetLog.session)
    var setLogs: [SetLog]? = []

    init(gym: Gym, workout: Workout?, plan: SessionPlan) {
        self.createdAt = .now
        self.workout = workout
        self.liftNames = plan.lifts.map(\.name)
        self.prUnits = plan.lifts.map(\.prUnit)
        self.gymName = gym.name
        self.gymUnit = gym.unit
        self.barWeight = gym.barWeight
        self.plateSizes = gym.plateSizes
    }

    /// SwiftData doesn't keep a relationship's order, so each log has an `order`.
    var orderedLogs: [SetLog] {
        (setLogs ?? []).sorted { $0.order < $1.order }
    }

    func liftName(for blockIndex: Int) -> String {
        liftNames.indices.contains(blockIndex) ? liftNames[blockIndex] : "Lift"
    }

    func prUnit(for blockIndex: Int) -> WeightUnit {
        prUnits.indices.contains(blockIndex) ? prUnits[blockIndex] : gymUnit
    }

    func prLift(for blockIndex: Int) -> String {
        prLifts.indices.contains(blockIndex) ? prLifts[blockIndex] : liftName(for: blockIndex)
    }

    /// Saves a new session with every planned set, ready to check off.
    static func start(workout: Workout?, plan: SessionPlan, prLifts: [String], gym: Gym, in context: ModelContext) -> Session {
        let session = Session(gym: gym, workout: workout, plan: plan)
        session.prLifts = prLifts
        context.insert(session)
        for (order, record) in plan.setRecords.enumerated() {
            let log = SetLog(order: order, record: record)
            context.insert(log)
            log.session = session
        }
        try? context.save()
        return session
    }

    /// The heaviest working set: what was lifted where reported, else what was planned.
    var heaviestLog: SetLog? {
        (setLogs ?? []).filter { !$0.isWarmUp }.max { $0.liftedTotal < $1.liftedTotal }
    }

    var heaviestTotal: Double? { heaviestLog?.liftedTotal }

    /// First check to last check (SPEC 3.8).
    var duration: TimeInterval? {
        guard let startedAt, let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }
}

/// One set of a session.
@Model
final class SetLog {
    var order: Int = 0
    var blockIndex: Int = 0
    var setIndex: Int = 0
    var isWarmUp: Bool = false
    var reps: Int = 0
    var pctText: String = ""
    var plannedTotal: Double = 0
    var unit: WeightUnit = WeightUnit.kg
    var perSide: [Double] = []
    var checkedAt: Date?
    /// What the user said they lifted (last set of each lift).
    var reportedTotal: Double?
    var session: Session?

    /// History keeps the planned load, except where the user reported what they lifted (SPEC 3.8).
    var liftedTotal: Double { reportedTotal ?? plannedTotal }

    init(order: Int, record: PlannedSetRecord) {
        self.order = order
        self.blockIndex = record.blockIndex
        self.setIndex = record.setIndex
        self.isWarmUp = record.isWarmUp
        self.reps = record.reps
        self.pctText = record.pctText
        self.plannedTotal = record.plannedTotal
        self.unit = record.unit
        self.perSide = record.perSide
    }
}
