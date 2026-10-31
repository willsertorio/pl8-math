import assert from "node:assert/strict";
import { test } from "node:test";
import { AttestError, verifyAssertion, verifyAttestation } from "../lib/appattest.js";
import { fixture, fixtureApp, in2024, phone } from "./helpers.js";

test("a real attestation from Apple's development environment passes", () => {
  const { keyId, attestation, challenge } = fixture("development");
  const key = verifyAttestation({ keyId, attestation, challenge, app: fixtureApp, now: in2024 });
  assert.match(key.publicKey, /BEGIN PUBLIC KEY/);
  assert.equal(key.counter, 0);
});

test("a real attestation from Apple's production environment passes, even when development isn't allowed", () => {
  const { keyId, attestation, challenge } = fixture("production");
  verifyAttestation({ keyId, attestation, challenge, app: { ...fixtureApp, allowDevelopment: false }, now: in2024 });
});

test("an attestation fails for another challenge, key, app, environment or date", () => {
  const { keyId, attestation, challenge } = fixture("development");
  const fails = (input: Partial<Parameters<typeof verifyAttestation>[0]>) =>
    assert.throws(() => verifyAttestation({ keyId, attestation, challenge, app: fixtureApp, now: in2024, ...input }), AttestError);
  fails({ challenge: Buffer.from("another challenge") });
  fails({ keyId: fixture("production").keyId });
  fails({ app: { ...fixtureApp, bundleId: "com.williansertorio.pl8" } });
  fails({ app: { ...fixtureApp, allowDevelopment: false } });
  fails({ now: new Date("2026-10-30T00:00:00Z") });
  fails({ attestation: Buffer.from("not cbor at all") });
});

test("an assertion passes once per counter, for this body and this app", () => {
  const app = { teamId: "KK29776897", bundleId: "com.williansertorio.pl8", allowDevelopment: false };
  const { key, assert: sign } = phone(app);
  const body = Buffer.from(JSON.stringify({ kind: "workout", text: "Back squat 5x5 @ 75%" }));
  assert.equal(verifyAssertion({ assertion: sign(body, 1), body, key, app }), 1);
  // The same counter again (a replay), another body, another app: refused.
  assert.throws(() => verifyAssertion({ assertion: sign(body, 1), body, key: { ...key, counter: 1 }, app }), AttestError);
  assert.throws(() => verifyAssertion({ assertion: sign(body, 2), body: Buffer.from("{}"), key: { ...key, counter: 1 }, app }), AttestError);
  assert.throws(() => verifyAssertion({ assertion: sign(body, 2, { ...app, bundleId: "x.y" }), body, key: { ...key, counter: 1 }, app }), AttestError);
  assert.equal(verifyAssertion({ assertion: sign(body, 2), body, key: { ...key, counter: 1 }, app }), 2);
});
