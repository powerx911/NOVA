import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.95.0";
import { createRemoteJWKSet, jwtVerify } from "npm:jose@5.10.0";

const FIREBASE_PROJECT_ID = "gen-lang-client-0074900177";
const FIREBASE_ISSUER = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;
const FIREBASE_KEYS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"),
);
const ALLOWED_ORIGINS = new Set([
  "https://powerx911.github.io",
  "http://localhost:3000",
  "http://localhost:5173",
]);

const cors = (origin: string | null) => ({
  "Access-Control-Allow-Origin": origin && ALLOWED_ORIGINS.has(origin) ? origin : "https://powerx911.github.io",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
  "Vary": "Origin",
});
const json = (body: unknown, status = 200, origin: string | null = null) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors(origin), "Content-Type": "application/json", "Cache-Control": "no-store" },
  });

function camelKey(key: string): string {
  return key === "user_id" ? "uid" : key.replace(/_([a-z])/g, (_, letter: string) => letter.toUpperCase());
}
function camelRow<T>(row: T): T {
  if (Array.isArray(row)) return row.map((item) => camelRow(item)) as T;
  if (!row || typeof row !== "object") return row;
  return Object.fromEntries(Object.entries(row as Record<string, unknown>).map(([k, v]) => [camelKey(k), v])) as T;
}

function getAdminClient() {
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

async function authenticate(req: Request) {
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

async function queryData<T>(promise: PromiseLike<{ data: T; error: { message: string } | null }>): Promise<T> {
  const { data, error } = await promise;
  if (error) throw new Error(error.message);
  return data;
}

async function bootstrap(admin: ReturnType<typeof getAdminClient>, uid: string) {
  const db = admin.schema("nexora");
  const [
    profile, userPrivate, wallet, inventory, sent, received, marketListings,
    marketOrders, companies, companyLogs, properties, organizations,
    organizationMembers, organizationRequests, playerMissions, dailyClaims,
    contractClaims, playerAchievements, notifications, worldEvents,
  ] = await Promise.all([
    queryData(db.from("player_profiles").select("*").eq("user_id", uid).maybeSingle()),
    queryData(db.from("player_private").select("*").eq("user_id", uid).maybeSingle()),
    queryData(db.from("wallets").select("*").eq("user_id", uid).maybeSingle()),
    queryData(db.from("inventory").select("*").eq("user_id", uid)),
    queryData(db.from("transactions").select("*").eq("from_uid", uid).order("created_at", { ascending: false }).limit(30)),
    queryData(db.from("transactions").select("*").eq("to_uid", uid).order("created_at", { ascending: false }).limit(30)),
    queryData(db.from("market_listings").select("*").eq("status", "active").order("created_at", { ascending: false }).limit(100)),
    queryData(db.from("market_orders").select("*").eq("buyer_uid", uid).order("created_at", { ascending: false }).limit(25)),
    queryData(db.from("companies").select("*").eq("owner_uid", uid)),
    queryData(db.from("company_logs").select("*").eq("owner_uid", uid).order("created_at", { ascending: false }).limit(25)),
    queryData(db.from("properties").select("*").eq("owner_uid", uid)),
    queryData(db.from("organizations").select("*").gte("reputation", 0).order("reputation", { ascending: false }).limit(40)),
    queryData(db.from("organization_members").select("*").eq("user_id", uid).limit(1)),
    queryData(db.from("organization_requests").select("*").eq("user_id", uid)),
    queryData(db.from("player_missions").select("*").eq("user_id", uid)),
    queryData(db.from("daily_claims").select("*").eq("user_id", uid).eq("date_key", new Date().toISOString().slice(0, 10)).maybeSingle()),
    queryData(db.from("contract_claims").select("*").eq("user_id", uid)),
    queryData(db.from("player_achievements").select("*").eq("user_id", uid)),
    queryData(db.from("notifications").select("*").eq("user_id", uid).order("created_at", { ascending: false }).limit(30)),
    queryData(db.from("world_events").select("*").eq("active", true)),
  ]);

  const orgId = (profile as Record<string, unknown> | null)?.org_id;
  const [orgMembers, orgRequests, orgTransactions] = orgId
    ? await Promise.all([
        queryData(db.from("organization_members").select("*").eq("org_id", orgId)),
        queryData(db.from("organization_requests").select("*").eq("org_id", orgId).eq("status", "pending")),
        queryData(db.from("organization_transactions").select("*").eq("org_id", orgId).order("created_at", { ascending: false }).limit(40)),
      ])
    : [[], [], []];

  const txMap = new Map<string, Record<string, unknown>>();
  for (const tx of [...(sent as Record<string, unknown>[]), ...(received as Record<string, unknown>[])]) {
    txMap.set(String(tx.id), tx);
  }
  const transactions = [...txMap.values()].sort(
    (a, b) => new Date(String(b.created_at)).getTime() - new Date(String(a.created_at)).getTime(),
  ).slice(0, 40);

  return {
    profile: camelRow(profile),
    userPrivate: camelRow(userPrivate),
    wallet: camelRow(wallet),
    inventory: camelRow(inventory),
    transactions: camelRow(transactions),
    marketListings: camelRow(marketListings),
    marketOrders: camelRow(marketOrders),
    companies: camelRow(companies),
    companyLogs: camelRow(companyLogs),
    properties: camelRow(properties),
    organizations: camelRow(organizations),
    myOrgMember: camelRow((organizationMembers as Record<string, unknown>[])[0] ?? null),
    orgMembers: camelRow(orgMembers),
    orgRequests: camelRow(orgRequests),
    myPendingOrgIds: (organizationRequests as Record<string, unknown>[]).filter((r) => r.status === "pending").map((r) => r.org_id),
    orgTransactions: camelRow(orgTransactions),
    playerMissions: camelRow(playerMissions),
    claimedDailyToday: Boolean(dailyClaims),
    contractClaims: camelRow(contractClaims),
    claimedContractsToday: (contractClaims as Record<string, unknown>[]).map((r) => r.contract_id),
    playerAchievements: camelRow(playerAchievements),
    notifications: camelRow(notifications),
    worldEvents: camelRow(worldEvents),
  };
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("Origin");
  if (origin && !ALLOWED_ORIGINS.has(origin)) return json({ error: "FORBIDDEN_ORIGIN" }, 403, origin);
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors(origin) });

  if (req.method === "GET") {
    try {
      const admin = getAdminClient().schema("nexora");
      const { error } = await admin.from("world_events").select("id").limit(1);
      if (error) throw error;
      return json({ ok: true, service: "nexora-api", schema: "nexora" }, 200, origin);
    } catch {
      return json({ ok: false, error: "DATABASE_UNAVAILABLE" }, 503, origin);
    }
  }

  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405, origin);

  try {
    const identity = await authenticate(req);
    const body = await req.json().catch(() => null) as Record<string, unknown> | null;
    if (!body || typeof body.action !== "string") return json({ error: "INVALID_REQUEST" }, 400, origin);
    const admin = getAdminClient();
    const db = admin.schema("nexora");

    if (body.action === "bootstrap") {
      // A signed-in Firebase user may not have created a game character yet.
      // Only unlock achievements after a player profile exists; otherwise the
      // achievement RPC raises ACCOUNT_NOT_FOUND and blocks onboarding.
      const { data: existingProfile, error: profileError } = await db
        .from("player_profiles")
        .select("user_id")
        .eq("user_id", identity.uid)
        .maybeSingle();
      if (profileError) throw profileError;
      if (existingProfile) {
        const { error: achievementError } = await db.rpc("unlock_eligible_achievements", { p_uid: identity.uid });
        if (achievementError) throw achievementError;
      }
      return json({ ok: true, data: await bootstrap(admin, identity.uid) }, 200, origin);
    }

    if (body.action === "claim_mission_reward") {
      const missionId = typeof body.missionId === "string" ? body.missionId : "";
      const { data, error } = await db.rpc("claim_mission_reward", { p_uid: identity.uid, p_mission_id: missionId });
      if (error) {
        const known = ["INVALID_MISSION","MISSION_ALREADY_CLAIMED","MISSION_NOT_COMPLETE","ACCOUNT_NOT_FOUND"].find((code) => error.message.includes(code));
        return json({ error: known ?? "MISSION_CLAIM_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "username_available") {
      const username = typeof body.username === "string" ? body.username.trim() : "";
      if (!/^[a-zA-Z0-9_]{3,24}$/.test(username)) {
        return json({ ok: true, available: false }, 200, origin);
      }
      const { data, error } = await db.from("usernames").select("uid").eq("username_lower", username.toLowerCase()).maybeSingle();
      if (error) throw error;
      return json({ ok: true, available: !data }, 200, origin);
    }

    if (body.action === "create_character") {
      const username = typeof body.username === "string" ? body.username.trim() : "";
      const avatarId = typeof body.avatarId === "string" ? body.avatarId : "strategist";
      const language = body.language === "en" ? "en" : "ar";
      if (!/^[a-zA-Z0-9_]{3,24}$/.test(username)) return json({ error: "INVALID_USERNAME" }, 400, origin);
      const { data, error } = await db.rpc("create_player_character", {
        p_uid: identity.uid,
        p_email: identity.email,
        p_username: username,
        p_avatar_id: avatarId,
        p_language: language,
      });
      if (error) {
        const message = error.message.includes("USERNAME_TAKEN") ? "USERNAME_TAKEN"
          : error.message.includes("PROFILE_EXISTS") ? "PROFILE_EXISTS"
          : error.message.includes("INVALID_USERNAME") ? "INVALID_USERNAME"
          : "CREATE_CHARACTER_FAILED";
        return json({ error: message }, 409, origin);
      }
      return json({ ok: true, data }, 201, origin);
    }

    if (body.action === "claim_daily_stipend") {
      const { data, error } = await db.rpc("claim_daily_stipend", { p_uid: identity.uid });
      if (error) {
        const message = error.message.includes("ALREADY_CLAIMED_TODAY") ? "ALREADY_CLAIMED_TODAY"
          : error.message.includes("ACCOUNT_NOT_FOUND") ? "ACCOUNT_NOT_FOUND"
          : "DAILY_CLAIM_FAILED";
        return json({ error: message }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "upgrade_skill") {
      const skillKey = typeof body.skillKey === "string" ? body.skillKey : "";
      const { data, error } = await db.rpc("upgrade_player_skill", {
        p_uid: identity.uid,
        p_skill: skillKey,
      });
      if (error) {
        const message = ["INVALID_SKILL","NO_SKILL_POINTS","SKILL_MAXED","ACCOUNT_NOT_FOUND"].find((code) => error.message.includes(code));
        return json({ error: message ?? "SKILL_UPGRADE_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "transfer_credits") {
      const recipientUsername = typeof body.recipientUsername === "string" ? body.recipientUsername.trim() : "";
      const amount = typeof body.amount === "number" && Number.isFinite(body.amount) ? Math.floor(body.amount) : 0;
      const note = typeof body.note === "string" ? body.note.slice(0, 180) : "";
      const { data, error } = await db.rpc("transfer_credits", {
        p_uid: identity.uid,
        p_recipient_username: recipientUsername,
        p_amount: amount,
        p_note: note,
      });
      if (error) {
        const known = ["RECIPIENT_NOT_FOUND","SELF_OR_MISSING_RECIPIENT","INVALID_AMOUNT","INSUFFICIENT_FUNDS"].find((code) => error.message.includes(code));
        return json({ error: known ?? "TRANSFER_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "create_market_listing") {
      const itemId = typeof body.itemId === "string" ? body.itemId : "";
      const quantity = typeof body.quantity === "number" && Number.isFinite(body.quantity) ? Math.floor(body.quantity) : 0;
      const unitPrice = typeof body.unitPrice === "number" && Number.isFinite(body.unitPrice) ? Math.round(body.unitPrice) : 0;
      const { data, error } = await db.rpc("create_market_listing", {
        p_uid: identity.uid, p_item_id: itemId, p_qty: quantity, p_unit_price: unitPrice,
      });
      if (error) {
        const known = ["INVALID_ITEM","INVALID_LISTING_PARAMS","INSUFFICIENT_INVENTORY","ACCOUNT_NOT_FOUND"].find((code) => error.message.includes(code));
        return json({ error: known ?? "CREATE_LISTING_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 201, origin);
    }

    if (body.action === "buy_market_listing") {
      const listingId = typeof body.listingId === "string" ? body.listingId : "";
      const quantity = typeof body.quantity === "number" && Number.isFinite(body.quantity) ? Math.floor(body.quantity) : 0;
      const { data, error } = await db.rpc("buy_market_listing", {
        p_uid: identity.uid, p_listing_id: listingId, p_qty: quantity,
      });
      if (error) {
        const known = ["INVALID_QUANTITY","LISTING_NOT_FOUND","INSUFFICIENT_LISTING_QTY","CANNOT_BUY_OWN_LISTING","INSUFFICIENT_FUNDS","ACCOUNT_NOT_FOUND","SELLER_ACCOUNT_NOT_FOUND"].find((code) => error.message.includes(code));
        return json({ error: known ?? "MARKET_PURCHASE_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "cancel_market_listing") {
      const listingId = typeof body.listingId === "string" ? body.listingId : "";
      const { data, error } = await db.rpc("cancel_market_listing", {
        p_uid: identity.uid, p_listing_id: listingId,
      });
      if (error) {
        const known = ["LISTING_NOT_FOUND","CANNOT_CANCEL_LISTING"].find((code) => error.message.includes(code));
        return json({ error: known ?? "CANCEL_LISTING_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "manufacture_recipe") {
      const recipeId = typeof body.recipeId === "string" ? body.recipeId : "";
      const batches = typeof body.batches === "number" && Number.isFinite(body.batches) ? Math.floor(body.batches) : 0;
      const { data, error } = await db.rpc("manufacture_recipe", {
        p_uid: identity.uid, p_recipe_id: recipeId, p_batches: batches,
      });
      if (error) {
        const known = ["INVALID_RECIPE","INVALID_QUANTITY","ACCOUNT_NOT_FOUND","INDUSTRY_SKILL_TOO_LOW","INSUFFICIENT_FUNDS","MISSING_INPUTS"].find((code) => error.message.includes(code));
        return json({ error: known ?? "MANUFACTURING_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "fulfill_trade_contract") {
      const contractId = typeof body.contractId === "string" ? body.contractId : "";
      const { data, error } = await db.rpc("fulfill_trade_contract", {
        p_uid: identity.uid, p_contract_id: contractId,
      });
      if (error) {
        const known = ["INVALID_CONTRACT","ACCOUNT_NOT_FOUND","CONTRACT_ALREADY_FULFILLED","MISSING_INPUTS"].find((code) => error.message.includes(code));
        return json({ error: known ?? "CONTRACT_FULFILLMENT_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "update_settings") {
      const language = body.language === "en" ? "en" : body.language === "ar" ? "ar" : "";
      if (!language || typeof body.notificationsEnabled !== "boolean") return json({ error: "INVALID_SETTINGS" }, 400, origin);
      const { data, error } = await db.rpc("update_player_settings", {
        p_uid: identity.uid, p_language: language, p_notifications_enabled: body.notificationsEnabled,
      });
      if (error) return json({ error: error.message.includes("ACCOUNT_NOT_FOUND") ? "ACCOUNT_NOT_FOUND" : "SETTINGS_UPDATE_FAILED" }, 409, origin);
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "update_avatar") {
      const avatarId = typeof body.avatarId === "string" ? body.avatarId.trim() : "";
      const { data, error } = await db.rpc("update_player_avatar", { p_uid: identity.uid, p_avatar_id: avatarId });
      if (error) {
        const known = ["INVALID_AVATAR","ACCOUNT_NOT_FOUND"].find((code) => error.message.includes(code));
        return json({ error: known ?? "AVATAR_UPDATE_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "mark_notification_read") {
      const notificationId = typeof body.notificationId === "string" ? body.notificationId : "";
      const { data, error } = await db.rpc("mark_notification_read", { p_uid: identity.uid, p_notification_id: notificationId });
      if (error) return json({ error: error.message.includes("NOTIFICATION_NOT_FOUND") ? "NOTIFICATION_NOT_FOUND" : "NOTIFICATION_UPDATE_FAILED" }, 409, origin);
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "mark_all_notifications_read") {
      const { data, error } = await db.rpc("mark_all_notifications_read", { p_uid: identity.uid });
      if (error) return json({ error: "NOTIFICATION_UPDATE_FAILED" }, 409, origin);
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "found_company") {
      const name = typeof body.name === "string" ? body.name.trim() : "";
      const sector = typeof body.sector === "string" ? body.sector : "";
      const { data, error } = await db.rpc("found_company", { p_uid: identity.uid, p_name: name, p_sector: sector });
      if (error) {
        const known = ["INVALID_NAME","INVALID_SECTOR","ACCOUNT_NOT_FOUND","INSUFFICIENT_FUNDS"].find((code) => error.message.includes(code));
        return json({ error: known ?? "COMPANY_FOUNDING_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 201, origin);
    }

    if (body.action === "buy_property") {
      const name = typeof body.name === "string" ? body.name.trim() : "";
      const propertyType = typeof body.propertyType === "string" ? body.propertyType : "";
      const { data, error } = await db.rpc("buy_property", { p_uid: identity.uid, p_name: name, p_type: propertyType });
      if (error) {
        const known = ["INVALID_NAME","INVALID_PROPERTY_TYPE","ACCOUNT_NOT_FOUND","INSUFFICIENT_FUNDS"].find((code) => error.message.includes(code));
        return json({ error: known ?? "PROPERTY_PURCHASE_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 201, origin);
    }

    if (body.action === "toggle_property_lease") {
      const propertyId = typeof body.propertyId === "string" ? body.propertyId : "";
      if (typeof body.nextState !== "boolean") return json({ error: "INVALID_LEASE_STATE" }, 400, origin);
      const { data, error } = await db.rpc("toggle_property_lease", { p_uid: identity.uid, p_property_id: propertyId, p_next_state: body.nextState });
      if (error) return json({ error: error.message.includes("PROPERTY_NOT_FOUND_OR_UNAUTHORIZED") ? "UNAUTHORIZED" : "LEASE_UPDATE_FAILED" }, 409, origin);
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "upgrade_property") {
      const propertyId = typeof body.propertyId === "string" ? body.propertyId : "";
      const { data, error } = await db.rpc("upgrade_property", { p_uid: identity.uid, p_property_id: propertyId });
      if (error) {
        const known = ["PROPERTY_NOT_FOUND","UNAUTHORIZED","MAX_LEVEL","ACCOUNT_NOT_FOUND","INSUFFICIENT_FUNDS"].find((code) => error.message.includes(code));
        return json({ error: known ?? "PROPERTY_UPGRADE_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "collect_property_rent") {
      const propertyId = typeof body.propertyId === "string" ? body.propertyId : "";
      const { data, error } = await db.rpc("collect_property_rent", { p_uid: identity.uid, p_property_id: propertyId });
      if (error) {
        const known = ["PROPERTY_NOT_FOUND","UNAUTHORIZED","PROPERTY_VACANT","NOTHING_TO_COLLECT","ACCOUNT_NOT_FOUND"].find((code) => error.message.includes(code));
        return json({ error: known ?? "PROPERTY_COLLECTION_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    const companyId = typeof body.companyId === "string" ? body.companyId : "";
    if (body.action === "company_upgrade" || body.action === "company_complete" ||
        body.action === "vault_upgrade" || body.action === "vault_complete" || body.action === "company_collect") {
      if (!companyId || companyId.length > 128) return json({ error: "INVALID_ARGUMENT" }, 400, origin);
      const rpcName = body.action === "company_upgrade" ? "start_company_upgrade"
        : body.action === "company_complete" ? "complete_company_upgrade"
        : body.action === "vault_upgrade" ? "upgrade_company_vault"
        : body.action === "vault_complete" ? "complete_company_vault_upgrade"
        : "collect_company_revenue";
      const { data, error } = await db.rpc(rpcName, { p_uid: identity.uid, p_company_id: companyId });
      if (error) {
        const known = [
          "COMPANY_NOT_FOUND","UNAUTHORIZED","MAX_LEVEL","UPGRADE_IN_PROGRESS","ACCOUNT_NOT_FOUND",
          "INSUFFICIENT_FUNDS","NO_UPGRADE_IN_PROGRESS","UPGRADE_NOT_FINISHED","INVALID_UPGRADE_STATE",
          "VAULT_MAX_LEVEL","MISSING_VAULT_MATERIALS","NOTHING_TO_COLLECT",
        ].find((code) => error.message.includes(code));
        return json({ error: known ?? "COMPANY_OPERATION_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "create_organization") {
      if (!identity.emailVerified) return json({ error: "EMAIL_NOT_VERIFIED" }, 403, origin);
      const name = typeof body.name === "string" ? body.name.trim() : "";
      const tag = typeof body.tag === "string" ? body.tag.trim().toUpperCase() : "";
      const description = typeof body.description === "string" ? body.description.trim().slice(0, 240) : "";
      const { data, error } = await db.rpc("create_organization", {
        p_uid: identity.uid, p_name: name, p_tag: tag, p_description: description,
      });
      if (error) {
        const known = ["INVALID_NAME","INVALID_TAG","ACCOUNT_NOT_FOUND","ALREADY_IN_ORG","INSUFFICIENT_FUNDS","TAG_TAKEN"].find((code) => error.message.includes(code));
        return json({ error: known ?? "ORGANIZATION_CREATE_FAILED" }, 409, origin);
      }
      return json({ ok: true, data: { orgId: (data as Record<string, unknown>)?.org_id } }, 201, origin);
    }

    if (body.action === "organization_upgrade" || body.action === "organization_complete" || body.action === "organization_research") {
      const orgId = typeof body.orgId === "string" ? body.orgId : "";
      if (!/^[a-zA-Z0-9_-]{1,128}$/.test(orgId)) return json({ error: "INVALID_ORG" }, 400, origin);
      const researchId = typeof body.researchId === "string" ? body.researchId : "";
      const rpcName = body.action === "organization_upgrade" ? "start_organization_upgrade"
        : body.action === "organization_complete" ? "complete_organization_upgrade"
        : "research_organization";
      const args = body.action === "organization_research"
        ? { p_uid: identity.uid, p_org_id: orgId, p_research_id: researchId }
        : { p_uid: identity.uid, p_org_id: orgId };
      const { data, error } = await db.rpc(rpcName, args);
      if (error) {
        const known = ["NOT_FOUND","UNAUTHORIZED","UPGRADE_IN_PROGRESS","MAX_LEVEL","INSUFFICIENT_TREASURY","UPGRADE_NOT_READY","INVALID_UPGRADE_STATE","INVALID_RESEARCH","RESEARCH_MAX_LEVEL"].find((code) => error.message.includes(code));
        return json({ error: known ?? "ORGANIZATION_UPGRADE_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "request_join_organization") {
      const orgId = typeof body.orgId === "string" ? body.orgId : "";
      const { data, error } = await db.rpc("request_join_organization", { p_uid: identity.uid, p_org_id: orgId });
      if (error) {
        const known = ["ACCOUNT_NOT_FOUND","ALREADY_IN_ORG","NOT_FOUND","REQUEST_ALREADY_PENDING"].find((x) => error.message.includes(x));
        return json({ error: known ?? "JOIN_REQUEST_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 201, origin);
    }

    if (body.action === "handle_org_join_request") {
      const orgId = typeof body.orgId === "string" ? body.orgId : "";
      const requestId = typeof body.requestId === "string" ? body.requestId : "";
      const decision = body.decision === "approved" || body.decision === "rejected" ? body.decision : "";
      const { data, error } = await db.rpc("handle_org_join_request", {
        p_actor_uid: identity.uid, p_org_id: orgId, p_request_id: requestId, p_decision: decision,
      });
      if (error) {
        const known = ["INVALID_DECISION","NOT_FOUND","UNAUTHORIZED","REQUEST_ALREADY_HANDLED","APPLICANT_IN_OTHER_ORG","ALREADY_ORG_MEMBER","ORG_FULL"].find((x) => error.message.includes(x));
        return json({ error: known ?? "JOIN_REQUEST_DECISION_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "update_org_member_role" || body.action === "kick_org_member" || body.action === "leave_organization") {
      const orgId = typeof body.orgId === "string" ? body.orgId : "";
      const targetUid = typeof body.targetUid === "string" ? body.targetUid : "";
      let rpcName = body.action;
      let args: Record<string, unknown> = { p_uid: identity.uid, p_org_id: orgId };
      if (body.action === "update_org_member_role") {
        rpcName = "update_org_member_role";
        args = { p_actor_uid: identity.uid, p_org_id: orgId, p_target_uid: targetUid, p_role: body.role };
      } else if (body.action === "kick_org_member") {
        rpcName = "kick_org_member";
        args = { p_actor_uid: identity.uid, p_org_id: orgId, p_target_uid: targetUid };
      } else {
        rpcName = "leave_organization";
        args = { p_uid: identity.uid, p_org_id: orgId };
      }
      const { data, error } = await db.rpc(rpcName, args);
      if (error) {
        const known = ["INVALID_ROLE","NOT_FOUND","UNAUTHORIZED","RANK_TOO_HIGH","LEADER_CANNOT_LEAVE","CANNOT_KICK_SELF"].find((x) => error.message.includes(x));
        return json({ error: known ?? "ORGANIZATION_MEMBER_ACTION_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "org_treasury_deposit" || body.action === "org_treasury_withdraw") {
      const orgId = typeof body.orgId === "string" ? body.orgId : "";
      const amount = Number(body.amount);
      const rpcName = body.action === "org_treasury_deposit" ? "deposit_org_treasury" : "withdraw_org_treasury";
      const { data, error } = await db.rpc(rpcName, { p_uid: identity.uid, p_org_id: orgId, p_amount: Math.floor(amount) });
      if (error) {
        const known = ["INVALID_AMOUNT","NOT_FOUND","UNAUTHORIZED","INSUFFICIENT_FUNDS","INSUFFICIENT_TREASURY"].find((x) => error.message.includes(x));
        return json({ error: known ?? "ORG_TREASURY_ACTION_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "fetch_org_pending_requests") {
      const orgId = typeof body.orgId === "string" ? body.orgId : "";
      const { data, error } = await db.rpc("get_org_pending_requests", { p_org_id: orgId, p_uid: identity.uid });
      if (error) return json({ error: error.message.includes("UNAUTHORIZED") ? "UNAUTHORIZED" : "ORG_REQUESTS_FETCH_FAILED" }, 403, origin);
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "unlock_eligible_achievements") {
      // Onboarding clients may request an achievement sync before a character exists.
      // Treat that state as an empty achievement set instead of surfacing ACCOUNT_NOT_FOUND.
      const { data: playerProfile, error: profileError } = await db
        .from("player_profiles")
        .select("user_id")
        .eq("user_id", identity.uid)
        .maybeSingle();
      if (profileError) throw profileError;
      if (!playerProfile) return json({ ok: true, data: { unlocked_ids: [] } }, 200, origin);
      const { data, error } = await db.rpc("unlock_eligible_achievements", { p_uid: identity.uid });
      if (error) return json({ error: "ACHIEVEMENT_SYNC_FAILED" }, 409, origin);
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "fetch_leaderboards") {
      const { data, error } = await db.rpc("fetch_leaderboards");
      if (error) return json({ error: "LEADERBOARD_FETCH_FAILED" }, 500, origin);
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "sync_self_org_membership") {
      const orgId = typeof body.orgId === "string" && body.orgId.length > 0 ? body.orgId : null;
      const { data, error } = await db.rpc("sync_self_org_membership", { p_uid: identity.uid, p_org_id: orgId });
      if (error) {
        const known = ["LEADER_CANNOT_LEAVE","NOT_ORG_MEMBER"].find((x) => error.message.includes(x));
        return json({ error: known ?? "ORG_MEMBERSHIP_SYNC_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    return json({ error: "UNKNOWN_ACTION" }, 400, origin);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status = message === "UNAUTHENTICATED" ? 401 : message === "VERIFIED_EMAIL_REQUIRED" ? 403 : 500;
    return json({ error: status === 500 ? "INTERNAL_ERROR" : message }, status, origin);
  }
});
