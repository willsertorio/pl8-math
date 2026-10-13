# pl8(math) — working agreement for Claude Code

Native iOS app that turns a CrossFit workout screenshot into plate loads. Read `SPEC.md` before any task; it is the source of truth.

## About the person you're working with
Will is a product person learning native iOS development with this project (and building a portfolio piece). He is new to Swift, Xcode and RealityKit.
- Explain what you did and why in plain words after each step, briefly. Name the Swift/SwiftUI concepts you used so he can look them up.
- When there is a real choice (architecture, library, UX trade-off), stop and ask with 2–3 options and a recommendation. Don't ask about things the spec already decides.
- Work in small steps. One milestone task at a time. Don't start the next task unprompted.

## Stack
- SwiftUI, iOS 18+, SwiftData, Swift Testing (`@Test`, `#expect`). No third-party dependencies without asking.
- `PlateKit/` — local Swift package with all math and parsing. No SwiftUI, no SwiftData, no UIKit in it.
- RealityKit `RealityView` for the 3D box (from M5). Vision / VisionKit for text. `.sensoryFeedback` for haptics.

## Layout
```
pl8/                 the app: pl8.xcodeproj + pl8/ sources (SwiftUI views, SwiftData models, RealityKit scene)
PlateKit/            Swift package: Sources/PlateKit, Tests/PlateKitTests
Fixtures/            real screenshots, OCR text and expected results (see Fixtures/README.md)
reference/           the web prototypes and the art/layout values; read-only, never ship
SPEC.md  CLAUDE.md  DECISIONS.md
```

## How we work
1. **Tests first for anything in PlateKit.** Turn the spec's examples and `Fixtures/README.md` into tests, see them fail, then implement.
2. **A task is done only when** `cd PlateKit && swift test` passes and the app builds. For app code, also build:
   `xcodebuild -project pl8/pl8.xcodeproj -scheme pl8 -destination 'platform=iOS Simulator,name=iPhone 16' build`
   (adjust the simulator name to one installed: `xcrun simctl list devices available`).
3. **Every bug from real use becomes a fixture + a failing test first**, then the fix.
4. Keep the rules in one place. If code needs a rule the spec doesn't have, propose the spec change; after Will agrees, update `SPEC.md` and add a line to `DECISIONS.md`.
5. UI work: tell Will what to look at in the Simulator or on his iPhone when you're done. You can't judge feel; he can.
6. Commit after each finished task with a clear message. Don't push unless asked.

## Reference material
- `reference/prototype-app-logic.js` — the whole web prototype (screens, flow, 3D scene). Use it to understand intent, timings and look. Don't port its math; the spec's rules replace it.
- `reference/scene-layout-and-look.json` — room layout, camera shots, palette, fonts, UI style values. Use these numbers.
- `reference/plate-math-web-prototype.html` — the earlier prototype whose plate rules were tested at the box; the golden values come from it.

## Current milestone
M3 — data (SwiftData). M0 done 2026-10-13, M1 done 2026-10-13, M2 done 2026-10-13. (Update this line as milestones finish.)
