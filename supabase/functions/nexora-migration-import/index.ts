import { createClient } from "npm:@supabase/supabase-js@2.95.0";
import { createRemoteJWKSet, jwtVerify } from "npm:jose@5.10.0";

const PROJECT_ID = "gen-lang-client-0074900177";
const FIREBASE_ISSUER = `https://securetoken.google.com/${PROJECT_ID}`;
const FIREBASE_KEYS = createRemoteJWKSet(new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"));
const GITHUB_ISSUER = "https://token.actions.githubusercontent.com";
const GITHUB_KEYS = createRemoteJWKSet(new URL("https://token.actions.githubusercontent.com/.well-known/jwks"));
const GITHUB_REPOSITORY = "luffyk124-del/nexora-game";
const GITHUB_WORKFLOW = ".github/workflows/nexora-firestore-export.yml";

type Json = Record<string, unknown>;
type Doc = { id: string; path: string; fields: Json };
type MapSpec = { table: string; conflict: string; columns: string[]; aliases?: Record<string, string> };

const SPECS: Record<string, MapSpec> = {
  profiles: { table: "player_profiles", conflict: "user_id", columns: ["user_id","username","username_lower","avatar_id","title","level","xp","reputation","influence","skill_points","skills","stats","org_id","created_at","updated_at"], aliases: { uid: "user_id" } },
  users_private: { table: "player_private", conflict: "user_id", columns: ["user_id","email","language","notifications_enabled","created_at","updated_at"], aliases: { uid: "user_id" } },
  wallets: { table: "wallets", conflict: "user_id", columns: ["user_id","balance","total_earned","total_spent","last_tx_id","created_at","updated_at"], aliases: { uid: "user_id" } },
  transactions: { table: "transactions", conflict: "id", columns: ["id","from_uid","to_uid","amount","fee","net_amount","type","reference_id","description","status","created_at"] },
  inventory: { table: "inventory", conflict: "user_id,item_id", columns: ["user_id","item_id","quantity","last_listing_id","updated_at"], aliases: { uid: "user_id" } },
  market_listings: { table: "market_listings", conflict: "id", columns: ["id","seller_uid","seller_name","item_id","quantity","remaining_qty","unit_price","status","created_at","updated_at"] },
  market_orders: { table: "market_orders", conflict: "id", columns: ["id","listing_id","buyer_uid","seller_uid","item_id","quantity","unit_price","total_price","tax_amount","tx_id","created_at"] },
  companies: { table: "companies", conflict: "id", columns: ["id","owner_uid","owner_name","name","sector","level","capital","employees_count","base_revenue_per_hour","expense_per_hour","total_revenue","vault_level","vault_balance","level_upgrade_started_at","level_upgrade_ends_at","level_upgrade_target_level","level_upgrade_cost","vault_upgrade_started_at","vault_upgrade_ends_at","vault_upgrade_target_level","auction_id","auction_ends_at","auction_status","last_collected_at","created_at","updated_at"] },
  company_auctions: { table: "company_auctions", conflict: "id", columns: ["id","company_id","company_name","company_level","seller_uid","seller_name","starting_price","current_bid","highest_bidder_uid","highest_bidder_name","ends_at","status","created_at","updated_at"] },
  company_logs: { table: "company_logs", conflict: "id", columns: ["id","company_id","owner_uid","action","amount","details","created_at"] },
  properties: { table: "properties", conflict: "id", columns: ["id","owner_uid","name","property_type","level","purchase_price","rent_per_hour","maintenance_per_hour","is_rented","last_collected_at","created_at","updated_at"], aliases: { type: "property_type" } },
  organizations: { table: "organizations", conflict: "id", columns: ["id","name","tag","description","leader_uid","leader_name","treasury_balance","member_count","reputation","level","member_capacity","join_mode","research","upgrade_started_at","upgrade_ends_at","upgrade_target_level","created_at","updated_at"] },
  organization_members: { table: "organization_members", conflict: "org_id,user_id", columns: ["org_id","user_id","username","role","permissions","joined_at"], aliases: { uid: "user_id" } },
  organization_requests: { table: "organization_requests", conflict: "id", columns: ["id","org_id","user_id","username","status","created_at","updated_at"], aliases: { uid: "user_id" } },
  organization_transactions: { table: "organization_transactions", conflict: "id", columns: ["id","org_id","user_id","username","type","amount","note","created_at"], aliases: { uid: "user_id" } },
  player_missions: { table: "player_missions", conflict: "user_id,mission_id", columns: ["user_id","mission_id","category","reward_credits","reward_xp","claimed_at"], aliases: { uid: "user_id" } },
  daily_claims: { table: "daily_claims", conflict: "user_id,date_key", columns: ["user_id","date_key","amount","claimed_at"], aliases: { uid: "user_id" } },
  contract_claims: { table: "contract_claims", conflict: "user_id,contract_id", columns: ["user_id","contract_id","amount","claimed_at"], aliases: { uid: "user_id" } },
  player_achievements: { table: "player_achievements", conflict: "user_id,achievement_id", columns: ["user_id","achievement_id","unlocked_at"], aliases: { uid: "user_id" } },
  notifications: { table: "notifications", conflict: "id", columns: ["id","user_id","title","body","type","is_read","created_at"], aliases: { uid: "user_id", read: "is_read" } },
  world_events: { table: "world_events", conflict: "id", columns: ["id","title_ar","title_en","description_ar","description_en","effect_type","target_item_id","affected_sectors","price_multiplier","revenue_multiplier","tax_delta","stack_group","starts_at","ends_at","active","created_at"] },
  audit_logs: { table: "audit_logs", conflict: "id", columns: ["id","user_id","action","entity_type","entity_id","details","created_at"], aliases: { userId: "user_id" } },
  usernames: { table: "usernames", conflict: "username_lower", columns: ["username_lower","uid","username","created_at"] },
  player_reports: { table: "player_reports", conflict: "id", columns: ["id","reporter_uid","target_uid","reason","status","created_at","reviewed_at","reviewed_by","details"] },
  user_blocks: { table: "user_blocks", conflict: "id", columns: ["id","owner_uid","target_uid","created_at"] },
  chat_rate_limits: { table: "chat_rate_limits", conflict: "id", columns: ["id","last_sent_at"] },
  conversations: { table: "conversations", conflict: "id", columns: ["id","participants","participant_names","participant_avatars","last_message","last_message_at","last_sender_uid","created_at","updated_at"] },
  conversation_messages: { table: "conversation_messages", conflict: "id", columns: ["id","conversation_id","sender_uid","sender_name","message_text","created_at"], aliases: { text: "message_text" } },
  global_chat_messages: { table: "global_chat_messages", conflict: "id", columns: ["id","sender_uid","sender_name","avatar_id","message_text","created_at"], aliases: { text: "message_text" } },
  organization_invites: { table: "organization_invites", conflict: "id", columns: ["id","org_id","org_name","org_tag","target_uid","inviter_uid","inviter_name","status","created_at","responded_at"] },
};

const allowedOrigins = new Set([
  "https://nexora-game-git-feature-nexora-social-economy-mo-add6d8-manus24.vercel.app",
  "https://nexora-game-wkbi2g3f9-manus24.vercel.app",
]);
const corsHeadersFor = (origin: string | null) => ({
  "Access-Control-Allow-Origin": origin && allowedOrigins.has(origin)
    ? origin
    : "https://nexora-game-git-feature-nexora-social-economy-mo-add6d8-manus24.vercel.app",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
  "Vary": "Origin",
});

const reply = (body: unknown, status = 200, origin: string | null = null) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeadersFor(origin), "Content-Type": "application/json", "Cache-Control": "no-store" },
  });

function camelToSnake(key: string): string {
  return key.replace(/[A-Z]/g, (letter) => "_" + letter.toLowerCase());
}

function sha256(value: string): Promise<string> {
  return crypto.subtle.digest("SHA-256", new TextEncoder().encode(value))
    .then((hash) => Array.from(new Uint8Array(hash)).map((b) => b.toString(16).padStart(2, "0")).join(""));
}

function safeId(value: unknown): value is string {
  return typeof value === "string" && value.length > 0 && value.length <= 512 && !value.includes("/");
}

async function main(req: Request): Promise<Response> {
  const origin = req.headers.get("Origin");
  if (origin && !allowedOrigins.has(origin)) return new Response("Forbidden origin", { status: 403 });
  const send = (body: unknown, status = 200) => reply(body, status, origin);
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeadersFor(origin) });
  }
  if (req.method !== "POST") return send({ error: "METHOD_NOT_ALLOWED" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const secretRaw = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!url || !secretRaw) return send({ error: "SERVER_CONFIGURATION_ERROR" }, 500);

  let serviceKey = "";
  try { serviceKey = JSON.parse(secretRaw).default ?? ""; } catch { return send({ error: "SERVER_CONFIGURATION_ERROR" }, 500); }
  if (!serviceKey) return send({ error: "SERVER_CONFIGURATION_ERROR" }, 500);

  const bearer = req.headers.get("Authorization") ?? "";
  const token = bearer.startsWith("Bearer ") ? bearer.slice(7) : "";
  if (!token) return send({ error: "UNAUTHENTICATED" }, 401);

  let uid = "";
  let claimedOwner = false;
  try {
    const { payload } = await jwtVerify(token, FIREBASE_KEYS, {
      issuer: FIREBASE_ISSUER, audience: PROJECT_ID, algorithms: ["RS256"],
    });
    const firebase = payload.firebase && typeof payload.firebase === "object" ? payload.firebase as Json : {};
    if (typeof payload.sub !== "string" || !payload.sub || payload.email_verified !== true || firebase.sign_in_provider === "anonymous") {
      return send({ error: "VERIFIED_OWNER_REQUIRED" }, 403);
    }
    uid = payload.sub;
    claimedOwner = payload.diagnosticsOwner === true;
  } catch {
    try {
      const audience = `${url}/functions/v1/nexora-migration-import`;
      const { payload } = await jwtVerify(token, GITHUB_KEYS, {
        issuer: GITHUB_ISSUER, audience, algorithms: ["RS256"],
      });
      const ref = typeof payload.ref === "string" ? payload.ref : "";
      const workflowRef = typeof payload.workflow_ref === "string" ? payload.workflow_ref : "";
      const actor = typeof payload.actor === "string" ? payload.actor : "";
      const allowedRef = ref === "refs/heads/feature/nexora-social-economy-mobile-overhaul" || ref === "refs/heads/main";
      if (payload.repository !== GITHUB_REPOSITORY || !allowedRef ||
          workflowRef !== `${GITHUB_REPOSITORY}/${GITHUB_WORKFLOW}@${ref}` ||
          !["workflow_dispatch","schedule"].includes(String(payload.event_name)) || actor !== "luffyk124-del") {
        return send({ error: "GITHUB_EXPORTER_NOT_AUTHORIZED" }, 403);
      }
      uid = `github-actions:${actor}`;
      claimedOwner = true;
    } catch {
      return send({ error: "UNAUTHENTICATED" }, 401);
    }
  }

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  if (!claimedOwner) {
    const { data: operator, error: operatorError } = await admin.schema("nexora")
      .from("migration_operators").select("firebase_uid,enabled,role")
      .eq("firebase_uid", uid).eq("enabled", true).eq("role", "owner").maybeSingle();
    if (operatorError || !operator) return send({ error: "MIGRATION_OWNER_REQUIRED" }, 403);
  }

  let body: Json;
  try { body = await req.json(); } catch { return send({ error: "INVALID_JSON" }, 400); }
  const collection = typeof body.collection === "string" ? body.collection : "";
  const spec = SPECS[collection];
  if (!spec) return send({ error: "COLLECTION_NOT_ALLOWED" }, 400);

  const parentId = typeof body.parentId === "string" ? body.parentId : "";
  if (collection === "conversation_messages" && !/^[A-Za-z0-9_-]{1,256}$/.test(parentId)) return send({ error: "PARENT_ID_REQUIRED" }, 400);
  if (collection !== "conversation_messages" && parentId) return send({ error: "UNEXPECTED_PARENT_ID" }, 400);

  if (!Array.isArray(body.documents) || body.documents.length > 100) return send({ error: "INVALID_BATCH_SIZE" }, 400);
  const docs = body.documents as Doc[];
  const ids = new Set<string>();
  const rows: Json[] = [];
  const payloadRows: Json[] = [];

  for (const doc of docs) {
    if (!doc || !safeId(doc.id) || typeof doc.path !== "string" || doc.path.length > 2048 ||
        !doc.fields || typeof doc.fields !== "object" || Array.isArray(doc.fields) || ids.has(doc.id)) {
      return send({ error: "INVALID_DOCUMENT" }, 400);
    }
    ids.add(doc.id);
    const suffix = collection === "conversation_messages"
      ? `/conversations/${parentId}/messages/${doc.id}`
      : `/${collection}/${doc.id}`;
    if (!doc.path.endsWith(suffix)) return send({ error: "DOCUMENT_PATH_MISMATCH" }, 400);

    const row: Json = {};
    for (const [key, value] of Object.entries(doc.fields)) {
      const column = spec.aliases?.[key] ?? camelToSnake(key);
      if (spec.columns.includes(column) && value !== undefined) row[column] = value;
    }
    // world_events.affected_sectors is NOT NULL in NEXORA; legacy Firestore
    // documents may omit it or store null, so normalize missing values to [].
    if (collection === "world_events" && (row.affected_sectors === undefined || row.affected_sectors === null)) {
      row.affected_sectors = [];
    }

    // company_logs.details is constrained to a JSON object in NEXORA.
    // Older Firestore records sometimes store it as plain text; preserve that text.
    if (collection === "company_logs") {
      const details = row.details;
      if (typeof details === "string") row.details = { message: details };
      else if (details === undefined || details === null) row.details = {};
      else if (typeof details !== "object" || Array.isArray(details)) row.details = { value: details };
    }

    if (spec.columns.includes("id") && row.id === undefined) row.id = doc.id;
    if (collection === "profiles" || collection === "users_private" || collection === "wallets") {
      if (row.user_id === undefined) row.user_id = doc.id;
    }
    if (collection === "usernames" && row.username_lower === undefined && typeof row.username === "string") {
      row.username_lower = row.username.toLowerCase();
    }
    if (collection === "conversation_messages") row.conversation_id = parentId;
    rows.push(row);
    payloadRows.push({
      source_collection: collection,
      source_parent_id: parentId,
      source_document_id: doc.id,
      source_path: doc.path,
      raw_fields: doc.fields,
    });
  }

  const checksum = await sha256(JSON.stringify({ collection, parentId, docs }));
  const db = admin.schema("nexora");
  const { data: priorBatch, error: priorError } = await db.from("migration_batches")
    .select("id,row_count").eq("source_collection", collection)
    .eq("source_parent_id", parentId).eq("checksum", checksum).maybeSingle();
  if (priorError) return send({ error: "MIGRATION_STATE_READ_FAILED" }, 500);
  if (priorBatch) return send({ ok: true, alreadyImported: true, imported: priorBatch.row_count, checksum });

  if (rows.length) {
    const immutableCollections = new Set(["transactions", "player_missions", "daily_claims", "contract_claims", "organization_transactions", "player_achievements", "audit_logs"]);
    const { error } = immutableCollections.has(collection)
      ? await db.from(spec.table).upsert(rows, { onConflict: spec.conflict, ignoreDuplicates: true })
      : await db.from(spec.table).upsert(rows, { onConflict: spec.conflict });
    if (error) return send({ error: "MAPPED_IMPORT_FAILED", table: spec.table, detail: error.message.slice(0, 180) }, 500);
  }

  if (payloadRows.length) {
    const { error } = await db.from("firestore_import_payloads").upsert(payloadRows, {
      onConflict: "source_collection,source_parent_id,source_document_id",
    });
    if (error) return send({ error: "RAW_ARCHIVE_FAILED", detail: error.message.slice(0, 180) }, 500);
  }

  const { error: batchError } = await db.from("migration_batches").insert({
    source_collection: collection,
    source_parent_id: parentId,
    row_count: rows.length,
    checksum,
    imported_by_firebase_uid: uid,
  });
  if (batchError) return send({ error: "MIGRATION_AUDIT_WRITE_FAILED" }, 500);

  return send({ ok: true, imported: rows.length, archived: payloadRows.length, checksum });
}

Deno.serve((req: Request) => main(req));
