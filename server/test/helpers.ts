import { createHash, generateKeyPairSync, sign } from "node:crypto";
import { readFileSync } from "node:fs";
import { encode } from "cbor-x";
import type { App, AttestedKey } from "../lib/appattest.js";

/** Real attestations from Apple's servers, with the app they were made for (from node-app-attest, MIT:
 *  test/fixtures/LICENSE-node-app-attest). Their certificates were valid in 2024. */
export const fixtureApp: App = { teamId: "V8H6LQ9448", bundleId: "io.uebelacker.AppAttestExample", allowDevelopment: true };
export const in2024 = new Date("2024-06-01T12:00:00Z");

export function fixture(name: "development" | "production") {
  const data = JSON.parse(readFileSync(new URL(`./fixtures/attestation-${name}.json`, import.meta.url), "utf8"));
  return {
    keyId: data.keyId as string,
    attestation: Buffer.from(data.attestation, "base64"),
    /** The challenge as the app hashed it: its text's bytes. */
    challenge: Buffer.from(data.challenge, "base64"),
  };
}

/** A phone's key, made here, and assertions signed with it the way App Attest signs them. */
export function phone(app: App) {
  const { privateKey, publicKey } = generateKeyPairSync("ec", { namedCurve: "P-256" });
  const key: AttestedKey = { publicKey: publicKey.export({ type: "spki", format: "pem" }).toString(), counter: 0 };
  const assert = (body: Buffer, counter: number, signingApp: App = app) => {
    const authData = Buffer.alloc(37);
    createHash("sha256").update(`${signingApp.teamId}.${signingApp.bundleId}`).digest().copy(authData, 0);
    authData[32] = 0x40;
    authData.writeUInt32BE(counter, 33);
    const nonce = createHash("sha256").update(Buffer.concat([authData, createHash("sha256").update(body).digest()])).digest();
    return Buffer.from(encode({ signature: sign("sha256", nonce, privateKey), authenticatorData: authData }));
  };
  return { key, assert };
}
