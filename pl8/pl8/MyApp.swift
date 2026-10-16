import SwiftData
import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            Group {
                if let shot = ScreenshotMode.shot {
                    ScreenshotHost(shot: shot)       // CI: one screen with demo data (tools/README)
                } else {
                    ContentView()
                }
            }
            // The look is black on white (SPEC 2.5), also when the phone is in Dark Mode.
            .preferredColorScheme(.light)
        }
        // Screenshot mode keeps its demo data in memory, away from the real data.
        .modelContainer(for: [Gym.self, PersonalRecord.self, PRHistory.self, Workout.self, Session.self, SetLog.self],
                        inMemory: ScreenshotMode.shot != nil)
    }
}
