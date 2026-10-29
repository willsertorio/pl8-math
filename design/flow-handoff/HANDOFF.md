# Plate Math: Flow prototype → iOS handoff

**v2:** read `CHANGES-v2.md` for what changed since the first handoff; this file is updated to match.

This folder is the design reference for the new app experience, called "the Flow": one question at a time, one 3D object per question, and a menu after the first session. Your job is to bring the iOS app in line with it.

- `prototype/` is the running reference. Open `prototype/index.html` in Chrome or Safari; it needs internet for Google Fonts. Tap the opening screen to start.
  - **W:** toggles rough edges.
  - **C:** toggles the background.
  - **On a phone:** double-tap the clock (rough edges) or the battery (background) instead.
- `source/` is the readable source of the prototype (web: three.js + cannon-es). It's a reference for behaviour and numbers, not code to port line by line.

**Before writing anything:** read the existing iOS codebase, map each section below to its screens and components, and list the differences. Ask me before replacing whole screens. Keep the app's existing architecture, 3D/physics stack and data layer, and change behaviour and visuals to match this spec.

---

## 1. Global rules (apply everywhere)

### Look
| Token | Value | Used for |
|---|---|---|
| `bg` | `#E5321C` | Red background on question screens, the menu, the scale and the opening |
| `light` | `#F4F1EA` | Light background (kit and sets), whiteboard surface, gym room walls, ink on red |
| `dark` | `#151515` | Ink on light screens: text, card text, chips, buttons, notebook cover, board frame, empty-gym lines |
| card | `#FFFFFF` | Kit chips card and set card (white, 22px radius, soft shadow) |
| accent | `#E5321C` | Finished-set progress dots |

**Type:** Helvetica Neue, five roles. The full table is in `CHANGES-v2.md` §1.
- **Display (questions, set titles):** 500 / 33pt, tracking −0.035em.
- **Labels under objects:** 500 / 21pt.
- **Body (cards, chips, buttons):** 400 / 17pt.
- **Small caps:** 500 / 12pt, all caps, +0.04em.
- **Numbers:** 500 / 32pt, tabular.

Handwriting on surfaces (whiteboard, notebook page and cover) uses Permanent Marker.

**Edges:** a post-process "sketch" pass gives rough hand-drawn outlines, plus duotone and posterize; see `source/glfx.js`.
- **Defaults:** question screens, the menu and the end-of-session scale are rough on orange. The kit and the sets are smooth on the light grid background (26px grid lines in `dark` at 9%).
- **Toggles:** the user can flip either default (the W / C keys in the prototype).

**Text:** centred, with the top of the question **150pt** from the top of the screen. The object below moves down to match (`CHANGES-v2.md` §3). Don't add helper or hint text anywhere; the objects explain themselves.

### Text reveal
Questions appear word by word with no fade (each word just becomes visible). Spoken timing:
- **Per word:** 95ms + 18ms per letter.
- **Pauses:** +230ms after `, ; :` and +420ms after `. ? !`.
- **Object entrance:** the screen's 3D object enters only after the sentence has finished.

### Transitions between questions: the pan
Nothing scales or fades. The camera moves straight down one screen-height along its own up axis. The question and the current object stay where they are in the world and slide up off screen together, and the next screen is waiting below.
- **Out:** ease-in quad over 0.30s.
- **In:** ease-out cubic over 0.45s. The speeds match where the two halves meet, so it reads as one continuous move.
- **Grid background:** moves with the pan.

### Gestures follow the finger (core premise)
Every navigation swipe is interactive: the screen follows the finger, commits past a threshold, otherwise springs back with an ease-out.
- **Back to the menu (from any menu edit):** swipe up; past about 110px it commits.
- **Kit:** drag down to go back to the board, drag up (or tap) to go to the sets.
- **Sets:** drag to change sets, or drag down on the first set to go back to the kit.
- **Menu item:** zooms back out as the finger moves.

### Sound and haptics
- **Light check sound:** when a step is confirmed.
- **Clicks:** on dial detents, plates landing and plates seating on the bar.
- **Haptics:** selection ticks on dials and carousels.
- **No sound:** when scrolling the menu, or when confirming each PR.

### Physics (all drops and drags)
- **Engine:** gravity 9.81, solver iterations 20, tolerance 0.0005.
- **Contacts:** plate–ground friction 0.55, restitution 0.2; plate–plate friction 0.35, restitution 0.12.
- **Damping:** linear 0.03, angular 0.06.
- **Sleep:** speed 0.06, time 0.8s.
- **Grab spring:** k 260, ζ 0.85, max force 140 × mass, angular damping 0.45 while held.
- **Impacts:** screen shake = trauma² × 0.1, a small squash on the object, and low-poly dust (colour `#E9E2D6`).

---

## 2. First run (onboarding)

1. **Gym name: "What's the name of your Gym?"**
   - **Dials:** two low-poly letter dials (A–Z, 0–9), front view, slide in from the left one after the other.
   - **Picking:** spin one dial, tap to lock it, then the second becomes active.
   - **Done:** a shine and sparkles, then pan.
2. **Units: "Cool. Let's set {name}. Do they use kilos or pounds there?"**
   - **Kettlebells:** KG and LB bells fall with physics. They never rotate or tip, even while dragged; they don't slide on landing.
   - **Floor square:** a fixed outline with a light platform inside. Only the inner platform sinks, slightly, like a scale.
   - **Choosing:** drop a bell on the platform to choose that unit. The other bell is abducted: a light beam and a glowing pool, and it lifts, spins and shrinks into the light.
3. **Plates: "What are the plates available?"**
   - **Layout:** a checklist, with the plates in a left column, top to bottom, weight beside each, and hand-drawn YES / NO boxes.
   - **Entrance:** rows appear one by one every 90ms (plate, weight and boxes together), with no fall, fade or easing.
   - **Ticking:** draw on the screen. One long stroke can tick a whole column, because every box the line passes through gets a check mark that draws itself in. The trail fades on release.
   - **Other inputs:** tapping a box also ticks it; ticking one box clears the other in that row.
   - **States:** a NO plate turns grey and see-through.
   - **Done:** when every row is answered, the YES plates shine, then pan.
4. **Bar: "What bar do you use?"**
   - **Carousel:** a horizontal carousel of tilted, spinning bars with weight labels under them. The 15 kg bar starts centred.
   - **Picking:** tap or swipe up to pick; it shines and twinkles.
5. **PRs: "Alright. And what are your PRs?"**
   - **Notebook:** it pops in and opens itself almost flat, centred, and a pencil (no cap) pops in at the bottom-right of the page. There are no buttons.
   - **Pencil:** tap it to type PRs on a number dial, one lift at a time, with a KG/LB switch; swipe up confirms each lift.
   - **Notebook:** tap it to upload a photo through the system picker. The page fills, the notebook closes and shines, then pan.
6. **Workout: "You're strong! What are we doing today?"**
   - **Entrance:** a whiteboard on wheels rolls in from the right, turning, and slows to a stop with no wobble. It rests slightly angled, with the same soft blob shadow as the menu's Train board.
   - **Upload:** tap the board to upload (system picker), and the workout is written on the board.
   - **Wipe:** scrub the board with a finger to wipe it clean. Once about 45% is wiped, it clears fully and a tap uploads again.
   - **Start:** tapping a board with a workout zooms into it and goes to the kit.
7. **Plate kit.**
   - **Layout:** plates drop one at a time onto a layout you can count at a glance: one line per size, each plate flat on its own spot, heaviest first, and smaller sizes sharing a line.
   - **Card:** a white card at the bottom with chips ("4 × 25 kg"), which the user can check off.
   - **Interaction:** plates can be dragged with physics.
   - **Drag down:** the plates fold away and the camera pulls back out of the board, the reverse of the zoom in.
   - **Drag up or tap:** the camera pans down and the bar comes up from below, already framed like the sets.
8. **Sets.**
   - **Camera:** at the end of the bar (sleeve), with a little orbit on a sideways drag. A white card shows the group, "Round 2 of 3", reps and weight, and progress dots.
   - **Changing sets:** drag up for the next set, down for the previous one. The card follows the finger and the next card slides in. The plates also follow: the outer ones slide off the sleeve, the new ones slide on, outermost first, all tied to the drag.
   - **First set:** drag down pans back up to the kit, laid out exactly as it was.
   - **Last set:** the card has an "End session" button.
9. **Scale.** The end-of-session animation weighs the heaviest set of the session (bar plus plates, both sides). It has rough edges by default. Tap to go to the menu.

---

## 3. Menu (after the first session)

- **Carousel:** three objects in a drag carousel with labels under them: **Train** (whiteboard), **My PRs** (notebook), **Gym** (box with the gym's initials).
- **Activating an item:** tap the centred item for a small zoom toward it, so it "wakes up" in place. Nothing is removed and nothing re-enters.
- **Leaving an item:** swipe up and it zooms back out with the finger.
- **Train:** the board always shows the last session.
  - **Start:** tap the board to start (zoom into the board, then the kit).
  - **Wipe:** scrub to wipe it clean, then tap to upload a new one, then tap again to start.
- **My PRs:** the notebook turns, opens almost flat and centred, and the pencil appears.
  - **Pencil:** tap it to edit the numbers on the dials.
  - **Notebook:** tap it to upload a photo.
- **Gym:** the box opens into a small isometric room. The lid lifts off and the front and right walls fall outward.
  - **Back wall:** a flag with the gym name, hanging from its top edge and waving, with no rod. Underneath it, along that wall: tall sorted piles of the gym's plates.
  - **Side wall:** three bars racked on hooks.
  - **Front corner by the bar wall:** a small kettlebell with the unit.
  - **Editing:** tap any of them (generous tap areas) to edit just that one thing (flag → name, bars → bar, plates → checklist, kettlebell → units). It returns straight to the open room.
  - **Edits start pre-filled:** the dials are on the current name, the plates are already ticked, and the bar is centred. Only the kettlebell choice starts fresh. In the plates checklist, changes save as you go, and it returns once you stop drawing for about 2 seconds.
  - **Several gyms:** swipe sideways in the room to move between gyms; the one you settle on becomes current. The last slot is an empty cube at about 70% size, drawn with dashed `dark` edges and no fill, shadow or plus. It slowly grows and shrinks and turns gently from side to side; tap it to set up a new gym through name → units → plates → bar.
  - **Delete:** press and hold a room for about 0.6s to get the native iOS alert "Delete {name}?" with Cancel and Delete. You can't delete the last gym; that shows an alert with only "OK".

---

## 4. Data model notes

A gym is `{ name, unit, ownedPlates[unit], bar[unit] }`, and the app keeps a list of gyms plus the current index. Each workout session keeps its plan, so the Train board can show the last session.

---

## 5. Where things are in `source/`

The prototype is one big class built from fragments. **Later files override earlier ones**, so the newest version of each function lives in the highest-numbered `comp_flow*.js` that defines it.

| Topic | Function(s) | File (latest) |
|---|---|---|
| Text reveal | `flSay` | comp_flow6.js |
| Pan transitions | `flPanTo`, `flGo`, `flPanGeo` | comp_flow7.js |
| Swipe-back that follows the finger | `flPanBackBind`, `flPanLive`, `flPanFinish` | comp_flow8.js |
| Gym name dials | `flName`, `flDrum` | comp_flow5.js |
| Kettlebells and scale platform | `flUnit` | comp_flow5.js |
| Plates checklist | `flPlates` | comp_flow8.js |
| Bar carousel | `flBarQ` | comp_flow5.js |
| PRs (onboarding) | `flPRs`, `penModel` | comp_flow9.js, comp_flow8.js |
| PR dial | `flPRDial` | comp_flow5.js |
| Whiteboard and wipe | `flWod`, `flBoardWiper`, `flDrawBoard`, `whiteboardModel` | comp_flow8.js, comp_flow11.js, comp_flow5.js, comp_flow4.js |
| Kit layout and drop | `flKitLayout`, `flKit` | comp_flow9.js, comp_flow4.js |
| Kit ↔ board / sets previews | `flKitPreview`, `flProxyAt` | comp_flow8.js, comp_flow9.js |
| Sets, card and plate swipes | `flSets`, `flCardDrag`, `flPlateSwap`, `flSetsKitDrag`, `flSetCardEl` | comp_flow9.js |
| Menu, items, gyms, delete | `flMenu`, `gymRoomModel`, `gymAddModel`, `flGym*`, `flAlert` | comp_flow8.js, comp_flow10.js |
| End scale | `flFinish`, `showSessionOver` | comp_flow11.js, comp_b.js |
| Physics config | `get PHYS` | comp_flow3.js |
| Rough-edge pass | `GLFX` | glfx.js |
| v2: palettes, question position, letter collage, board shadow | `FLPALS`, `flPalSet`, `flQShift`, `flSay`, `flCollage`, `flBoardShadow` | comp_flow12.js |
| v2: Helvetica type roles | applied at build time (Flow only) | `build.py` notes in CHANGES-v2.md §1 |
