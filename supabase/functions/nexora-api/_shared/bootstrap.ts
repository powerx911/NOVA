import { getAdminClient } from "./auth.ts";
import { camelRow, queryData } from "./serialization.ts";

export async function bootstrap(admin: ReturnType<typeof getAdminClient>, uid: string) {
  const db = admin.schema("nexora");
  const [profile, userPrivate, wallet, inventory, sent, received, marketListings,
    marketOrders, companies, factories, organizations,
    organizationMembers, organizationRequests, playerMissions, dailyClaims, missionProgress,
    contractClaims, playerAchievements, notifications, worldEvents] = await Promise.all([
    queryData(db.from("player_profiles").select("*").eq("user_id", uid).maybeSingle()),
    queryData(db.from("player_private").select("*").eq("user_id", uid).maybeSingle()),
    queryData(db.from("wallets").select("*").eq("user_id", uid).maybeSingle()),
    queryData(db.from("inventory").select("*").eq("user_id", uid)),
    queryData(db.from("transactions").select("*").eq("from_uid", uid).order("created_at", { ascending: false }).limit(30)),
    queryData(db.from("transactions").select("*").eq("to_uid", uid).order("created_at", { ascending: false }).limit(30)),
    queryData(db.from("market_listings").select("*").eq("status", "active").order("created_at", { ascending: false }).limit(100)),
    queryData(db.from("market_orders").select("*").eq("buyer_uid", uid).order("created_at", { ascending: false }).limit(25)),
    queryData(db.from("companies").select("*").eq("owner_uid", uid).eq("is_deleted", false)),
    queryData(db.from("factories").select("*").eq("owner_uid", uid).order("created_at", { ascending: true })),
    queryData(db.from("organizations").select("*").gte("reputation", 0).order("reputation", { ascending: false }).limit(40)),
    queryData(db.from("organization_members").select("*").eq("user_id", uid).limit(1)),
    queryData(db.from("organization_requests").select("*").eq("user_id", uid)),
    queryData(db.from("player_missions").select("*").eq("user_id", uid)),
    queryData(db.from("daily_claims").select("*").eq("user_id", uid).eq("date_key", new Date().toISOString().slice(0, 10)).maybeSingle()),
    queryData(db.rpc("get_mission_progress", { p_uid: uid })),
    queryData(db.from("contract_claims").select("*").eq("user_id", uid)),
    queryData(db.from("player_achievements").select("*").eq("user_id", uid)),
    queryData(db.from("notifications").select("*").eq("user_id", uid).order("created_at", { ascending: false }).limit(30)),
    queryData(db.from("world_events").select("*").eq("active", true)),
  ]);

  const ownedCompanyIds = (companies as Record<string, unknown>[]).map((company) => String(company.id)).filter(Boolean);
  const companyLogs = ownedCompanyIds.length
    ? await queryData(db.from("company_logs").select("*").in("company_id", ownedCompanyIds)
        .order("created_at", { ascending: false }).limit(200))
    : [];

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
    profile: {
      ...(camelRow(profile) as Record<string, unknown>),
      ...((missionProgress ?? {}) as Record<string, unknown>),
    },
    userPrivate: camelRow(userPrivate),
    wallet: camelRow(wallet),
    inventory: camelRow(inventory),
    transactions: camelRow(transactions),
    marketListings: camelRow(marketListings),
    marketOrders: camelRow(marketOrders),
    companies: camelRow(companies),
    factories: camelRow(factories),
    companyLogs: camelRow(companyLogs),
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
    notifications: (notifications as Record<string, unknown>[]).map((notification) => ({
      ...camelRow(notification),
      // The game client reads `read`; the database stores this as `is_read`.
      read: notification.is_read === true,
    })),
    worldEvents: camelRow(worldEvents),
  };
}
