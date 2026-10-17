import SwiftData
import SwiftUI

@main struct MyApp: App {
    init() { Fonts.register() }

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
            // Space Grotesk everywhere, like the prototype's screens.
            .font(Theme.text(17))
        }
        // Screenshot mode keeps its demo data in memory, away from the real data.
        .modelContainer(for: [Gym.self, PersonalRecord.self, PRHistory.self, Workout.self, Session.self, SetLog.self],
                        inMemory: ScreenshotMode.shot != nil)
    }
}
