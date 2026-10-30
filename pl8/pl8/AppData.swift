import Foundation
import SwiftData
import PlateKit

/// The app's saved data (docs/DATA-AND-SERVICES.md §1): SwiftData, synced through the user's private iCloud
/// database when the app is signed with its iCloud container and the user is signed in; on the phone only
/// otherwise. Older stores are brought up to date by `DataMigration`.
enum AppData {
    static let container: ModelContainer = make()

    private static func make() -> ModelContainer {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-pl8MigrationCheck") { DataCheck.report(DataCheck.migration(), to: "migration-check.txt") }
        let schema = Schema(versionedSchema: SchemaV2.self)
        // Screenshot mode keeps its demo data in memory, away from the real data and from iCloud.
        if ScreenshotMode.shot != nil {
            return try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        }
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        do {
            let container = try ModelContainer(for: schema, migrationPlan: DataMigration.self, configurations: configuration)
            if arguments.contains("-pl8DataCheck") { DataCheck.report(DataCheck.counts(container), to: "data-check.txt") }
            return container
        } catch {
            // A store that won't open is moved aside, not lost, and the app starts with a new one: it opens either way.
            let backup = moveAside(configuration.url)
            if arguments.contains("-pl8DataCheck") {
                DataCheck.report(["result: failed", "error: \(error)", "moved to: \(backup?.path ?? "-")"], to: "data-check.txt")
            }
            if let fresh = try? ModelContainer(for: schema, migrationPlan: DataMigration.self, configurations: configuration) { return fresh }
            return try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        }
    }

    /// The store's files go to "Store backups/<seconds>" next to it.
    private static func moveAside(_ url: URL) -> URL? {
        let manager = FileManager.default
        let folder = url.deletingLastPathComponent()
            .appending(path: "Store backups/\(Int(Date.now.timeIntervalSince1970))", directoryHint: .isDirectory)
        guard (try? manager.createDirectory(at: folder, withIntermediateDirectories: true)) != nil else { return nil }
        for suffix in ["", "-shm", "-wal"] {
            let file = URL(fileURLWithPath: url.path + suffix)
            if manager.fileExists(atPath: file.path) { try? manager.moveItem(at: file, to: folder.appending(path: file.lastPathComponent)) }
        }
        return folder
    }
}

/// What the CI's data checks read, a few lines in Documents: `-pl8MigrationCheck` (a version 1 store made here
/// opens as version 2 with every row and link) and `-pl8DataCheck` (what the real store holds once open, after
/// the CI has installed this build over an older one).
enum DataCheck {
    static func report(_ lines: [String], to name: String) {
        guard let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        try? (lines.joined(separator: "\n") + "\n").write(to: folder.appending(path: name), atomically: true, encoding: .utf8)
    }

    static func counts(_ container: ModelContainer) -> [String] {
        let context = ModelContext(container)
        func count<T: PersistentModel>(_ type: T.Type) -> Int { (try? context.fetchCount(FetchDescriptor<T>())) ?? -1 }
        return ["result: ok", "gyms: \(count(Gym.self))", "prs: \(count(PersonalRecord.self))", "workouts: \(count(Workout.self))",
                "sessions: \(count(Session.self))", "sets: \(count(SetLog.self))"]
    }

    static func migration() -> [String] {
        let url = FileManager.default.temporaryDirectory.appending(path: "migration-check-\(UUID().uuidString).store")
        do {
            try makeVersion1Store(at: url)
            let container = try ModelContainer(for: Schema(versionedSchema: SchemaV2.self), migrationPlan: DataMigration.self,
                                               configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
            let context = ModelContext(container)
            let gyms = try context.fetch(FetchDescriptor<Gym>())
            let records = try context.fetch(FetchDescriptor<PersonalRecord>())
            let workouts = try context.fetch(FetchDescriptor<Workout>())
            let sessions = try context.fetch(FetchDescriptor<Session>())
            var problems: [String] = []
            let gym = gyms.first
            let plates: [Double] = gym?.plateSizes ?? []
            if gyms.count != 1 || gym?.name != "79" || gym?.isCurrent != true || plates != [25, 20] { problems.append("gym") }
            let record = records.first
            let earlier: Double? = record?.history?.first?.value
            if record?.value != 120 || earlier != 110 { problems.append("PR and its history") }
            let workout = workouts.first
            let workoutSessions: Int = workout?.sessions?.count ?? 0
            if workout?.sourceText != "A. Back Squat" || workout?.clearedAt != nil || workoutSessions != 1 { problems.append("workout") }
            let session = sessions.first
            let totals: [Double] = session?.orderedLogs.map(\.plannedTotal) ?? []
            if session?.workout == nil || totals != [60, 70] { problems.append("session and its sets") }
            return [problems.isEmpty ? "result: ok" : "result: failed", "problems: \(problems.joined(separator: ", "))",
                    "gyms: \(gyms.count)", "prs: \(records.count)", "workouts: \(workouts.count)", "sessions: \(sessions.count)"]
        } catch {
            return ["result: failed", "error: \(error)"]
        }
    }

    /// One of everything, linked as the app links them, saved with the version 1 models.
    private static func makeVersion1Store(at url: URL) throws {
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV1.self),
                                           configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        let context = ModelContext(container)
        context.insert(SchemaV1.Gym(name: "79", unit: .kg, plateSizes: [25, 20], barWeight: 20, isCurrent: true))
        let record = SchemaV1.PersonalRecord(lift: "Back Squat", value: 120, unit: .kg, updatedAt: .now)
        context.insert(record)
        let earlier = SchemaV1.PRHistory(value: 110, unit: .kg, date: .now)
        context.insert(earlier)
        earlier.record = record
        let workout = SchemaV1.Workout(date: .now, sourceText: "A. Back Squat", blocksData: Data())
        context.insert(workout)
        let session = SchemaV1.Session(createdAt: .now, liftNames: ["Back Squat"], gymName: "79", gymUnit: .kg, barWeight: 20,
                                       plateSizes: [25, 20])
        context.insert(session)
        session.workout = workout
        for (order, total) in [60.0, 70.0].enumerated() {
            let log = SchemaV1.SetLog(order: order, reps: 3, plannedTotal: total, unit: .kg, perSide: [])
            context.insert(log)
            log.session = session
        }
        try context.save()
    }
}
