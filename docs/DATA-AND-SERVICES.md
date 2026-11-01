# pl8(math): data, photo reading and analytics

This spec covers everything behind the screens. The app is **always free**, has **no accounts**, supports **iOS 17 and later**, and reads photos **on the device first, with a cloud fallback**.

The privacy policy (`privacy.html`) describes exactly this behaviour. If you change how data is handled, flag it, so the policy and the App Store privacy label can be updated to match.

Read the codebase first. Then propose a plan, including the files and types you'll add, before you change anything.

---

## 1. Storage: SwiftData with iCloud sync

- **Deployment target:** iOS 17.0.
- **Sync:** SwiftData with CloudKit sync in the user's **private** iCloud database (the `iCloud` capability with a CloudKit container, plus Background Modes → Remote notifications for sync pushes).
- **No iCloud:** if the user isn't signed in to iCloud, the app works the same, local-only.
- **CloudKit rules:**
  - Every property must be optional or have a default.
  - There are no unique constraints.
  - Every relationship must be optional and have an inverse.

### Models (starting point)

```swift
@Model final class Gym {
  var id: UUID = UUID()
  var name: String = ""              // two characters from the dials, e.g. "AA"
  var unit: String = "kg"            // "kg" | "lb"
  var ownedPlates: [Double] = []     // in this gym's unit, e.g. [25, 20, 15, 10, 5, 2.5]
  var barWeight: Double = 20
  var sortIndex: Int = 0
  var createdAt: Date = Date()
}

@Model final class PersonalRecord {
  var lift: String = ""              // "Back squat", "Deadlift", ...
  var weight: Double? = nil
  var unit: String = "kg"
  var updatedAt: Date = Date()
}

@Model final class Workout {          // what's on the whiteboard
  var createdAt: Date = Date()
  var json: Data = Data()            // the parsed workout (schema in §2.4), kept as JSON
  var finishedAt: Date? = nil
  var doneSetIndexes: [Int] = []
}
```

- **Current gym:** store the current gym's ID in `@AppStorage` (it's per device, and doesn't need to sync).
- **The menu's Train board** shows the newest `Workout`.
- **Wiping the board** deletes that workout or marks it cleared.
- **No photos are stored, ever.** Keep the recognized text and the parsed result (the text stays on the phone and in iCloud; it's how a bug from real use becomes a fixture). *(Will, 2026-10-30; the privacy policy says so.)*

---

## 2. Photo reading pipeline

The user picks a photo (the system photo picker, `PhotosPicker`). The app reads it in stages and stops at the first stage that produces a valid result:

1. **Read the text on the device.** Vision's `RecognizeTextRequest` (iOS 18+), or `VNRecognizeTextRequest` on iOS 17, at the `.accurate` level, with language correction off for numbers.
2. **Parse on the device.**
   - **Rules first.** Write a deterministic parser for common formats (§2.3). Its output is accepted only if it passes validation (§2.4).
   - **Then Apple's on-device model.** If rules fail and the device supports Apple Intelligence (Foundation Models framework, iOS 26+, roughly iPhone 15 Pro and newer), ask the on-device model for the §2.4 schema using guided generation (`@Generable`), then validate.
3. **Cloud fallback.**
   - **Text when possible:** send the **recognized text** to our server.
   - **Photo only as a last resort:** send the photo itself only when text recognition produced almost nothing (for example, fewer than 8 characters). Downscale it to 1600px on the long edge, JPEG quality 0.7, with EXIF and location data removed.
   - **Consent before the first send:** see §2.2.
4. **If everything fails:** fall back to manual entry. Workouts don't have a manual entry screen yet; show a gentle "Couldn't read that, try a closer photo" and offer to retry. PRs use the existing pencil, which opens the PR dial.

### 2.1 Feedback while reading

- **Wait screen:** reuse the existing "Reading your workout…" and "Reading your PRs…" screens.
- **Timeouts:** about 6s for the on-device stages, 15s for the cloud.

### 2.2 Consent before the first cloud send (App Review guideline 5.1.2)

Before the **first** time any text or photo leaves the device, show a one-time native sheet, with this suggested copy:

> **Read it in the cloud?**
> Your phone couldn't read this one. pl8(math) can send the text (or the photo, if needed) to our server, where an AI service reads it. Nothing is kept after it's read.
> [Allow] [Not now]

- **Remember the answer.** If the user taps "Not now", skip the cloud stage and go straight to manual or retry.
- **Settings:** add a toggle to change it later, wherever settings live (for now, a long-press menu or the gym room is fine; ask me).

### 2.3 Formats the rules parser should handle

Examples from CrossFit whiteboards:
- `Back squat 5x5 @ 75%`
- `5 × 5 @ 75%` (the lift on the line above)
- `Deadlift 3-3-3 @80%`
- `EMOM 10: 3 cleans @ 70%`
- `Bench 5/3/1`
- `Strict press 4x6 @ 40kg`
- `A. BACK SQUAT` (a section header) followed by `5x5 @ 75%`

Normalise: `×`/`x`/`X`, `@`, `%`, `kg`/`lb`/`#`, and spacing. Anything unclear is a parse **failure**; never guess.

### 2.4 Output schema (shared by all three stages)

```json
{
  "kind": "workout",
  "unit": "kg | lb | null",
  "blocks": [
    {
      "label": "A",
      "lift": "Back squat",
      "sets": [ { "reps": 5, "percent": 75, "weight": null } ],
      "note": "optional free text, e.g. EMOM 10"
    }
  ]
}
```

```json
{ "kind": "prs", "unit": "kg | lb | null", "prs": [ { "lift": "Deadlift", "weight": 180 } ] }
```

**Validation:**
- Reps must be between 1 and 50.
- Percent must be between 30 and 110.
- Weight must be between 1 and 500 kg (or 1,100 lb).
- There must be at least one block or PR.
- Lift names are matched to a known list, case-insensitive and with simple synonyms (`bs` → Back squat, `dl` → Deadlift, `cj`/`c&j` → Clean & jerk).
- Unknown lifts are allowed, with their name kept as written.

Weights come from percent × PR, rounded to plates the current gym owns. That logic already exists, so keep it.

---

## 3. The server: a small read proxy

It does exactly one job: holding the AI provider's key and calling it. It has no database and no user accounts.

- **Hosting:** any serverless platform in an **EU region**, such as Cloudflare Workers, Vercel or Fly.
- **Endpoint:** `POST /v1/read`, with this body:

  ```json
  { "kind": "workout|prs", "text": "...", "image": "<base64 jpeg, optional>", "locale": "es-ES", "unit": "kg" }
  ```

  It returns the §2.4 JSON, or `{ "error": "unreadable" }`.
- **Only our app may call it:**
  - The app uses **App Attest** (`DCAppAttestService`): it registers once, then sends an assertion with each request.
  - The server verifies the assertion and rejects everything else.
- **Abuse limits:**
  - 20 reads per device per day, tracked by the attested key ID in a tiny key-value store with a time-to-live (a counter only, never content). App Attest also needs each key's public key and its sign counter kept, to check later requests; the privacy policy says so. *(Will, 2026-10-30.)*
  - A global spending cap, set in the AI provider's dashboard.
- **Privacy:**
  - Never log the request body, the text or the image.
  - Log only status, latency and model per request.
  - Anthropic's commercial API terms don't use inputs for training. The privacy policy names Claude by Anthropic, so if you switch providers, tell me and the policy will be updated.
- **Model:** **Claude by Anthropic**, through the Anthropic API. Use a small, inexpensive Claude model with vision (for example the current Haiku) and structured JSON output. The prompt contains only the schema, the validation rules and the input.
- **Secrets:** the provider key lives only in the server's environment variables, never in the app.

---

## 4. Analytics: PostHog

- **SDK:** the `posthog-ios` package.
- **Host:** the **EU cloud** (`https://eu.i.posthog.com`).
- **Configuration:**
  - **Anonymous only:** set `personProfiles` to `.never`. Never call `identify`.
  - **Session replay off.** **Autocapture off**, so only the events below are sent.
  - **Discard IP data:** turn this on in the PostHog project settings.
  - **Lifecycle events on:** `captureApplicationLifecycleEvents = true` (app opened, installed, updated).
- **Never send** photos, recognized text, gym names or PR values.

| Event | Properties |
|---|---|
| `onboarding_step_viewed` | `step`: name, unit, plates, bar, prs, pr_dial, workout |
| `onboarding_completed` | `seconds` |
| `photo_read` | `kind`: workout or prs; `stage`: rules, on_device_model, cloud or failed; `ms` |
| `cloud_consent` | `allowed`: true or false |
| `kit_viewed` | `plate_count` |
| `session_started` | `sets_total` |
| `set_completed` | `index` |
| `session_finished` | `sets_done`, `sets_total`, `minutes` |
| `board_wiped` | none |
| `gym_added`, `gym_deleted`, `gym_edited` | `field` for `gym_edited`: name, unit, plates or bar |
| `palette_changed` | Don't ship. This is prototype-only. |

---

## 5. App Store privacy setup

**Permission text in the app's settings file (`Info.plist`):**
- **Photo library:** with `PhotosPicker`, no permission prompt is needed. If you add direct camera capture, add `NSCameraUsageDescription`: "Take a photo of today's whiteboard or your PR list so pl8(math) can read it."
- **Encryption:** `ITSAppUsesNonExemptEncryption` = `NO`.

**Privacy manifest (`PrivacyInfo.xcprivacy`):**
- Declare the required-reason APIs you use (for example `UserDefaults`, reason `CA92.1`).
- Make sure PostHog's own manifest is included through the package.

**App Privacy label answers (in App Store Connect):**

| Category | Collected? | Linked to the user? | Tracking? | Purpose |
|---|---|---|---|---|
| Usage Data → Product interaction | Yes | No | No | Analytics |
| Diagnostics → Crash data, Performance data | Yes | No | No | App functionality, Analytics |
| User Content → Photos or videos / Other user content | Yes (only via the cloud fallback, never stored) | No | No | App functionality |
| Identifiers, Location, Contact info, Health & Fitness | No | n/a | n/a | n/a |

Workout data stays in the user's iCloud, which we can't access, so it isn't "collected".
