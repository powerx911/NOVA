import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { getAdminClient, authenticate } from "./_shared/auth.ts";
import { bootstrap } from "./_shared/bootstrap.ts";
import { getSocialAction } from "./_shared/social.ts";
import { camelRow } from "./_shared/serialization.ts";

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

    if (body.action === "fetch_market_listings") {
      const { data, error } = await db.from("market_listings").select("*")
        .eq("status", "active").gt("remaining_qty", 0)
        .order("unit_price", { ascending: true }).order("created_at", { ascending: true }).limit(500);
      if (error) throw error;
      return json({ ok: true, data: camelRow(data ?? []) }, 200, origin);
    }

    if (body.action === "fetch_market_activity") {
      const { data: orders, error } = await db.from("market_orders")
        .select("id,listing_id,buyer_uid,seller_uid,item_id,quantity,unit_price,total_price,tax_amount,tx_id,created_at")
        .or(`buyer_uid.eq.${identity.uid},seller_uid.eq.${identity.uid}`)
        .order("created_at", { ascending: false }).limit(100);
      if (error) throw error;
      const participantIds = [...new Set((orders ?? [])
        .flatMap((order) => [order.buyer_uid, order.seller_uid])
        .filter((uid): uid is string => typeof uid === "string" && uid.length > 0 && uid !== "SYSTEM"))];
      const names = new Map<string, string>();
      if (participantIds.length > 0) {
        const { data: players, error: playersError } = await db.from("player_profiles")
          .select("user_id,username").in("user_id", participantIds);
        if (playersError) throw playersError;
        for (const player of players ?? []) names.set(player.user_id, player.username);
      }
      return json({ ok: true, data: (orders ?? []).map((order) => ({
        id: order.id,
        listingId: order.listing_id,
        buyerUid: order.buyer_uid,
        buyerName: names.get(order.buyer_uid) ?? "—",
        sellerUid: order.seller_uid,
        sellerName: order.seller_uid === "SYSTEM" ? "NEXORA CITY" : (names.get(order.seller_uid) ?? "—"),
        itemId: order.item_id,
        quantity: order.quantity,
        unitPrice: order.unit_price,
        totalPrice: order.total_price,
        taxAmount: order.tax_amount,
        txId: order.tx_id,
        createdAt: order.created_at,
      })) }, 200, origin);
    }

    if (body.action === "fetch_inventory_capacity_usage") {
      const { data, error } = await db.rpc("player_inventory_usage", { p_uid: identity.uid });
      if (error) throw error;
      return json({ ok: true, data: Number(data ?? 0) }, 200, origin);
    }

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
        const [{ error: missionNoticeError }, { error: contractSettleError }] = await Promise.all([
          db.rpc("notify_ready_missions", { p_uid: identity.uid }),
          db.rpc("settle_dynamic_contracts", { p_uid: identity.uid }),
        ]);
        if (missionNoticeError) throw missionNoticeError;
        if (contractSettleError) throw contractSettleError;
        const { error: readyContractNoticeError } = await db.rpc("notify_ready_contracts", { p_uid: identity.uid });
        if (readyContractNoticeError) throw readyContractNoticeError;
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

    if (body.action === "validate_transfer_recipient") {
      const username = typeof body.username === "string" ? body.username.trim() : "";
      if (!/^[a-zA-Z0-9_]{3,24}$/.test(username)) {
        return json({ ok: true, data: { exists: false, isSelf: false } }, 200, origin);
      }
      const { data, error } = await db.from("usernames").select("uid")
        .eq("username_lower", username.toLowerCase()).maybeSingle();
      if (error) throw error;
      return json({ ok: true, data: { exists: Boolean(data), isSelf: Boolean(data && data.uid === identity.uid) } }, 200, origin);
    }

    if (body.action === "refresh_achievements") {
      const { data, error } = await db.rpc("unlock_eligible_achievements", { p_uid: identity.uid });
      if (error) throw error;
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "username_available") {
      const username = typeof body.username === "string" ? body.username.trim() : "";
      if (!/^[a-zA-Z0-9_]{3,24}$/.test(username)) {
        return json({ ok: true, data: { available: false } }, 200, origin);
      }
      const { data, error } = await db.from("usernames").select("uid").eq("username_lower", username.toLowerCase()).maybeSingle();
      if (error) throw error;
      return json({ ok: true, data: { available: !data } }, 200, origin);
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

    if (body.action === "reset_skills") {
      const { data, error } = await db.rpc("reset_player_skills", { p_uid: identity.uid });
      if (error) {
        const known = ["ACCOUNT_NOT_FOUND","NO_SKILLS_TO_RESET","INSUFFICIENT_FUNDS"].find((code) => error.message.includes(code));
        return json({ error: known ?? "SKILL_RESET_FAILED" }, 409, origin);
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
        const known = ["RECIPIENT_NOT_FOUND","SELF_OR_MISSING_RECIPIENT","INVALID_AMOUNT","INSUFFICIENT_FUNDS","TRANSFER_LEVEL_REQUIRED","TRANSFER_DAILY_LIMIT"].find((code) => error.message.includes(code));
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
        const known = ["INVALID_ITEM","INVALID_LISTING_PARAMS","INSUFFICIENT_INVENTORY","ACCOUNT_NOT_FOUND","PRICE_BELOW_MINIMUM","PRICE_ABOVE_MAXIMUM"].find((code) => error.message.includes(code));
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
        const known = ["INVALID_QUANTITY","LISTING_NOT_FOUND","INSUFFICIENT_LISTING_QTY","CANNOT_BUY_OWN_LISTING","INSUFFICIENT_FUNDS","ACCOUNT_NOT_FOUND","SELLER_ACCOUNT_NOT_FOUND","INVENTORY_CAPACITY_EXCEEDED","PRICE_BELOW_MINIMUM","PRICE_ABOVE_MAXIMUM"].find((code) => error.message.includes(code));
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
        const known = ["INVALID_RECIPE","INVALID_QUANTITY","ACCOUNT_NOT_FOUND","INDUSTRY_SKILL_TOO_LOW","INSUFFICIENT_FUNDS","MISSING_INPUTS","MANUFACTURING_JOB_IN_PROGRESS"].find((code) => error.message.includes(code));
        return json({ error: known ?? "MANUFACTURING_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "get_manufacturing_job") {
      const { data, error } = await db.rpc("get_manufacturing_job", { p_uid: identity.uid });
      if (error) return json({ error: "MANUFACTURING_JOB_FETCH_FAILED" }, 500, origin);
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "complete_manufacturing_job") {
      const jobId = typeof body.jobId === "string" ? body.jobId : "";
      if (!jobId || jobId.length > 128) return json({ error: "INVALID_ARGUMENT" }, 400, origin);
      const { data, error } = await db.rpc("complete_manufacturing_job", {
        p_uid: identity.uid, p_job_id: jobId,
      });
      if (error) {
        const known = ["MANUFACTURING_JOB_NOT_FOUND","MANUFACTURING_JOB_NOT_FINISHED","MANUFACTURING_JOB_CANCELLED","INVENTORY_CAPACITY_EXCEEDED","ACCOUNT_NOT_FOUND"].find((code) => error.message.includes(code));
        return json({ error: known ?? "MANUFACTURING_COMPLETION_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "cancel_manufacturing_job") {
      const jobId = typeof body.jobId === "string" ? body.jobId : "";
      if (!jobId || jobId.length > 128) return json({ error: "INVALID_ARGUMENT" }, 400, origin);
      const { data, error } = await db.rpc("cancel_manufacturing_job", {
        p_uid: identity.uid, p_job_id: jobId,
      });
      if (error) {
        const known = ["MANUFACTURING_JOB_NOT_FOUND","MANUFACTURING_JOB_ALREADY_FINISHED","MANUFACTURING_JOB_ALREADY_COMPLETED","MANUFACTURING_JOB_CANCELLED","ACCOUNT_NOT_FOUND"].find((code) => error.message.includes(code));
        return json({ error: known ?? "MANUFACTURING_CANCELLATION_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    // @deprecated Retained for legacy clients only; the NOVA UI no longer calls this route.
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

    const dynamicContractActions: Record<string, { rpc: string; args: Record<string, unknown>; status: number }> = {
      get_dynamic_contract_board: { rpc: "get_dynamic_contract_board", args: { p_uid: identity.uid }, status: 200 },
      get_contract_slot_cooldowns: { rpc: "get_contract_slot_cooldowns", args: { p_uid: identity.uid }, status: 200 },
      refresh_dynamic_contract: {
        rpc: "refresh_dynamic_contract",
        args: { p_uid: identity.uid, p_contract_id: typeof body.contractId === "string" ? body.contractId : "" },
        status: 200,
      },
      accept_dynamic_contract: {
        rpc: "accept_dynamic_contract",
        args: { p_uid: identity.uid, p_contract_id: typeof body.contractId === "string" ? body.contractId : "" },
        status: 200,
      },
      deliver_dynamic_contract: {
        rpc: "deliver_dynamic_contract",
        args: { p_uid: identity.uid, p_contract_id: typeof body.contractId === "string" ? body.contractId : "" },
        status: 200,
      },
      abandon_dynamic_contract: {
        rpc: "abandon_dynamic_contract",
        args: { p_uid: identity.uid, p_contract_id: typeof body.contractId === "string" ? body.contractId : "" },
        status: 200,
      },
      claim_dynamic_contract: {
        rpc: "claim_dynamic_contract",
        args: { p_uid: identity.uid, p_contract_id: typeof body.contractId === "string" ? body.contractId : "" },
        status: 200,
      },
      get_org_weekly_goals: { rpc: "get_org_weekly_goals", args: { p_uid: identity.uid }, status: 200 },
    };
    const dynamicContractAction = dynamicContractActions[body.action];
    if (dynamicContractAction) {
      if (body.action !== "get_dynamic_contract_board" && body.action !== "get_org_weekly_goals" && body.action !== "get_contract_slot_cooldowns") {
        const contractId = dynamicContractAction.args.p_contract_id;
        if (typeof contractId !== "string" || !contractId || contractId.length > 128) {
          return json({ error: "INVALID_ARGUMENT" }, 400, origin);
        }
      }
      const { data, error } = await db.rpc(dynamicContractAction.rpc, dynamicContractAction.args);
      if (error) {
        const known = [
          "ACCOUNT_NOT_FOUND", "CONTRACT_NOT_FOUND", "CONTRACT_NOT_AVAILABLE", "CONTRACT_EXPIRED",
          "UNAUTHORIZED", "ORG_NOT_FOUND", "ORG_MEMBERSHIP_TOO_NEW", "CONTRACT_ALREADY_CLAIMED",
          "ORG_ACTIVE_CONTRACT_LIMIT", "ACTIVE_CONTRACT_LIMIT", "CONTRACT_NOT_ACCEPTED",
          "CONTRACT_CANNOT_BE_ABANDONED", "MISSING_INPUTS", "INSUFFICIENT_FUNDS",
          "CONTRACT_NOT_READY", "CONTRACT_NOT_CLAIMABLE", "DAILY_CONTRACT_LIMIT_REACHED", "CONTRACT_NOT_REFRESHABLE", "ORG_REFRESH_PERMISSION_REQUIRED", "CONTRACT_REFRESH_LIMIT_REACHED",
          "NOT_IN_ORG",
        ].find((code) => error.message.includes(code));
        return json({ error: known ?? "DYNAMIC_CONTRACT_FAILED" }, 409, origin);
      }
      if (data && typeof data === "object" && "error" in data && (data as { error?: unknown }).error) {
        return json({ error: String((data as { error: unknown }).error) }, 409, origin);
      }
      if (body.action === "get_dynamic_contract_board") {
        const { data: cooldowns, error: cooldownError } = await db.rpc("get_contract_slot_cooldowns", { p_uid: identity.uid });
        if (cooldownError) return json({ error: "CONTRACT_COOLDOWN_FETCH_FAILED" }, 500, origin);
        return json({ ok: true, data: { ...(data as Record<string, unknown>), cooldowns } }, dynamicContractAction.status, origin);
      }
      return json({ ok: true, data }, dynamicContractAction.status, origin);
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


    if (body.action === "found_factory") {
      const name = typeof body.name === "string" ? body.name.trim() : "";
      const resourceId = typeof body.resourceId === "string" ? body.resourceId : "";
      const { data, error } = await db.rpc("found_factory", { p_uid: identity.uid, p_name: name, p_resource_id: resourceId });
      if (error) {
        const known = ["INVALID_NAME","INVALID_RESOURCE","ACCOUNT_NOT_FOUND","FACTORY_CAPACITY_REACHED","INSUFFICIENT_FUNDS"].find((code) => error.message.includes(code));
        return json({ error: known ?? "FACTORY_FOUNDING_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 201, origin);
    }

    if (body.action === "sync_factory" || body.action === "upgrade_factory" ||
        body.action === "complete_factory_upgrade" || body.action === "upgrade_factory_skill" ||
        body.action === "withdraw_factory_warehouse" || body.action === "set_factory_active" ||
        body.action === "upgrade_factory_warehouse" || body.action === "complete_factory_warehouse_upgrade") {
      const factoryId = typeof body.factoryId === "string" ? body.factoryId : "";
      if (!factoryId || factoryId.length > 128) return json({ error: "INVALID_ARGUMENT" }, 400, origin);
      let rpcName = "sync_factory_production";
      let args: Record<string, unknown> = { p_uid: identity.uid, p_factory_id: factoryId };
      if (body.action === "upgrade_factory") rpcName = "upgrade_factory";
      else if (body.action === "complete_factory_upgrade") rpcName = "complete_factory_upgrade";
      else if (body.action === "upgrade_factory_skill") rpcName = "upgrade_factory_skill";
      else if (body.action === "upgrade_factory_warehouse") rpcName = "upgrade_factory_warehouse";
      else if (body.action === "complete_factory_warehouse_upgrade") rpcName = "complete_factory_warehouse_upgrade";
      else if (body.action === "set_factory_active") {
        rpcName = "set_factory_active";
        args = { ...args, p_active: body.active === true };
      }
      else if (body.action === "withdraw_factory_warehouse") {
        rpcName = "withdraw_factory_warehouse";
        const quantity = typeof body.quantity === "number" && Number.isFinite(body.quantity) ? Math.floor(body.quantity) : 0;
        args = { ...args, p_quantity: quantity };
      }
      const { data, error } = await db.rpc(rpcName, args);
      if (error) {
        const known = [
          "FACTORY_NOT_FOUND","UNAUTHORIZED","ACCOUNT_NOT_FOUND","INSUFFICIENT_FUNDS",
          "FACTORY_CAPACITY_REACHED","UPGRADE_IN_PROGRESS","MAX_LEVEL","MISSING_FACTORY_MATERIALS",
          "NO_UPGRADE_IN_PROGRESS","UPGRADE_NOT_FINISHED","SKILL_MAXED","INVALID_QUANTITY",
          "WAREHOUSE_INSUFFICIENT_STOCK","INVENTORY_CAPACITY_EXCEEDED",
        ].find((code) => error.message.includes(code));
        return json({ error: known ?? "FACTORY_OPERATION_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "found_company") {
      const name = typeof body.name === "string" ? body.name.trim() : "";
      const sector = typeof body.sector === "string" ? body.sector : "";
      const { data, error } = await db.rpc("found_company", { p_uid: identity.uid, p_name: name, p_sector: sector });
      if (error) {
        const known = ["INVALID_NAME","INVALID_SECTOR","ACCOUNT_NOT_FOUND","INSUFFICIENT_FUNDS","COMPANY_CAPACITY_REACHED","COMPANY_AUCTION_PENDING"].find((code) => error.message.includes(code));
        return json({ error: known ?? "COMPANY_FOUNDING_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 201, origin);
    }

    if (body.action === "fetch_company_auctions") {
      const { data, error } = await db.rpc("fetch_company_auctions", { p_uid: identity.uid });
      if (error) return json({ error: "COMPANY_AUCTIONS_FETCH_FAILED" }, 500, origin);
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "list_factory_for_auction") {
      const factoryId = typeof body.factoryId === "string" ? body.factoryId : "";
      const startingPrice = typeof body.startingPrice === "number" && Number.isFinite(body.startingPrice) ? Math.floor(body.startingPrice) : 0;
      const { data, error } = await db.rpc("list_factory_for_auction", { p_uid: identity.uid, p_factory_id: factoryId, p_starting_price: startingPrice });
      if (error) {
        const known = ["FACTORY_NOT_FOUND","UNAUTHORIZED","FACTORY_LEVEL_TOO_LOW","FACTORY_ALREADY_LISTED","FACTORY_UPGRADE_IN_PROGRESS","INVALID_STARTING_PRICE"].find((code) => error.message.includes(code));
        return json({ error: known ?? "FACTORY_AUCTION_LIST_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 201, origin);
    }

    if (body.action === "list_company_for_auction") {
      const companyId = typeof body.companyId === "string" ? body.companyId : "";
      const startingPrice = typeof body.startingPrice === "number" && Number.isFinite(body.startingPrice)
        ? Math.floor(body.startingPrice) : 0;
      const { data, error } = await db.rpc("list_company_for_auction", {
        p_uid: identity.uid, p_company_id: companyId, p_starting_price: startingPrice,
      });
      if (error) {
        const known = ["COMPANY_NOT_FOUND","UNAUTHORIZED","COMPANY_LEVEL_TOO_LOW","COMPANY_ALREADY_LISTED",
          "COMPANY_UPGRADE_IN_PROGRESS","INVALID_STARTING_PRICE"].find((code) => error.message.includes(code));
        return json({ error: known ?? "COMPANY_AUCTION_LIST_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 201, origin);
    }

    if (body.action === "place_factory_auction_bid") {
      const auctionId = typeof body.auctionId === "string" ? body.auctionId : "";
      const amount = typeof body.amount === "number" && Number.isFinite(body.amount) ? Math.floor(body.amount) : 0;
      const { data, error } = await db.rpc("place_factory_auction_bid", { p_uid: identity.uid, p_auction_id: auctionId, p_amount: amount });
      if (error) {
        const known = ["AUCTION_NOT_FOUND","AUCTION_NOT_ACTIVE","CANNOT_BID_OWN_FACTORY","BID_TOO_LOW","ACCOUNT_NOT_FOUND","FACTORY_CAPACITY_REACHED","INSUFFICIENT_FUNDS"].find((code) => error.message.includes(code));
        return json({ error: known ?? "FACTORY_AUCTION_BID_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "place_company_auction_bid") {
      const auctionId = typeof body.auctionId === "string" ? body.auctionId : "";
      const amount = typeof body.amount === "number" && Number.isFinite(body.amount) ? Math.floor(body.amount) : 0;
      const { data, error } = await db.rpc("place_company_auction_bid", {
        p_uid: identity.uid, p_auction_id: auctionId, p_amount: amount,
      });
      if (error) {
        const known = ["AUCTION_NOT_FOUND","AUCTION_NOT_ACTIVE","CANNOT_BID_OWN_COMPANY","INVALID_BID",
          "BID_TOO_LOW","ACCOUNT_NOT_FOUND","COMPANY_CAPACITY_REACHED","INSUFFICIENT_FUNDS"].find((code) => error.message.includes(code));
        return json({ error: known ?? "COMPANY_AUCTION_BID_FAILED" }, 409, origin);
      }
      return json({ ok: true, data }, 200, origin);
    }

    if (body.action === "delete_company") {
      const companyId = typeof body.companyId === "string" ? body.companyId : "";
      const { data, error } = await db.rpc("delete_company", { p_uid: identity.uid, p_company_id: companyId });
      if (error) {
        const known = ["COMPANY_NOT_FOUND","UNAUTHORIZED","COMPANY_IN_AUCTION"].find((code) => error.message.includes(code));
        return json({ error: known ?? "COMPANY_DELETE_FAILED" }, 409, origin);
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

    if (body.action === "claim_achievement_reward") {
      const achievementId = typeof body.achievementId === "string" ? body.achievementId : "";
      const { data, error } = await db.rpc("claim_achievement_reward", { p_uid: identity.uid, p_achievement_id: achievementId });
      if (error) {
        const known = ["INVALID_ACHIEVEMENT","ACHIEVEMENT_NOT_UNLOCKED","ACHIEVEMENT_ALREADY_CLAIMED","ACCOUNT_NOT_FOUND"].find((code) => error.message.includes(code));
        return json({ error: known ?? "ACHIEVEMENT_CLAIM_FAILED" }, 409, origin);
      }
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

    const socialAction = getSocialAction(body.action as string, body, identity.uid);
    if (socialAction) {
      const { data, error } = await db.rpc(socialAction.rpc, socialAction.args);
      if (error) {
        const known = [
          "PLAYER_NOT_FOUND","INVALID_TARGET","INVALID_REPORT","REPORT_RATE_LIMIT","PLAYER_BLOCKED",
          "CONVERSATION_ACCESS_DENIED","INVALID_MESSAGE","EMPTY_MESSAGE","CHAT_RATE_LIMIT",
          "PROFILE_NOT_FOUND","NOT_IN_ORG","ORG_CHAT_ACCESS_DENIED","ORG_CHAT_NOT_AVAILABLE","INVITE_PERMISSION_REQUIRED","TARGET_ALREADY_IN_ORG",
          "INVITE_ALREADY_PENDING","INVITE_NOT_AVAILABLE","ALREADY_IN_ORG","ORG_FULL",
        ].find((code) => error.message.includes(code));
        return json({ error: known ?? "SOCIAL_OPERATION_FAILED" }, 409, origin);
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
