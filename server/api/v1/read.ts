import { handleRead, withLiveDeps } from "../../lib/handlers.js";

export async function POST(request: Request): Promise<Response> {
  return withLiveDeps((deps) => handleRead(request, deps));
}
