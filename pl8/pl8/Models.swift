import Foundation
import SwiftData
import PlateKit

/// A gym's setup (SPEC Part 4). The rules live in PlateKit; this is what gets saved.
@Model
final class Gym {
    var id = UUID()
    /// Uppercase, up to 8 characters.
    var name: String
    var unit: WeightUnit
    /// Heaviest first. Which sizes the gym has, not how many.
    var plateSizes: [Double]
    var barWeight: Double
    var isCurrent: Bool
    var placeID: String?

    init(name: String, unit: WeightUnit, isCurrent: Bool = true) {
        let defaults = GymSetup(unit: unit)
        self.name = GymSetup.normalizedName(name)
        self.unit = unit
        self.plateSizes = defaults.plateSizes
        self.barWeight = defaults.barWeight
        self.isCurrent = isCurrent
    }

    /// What PlateKit needs to plan loads.
    var setup: GymSetup {
        GymSetup(unit: unit, plateSizes: plateSizes, barWeight: barWeight)
    }

    /// A new unit brings that unit's plates and bar.
    func switchUnit(to newUnit: WeightUnit) {
        guard newUnit != unit else { return }
        let defaults = GymSetup(unit: newUnit)
        unit = newUnit
        plateSizes = defaults.plateSizes
        barWeight = defaults.barWeight
    }

    func setPlate(_ size: Double, isOn: Bool) {
        var sizes = plateSizes.filter { $0 != size }
        if isOn { sizes.append(size) }
        plateSizes = sizes.sorted(by: >)
    }
}

/// A PR. It keeps the unit it was entered in; earlier values go to `history`.
@Model
final class PersonalRecord {
    var id = UUID()
    /// Canonical lift name, e.g. "Back Squat".
    var lift: String
    /// Nil until the user enters it.
    var value: Double?
    var unit: WeightUnit
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \PRHistory.record)
    var history: [PRHistory] = []

    init(lift: String, value: Double? = nil, unit: WeightUnit = .kg) {
        self.lift = LiftNames.canonical(lift)
        self.value = value
        self.unit = unit
        self.updatedAt = .now
    }

    /// Saves a new value; the old one (if any) is kept in history.
    func update(value newValue: Double, unit newUnit: WeightUnit) {
        if let oldValue = value {
            history.append(PRHistory(value: oldValue, unit: unit, date: updatedAt))
        }
        value = newValue
        unit = newUnit
        updatedAt = .now
    }
}

/// An earlier value of a PR.
@Model
final class PRHistory {
    var value: Double
    var unit: WeightUnit
    var date: Date
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
    var date: Date
    /// The text the blocks were read from.
    var sourceText: String
    /// The blocks, saved as JSON so SwiftData only stores plain data.
    private var blocksData: Data

    init(sourceText: String, blocks: [StrengthBlock], date: Date = .now) {
        self.date = date
        self.sourceText = sourceText
        self.blocksData = (try? JSONEncoder().encode(blocks)) ?? Data()
    }

    var blocks: [StrengthBlock] {
        get { (try? JSONDecoder().decode([StrengthBlock].self, from: blocksData)) ?? [] }
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
