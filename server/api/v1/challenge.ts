import { handleChallenge, withLiveDeps } from "../../lib/handlers.js";

export async function GET(): Promise<Response> {
  return withLiveDeps((deps) => handleChallenge(deps));
}
