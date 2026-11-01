import assert from "node:assert/strict";
import { test } from "node:test";
import { DAILY_READS, handleAttest, handleChallenge, handleRead, type Deps } from "../lib/handlers.js";
import type { ReadResult } from "../lib/schema.js";
import { memoryStore } from "../lib/store.js";
import { fixture, fixtureApp, in2024, phone } from "./helpers.js";

const workout: ReadResult = {
  kind: "workout", unit: "kg",
  blocks: [{ label: "A", lift: "Back squat", sets: [{ reps: 5, percent: 75, weight: null }], note: null }],
};

function deps(overrides: Partial<Deps> = {}) {
  const logged: Record<string, unknown>[] = [];
  const store = memoryStore();
  const all: Deps = { store, read: async () => workout, app: fixtureApp, now: () => in2024, log: (entry) => logged.push(entry), ...overrides };
  return { deps: all, store, logged };
}

const post = (path: string, body: string | Buffer, headers: Record<string, string> = {}) =>
  new Request(`https://read.example${path}`, { method: "POST", body: typeof body === "string" ? body : new Uint8Array(body),
                                               headers: { "content-type": "application/json", ...headers } });

test("a challenge is given once and taken by the attestation that uses it", async () => {
  const { deps: d, store } = deps();
  const { challenge } = await (await handleChallenge(d)).json();
  assert.ok(store.keys().includes(`challenge:${challenge}`));

  // Attest a real key against the challenge its app was given.
  const { keyId, attestation, challenge: bytes } = fixture("development");
  await store.set(`challenge:${bytes.toString("utf8")}`, "1");
  const body = JSON.stringify({ keyId, attestation: attestation.toString("base64"), challenge: bytes.toString("utf8") });
  assert.equal((await handleAttest(post("/v1/attest", body), d)).status, 204);
  assert.ok(store.keys().includes(`key:${keyId}`));
  // Used up: the same challenge can't attest again.
  assert.equal((await handleAttest(post("/v1/attest", body), d)).status, 401);
});

test("a read signed by an attested key gets the result; nothing it contained is logged", async () => {
  const { deps: d, store, logged } = deps();
  const { key, assert: sign } = phone(fixtureApp);
  await store.set("key:phone", JSON.stringify(key));
  const body = Buffer.from(JSON.stringify({ kind: "workout", text: "Back squat 5x5 @ 75%", locale: "es-ES", unit: "kg" }));
  const response = await handleRead(post("/v1/read", body, { "x-attest-key-id": "phone", "x-attest-assertion": sign(body, 1).toString("base64") }), d);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), workout);
  assert.deepEqual(Object.keys(logged[0]).sort(), ["model", "ms", "route", "status"]);
  // The counter moved on: the same assertion again is refused.
  assert.equal(JSON.parse((await store.get("key:phone"))!).counter, 1);
  const replay = await handleRead(post("/v1/read", body, { "x-attest-key-id": "phone", "x-attest-assertion": sign(body, 1).toString("base64") }), d);
  assert.equal(replay.status, 401);
});

test("no key, an unknown key or a bad request are refused", async () => {
  const { deps: d, store } = deps();
  const { key, assert: sign } = phone(fixtureApp);
  await store.set("key:phone", JSON.stringify(key));
  const body = Buffer.from("{}");
  assert.equal((await handleRead(post("/v1/read", body), d)).status, 401);
  assert.equal((await handleRead(post("/v1/read", body, { "x-attest-key-id": "other", "x-attest-assertion": sign(body, 1).toString("base64") }), d)).status, 401);
  assert.equal((await handleRead(post("/v1/read", body, { "x-attest-key-id": "phone", "x-attest-assertion": sign(body, 1).toString("base64") }), d)).status, 400);
});

test("twenty reads a day per phone", async () => {
  const { deps: d, store } = deps();
  const { key, assert: sign } = phone(fixtureApp);
  await store.set("key:phone", JSON.stringify(key));
  const body = Buffer.from(JSON.stringify({ kind: "prs", text: "Deadlift 180 kg", locale: "en-US", unit: "kg" }));
  const statuses: number[] = [];
  for (let counter = 1; counter <= DAILY_READS + 1; counter++) {
    const response = await handleRead(post("/v1/read", body, { "x-attest-key-id": "phone", "x-attest-assertion": sign(body, counter).toString("base64") }), d);
    statuses.push(response.status);
  }
  assert.deepEqual(statuses.slice(0, DAILY_READS), Array(DAILY_READS).fill(200));
  assert.equal(statuses[DAILY_READS], 429);
});

test("an answer that isn't clear, or is outside the limits, is unreadable", async () => {
  const { key, assert: sign } = phone(fixtureApp);
  const body = Buffer.from(JSON.stringify({ kind: "workout", text: "Run 400 m", locale: "en-US", unit: "kg" }));
  const unlikely: ReadResult = { ...workout, blocks: [{ ...workout.blocks[0], sets: [{ reps: 5, percent: 175, weight: null }] }] };
  for (const read of [async () => null, async () => unlikely, async () => { throw new Error("overloaded"); }]) {
    const { deps: d, store } = deps({ read });
    await store.set("key:phone", JSON.stringify(key));
    const response = await handleRead(post("/v1/read", body, { "x-attest-key-id": "phone", "x-attest-assertion": sign(body, 1).toString("base64") }), d);
    assert.ok([422, 502].includes(response.status));
    assert.deepEqual(await response.json(), { error: "unreadable" });
  }
});
