# Plate Math Flow: changes in v2

This is everything that changed since the first handoff. Apply it on top of `HANDOFF.md`, which has also been updated to match.

`prototype/index.html` is the current build: open it to see every change running.

Read the codebase first. Then show me a short plan mapping each item below to our screens before you change anything.

---

## 1. Typography: Helvetica Neue everywhere

Replace Space Grotesk with **Helvetica Neue** for all interface text. On iOS, use the system font family `Helvetica Neue` (not SF).

| Role | Used for | Weight | Size | Tracking | Line height | Case |
|---|---|---|---|---|---|---|
| Display | Questions, set titles ("Round 2 of 3") | 500 (Medium) | 33 | −0.035em | 1.02 | as written |
| Label | Labels under 3D objects, menu items, bar weights, plate rows | 500 | 21 | −0.02em | 1.15 | as written |
| Body | Cards, chips, buttons, set info ("3 reps · 73 kg") | 400 (Regular) | 17 (chips 16, "End session" 19) | −0.01em | 1.3 | as written |
| Small caps | YES / NO, overlines on cards | 500 | 12 | +0.04em | 1.2 | ALL CAPS |
| Numbers | Weights, the scale readout, PR dial, letter dials | 500 | 32 | −0.04em | 1.0 | n/a |

- Numbers are **tabular** everywhere (`monospacedDigit()`), so weights line up.
- Text drawn into 3D textures uses Helvetica Neue Medium (500): the letter dials, the PR dial, the KG/LB labels on the kettlebells, the gym box initials and the gym flag.
- Handwriting doesn't change: the whiteboard and notebook still use **Permanent Marker**.
- The iOS delete alert stays the native system alert.

## 2. Colour: new default palette ("Swiss red")

| Token | Hex | Used for |
|---|---|---|
| `bg` | `#E5321C` | Background on question screens, the menu, the scale and the opening |
| `light` | `#F4F1EA` | Ink on red, light screens (kit and sets), whiteboard surface, gym room walls |
| `dark` | `#151515` | Ink on light, frames, the notebook cover, chips, buttons, empty-gym lines |
| `card` | `#FFFFFF` | Kit and set cards |
| `accent` | `#E5321C` | Finished-set progress dots |

- **Grid lines** on light screens and on the whiteboard are now `dark` at 9% (screens) and 11% (board) opacity. They used to be a fixed brown.
- **Built as a theme:** build colours as one theme object read everywhere, not hard-coded per view. Every 3D material, board texture, card and dot takes its colour from the theme.
- **Prototype-only palettes:** the prototype also includes four other palettes, used only for exploring.

  | Palette | `bg` | `light` | `dark` | `card` | `accent` |
  |---|---|---|---|---|---|
  | Current (old orange) | `#FF6200` | `#F0E2F3` | `#6C3713` | `#FFFFFF` | `#FF6200` |
  | Ink blue | `#2A4BFF` | `#EEF0F6` | `#0C1A4A` | `#FFFFFF` | `#2A4BFF` |
  | Chalk green | `#1F6B49` | `#EEE9DC` | `#16261D` | `#FBF9F3` | `#E8B43A` |
  | Mono | `#141414` | `#F2F2F0` | `#141414` | `#FFFFFF` | `#FF6200` |

  **Don't ship a palette switcher** unless I ask for one.
- **Contrast:** `light` on `bg` is about 4:1. That passes for the large question text, but is low for 12–17pt text on red. Avoid small text directly on the red background where possible.

## 3. Layout: the question sits lower

- **Question:** the top of the question text is now **150pt** from the top of the screen (it was 92pt).
- **Objects below it:** on every question screen, the 3D object moves down by the same **58pt** so nothing overlaps. These are the name dials, kettlebells, bars, notebook, PR dial and whiteboard.
  - **Implementation:** shift the camera up along its own up axis by the world distance that equals 58pt at the camera's target depth. This keeps the composition and only moves it on screen.
- **Plates checklist:** the first row is now at **272pt** (was 214) and the last row ends at 800pt, so the rows are slightly tighter.
- **Hand-offs:** the pull-back from the kit to the whiteboard, and the zoom into the board, use the shifted board view so neither jumps.

## 4. Plates checklist: rows just appear

- **No motion:** the plates no longer fall in.
- **One row at a time:** every **90ms** a whole row appears at once in its final place: the plate, its weight label and its YES / NO boxes.
  - There's no fade, scale, slide or easing. The only feedback is a soft click.
  - The YES / NO headers also appear without a fade.
- **When editing from the gym:** the saved ticks are drawn in as each row appears.

## 5. Whiteboard: same shadow as in the menu

- **Shadow style:** on "What are we doing today?" the whiteboard no longer casts a real-time shadow onto an invisible floor. It uses the **same soft blob shadow as the Train board in the menu**: a radial gradient ellipse, about 1.13 × 0.68 board units, under the board.
- **Follows the board:** the shadow is attached to the board, so it travels and turns with it as it rolls in.
- **Kit preview:** the board shown while dragging back from the kit uses the same shadow.

## 6. Empty gym slot (the "add gym" box)

- **Size:** about 70% of a gym box.
- **Lines:** **dashed** edges (dash 0.07, gap 0.05 units) in `dark`, thin, with no fill, no shadow and no plus sign.
- **Idle animation**, so it reads as tappable:
  - It slowly grows and shrinks between 65% and 75% scale over about 4.8s.
  - It turns gently from side to side, about ±20° (0.35 rad), over about 11s.

## 7. Question letters: optional "collage" style (off by default)

- **The effect:** each letter of the question can be offset to look cut and pasted, with one setting `k` from 0 (clean) to 1:
  - Extra letter spacing: + k × 0.09em.
  - A rotation per letter: up to ±14° × k.
  - A vertical hop per letter: up to ±5pt × k.
  - A scale per letter: 1 ± 0.12 × k.
- **Fixed per letter:** each letter's offsets come from a fixed per-letter seed, so the result is stable and never jitters, and words never break across lines.
- **Default:** **ship with k = 0 (off)**. If I settle on a level I'll give you the number; structure the text view so `k` is one parameter.

## 8. Opening screen

- **Colours:** no change in design. The opening (title and flying plates) uses the normal palette: `bg` background with plates in `dark`.
- **Not adopted:** an inverted version was tried and dropped.

---

## Prototype-only controls (don't build these into the app)

These exist in the web prototype for tuning. They're listed so you don't mistake them for features:

| Control | What it does |
|---|---|
| Tap the clock, or press P | Next palette |
| Double-tap the Dynamic Island, or press W | Rough edges on or off |
| Double-tap the battery, or press C | Background on or off |
| ↑ / ↓ | Letter collage level, in 10% steps (Backspace clears it) |
| Option + ↑ / ↓ (Shift for 10pt steps) | Question position; 0 resets it to 150 |
