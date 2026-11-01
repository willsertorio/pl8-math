// Apple App Attest on the server (docs/DATA-AND-SERVICES.md §3): only pl8(math) on a real iPhone may read.
// The phone attests a key once (verifyAttestation), then signs every request with it (verifyAssertion).
// Steps follow Apple's "Validating apps that connect to your server".
import { createHash, createPublicKey, verify as verifySignature, X509Certificate, type KeyObject } from "node:crypto";
import { readFileSync } from "node:fs";
import { decode } from "cbor-x";

/** Apple App Attestation Root CA (valid 2020–2045). SHA-256 fingerprint
 *  1C:B9:82:3B:A2:8B:A6:AD:2D:33:A0:06:94:1D:E2:AE:4F:51:3E:F1:D4:E8:31:B9:F7:E0:FA:7B:62:42:C9:32 —
 *  the same as https://www.apple.com/certificateauthority/Apple_App_Attestation_Root_CA.pem. */
const APPLE_ROOT = new X509Certificate(readFileSync(new URL("./apple-app-attestation-root-ca.pem", import.meta.url)));
const NONCE_OID = Buffer.from([0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x08, 0x02]); // 1.2.840.113635.100.8.2
const AAGUID_DEVELOPMENT = Buffer.from("appattestdevelop");
const AAGUID_PRODUCTION = Buffer.concat([Buffer.from("appattest"), Buffer.alloc(7)]);

export interface App {
  teamId: string;
  bundleId: string;
  /** Builds run from Xcode attest in Apple's development environment. */
  allowDevelopment: boolean;
}

export class AttestError extends Error {}

const sha256 = (...parts: Buffer[]) => createHash("sha256").update(Buffer.concat(parts)).digest();

/** A key the phone attested, kept with the last counter it signed with. */
export interface AttestedKey {
  publicKey: string; // PEM
  counter: number;
}

/** Checks a key's attestation against the challenge the server gave out. Returns the key to keep. */
export function verifyAttestation(input: { keyId: string; attestation: Buffer; challenge: Buffer; app: App; now?: Date }): AttestedKey {
  const { keyId, app } = input;
  let object: { fmt?: string; attStmt?: { x5c?: Uint8Array[] }; authData?: Uint8Array };
  try {
    object = decode(input.attestation);
  } catch {
    throw new AttestError("not an attestation");
  }
  const chain = object.attStmt?.x5c;
  if (object.fmt !== "apple-appattest" || !chain || chain.length !== 2 || !object.authData) throw new AttestError("not an attestation");
  const authData = Buffer.from(object.authData);

  // 1. The credential certificate, signed by Apple's intermediate, signed by Apple's root; all in date.
  const [credential, intermediate] = chain.map((der) => new X509Certificate(Buffer.from(der)));
  const now = input.now ?? new Date();
  for (const certificate of [credential, intermediate]) {
    if (now < new Date(certificate.validFrom) || now > new Date(certificate.validTo)) throw new AttestError("certificate out of date");
  }
  if (!intermediate.verify(APPLE_ROOT.publicKey) || !credential.verify(intermediate.publicKey)) throw new AttestError("not Apple's");

  // 2–4. The nonce in the certificate is SHA256(authData ‖ SHA256(challenge)).
  const nonce = sha256(authData, sha256(input.challenge));
  if (!nonceInCertificate(credential.raw)?.equals(nonce)) throw new AttestError("nonce does not match");

  // 5. The key id is the SHA256 of the certificate's public key (its uncompressed point).
  if (!sha256(rawPublicKey(credential.publicKey)).equals(Buffer.from(keyId, "base64"))) throw new AttestError("key id does not match");

  // 6–9. Our app, a fresh key (counter 0), the right environment, the same key id.
  const data = authenticatorData(authData);
  if (!data.rpIdHash.equals(sha256(Buffer.from(`${app.teamId}.${app.bundleId}`)))) throw new AttestError("another app");
  if (data.counter !== 0) throw new AttestError("counter is not 0");
  const aaguid = authData.subarray(37, 53);
  const development = aaguid.equals(AAGUID_DEVELOPMENT);
  if (!development && !aaguid.equals(AAGUID_PRODUCTION)) throw new AttestError("unknown environment");
  if (development && !app.allowDevelopment) throw new AttestError("development builds aren't allowed");
  const idLength = authData.readUInt16BE(53);
  if (!authData.subarray(55, 55 + idLength).equals(Buffer.from(keyId, "base64"))) throw new AttestError("credential id does not match");

  return { publicKey: credential.publicKey.export({ type: "spki", format: "pem" }).toString(), counter: 0 };
}

/** Checks a request's assertion: signed by the attested key over SHA256(body), for our app, with a counter that
 *  only goes up. Returns the new counter to keep. */
export function verifyAssertion(input: { assertion: Buffer; body: Buffer; key: AttestedKey; app: App }): number {
  let object: { signature?: Uint8Array; authenticatorData?: Uint8Array };
  try {
    object = decode(input.assertion);
  } catch {
    throw new AttestError("not an assertion");
  }
  if (!object.signature || !object.authenticatorData) throw new AttestError("not an assertion");
  const authData = Buffer.from(object.authenticatorData);
  if (authData.length < 37) throw new AttestError("not an assertion");
  const nonce = sha256(authData, sha256(input.body));
  if (!verifySignature("sha256", nonce, createPublicKey(input.key.publicKey), Buffer.from(object.signature))) throw new AttestError("bad signature");
  const data = authenticatorData(authData);
  if (!data.rpIdHash.equals(sha256(Buffer.from(`${input.app.teamId}.${input.app.bundleId}`)))) throw new AttestError("another app");
  if (data.counter <= input.key.counter) throw new AttestError("replayed");
  return data.counter;
}

function authenticatorData(data: Buffer) {
  return { rpIdHash: data.subarray(0, 32), counter: data.readUInt32BE(33) };
}

/** 0x04 ‖ x ‖ y of an EC P-256 key. */
function rawPublicKey(key: KeyObject): Buffer {
  const jwk = key.export({ format: "jwk" });
  if (!jwk.x || !jwk.y) throw new AttestError("not an EC key");
  return Buffer.concat([Buffer.from([0x04]), Buffer.from(jwk.x, "base64url"), Buffer.from(jwk.y, "base64url")]);
}

/** The credential certificate's extension 1.2.840.113635.100.8.2: SEQUENCE { [1] { OCTET STRING nonce } }. */
export function nonceInCertificate(der: Buffer): Buffer | undefined {
  const at = der.indexOf(NONCE_OID);
  if (at < 0) return undefined;
  let next = at + NONCE_OID.length;
  let field = tlv(der, next);
  if (field?.tag === 0x01) field = tlv(der, field.end); // "critical"
  if (field?.tag !== 0x04) return undefined; // the extension's value, as an OCTET STRING
  const sequence = tlv(der, field.start);
  if (sequence?.tag !== 0x30) return undefined;
  const tagged = tlv(der, sequence.start);
  if (tagged?.tag !== 0xa1) return undefined;
  const octets = tlv(der, tagged.start);
  if (octets?.tag !== 0x04) return undefined;
  next = octets.end;
  return der.subarray(octets.start, next);
}

/** One DER tag-length-value at `offset`: where its value starts and ends. */
function tlv(der: Buffer, offset: number): { tag: number; start: number; end: number } | undefined {
  if (offset + 2 > der.length) return undefined;
  const tag = der[offset];
  let length = der[offset + 1];
  let start = offset + 2;
  if (length & 0x80) {
    const bytes = length & 0x7f;
    if (bytes === 0 || bytes > 4 || start + bytes > der.length) return undefined;
    length = 0;
    for (let i = 0; i < bytes; i++) length = length * 256 + der[start + i];
    start += bytes;
  }
  const end = start + length;
  return end <= der.length ? { tag, start, end } : undefined;
}
