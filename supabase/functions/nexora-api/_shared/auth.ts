import { createClient } from "npm:@supabase/supabase-js@2.95.0";
import { createRemoteJWKSet, jwtVerify } from "npm:jose@5.10.0";

const FIREBASE_PROJECT_ID = "gen-lang-client-0074900177";
const FIREBASE_ISSUER = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;
const FIREBASE_KEYS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"),
);
export function getAdminClient() {
  // The CLI can inject a host-loopback SUPABASE_URL into the Edge Runtime
  // container. Prefer the explicitly supplied Docker-network URL in local E2E.
  const url = Deno.env.get("NOVA_E2E_SUPABASE_URL") || Deno.env.get("SUPABASE_URL");
  if (!url) throw new Error("SUPABASE_URL_MISSING");
  let key = Deno.env.get("NOVA_E2E_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
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

  // The E2E identity override is accepted only by an explicitly enabled local
  // Supabase stack. HTTPS/hosted deployments can never use this bypass.
  const e2eToken = Deno.env.get("NOVA_E2E_AUTH_TOKEN") ?? "";
  const supabaseUrl = Deno.env.get("NOVA_E2E_SUPABASE_URL") || Deno.env.get("SUPABASE_URL") || "";
  let localE2EEnabled = false;
  try {
    const parsed = new URL(supabaseUrl);
    localE2EEnabled =
      Deno.env.get("NOVA_E2E_ALLOW_LOCAL_AUTH") === "true" &&
      parsed.protocol === "http:" &&
      ["localhost", "127.0.0.1", "kong"].includes(parsed.hostname) &&
      e2eToken.length >= 32 &&
      token === e2eToken;
  } catch {
    localE2EEnabled = false;
  }
  if (localE2EEnabled) {
    const uid = Deno.env.get("NOVA_E2E_UID") ?? "";
    if (!uid) throw new Error("NOVA_E2E_UID_MISSING");
    return {
      uid,
      email: Deno.env.get("NOVA_E2E_EMAIL") ?? "",
      emailVerified: true,
      isAnonymous: false,
      authTime: Math.floor(Date.now() / 1000),
      isE2E: true,
    };
  }

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
    isAnonymous,
    authTime: typeof payload.auth_time === "number" ? payload.auth_time : null,
    isE2E: false,
  };
}
