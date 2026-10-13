# Test fixtures

Real inputs from Will's box and the results the app must produce. Every bug found at the box adds a fixture here first.

## Workouts (`workouts/`)

| File | What it is |
|---|---|
| `2026-10-01.png` | Screenshot from the box's app, 01/10 |
| `2026-10-01.ocr.txt` | Text read from it (Tesseract, during prototyping). Regenerate with Vision in M2 and keep both. |
| `2026-10-02.png` / `.ocr.txt` | 02/10 |
| `2026-10-05.png` / `.ocr.txt` | 05/10 — the Back Squat line in block D is hidden under the app's "Check-In" button |
| `2026-10-01.vision.txt` | 01/10 read by Vision on the iPhone (from Will's own screenshot; again a Cyrillic А in "A.") |
| `2026-10-02-app.vision.txt` | 02/10 as the box's app showed it later, read by Vision (no image saved): block B is a fixed-load AMRAP and C is "C. After a Party" on one line |
| `2026-10-13.webp` / `.vision.txt` | 13/10 — read by Vision on the iPhone. Vision read "A." with a **Cyrillic А** (and Cyrillic letters in "TIMECAP"), so the block was missed. |

### Expected parse

**01/10**
- A · Back Squat · EMOM · prLift `Back Squat` · 5 sets × 3 reps: `75–78`, `75–78`, `78–80`, `78–80`, `80+`
- B (300m run + fixed loads 115/80): ignored

**02/10**
- A · Snatch Balance · EMOM · prLift `Snatch Balance` · 6 × 1: `68, 68, 73, 73, 75, 75`
- B · Snatch Pull + Snatch · prLift `Snatch` · 8 × 1: `68, 68, 70, 73, 75, 75, 78, 78` · note "Rest 2 minutes between sets"
- C (For Time: double unders, GHD, toes to bar): ignored

**05/10**
- A (Snatch Deadlift + Floating complex, no %): ignored
- B · Snatch · EMOM · prLift `Snatch` · 6 × 1: `75–80` ×3, `80–83` ×3
- C (dumbbell snatch + lunges, 50/35): ignored
- D "After Party" · Back Squat · EMOM · prLift `Back Squat` · 5 × 2 · **pctMissing** (the user then enters `83-85`)

**01/10** (`.vision.txt`): same as 01/10 above.

**02/10, app version** (`2026-10-02-app.vision.txt`)
- A · Snatch Balance · EMOM · 6 × 1: `68, 68, 73, 73, 75, 75`
- B (Back Squats 225/155, RPE 8, no %): ignored
- C "After a Party" (For Time): ignored

**13/10** (`.vision.txt`)
- A · Split Jerk · EMOM · prLift `Split Jerk` · 6 × 1: `83, 83, 85, 85, 85–88, 85–88`
- B (run, double unders, wall walks): ignored
- C "After a Party" (planks, cut off by Check-In, no %): ignored

## Golden loads (M1)

Gym plate sets used below — **lb**: 55, 45, 35, 25, 15, 10, 5, 2.5 · **kg**: 25, 20, 15, 10, 5, 2.5, 2, 1.5, 1, 0.5.
Format: `reps @ total [plates per side]`. Totals in the gym's unit.

### 01/10 · Back Squat PR 100 kg · lb gym, 45 lb bar
- Warm-up: `5@85 [15+5]` · `3@120 [35+2.5]` · `3@145 [45+5]`
- Back Squat: `3@170 [55+5+2.5]` · `3@170 [55+5+2.5]` · `3@175 [55+10]` · `3@175 [55+10]` · `3@180 [55+10+2.5]`
- Kit: 2×55, 2×45, 2×35, 2×15, 2×10, 2×5, 2×2.5
- Display: set 1 shows `77.1 kg` (PR unit), plates in lb

### 01/10 · same PR · kg gym, 20 kg bar
- Warm-up: `5@39 [5+2.5+2]` · `3@55 [15+2.5]` · `3@66 [20+2.5+0.5]`
- Back Squat: `3@78 [25+2.5+1.5]` ×2 · `3@80 [25+5]` ×3
- Kit: 2×25, 2×20, 2×15, 2×5, 2×2.5, 2×2, 2×1.5, 2×0.5

### 02/10 · Snatch Balance PR 100 kg, Snatch PR 85 kg · lb gym, 45 lb bar
- Warm-up: `5@75 [15]` · `3@105 [25+5]` · `1@125 [35+5]`
- Snatch Balance: `1@150 [45+5+2.5]` ×2 · `1@160 [55+2.5]` ×2 · `1@165 [55+5]` ×2
- Snatch Pull + Snatch: `1@125 [35+5]` ×2 · `1@130 [35+5+2.5]` · `1@135 [45]` · `1@140 [45+2.5]` ×2 · `1@145 [45+5]` ×2
- Kit: 2×55, 2×45, 2×35, 2×25, 2×15, 2×5, 2×2.5

### 05/10 · Snatch PR 85 kg, Back Squat PR 140 kg, user enters 83-85 for D · lb gym, 45 lb bar
- Warm-up: `5@70 [10+2.5]` · `3@100 [25+2.5]` · `1@125 [35+5]`
- Snatch: `1@145 [45+5]` ×3 · `1@155 [55]` ×3
- Back Squat: `2@260 [55+45+5+2.5]` ×5
- Kit: 2×55, 2×45, 2×35, 2×25, 2×10, 2×5, 2×2.5
- Change text, Snatch set 3 → 4: "Take off 5 + 45, then add 55 each side"

### 05/10 · same · kg gym, 20 kg bar
- Warm-up: `5@34 [5+2]` · `3@48 [10+2.5+1.5]` · `1@58 [15+2.5+1.5]`
- Snatch: `1@68 [20+2.5+1.5]` ×3 · `1@70 [25]` ×3
- Back Squat: `2@119 [25+20+2.5+2]` ×5
- Kit: 2×25, 2×20, 2×15, 2×10, 2×5, 2×2.5, 2×2, 2×1.5

### Edge: target lighter than the bar · Snatch PR 60 kg @20% · kg gym, 20 kg bar
- Warm-up: one round `5@20 []`
- Snatch: `3@20 []`, flagged "Lighter than the bar"
- Kit: just the bar

### Edge: missing small plates · Back Squat PR 100 kg @75–78% ×5 reps · lb gym with only 45, 35, 25, 15, 10 · 45 lb bar
- Warm-up: `5@85 [10+10]` · `5@115 [35]` · `5@145 [35+15]`
- Back Squat: `5@165 [45+15]`
- Kit: 2×45, 2×35, 2×15, **4×10**
- (The prototype gave `5@125 [25+15]` for round 2 because it only tried totals in steps of 2 × the smallest plate. Changed to follow SPEC 3.3 — see DECISIONS.md 2026-10-13.)

These numbers come from `reference/plate-math-web-prototype.html`, the web prototype Will tested at the box. If a Swift result differs, check the rule in `SPEC.md` 3.3–3.5 before changing either.
