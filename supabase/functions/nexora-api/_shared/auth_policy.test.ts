import { isRecentFirebaseAuth } from "./auth_policy.ts";

Deno.test("accepts authentication at the current time", () => {
  if (!isRecentFirebaseAuth(1_800_000_000, 1_800_000_000)) {
    throw new Error("current auth_time should be accepted");
  }
});

Deno.test("accepts authentication exactly at the five-minute boundary", () => {
  if (!isRecentFirebaseAuth(1_800_000_000 - 300, 1_800_000_000)) {
    throw new Error("five-minute boundary should be accepted");
  }
});

Deno.test("rejects authentication older than five minutes", () => {
  if (isRecentFirebaseAuth(1_800_000_000 - 301, 1_800_000_000)) {
    throw new Error("stale auth_time must be rejected");
  }
});

Deno.test("rejects missing, malformed, or unsafe authentication timestamps", () => {
  for (const value of [null, undefined, "1800000000", 0, Number.NaN, Number.POSITIVE_INFINITY]) {
    if (isRecentFirebaseAuth(value, 1_800_000_000)) {
      throw new Error(`invalid auth_time accepted: ${String(value)}`);
    }
  }
});

Deno.test("allows a small clock skew but rejects a future timestamp beyond tolerance", () => {
  if (!isRecentFirebaseAuth(1_800_000_030, 1_800_000_000)) {
    throw new Error("small clock skew should be tolerated");
  }
  if (isRecentFirebaseAuth(1_800_000_061, 1_800_000_000)) {
    throw new Error("future auth_time beyond tolerance must be rejected");
  }
});
