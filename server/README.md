# pl8(math) read server

The cloud step of reading a photo (`docs/DATA-AND-SERVICES.md` §3). It does one job: it holds the Anthropic key and
asks Claude (`claude-haiku-5-5`) to read a workout or a PR list into the app's result. It has no database and no
accounts; it stores only one-time challenges, each phone's App Attest key and its read count per day. It never
stores or logs what a read contained, only the route, status, time and model.

| Endpoint | Body | Answer |
|---|---|---|
| `GET /v1/challenge` | | `{ "challenge" }`, good for five minutes, once |
| `POST /v1/attest` | `{ "keyId", "attestation", "challenge" }` (base64 attestation) | `204`, or `401` |
| `POST /v1/read` | `{ "kind": "workout" \| "prs", "text", "image"?, "locale", "unit" }`, headers `X-Attest-Key-Id` and `X-Attest-Assertion` (signed over the body) | `200` with the result (§2.4), `422 { "error": "unreadable" }`, `401` (attest again), `429` (20 reads a day) |

## Run the tests

```bash
cd server
npm ci
npm test          # real Apple attestations, signed requests, the three endpoints with a stand-in for Claude
npm run typecheck
```

## Deploy it (once, on Vercel)

1. **Vercel:** import this repository, set **Root Directory** to `server`. `vercel.json` pins the functions to
   Frankfurt (`fra1`), so they run in the EU as the privacy policy says.
2. **Store:** in the Vercel project, Storage → add **Upstash for Redis**, region **eu-central-1 (Frankfurt)**. It sets
   `KV_REST_API_URL` and `KV_REST_API_TOKEN`, which the server reads.
3. **Anthropic:** in the Anthropic Console, create an API key for this server only and set a **monthly spend limit**
   (Settings → Limits). The policy names Claude by Anthropic: if you ever switch providers, the policy changes too.
4. **Environment variables** (Vercel → Settings → Environment Variables):
   | Name | Value |
   |---|---|
   | `ANTHROPIC_API_KEY` | the key from step 3 |
   | `APPLE_TEAM_ID` | `KK29776897` (your team, from the Xcode project) |
   | `APPLE_BUNDLE_ID` | `com.williansertorio.pl8` |
   | `APP_ATTEST_ALLOW_DEVELOPMENT` | `1` while you run builds from Xcode or TestFlight; remove it for the App Store |
5. **Logs:** Vercel's request logs show URLs and statuses, never bodies. Leave log drains off.
6. **The app:** put the deployment's address (e.g. `https://pl8-read.vercel.app`) in `pl8/Info.plist` as
   `PL8ReadServer`. Until then the app never uses the cloud.

Apple's root certificate is in `lib/apple-app-attestation-root-ca.pem`. Its SHA-256 fingerprint is
`1C:B9:82:3B:A2:8B:A6:AD:2D:33:A0:06:94:1D:E2:AE:4F:51:3E:F1:D4:E8:31:B9:F7:E0:FA:7B:62:42:C9:32`; you can check it
against the one at https://www.apple.com/certificateauthority/Apple_App_Attestation_Root_CA.pem.

The test attestations in `test/fixtures` come from [node-app-attest](https://github.com/uebelack/node-app-attest)
(MIT, see `test/fixtures/LICENSE-node-app-attest`).
