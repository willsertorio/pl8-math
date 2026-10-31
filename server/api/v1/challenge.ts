import { handleChallenge, liveDeps } from "../../lib/handlers.js";

export async function GET(): Promise<Response> {
  return handleChallenge(await liveDeps());
}
