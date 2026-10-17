import Foundation
import SwiftData
import PlateKit

/// Keeping the saved data tidy.
@MainActor
enum DataCleanup {
    /// One PR per lift: records whose names are the same lift ("backsquat", "Back Squat") are merged into one,
    /// keeping the most recently updated value and its history, under the lift's proper name.
    static func mergeDuplicatePRs(in context: ModelContext) {
        let records = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        let groups = Dictionary(grouping: records) { LiftNames.key(LiftNames.canonical($0.lift)) }
        for (_, group) in groups {
            let keep = group.filter { $0.value != nil }.max { $0.updatedAt < $1.updatedAt } ?? group[0]
            keep.lift = LiftNames.canonical(keep.lift)
            for other in group where other !== keep {
                for entry in other.history { entry.record = keep }
                context.delete(other)
            }
        }
        try? context.save()
    }

    /// Replaying the first run starts from nothing: every gym, PR, workout and session is deleted.
    static func eraseEverything(in context: ModelContext) {
        try? context.delete(model: SetLog.self)
        try? context.delete(model: Session.self)
        try? context.delete(model: Workout.self)
        try? context.delete(model: PRHistory.self)
        try? context.delete(model: PersonalRecord.self)
        try? context.delete(model: Gym.self)
        try? context.save()
    }
}
