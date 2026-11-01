// The read's request and result (docs/DATA-AND-SERVICES.md §2.4, §3) and the checks every result must pass —
// the same limits as the app's (PlateKit's ReadResult.validated()).
import { z } from "zod";

export const ReadRequest = z.object({
  kind: z.enum(["workout", "prs"]),
  text: z.string().max(20_000),
  /** A JPEG, base64, only when the phone found almost no text. */
  image: z.string().max(4_000_000).optional(),
  locale: z.string().max(35),
  unit: z.enum(["kg", "lb"]),
});
export type ReadRequest = z.infer<typeof ReadRequest>;

const Unit = z.enum(["kg", "lb"]).nullable().describe("kg or lb when written, else null");

/** What Claude fills in for a workout (structured output); `kind` is added after. */
export const WorkoutAnswer = z.object({
  unit: Unit,
  blocks: z.array(
    z.object({
      label: z.string().nullable().describe("The block's letter, like A, or null"),
      lift: z.string().describe("The lift as named, like Back squat"),
      sets: z.array(
        z.object({
          reps: z.number().int(),
          percent: z.number().nullable().describe("Percent of the 1RM, or null"),
          weight: z.number().nullable().describe("A fixed weight, or null"),
        }),
      ),
      note: z.string().nullable().describe("A format like EMOM 10, or null"),
    }),
  ),
});

export const PRsAnswer = z.object({
  unit: Unit,
  prs: z.array(z.object({ lift: z.string(), weight: z.number() })),
});

export type WorkoutResult = { kind: "workout" } & z.infer<typeof WorkoutAnswer>;
export type PRsResult = { kind: "prs" } & z.infer<typeof PRsAnswer>;
export type ReadResult = WorkoutResult | PRsResult;

const RECEIPT_WORDS = new Set(["order", "completed", "subtotal", "total", "shipping", "delivery", "fee", "discount", "tax",
  "payment", "paid", "price", "amount", "receipt", "invoice", "purchase"]);

/** LiftNames.couldBeALift: letters, no marks a lift never has, no receipt's words. */
export function couldBeALift(name: string): boolean {
  if (!/[A-Za-z]{2}/.test(name) || /[@%!?$€£¥#]/.test(name)) return false;
  return !name.toLowerCase().split(/[^\p{L}]+/u).some((word) => RECEIPT_WORDS.has(word));
}

/** Reps 1–50, percent 30–110, weight 1–500 kg (1,100 lb), names that can be lifts, at least one block or PR. */
export function isLikely(result: ReadResult): boolean {
  const heaviest = result.unit === "lb" ? 1100 : 500;
  const weightOK = (w: number | null) => w === null || (w >= 1 && w <= heaviest);
  if (result.kind === "workout") {
    return result.blocks.length > 0 && result.blocks.every((block) =>
      couldBeALift(block.lift.trim()) && block.sets.length > 0 && block.sets.every((set) =>
        Number.isInteger(set.reps) && set.reps >= 1 && set.reps <= 50 &&
        (set.percent === null || (set.percent >= 30 && set.percent <= 110)) && weightOK(set.weight)));
  }
  return result.prs.length > 0 && result.prs.every((pr) => couldBeALift(pr.lift.trim()) && weightOK(pr.weight));
}
