import { handleAttest, liveDeps } from "../../lib/handlers.js";

export async function POST(request: Request): Promise<Response> {
  return handleAttest(request, await liveDeps());
}
