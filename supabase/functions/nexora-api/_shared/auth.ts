import { createClient } from "npm:@supabase/supabase-js@2.95.0";
import { createRemoteJWKSet, jwtVerify } from "npm:jose@5.10.0";

const FIREBASE_PROJECT_ID = "gen-lang-client-0074900177";
const FIREBASE_ISSUER = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;
const FIREBASE_KEYS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"),
);
export function getAdminClient() {
  const url = Deno.env.get("SUPABASE_URL");
  if (!url) throw new Error("SUPABASE_URL_MISSING");
  // Prefer the legacy JWT service_role key with supabase-js v2. The newer
  // sb_secret_* key is not a JWT and must be sent via apikey-only headers.
  let key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!key) {
    const secrets = Deno.env.get("SUPABASE_SECRET_KEYS");
    if (secrets) {
      try { key = JSON.parse(secrets).default ?? ""; } catch { /* fail closed below */ }
    }
  }
  if (!key) throw new Error("SUPABASE_SERVER_KEY_MISSING");
  return createClient(url, key, {
    db: { schema: "nexora" },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export async function authenticate(req: Request) {
  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!token) throw new Error("UNAUTHENTICATED");
  const { payload } = await jwtVerify(token, FIREBASE_KEYS, {
    issuer: FIREBASE_ISSUER,
    audience: FIREBASE_PROJECT_ID,
    algorithms: ["RS256"],
  });
  const firebase = payload.firebase && typeof payload.firebase === "object"
    ? payload.firebase as Record<string, unknown>
    : {};
  const isAnonymous = firebase.sign_in_provider === "anonymous";
  if (
    typeof payload.sub !== "string" || !payload.sub ||
    (!isAnonymous && payload.email_verified !== true)
  ) throw new Error("VERIFIED_EMAIL_REQUIRED");
  return {
    uid: payload.sub,
    email: typeof payload.email === "string" ? payload.email : "",
    emailVerified: payload.email_verified === true,
  };
}
