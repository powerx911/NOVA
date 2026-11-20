export const FIREBASE_RECENT_AUTH_WINDOW_SECONDS = 5 * 60;

/**
 * Firebase requires a recent sign-in for account deletion. auth_time is a
 * signed JWT claim and is intentionally distinct from iat (token refresh time).
 */
export function isRecentFirebaseAuth(
  authTime: unknown,
  nowSeconds = Math.floor(Date.now() / 1000),
): boolean {
  if (
    typeof authTime !== "number" ||
    !Number.isSafeInteger(authTime) ||
    !Number.isSafeInteger(nowSeconds) ||
    authTime <= 0
  ) return false;

  const ageSeconds = nowSeconds - authTime;
  return ageSeconds >= -60 && ageSeconds <= FIREBASE_RECENT_AUTH_WINDOW_SECONDS;
}
