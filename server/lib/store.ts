// A tiny key-value store with expiry (Upstash Redis, in the EU): challenges for five minutes, each phone's attested
// key and last counter, and a read count per phone per day. Never what a read contained.
import { Redis } from "@upstash/redis";

export interface Store {
  get(key: string): Promise<string | null>;
  set(key: string, value: string, seconds?: number): Promise<void>;
  /** Reads and deletes in one step (a challenge is used once). */
  take(key: string): Promise<string | null>;
  /** Adds one and returns the new count; the key expires after `seconds`. */
  increment(key: string, seconds: number): Promise<number>;
}

export function redisStore(): Store {
  const url = process.env.UPSTASH_REDIS_REST_URL ?? process.env.KV_REST_API_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN ?? process.env.KV_REST_API_TOKEN;
  if (!url || !token) throw new Error("The store isn't configured (UPSTASH_REDIS_REST_URL / _TOKEN).");
  const redis = new Redis({ url, token, automaticDeserialization: false });
  return {
    get: (key) => redis.get<string>(key),
    async set(key, value, seconds) {
      if (seconds) await redis.set(key, value, { ex: seconds });
      else await redis.set(key, value);
    },
    take: (key) => redis.getdel<string>(key),
    async increment(key, seconds) {
      const count = await redis.incr(key);
      if (count === 1) await redis.expire(key, seconds);
      return count;
    },
  };
}

/** For the tests. */
export function memoryStore(): Store & { keys(): string[] } {
  const values = new Map<string, string>();
  return {
    keys: () => [...values.keys()],
    get: async (key) => values.get(key) ?? null,
    set: async (key, value) => void values.set(key, value),
    async take(key) {
      const value = values.get(key) ?? null;
      values.delete(key);
      return value;
    },
    async increment(key) {
      const count = Number(values.get(key) ?? 0) + 1;
      values.set(key, String(count));
      return count;
    },
  };
}
