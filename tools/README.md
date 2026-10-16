# Automatic checks

Every push runs `.github/workflows/ci.yml` on GitHub:

- **PlateKit tests + prototype check** (Linux): `swift test`, then `visual-check/compare.mjs` renders each camera
  station twice — from the prototype's own code (`reference/prototype-app-logic.js`) and from PlateKit's baked room —
  and scores how much of the picture differs. It fails when a station differs on 1 % more of the picture than
  `visual-check/baseline.json` says. Side-by-side pictures (prototype | app | difference) are in the
  `prototype-check` artifact.
- **App build + screenshots** (macOS): builds the app for the iPhone Simulator and takes screenshots of its main
  screens in screenshot mode (`-pl8Shot <screen>`, demo data in memory; see `pl8/pl8/ScreenshotMode.swift`). They are
  in the `screenshots` artifact with the build log.

Run the prototype check locally:

```sh
cd PlateKit && PL8_SCENE_DUMP=$PWD/../tools/visual-check/out swift test --filter SceneDump
cd ../tools/visual-check && npm ci && npx playwright install chromium && node compare.mjs
```

When a change is meant to look different, update the baseline: `UPDATE_BASELINE=1 node compare.mjs`.
