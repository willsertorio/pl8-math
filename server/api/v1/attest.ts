import { handleAttest, withLiveDeps } from "../../lib/handlers.js";

export async function POST(request: Request): Promise<Response> {
  return withLiveDeps((deps) => handleAttest(request, deps));
}
