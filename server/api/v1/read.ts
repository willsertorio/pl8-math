import { handleRead, liveDeps } from "../../lib/handlers.js";

export async function POST(request: Request): Promise<Response> {
  return handleRead(request, await liveDeps());
}
