function camelKey(key: string): string {
  return key === "user_id" ? "uid" : key.replace(/_([a-z])/g, (_, letter: string) => letter.toUpperCase());
}
export function camelRow<T>(row: T): T {
  if (Array.isArray(row)) return row.map((item) => camelRow(item)) as T;
  if (!row || typeof row !== "object") return row;
  return Object.fromEntries(Object.entries(row as Record<string, unknown>).map(([key, value]) => {
    const normalizedKey = camelKey(key);
    // Postgres timestamptz values arrive from PostgREST as ISO strings, while
    // the game client models timers as epoch milliseconds. Normalize every
    // timestamp column at the API boundary so countdowns and auto-completion
    // compare like-for-like values.
    if (key.endsWith("_at") && typeof value === "string") {
      const timestamp = Date.parse(value);
      if (Number.isFinite(timestamp)) return [normalizedKey, timestamp];
    }
    return [normalizedKey, value];
  })) as T;
}

export async function queryData<T>(promise: PromiseLike<{ data: T; error: { message: string } | null }>): Promise<T> {
  const { data, error } = await promise;
  if (error) throw new Error(error.message);
  return data;
}

