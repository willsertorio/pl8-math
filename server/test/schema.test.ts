import assert from "node:assert/strict";
import { test } from "node:test";
import { couldBeALift, isLikely, type ReadResult } from "../lib/schema.js";

const set = (reps: number, percent: number | null, weight: number | null) => ({ reps, percent, weight });
const workout = (sets: ReturnType<typeof set>[], unit: "kg" | "lb" | null = "kg"): ReadResult =>
  ({ kind: "workout", unit, blocks: [{ label: "A", lift: "Back squat", sets, note: null }] });

test("the same limits as the app's (PlateKit ReadResult.validated)", () => {
  assert.ok(isLikely(workout([set(5, 75, null)])));
  assert.ok(isLikely(workout([set(50, 30, null), set(1, 110, null)])));
  assert.ok(!isLikely(workout([set(0, 75, null)])));
  assert.ok(!isLikely(workout([set(51, 75, null)])));
  assert.ok(!isLikely(workout([set(5, 29, null)])));
  assert.ok(!isLikely(workout([set(5, 111, null)])));
  assert.ok(isLikely(workout([set(5, null, 500)])));
  assert.ok(!isLikely(workout([set(5, null, 501)])));
  assert.ok(isLikely(workout([set(5, null, 1100)], "lb")));
  assert.ok(!isLikely(workout([set(5, null, 1101)], "lb")));
  assert.ok(!isLikely(workout([])));
  assert.ok(!isLikely({ kind: "workout", unit: null, blocks: [] }));
  assert.ok(isLikely({ kind: "prs", unit: "kg", prs: [{ lift: "Deadlift", weight: 180 }] }));
  assert.ok(!isLikely({ kind: "prs", unit: "kg", prs: [] }));
  assert.ok(!isLikely({ kind: "prs", unit: "kg", prs: [{ lift: "Order completed", weight: 45.9 }] }));
});

test("names that can't be lifts", () => {
  for (const name of ["Order completed!", "Total R$", "Subtotal", "3 Back Squat @80%", "5G"]) assert.ok(!couldBeALift(name), name);
  for (const name of ["Back squat", "Clean & Jerk", "Zercher squat", "Sots press"]) assert.ok(couldBeALift(name), name);
});
