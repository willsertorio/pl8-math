import SwiftData
import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // The look is black on white (SPEC 2.5), also when the phone is in Dark Mode.
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [Gym.self, PersonalRecord.self, PRHistory.self, Workout.self, Session.self, SetLog.self])
    }
}
