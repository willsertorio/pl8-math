# Decision log

Short entries, newest last. Why we chose something, so future-me (and anyone reading the portfolio) can follow the thinking.

- **2026-10-01 · Prototype on the web first.** Validate the flow at the box before writing native code. A web page with real plate math was enough to learn what was missing.
- **2026-10-01 · Load rule: heaviest load inside the range.** For "75–78%" pick the heaviest load the plates can make inside the range; "80%+" picks the lightest load at or above 80%.
- **2026-10-02 · Only strength work matters.** The app reads the whole screenshot but keeps only blocks with % of 1RM. Learned at the box: a day can have two strength blocks.
- **2026-10-02 · Set number and reps are the headline.** At the box the set number was too faint; the load is secondary.
- **2026-10-02 · Built-in warm-up.** Three rounds up to the first working load, because working out the warm-up was the next piece of mental math at the box.
- **2026-10-03 · Scope: Train, PRs, Gyms, History.** Gym search via Google Places and shared gym setups are deferred (local-only v1).
- **2026-10-03 · Ask what was lifted only on the last set.** Keeps history honest and detects new PRs without adding friction to every set.
- **2026-10-04 · Anything with % is strength.** A block called "After Party" was missed. Also: when the % is hidden on the screenshot, ask instead of guessing.
- **2026-10-11 · Native Swift + RealityKit, not React Native or a web view.** Best feel and performance, and the point is learning native iOS. Cost: the 3D scene is rebuilt, not reused.
- **2026-10-11 · Build in 2D first, 3D after.** The math and flow must be right at the box before the 3D layer goes on top.
- **2026-10-11 · Free Apple developer account for now.** The app expires every 7 days; fine while building. Paid program when it's in weekly use.
- **2026-10-11 · Rules-first parsing, on device.** The box's format is regular; Vision OCR + rules works offline and free. AI only as a later fallback.
- **2026-10-13 · Any combination of plates counts as loadable.** The prototype only tried totals in jumps of 2 × the smallest plate, so with only 45/35/25/15/10 lb plates it skipped 115 lb (one 35 a side) for a 115.5 lb target and loaded 125. PlateKit follows SPEC 3.3: any sum of the gym's plates. Fixture updated.
- **2026-10-13 · A block can start with its label on the same line.** The box's app showed "C. After a Party" on one line, which wasn't read as block C. SPEC 3.6 rule 1 now accepts `C. After a Party`; the text after the dot is the label.
- **2026-10-14 · Sessions keep their lift names.** History should still say "Back Squat" after the workout it came from is deleted, so `Session` stores `liftNames` by block index.
- **2026-10-14 · History is a 4th tab.** Train · PRs · Gym · History; simplest in 2D, and the 3D wall calendar can link to it later.
- **2026-10-14 · "Type it in" is the simple form.** Lift, sets, reps, one %: fastest between sets. Per-set % still comes from screenshots.
- **2026-10-14 · M4 uses the spec look with the system font.** Black on white, square black buttons, outlined fields, orange background (SPEC 2.5) now, so screens aren't restyled later. Space Grotesk comes in when the font file is added.
- **2026-10-14 · Sessions keep each lift's PR unit.** Set totals are shown in the PR's unit (SPEC 3.2); storing `prUnits` with the session keeps that right even if a PR changes later.
- **2026-10-14 · Wrapped lines are joined before reading.** On 14/10 each Power Clean complex wrapped over 3 lines and block B was missed. SPEC 3.6 rule 2 now says how wrapped lines continue. Upload also takes several screenshots, in order, for workouts longer than one screen.
- **2026-10-14 · RPE blocks are read, with RPE × 10 suggested.** 14/10 block A was "@ 5/10 RPE". Instead of ignoring it, the app asks "What % for A?" with 50% filled in. Simple and predictable; an RPE chart was considered but has no values below RPE 6 and doesn't fit complexes. The PR is guessed from the first lift named and can be changed in Edit.
