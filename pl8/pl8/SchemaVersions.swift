import Foundation
import SwiftData
import PlateKit

/// The saved data's versions (docs/DATA-AND-SERVICES.md §1). SwiftData matches the store on the phone to one of
/// these and migrates it to the newest. Version 1 is the data as it was until 2026-10-30, copied exactly (names,
/// types, which can be empty): never change it. Version 2 is ready for iCloud (CloudKit): every property has a
/// default or can be empty, every relationship can be empty and has an inverse, nothing is unique.
nonisolated enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Gym.self, PersonalRecord.self, PRHistory.self, Workout.self, Session.self, SetLog.self]
    }

    @Model
    final class Gym {
        var id = UUID()
        var name: String
        var unit: WeightUnit
        var plateSizes: [Double]
        var barWeight: Double
        var isCurrent: Bool
        var placeID: String?
        var kgPlates: [Double]?
        var lbPlates: [Double]?
        var kgBar: Double?
        var lbBar: Double?
        var sortIndex: Int = 0

        init(name: String, unit: WeightUnit, plateSizes: [Double], barWeight: Double, isCurrent: Bool) {
            self.name = name
            self.unit = unit
            self.plateSizes = plateSizes
            self.barWeight = barWeight
            self.isCurrent = isCurrent
        }
    }

    @Model
    final class PersonalRecord {
        var id = UUID()
        var lift: String
        var value: Double?
        var unit: WeightUnit
        var updatedAt: Date
        @Relationship(deleteRule: .cascade, inverse: \PRHistory.record)
        var history: [PRHistory] = []

        init(lift: String, value: Double?, unit: WeightUnit, updatedAt: Date) {
            self.lift = lift
            self.value = value
            self.unit = unit
            self.updatedAt = updatedAt
        }
    }

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

    @Model
    final class Workout {
        var id = UUID()
        var date: Date
        var sourceText: String
        var blocksData: Data
        @Relationship(deleteRule: .nullify, inverse: \Session.workout)
        var sessions: [Session] = []

        init(date: Date, sourceText: String, blocksData: Data) {
            self.date = date
            self.sourceText = sourceText
            self.blocksData = blocksData
        }
    }

    @Model
    final class Session {
        var id = UUID()
        var createdAt: Date
        var workout: Workout?
        var liftNames: [String]
        var prUnits: [WeightUnit] = []
        var prLifts: [String] = []
        var gymName: String
        var gymUnit: WeightUnit
        var barWeight: Double
        var plateSizes: [Double]
        var startedAt: Date?
        var endedAt: Date?
        @Relationship(deleteRule: .cascade, inverse: \SetLog.session)
        var setLogs: [SetLog] = []

        init(createdAt: Date, liftNames: [String], gymName: String, gymUnit: WeightUnit, barWeight: Double, plateSizes: [Double]) {
            self.createdAt = createdAt
            self.liftNames = liftNames
            self.gymName = gymName
            self.gymUnit = gymUnit
            self.barWeight = barWeight
            self.plateSizes = plateSizes
        }
    }

    @Model
    final class SetLog {
        var order: Int
        var blockIndex: Int
        var setIndex: Int
        var isWarmUp: Bool
        var reps: Int
        var pctText: String
        var plannedTotal: Double
        var unit: WeightUnit
        var perSide: [Double]
        var checkedAt: Date?
        var reportedTotal: Double?
        var session: Session?

        init(order: Int, reps: Int, plannedTotal: Double, unit: WeightUnit, perSide: [Double]) {
            self.order = order
            self.blockIndex = 0
            self.setIndex = order
            self.isWarmUp = false
            self.reps = reps
            self.pctText = ""
            self.plannedTotal = plannedTotal
            self.unit = unit
            self.perSide = perSide
        }
    }
}

/// Version 2: the app's models (Models.swift).
nonisolated enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Gym.self, PersonalRecord.self, PRHistory.self, Workout.self, Session.self, SetLog.self]
    }
}

/// 1 → 2 adds nothing that needs copying (defaults, emptiable relationships, `Workout.clearedAt`), so SwiftData
/// does it by itself. CloudKit stores only take this kind of step.
nonisolated enum DataMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)] }
}
