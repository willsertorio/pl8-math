import Foundation
import PostHog

/// Anonymous usage statistics (docs/DATA-AND-SERVICES.md §4): PostHog's EU cloud, a random id made by the app, no
/// person profiles, no screen views, autocapture or session replay. Only these events go, and never photos, the text
/// in them, a gym's name or a PR's value. Off until the project's key is in Info.plist (`PostHogAPIKey`), and in the
/// CI's screenshot mode.
enum Analytics {
    enum Event {
        case onboardingStepViewed(step: String)
        case onboardingCompleted(seconds: Int)
        case photoRead(kind: String, stage: String, milliseconds: Int)
        case cloudConsent(allowed: Bool)
        case kitViewed(plateCount: Int)
        case sessionStarted(setsTotal: Int)
        case setCompleted(index: Int)
        case sessionFinished(setsDone: Int, setsTotal: Int, minutes: Int)
        case boardWiped
        case gymAdded
        case gymDeleted
        case gymEdited(field: String)

        var name: String {
            switch self {
            case .onboardingStepViewed: "onboarding_step_viewed"
            case .onboardingCompleted: "onboarding_completed"
            case .photoRead: "photo_read"
            case .cloudConsent: "cloud_consent"
            case .kitViewed: "kit_viewed"
            case .sessionStarted: "session_started"
            case .setCompleted: "set_completed"
            case .sessionFinished: "session_finished"
            case .boardWiped: "board_wiped"
            case .gymAdded: "gym_added"
            case .gymDeleted: "gym_deleted"
            case .gymEdited: "gym_edited"
            }
        }

        var properties: [String: Any] {
            switch self {
            case .onboardingStepViewed(let step): ["step": step]
            case .onboardingCompleted(let seconds): ["seconds": seconds]
            case .photoRead(let kind, let stage, let milliseconds): ["kind": kind, "stage": stage, "ms": milliseconds]
            case .cloudConsent(let allowed): ["allowed": allowed]
            case .kitViewed(let plateCount): ["plate_count": plateCount]
            case .sessionStarted(let setsTotal): ["sets_total": setsTotal]
            case .setCompleted(let index): ["index": index]
            case .sessionFinished(let setsDone, let setsTotal, let minutes): ["sets_done": setsDone, "sets_total": setsTotal, "minutes": minutes]
            case .gymEdited(let field): ["field": field]
            case .boardWiped, .gymAdded, .gymDeleted: [:]
            }
        }
    }

    private static var started = false

    static func start() {
        guard ScreenshotMode.shot == nil,
              let key = Bundle.main.object(forInfoDictionaryKey: "PostHogAPIKey") as? String, !key.isEmpty else { return }
        let config = PostHogConfig(projectToken: key, host: "https://eu.i.posthog.com")
        config.personProfiles = .never
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false
        config.preloadFeatureFlags = false
        PostHogSDK.shared.setup(config)
        started = true
    }

    static func send(_ event: Event) {
        guard started else { return }
        PostHogSDK.shared.capture(event.name, properties: event.properties)
    }

    /// The first run's questions by the names the events use.
    static func onboardingStep(_ step: Flow.Step) -> String? {
        switch step {
        case .name: "name"
        case .unit: "unit"
        case .plates: "plates"
        case .bar: "bar"
        case .prs: "prs"
        case .prDial: "pr_dial"
        case .wod: "workout"
        default: nil
        }
    }
}
