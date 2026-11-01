// The one thing the server does: ask Claude (by Anthropic) to read a workout or PR list into the app's result.
// The prompt holds only the task, the rules and the input. Anthropic's commercial terms don't train on it.
import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { PRsAnswer, WorkoutAnswer, type ReadRequest, type ReadResult } from "./schema.js";

/** A small, inexpensive Claude model with vision (docs/DATA-AND-SERVICES.md §3). */
export const MODEL = "claude-haiku-5-5";

const SYSTEM = {
  workout: `You read a CrossFit workout from the text recognised in a photo of a whiteboard or a box app, and \
sometimes the photo itself. Return only the strength work: each lift with its sets. A set has reps (1 to 50) and \
either a percent of the 1RM (30 to 110) or a fixed weight; null for what isn't written. Expand schemes like 5x5 or \
3-3-3 into one set each; an EMOM of N minutes with one set repeats it N times. Label is the block's letter (like A) \
or null; note holds a format like "EMOM 10" or null. Leave out conditioning work without a percent. Never guess: \
leave out anything unclear, and return no blocks if nothing is clear.`,
  prs: `You read a list of personal records (one-rep maxes) from the text recognised in a photo, and sometimes the \
photo itself. Return each lift with its weight, and the unit when it's written. Weights are between 1 and 500 kg or \
1 and 1100 lb. Leave out anything that isn't a lift, like totals, prices, dates or the phone's status bar. Never \
guess: return no PRs if nothing is clear.`,
};

export type Reader = (request: ReadRequest) => Promise<ReadResult | null>;

/** Claude's reading, or null when it declined or the answer didn't parse. */
export function claudeReader(client: Anthropic = new Anthropic()): Reader {
  return async (request) => {
    const content: Anthropic.ContentBlockParam[] = [];
    if (request.image) {
      content.push({ type: "image", source: { type: "base64", media_type: "image/jpeg", data: request.image } });
    }
    content.push({
      type: "text",
      text: `Phone locale: ${request.locale}. The gym's unit: ${request.unit}.\nRecognised text:\n${request.text || "(none)"}`,
    });
    if (request.kind === "workout") {
      const response = await client.messages.parse({
        model: MODEL,
        max_tokens: 8000,
        system: SYSTEM.workout,
        messages: [{ role: "user", content }],
        output_config: { format: zodOutputFormat(WorkoutAnswer), effort: "low" },
      });
      if (response.stop_reason === "refusal" || !response.parsed_output) return null;
      return { kind: "workout", ...response.parsed_output };
    }
    const response = await client.messages.parse({
      model: MODEL,
      max_tokens: 8000,
      system: SYSTEM.prs,
      messages: [{ role: "user", content }],
      output_config: { format: zodOutputFormat(PRsAnswer), effort: "low" },
    });
    if (response.stop_reason === "refusal" || !response.parsed_output) return null;
    return { kind: "prs", ...response.parsed_output };
  };
}
