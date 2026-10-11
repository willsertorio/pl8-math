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
