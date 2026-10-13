# pl8(math) — Product spec

Version 1.0 · 11 Oct 2026 · Owner: Will

This file is the source of truth for what the app does. Code, tests and Claude Code sessions follow it.
When the app and this file disagree, either the code is wrong or this file needs a deliberate update (log it in `DECISIONS.md`).

---

## Part 1 — Product (the short PRD)

### Problem
CrossFit strength work is prescribed as a percentage of your 1-rep max ("3 Back Squat @75–78% 1RM"). At the box you have to:
remember your PR (often in a different unit than the gym's plates), work out the percentage, convert kg↔lb, round it to what the plates can make, and figure out which plates to grab for every set. It's a lot of mental math between sets, and mistakes mean a wrong load.

### User
Will (and people like him): trains CrossFit several times a week, gets the workout as a screenshot from the box's app, trains in gyms that may use kg or lb plates.

### What the app does
1. Reads today's workout from a screenshot (or camera, or typed in) and keeps only the strength work.
2. Turns each set's % into a real load the gym's plates can make, in the right unit.
3. Shows the **plate kit**: which plates to take from the rack for the whole session.
4. Walks you **set by set**: what goes on the bar, what changes from the last set, one tap to check it off.
5. Keeps your PRs, your gyms' setups, and a history of sessions.

### Success
- At the box, from screenshot to first set in under 60 seconds.
- Zero wrong loads: every load matches the rules in Part 3.
- Will uses it in every strength class for 4 weeks.

### Non-goals (v1)
Accounts or cloud sync · sharing gym setups between users · Android · tracking metcons / WOD scores · fixed-load parts of the WOD like "(115/80)" · App Store release.

### Why it exists (portfolio context)
A learning project: shipping a native iOS app with AI (Claude Code), test-first, with a distinctive 3D look.

---

## Part 2 — Experience

The prototype (web, Three.js) is the reference for flow, look and feel:
`reference/prototype-app-logic.js` (all screens and the 3D scene) and `reference/scene-layout-and-look.json` (room layout, camera shots, colours, fonts).
The prototype fakes scanning and keeps no data; the rules in Part 3 replace its simplified math.

### 2.1 Concept
The whole app lives in **one small 3D CrossFit box**, low-poly with a hand-drawn outline, seen like a diorama. Each step of the app is a **station** in the room; moving between steps flies the camera there. UI sits in sheets and floating cards over the scene.

Stations (camera shot names from `scene-layout-and-look.json`):

| Station | Shot | What lives there |
|---|---|---|
| Overview | `overview` | The whole box; home |
| Plate shelf | `corner` | One pile per plate size on wall pegs (gym setup) |
| Flag | `nameFlag` / `flag` | Flag on the back wall with the gym's name |
| Bar holder | `bar` | The gym's bar (gym setup) |
| PR board | `pr` | Wall board listing your PRs |
| Whiteboard | `board` | Today's workout, written out |
| Kit floor | `kit` | The session's plates dropped on the floor |
| Rack | `setv` | Bar on the rack, loaded for the current set |

### 2.2 First run
**0 · Opening.** Title "pl8(math)" → tap → a closed box pops in → tap → the box opens and the room unfolds (walls drop, furniture lands). Light haptic on each tap.

**1 · Gym setup** — one question per sheet, each answer visibly builds the room:
1. *"Where are you training now?"* Name, up to 8 characters, uppercase. As you type, the flag on the back wall unrolls with the name.
2. *"Is the gym kilos or pounds?"* Kilograms / Pounds list with a checkmark. The plate shelf swaps to that unit's plates.
3. *"Which plates does your gym have?"* Chips, one per plate size, with a colour dot sized by diameter. Each toggle pops that pile on/off its peg.
4. *"Which bar do you use?"* kg: 20 Olympic · 15 Women's Olympic · 10 Technique. lb: 45 · 35 · 15. The bar on the holder changes to match.
"Done" → camera flies to the PR board.

**2 · PRs** — sheet "Add your PRs" with three options: **Upload a screenshot** (tag: Fastest) · **Scan with the camera** · **Type them in**.
All three end on the PR list: one row per lift, value + unit, tap a row to edit with the number pad. The PR board in the room updates live.

**3 · Today's workout** — sheet "Add today's workout": **Scan the whiteboard** · **Upload a screenshot** · **Type it in**.
While reading: a spinning plate loader. Then the whiteboard in the room shows the plan and a sheet asks *"Ready to lift?"* → **Start training** · Edit · Cancel.
Before Start, the app asks for anything it's missing (see 3.6): a PR it doesn't have ("What's your Snatch PR?", saved to PRs) and any % it couldn't read ("What % for Back Squat?").

### 2.3 A session
**4 · Plate kit.** Camera to the kit floor; the session's plates drop onto the floor with a little physics and dust. Floating card: one chip per plate size, e.g. **2 × 45 LB**, which you tick off as you collect them. Button: **Start session**.

**5 · Set by set.** Camera to the rack. Floating card at the bottom:
- small label: block name, e.g. `WARM-UP · SNATCH` or `SNATCH`
- **big: "Set 3 of 6" and "1 rep"** — set number and reps are the most prominent text (learned at the box)
- secondary: the load in the PR's unit, e.g. `145 lb`, and the % (`75–80%`)
- the change from the last set: *"Take off 5, then add 10 each side"* / *"Same plates as the last set"*
- progress dots for this block (done = green, current = dark)
- big **Done** button; a small **Plates** button returns to the kit and back without losing your place.
On the rack, the plates slide off and on the sleeves to match the set. For pulls from the floor (snatch, clean, deadlift) the camera aims lower.
**Done** → success haptic → next unchecked set.

**6 · Last set of each lift** → "How much did you lift?" prefilled with the planned load (one tap to confirm). If it beats the PR → "New PR! Update Snatch to 90 kg?" → yes updates the PR and rings the bell.

**7 · Session over.** After the last set: the bell rings (three strikes) and a "scale" weighs the session's heaviest set (its plates and bar, total, label *Heaviest set*). Tap → kit is put away, camera to overview, tab bar appears. The session is saved to history.

### 2.4 Home (after first run)
Tab bar: **Train** · **PRs** · **Gym**.
- **Train** → whiteboard + "Add today's workout" (step 3). If today's workout exists, offer to resume it.
- **PRs** → PR list (add, edit, delete, swipe to delete).
- **Gym** → gym sheet: gyms as chips (tap to switch, **+ Add gym**, remove current), name, units (segmented), plates (chips), bar (chips). The room updates live.
- **History** (not in the prototype yet): list of sessions → session detail (date, duration, gym, each lift's sets and loads). Placement to be decided (see Open decisions).

### 2.5 Look & feel
- **Scene:** palette box light `#F0E2F3`, box dark `#6C3713`, flat background `#FF6200`. Toon shading, hand-drawn outline in the dark brown (double line, slight roughness). Plates are the only saturated colours.
- **Plates:** real sizes and IWF-style colours — table in 3.1.
- **UI:** black on white. Space Grotesk (display 700, text 600), heading 25 pt. Drawers: square corners, 2 pt black border, rough hand-drawn edge. Buttons: solid black, square, 40 pt (big: 56 pt), rough edge. Fields: outline, 56 pt tall, radius 14. Exact values: `reference/scene-layout-and-look.json` → `uiLook`.
- **Haptics:** `.selection` for picks and steppers · `.impact(.light)` for continue/toggles · `.success` for set done and workout read · `.impact(.medium)` for camera shutter · `.warning` for missing info.
- **Sound:** small brass bell (three strikes) at session end and on a new PR; a clank when plates hit the floor/bar. Respect the silent switch.
- **Accessibility:** every 3D action has a plain UI equivalent; VoiceOver labels on the scene's key objects; Reduce Motion → camera cuts instead of flights, no shake.

---

## Part 3 — Rules (the math)

All rules live in the `PlateKit` Swift package (no UI, no SwiftData) so they're fast to test.

### 3.1 Plates and bars
| Unit | Size | Colour | Diameter (m) | Thickness (m) | Kind |
|---|---|---|---|---|---|
| kg | 25 | red `#D3262E` | 0.450 | 0.056 | bumper |
| kg | 20 | blue `#1E5BC6` | 0.450 | 0.046 | bumper |
| kg | 15 | yellow `#F3C318` | 0.450 | 0.036 | bumper |
| kg | 10 | green `#2E8A4B` | 0.450 | 0.027 | bumper |
| kg | 5 | white `#F2F2EE` | 0.230 | 0.024 | change |
| kg | 2.5 | red | 0.190 | 0.019 | change |
| kg | 2 | blue | 0.175 | 0.017 | change |
| kg | 1.5 | yellow | 0.160 | 0.015 | change |
| kg | 1 | green | 0.150 | 0.013 | change |
| kg | 0.5 | white | 0.135 | 0.011 | change |
| lb | 55 | red | 0.450 | 0.058 | bumper |
| lb | 45 | blue | 0.450 | 0.050 | bumper |
| lb | 35 | yellow | 0.450 | 0.040 | bumper |
| lb | 25 | green | 0.450 | 0.030 | bumper |
| lb | 15 | white | 0.300 | 0.026 | change |
| lb | 10 | iron `#26282C` | 0.250 | 0.024 | change |
| lb | 5 | iron | 0.205 | 0.020 | change |
| lb | 2.5 | iron | 0.165 | 0.016 | change |

A gym stores **which sizes it has** (not how many). Default: all sizes of its unit.
Bars — kg: 20 / 15 / 10. lb: 45 / 35 / 15. Collars are ignored.

### 3.2 Units
- 1 kg = 2.2046226218 lb. Convert with full precision; round only for display.
- A PR keeps the unit it was entered in.
- Loads are built in the **gym's** unit. The set's total is **shown in the PR's unit** (1 decimal when converted, e.g. `66.7 kg`); plates always in the gym's unit.

### 3.3 One load
Inputs: target range (low, optional high, optional "plus"), bar weight, the gym's plate sizes. Plates per side are unlimited.

1. Loadable totals = bar + 2 × (any sum of plate sizes).
2. Per side, use the **fewest plates**; on ties prefer the **larger plates**. List them heaviest first (inner to outer).
3. Choose the total:
   - **Range** `75–78%` → the heaviest loadable total inside the range; if none is inside, the one nearest the middle (tie → lighter).
   - **Plus** `80%+` (also written `80-80+%`) → the lightest loadable total **≥ low**.
   - **Single** `80%` → the nearest loadable total (tie → lighter).
4. If the target is lighter than the bar: load the empty bar and flag *"Lighter than the bar"*.

### 3.4 Warm-up
Before the **first** lift only. Three rounds aimed at 50%, 70% and 85% of the first working set's total; reps `max(5, r)`, `max(3, r)`, `r`, where r = reps of the first working set.
Each round = nearest loadable total. Drop a round if it isn't heavier than the previous one or isn't lighter than the first working set. If none survive: one round of 5 with the empty bar.
Label each round "Round n", with "≈N% 1RM".

### 3.5 Kit and changes
- **Kit**: for each plate size, the most of it any single set (warm-up included) needs on one side, × 2. Plus the bar. Sorted heaviest first.
- **Change between sets** (same bar, consecutive sets): keep the longest common inner part of the two per-side lists; the rest of the old list comes off (outer first), the rest of the new list goes on.
  Text: *"Take off A + B, then add C each side"*, *"Add C each side"*, *"Take off A each side"*, *"Same plates as the last set"*.

### 3.6 Reading a workout
Input: text lines (from Vision OCR, or typed). Output: strength blocks, each `{name, prLift, format, note, sets[{reps, pctLow, pctHigh?, plus}], pctMissing}`.

1. **Blocks** start at a line that is just a letter and a dot (`A.`, `B.`…). Labels inside a block ("After Party", "6 Sets", "Compete") stay in the block.
2. **A strength line** has reps, a movement and a percentage: `1 Snatch @75-80% 1RM Snatch`, `3 Back Squat @80-80+% 1RM Back Squat`, `5x3 @80%`.
   The lift whose PR applies is the text after `1RM`; if absent, the movement itself.
3. **Anything with a % of 1RM is strength**, whatever the block is called and wherever it appears (including after the WOD). A block with no % lines is a WOD and is ignored, even if it lists loads like `(50/35)`.
4. Consecutive strength lines for the same movement form one lift; each line is one set.
5. Format headers expand a single line: `N Minute EMOM` + one line → N sets; `E2MOM N min` → N/2 sets; `N Sets` + one line → N sets; `NxR @P%` → N sets of R reps.
6. **Hidden %**: a line that looks like a strength line whose % was cut off or garbled → keep the block with `pctMissing = true`; the app asks "What % for Back Squat?" (accepts `83-85`, `80`, `80+`). Never invent a %.
   A line counts as cut off when it starts with `<reps> <known lift>`, sits under a format header (`N Minute EMOM`, `N Sets`), and has leftover fragments of a strength line: `@`, `%`, `RM`, or the lift's last word repeated (the 05/10 OCR reads `2 Back Squat K checn J Squat`).
   Complexes joined with `+` that have no `@`/`%` anywhere (05/10 block A) are technique work, not hidden %, and are ignored.
7. **Lift names** match case-insensitively, trimmed, with an alias list (`Back squat` = `Back Squat` = `BS`). Unknown lifts are added to the PR list when the user enters their PR.
8. Several screenshots of one workout are read in order and joined.
9. (Later, optional) AI fallback when the rules find nothing.

### 3.7 Reading PRs
Lines like `Back Squat 140 kg`, `Snatch - 85kg`, `Deadlift: 405 lb`. Unit from the line; if missing, ask once for the whole screenshot.

### 3.8 Session data
- **Duration** = first check to last check.
- **History stores the planned loads**, except the last set of each lift, which stores what the user said they lifted.
- **New PR**: after the last set of each lift (and any "plus" set), compare the reported weight (converted) with the PR; if higher, offer to update.

---

## Part 4 — Data (SwiftData)

- `Gym`: id, name (≤ 8 chars), unit (kg|lb), plateSizes [Double], barWeight, isCurrent, placeID? (later).
- `PersonalRecord`: id, lift (canonical name), value, unit, updatedAt. Keep previous values as `PRHistory` entries.
- `Workout`: id, date, sourceText, blocks (Codable `StrengthBlock` array).
- `Session`: id, workout, gym snapshot (name, unit, bar, plates), startedAt?, endedAt?, setLogs.
- `SetLog`: blockIndex, setIndex, isWarmUp, reps, pctText, plannedTotal, unit, perSide [Double], checkedAt?, reportedTotal?.
Default PR list: Back squat, Front squat, Deadlift, Clean, Snatch, Bench press (empty values).

---

## Part 5 — Tech

- **SwiftUI** app, iOS 18+, **SwiftData** for storage, **Swift Testing** for tests.
- `PlateKit` — local Swift package: models, plate solver, planner (loads, warm-up, kit, changes), unit conversion, workout and PR parsers. Pure Swift, no UI. Tests run with `swift test` on the Mac.
- **Vision** (`VNRecognizeTextRequest`, accurate) for screenshots; **VisionKit** `DataScannerViewController` for the camera; `PhotosPicker` for uploads.
- **RealityKit** `RealityView` for the room; procedural meshes (box, cylinder) like the prototype; `PhysicsBodyComponent` for the kit drop; a camera entity animated between shots.
- Haptics: `.sensoryFeedback`. Sound: `AVAudioEngine` (bell can be a short bundled file).
- **Risk to spike early**: the hand-drawn outline and toon look in RealityKit (needs a custom material or post-process). Fallback: flat toon colours without outline.

---

## Part 6 — Milestones

Each milestone ends with tests green and something Will can try on his iPhone.

| # | Milestone | Done when |
|---|---|---|
| M0 | Repo + Xcode project + `PlateKit` package skeleton | App runs on the iPhone; `swift test` runs |
| M1 | Plate engine | All golden cases in `Fixtures/README.md` pass |
| M2 | Parsers + OCR | The three fixture workouts parse as expected (text fixtures, then Vision on the PNGs) |
| M3 | Data | Gyms, PRs, workouts, sessions saved and reloaded |
| M4 | **The app in plain 2D** | Full flow from 2.2–2.4 with SwiftUI sheets over a flat background; used in a real class |
| M5 | 3D spike | One plate + bar in a `RealityView` with the target look; decision logged |
| M6 | The 3D box | Stations, camera flights, shelf piles, flag, PR board, whiteboard, rack loading, kit drop, bell, opening, session-over scale |
| M7 | Polish | Haptics and sound pass, accessibility, History screen, PR screenshot import |
| Later | | Gym search with Google Places, shared gym setups, AI fallback parsing, TestFlight |

---

## Open decisions
1. Where History lives: a 4th tab, or the wall calendar in the room (the prototype already builds a calendar object).
2. Does the opening box animation play on every launch, or only the first?
3. "Type it in": keep the prototype's simple form (lift, sets, reps, one %), or allow a % per set?
4. Plate counts per gym (e.g. only two 2.5s) — currently out of scope.
