import SwiftData
import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Gym.self, PersonalRecord.self, PRHistory.self, Workout.self])
    }
}
