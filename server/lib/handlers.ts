// The three endpoints (docs/DATA-AND-SERVICES.md §3), with what they depend on passed in so the tests can run them:
//   GET  /v1/challenge → { challenge }                         a one-time challenge for attesting a key
//   POST /v1/attest    { keyId, attestation, challenge } → 204  the phone's key, checked with Apple, kept
//   POST /v1/read      { kind, text, image?, locale, unit }     signed with that key → the result,
//                      → 200 result | 422 { error: "unreadable" } | 401 | 429
// Nothing a read contains is stored or logged: only the route, the status, the time and the model.
import { randomBytes } from "node:crypto";
import { z } from "zod";
import { AttestError, verifyAssertion, verifyAttestation, type App, type AttestedKey } from "./appattest.js";
import { MODEL, type Reader } from "./claude.js";
import { isLikely, ReadRequest } from "./schema.js";
import type { Store } from "./store.js";

export interface Deps {
  store: Store;
  read: Reader;
  app: App;
  now: () => Date;
  log: (entry: Record<string, unknown>) => void;
}

/** Reads per phone per day (§3, abuse limits). */
export const DAILY_READS = 20;
const CHALLENGE_SECONDS = 300;
const KEY_SECONDS = 400 * 24 * 3600;
const MAX_BODY = 5_000_000;

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

export async function handleChallenge(deps: Deps): Promise<Response> {
  const challenge = randomBytes(32).toString("base64url");
  await deps.store.set(`challenge:${challenge}`, "1", CHALLENGE_SECONDS);
  return json(200, { challenge });
}

const AttestBody = z.object({ keyId: z.string().max(100), attestation: z.string().max(20_000), challenge: z.string().max(100) });

export async function handleAttest(request: Request, deps: Deps): Promise<Response> {
  const start = Date.now();
  const response = await attest(request, deps);
  deps.log({ route: "attest", status: response.status, ms: Date.now() - start });
  return response;
}

async function attest(request: Request, deps: Deps): Promise<Response> {
  const body = AttestBody.safeParse(await request.json().catch(() => null));
  if (!body.success) return json(400, { error: "bad request" });
  const { keyId, attestation, challenge } = body.data;
  if (!(await deps.store.take(`challenge:${challenge}`))) return json(401, { error: "unknown challenge" });
  try {
    const key = verifyAttestation({ keyId, attestation: Buffer.from(attestation, "base64"), challenge: Buffer.from(challenge, "utf8"),
                                    app: deps.app, now: deps.now() });
    await deps.store.set(`key:${keyId}`, JSON.stringify(key), KEY_SECONDS);
    return new Response(null, { status: 204 });
  } catch (error) {
    if (error instanceof AttestError) return json(401, { error: "attestation" });
    throw error;
  }
}

export async function handleRead(request: Request, deps: Deps): Promise<Response> {
  const start = Date.now();
  const response = await read(request, deps);
  deps.log({ route: "read", status: response.status, ms: Date.now() - start, model: MODEL });
  return response;
}

async function read(request: Request, deps: Deps): Promise<Response> {
  const keyId = request.headers.get("x-attest-key-id");
  const assertion = request.headers.get("x-attest-assertion");
  if (!keyId || !assertion) return json(401, { error: "not attested" });
  const body = Buffer.from(await request.arrayBuffer());
  if (body.length > MAX_BODY) return json(413, { error: "too large" });

  // This phone's key, and a request it signed: a 401 makes the app attest again, once.
  const stored = await deps.store.get(`key:${keyId}`);
  if (!stored) return json(401, { error: "unknown key" });
  const key = JSON.parse(stored) as AttestedKey;
  try {
    const counter = verifyAssertion({ assertion: Buffer.from(assertion, "base64"), body, key, app: deps.app });
    await deps.store.set(`key:${keyId}`, JSON.stringify({ ...key, counter }), KEY_SECONDS);
  } catch (error) {
    if (error instanceof AttestError) return json(401, { error: "assertion" });
    throw error;
  }

  const day = deps.now().toISOString().slice(0, 10);
  if ((await deps.store.increment(`reads:${keyId}:${day}`, 2 * 24 * 3600)) > DAILY_READS) return json(429, { error: "limit" });

  const parsed = ReadRequest.safeParse(JSON.parse(body.toString("utf8") || "null"));
  if (!parsed.success) return json(400, { error: "bad request" });
  let result;
  try {
    result = await deps.read(parsed.data);
  } catch {
    return json(502, { error: "unreadable" });
  }
  if (!result || !isLikely(result)) return json(422, { error: "unreadable" });
  return json(200, result);
}

/** The deployed server's dependencies, from its environment variables. */
export async function liveDeps(): Promise<Deps> {
  const { redisStore } = await import("./store.js");
  const { claudeReader } = await import("./claude.js");
  const teamId = process.env.APPLE_TEAM_ID;
  if (!teamId) throw new Error("APPLE_TEAM_ID isn't set.");
  return {
    store: redisStore(),
    read: claudeReader(),
    app: { teamId, bundleId: process.env.APPLE_BUNDLE_ID ?? "com.williansertorio.pl8", allowDevelopment: process.env.APP_ATTEST_ALLOW_DEVELOPMENT === "1" },
    now: () => new Date(),
    log: (entry) => console.log(JSON.stringify(entry)),
  };
}
