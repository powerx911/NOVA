import {
  COMPANY_SECTORS,
  ITEM_MAP,
  MANUFACTURING_RECIPES,
  MISSIONS,
  SKILL_DEFINITIONS,
  TRADE_CONTRACTS,
} from '../data/catalog';
import {
  calculateLevelProgress,
  isValidUsername,
  LISTING_MAX_PRICE,
  LISTING_MAX_QTY,
  timestampToMs as parseTimestampMs,
} from '../lib/economy';
import { nexoraApi } from '../lib/nexoraApi';
import type {
  Company,
  CompanySector,
  InventoryItem,
  Language,
  MarketListing,
  Organization,
  OrganizationMember,
  OrgRole,
  PlayerProfile,
  SkillKey,
  Wallet,
} from '../types/game';

export function getUtcDateKey(): string {
  return new Date().toISOString().slice(0, 10);
}

export function timestampToMs(ts: unknown): number {
  return parseTimestampMs(ts, Date.now());
}

function applyXpAndLevel(
  profile: PlayerProfile,
  xpGain: number,
  reputationGain = 0,
  influenceGain = 0
) {
  const nextXp = profile.xp + Math.max(0, Math.round(xpGain));
  const prog = calculateLevelProgress(nextXp);
  const levelsGained = Math.max(0, prog.level - profile.level);
  const leadershipBonus = 1 + (profile.skills.leadership || 0) * 0.1;
  return {
    xp: nextXp,
    level: prog.level,
    skillPoints: profile.skillPoints + levelsGained,
    reputation: profile.reputation + Math.round(reputationGain * leadershipBonus),
    influence: profile.influence + Math.round(influenceGain * leadershipBonus),
  };
}

export async function ensureBootstrapWorldData(): Promise<void> {
  // Global market listings and world events are provisioned in the NEXORA Supabase schema.
}

export async function isUsernameAvailable(username: string): Promise<boolean> {
  const clean = username.trim();
  if (!isValidUsername(clean)) return false;
  const result = await nexoraApi<{ available: boolean }>('username_available', { username: clean });
  if (typeof result?.available !== 'boolean') throw new Error('USERNAME_CHECK_FAILED');
  return result.available;
}

export async function createPlayerCharacter(
  _uid: string,
  _email: string,
  username: string,
  avatarId: string,
  language: Language
): Promise<void> {
  const trimmed = username.trim();
  if (!isValidUsername(trimmed)) throw new Error('INVALID_USERNAME');
  try {
    await nexoraApi('create_character', {
      username: trimmed,
      avatarId,
      language,
    });
  } catch (error) {
    if (error instanceof Error && 'code' in error) {
      const code = String((error as { code?: unknown }).code ?? '');
      if (['INVALID_USERNAME', 'USERNAME_TAKEN', 'PROFILE_EXISTS'].includes(code)) {
        throw new Error(code);
      }
    }
    throw error;
  }
}

export async function claimDailyStipend(_uid: string): Promise<number> {
  try {
    const result = await nexoraApi<{ amount: number }>('claim_daily_stipend');
    return result.amount;
  } catch (error) {
    if (error instanceof Error && 'code' in error) {
      throw new Error(String((error as { code?: unknown }).code ?? 'DAILY_CLAIM_FAILED'));
    }
    throw error;
  }
}

export async function upgradeSkill(_uid: string, skillKey: SkillKey): Promise<void> {
  try {
    await nexoraApi('upgrade_skill', { skillKey });
  } catch (error) {
    if (error instanceof Error && 'code' in error) {
      throw new Error(String((error as { code?: unknown }).code ?? 'SKILL_UPGRADE_FAILED'));
    }
    throw error;
  }
}

export async function transferCredits(
  _fromUid: string,
  recipientUsername: string,
  amountRaw: number,
  note: string
): Promise<void> {
  const amount = Number.isFinite(amountRaw) ? Math.floor(amountRaw) : 0;
  try {
    await nexoraApi('transfer_credits', {
      recipientUsername: recipientUsername.trim(),
      amount,
      note: note.trim().slice(0, 180),
    });
  } catch (error) {
    if (error instanceof Error && 'code' in error) {
      throw new Error(String((error as { code?: unknown }).code ?? 'TRANSFER_FAILED'));
    }
    throw error;
  }
}

export async function createMarketListing(
  _uid: string,
  _username: string,
  itemId: string,
  qtyRaw: number,
  unitPriceRaw: number
): Promise<void> {
  const quantity = Number.isFinite(qtyRaw) ? Math.floor(qtyRaw) : 0;
  const unitPrice = Number.isFinite(unitPriceRaw) ? Math.round(unitPriceRaw) : 0;
  if (!ITEM_MAP[itemId]) throw new Error('INVALID_ITEM');
  if (quantity < 1 || quantity > LISTING_MAX_QTY || unitPrice < 1 || unitPrice > LISTING_MAX_PRICE) {
    throw new Error('INVALID_LISTING_PARAMS');
  }
  try {
    await nexoraApi('create_market_listing', { itemId, quantity, unitPrice });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'CREATE_LISTING_FAILED'));
    throw error;
  }
}

export async function buyMarketListing(
  _buyerUid: string,
  listingId: string,
  buyQtyRaw: number,
  _taxRate: number
): Promise<void> {
  const quantity = Number.isFinite(buyQtyRaw) ? Math.floor(buyQtyRaw) : 0;
  if (quantity < 1) throw new Error('INVALID_QUANTITY');
  try {
    await nexoraApi('buy_market_listing', { listingId, quantity });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'MARKET_PURCHASE_FAILED'));
    throw error;
  }
}

export async function cancelMarketListing(_uid: string, listingId: string): Promise<void> {
  try {
    await nexoraApi('cancel_market_listing', { listingId });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'CANCEL_LISTING_FAILED'));
    throw error;
  }
}

export async function manufactureRecipe(_uid: string, recipeId: string, batchQuantity = 1): Promise<void> {
  if (!MANUFACTURING_RECIPES.some((recipe) => recipe.id === recipeId)) throw new Error('INVALID_RECIPE');
  if (!Number.isInteger(batchQuantity) || batchQuantity < 1 || batchQuantity > 999) throw new Error('INVALID_QUANTITY');
  try {
    await nexoraApi('manufacture_recipe', { recipeId, batches: batchQuantity });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'MANUFACTURING_FAILED'));
    throw error;
  }
}

export async function fulfillTradeContract(_uid: string, contractId: string): Promise<number> {
  if (!TRADE_CONTRACTS.some((contract) => contract.id === contractId)) throw new Error('INVALID_CONTRACT');
  try {
    const result = await nexoraApi<{ payout: number }>('fulfill_trade_contract', { contractId });
    return result.payout;
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'CONTRACT_FULFILLMENT_FAILED'));
    throw error;
  }
}

export async function foundCompany(
  _uid: string,
  _ownerName: string,
  name: string,
  sector: CompanySector
): Promise<void> {
  const cleanName = name.trim();
  if (cleanName.length < 2 || cleanName.length > 48) throw new Error('INVALID_NAME');
  if (!COMPANY_SECTORS.some((item) => item.sector === sector)) throw new Error('INVALID_SECTOR');
  await nexoraApi('found_company', { name: cleanName, sector });
}

async function callSupabaseCompanyAction<T>(action: string, companyId: string): Promise<T> {
  try {
    return await nexoraApi<T>(action, { companyId });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'COMPANY_OPERATION_FAILED'));
    throw error;
  }
}

export async function upgradeCompany(_uid: string, companyId: string): Promise<void> {
  await callSupabaseCompanyAction('company_upgrade', companyId);
}

export async function upgradeCompanyVault(_uid: string, companyId: string): Promise<void> {
  await callSupabaseCompanyAction('vault_upgrade', companyId);
}

export async function completeCompanyUpgrade(_uid: string, companyId: string): Promise<void> {
  await callSupabaseCompanyAction('company_complete', companyId);
}

export async function completeCompanyVaultUpgrade(_uid: string, companyId: string): Promise<void> {
  await callSupabaseCompanyAction('vault_complete', companyId);
}

export async function collectCompanyRevenue(_uid: string, companyId: string): Promise<number> {
  const result = await callSupabaseCompanyAction<{ payout: number }>('company_collect', companyId);
  return result.payout;
}

export async function claimMissionReward(_uid: string, missionId: string): Promise<void> {
  if (!MISSIONS.some((mission) => mission.id === missionId)) throw new Error('INVALID_MISSION');
  try {
    await nexoraApi('claim_mission_reward', { missionId });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'MISSION_CLAIM_FAILED'));
    throw error;
  }
}
export async function createOrganization(
  _uid: string,
  _username: string,
  name: string,
  tag: string,
  description: string
): Promise<string> {
  const cleanName = name.trim();
  const cleanTag = tag.trim().toUpperCase();
  if (cleanName.length < 3 || cleanName.length > 40) throw new Error('INVALID_NAME');
  if (cleanTag.length < 2 || cleanTag.length > 6) throw new Error('INVALID_TAG');
  const result = await nexoraApi<{ orgId: string }>('create_organization', {
    name: cleanName,
    tag: cleanTag,
    description: description.trim().slice(0, 240),
  });
  if (!result.orgId) throw new Error('ORGANIZATION_CREATE_FAILED');
  return result.orgId;
}

export async function requestJoinOrganization(
  _uid: string,
  _username: string,
  orgId: string
): Promise<void> {
  await nexoraApi('request_join_organization', { orgId });
}

export async function handleOrgJoinRequest(
  orgId: string,
  reqId: string,
  _applicantUid: string,
  _applicantUsername: string,
  decision: 'approved' | 'rejected'
): Promise<void> {
  await nexoraApi('handle_org_join_request', { orgId, requestId: reqId, decision });
}

export async function syncSelfOrgMembership(_uid: string, orgId: string | null): Promise<void> {
  await nexoraApi('sync_self_org_membership', { orgId });
}

export async function updateOrgMemberRole(
  orgId: string,
  targetUid: string,
  newRole: Exclude<OrgRole, 'leader'>
): Promise<void> {
  await nexoraApi('update_org_member_role', { orgId, targetUid, role: newRole });
}

export async function leaveOrganization(_uid: string, orgId: string): Promise<void> {
  await nexoraApi('leave_organization', { orgId });
}

export async function kickOrgMember(
  _actorUid: string,
  orgId: string,
  targetUid: string
): Promise<void> {
  await nexoraApi('kick_org_member', { orgId, targetUid });
}

export async function upgradeOrganization(
  _uid: string,
  _username: string,
  orgId: string
): Promise<{ targetLevel: number; endsAt: number; cost: number }> {
  const result = await nexoraApi<{ target_level: number; ends_at: string; cost: number }>('organization_upgrade', { orgId });
  return {
    targetLevel: Number(result.target_level),
    endsAt: new Date(result.ends_at).getTime(),
    cost: Number(result.cost),
  };
}

export async function completeOrganizationUpgrade(orgId: string): Promise<void> {
  await nexoraApi('organization_complete', { orgId });
}

export async function researchOrganization(
  orgId: string,
  researchId: 'commerce' | 'engineering' | 'expansion' | 'finance' | 'diplomacy'
): Promise<{ level: number; cost: number }> {
  const result = await nexoraApi<{ level: number; cost: number }>('organization_research', { orgId, researchId });
  return { level: Number(result.level), cost: Number(result.cost) };
}

export async function depositToOrgTreasury(
  _uid: string,
  _username: string,
  orgId: string,
  amountRaw: number
): Promise<void> {
  await nexoraApi('org_treasury_deposit', { orgId, amount: Math.floor(amountRaw) });
}

export async function withdrawFromOrgTreasury(
  _uid: string,
  _username: string,
  orgId: string,
  amountRaw: number
): Promise<void> {
  await nexoraApi('org_treasury_withdraw', { orgId, amount: Math.floor(amountRaw) });
}

export async function updatePlayerSettings(
  _uid: string,
  language: Language,
  notificationsEnabled: boolean
): Promise<void> {
  await nexoraApi('update_settings', { language, notificationsEnabled });
}

export async function updatePlayerAvatar(_uid: string, avatarId: string): Promise<void> {
  await nexoraApi('update_avatar', { avatarId });
}

export async function markNotificationRead(notifId: string): Promise<void> {
  await nexoraApi('mark_notification_read', { notificationId: notifId });
}

export async function markAllNotificationsRead(_notifIds: string[]): Promise<void> {
  await nexoraApi('mark_all_notifications_read');
}

export async function fetchLeaderboards(): Promise<{
  players: PlayerProfile[];
  companies: Company[];
  organizations: Organization[];
}> {
  return nexoraApi('fetch_leaderboards');
}

export async function checkAndUnlockAchievements(
  _uid: string,
  _profile: PlayerProfile,
  unlockedIds: Set<string>,
  _achievements: {
    id: string;
    metric: 'trades' | 'companies' | 'produced' | 'level' | 'reputation';
    threshold: number;
  }[]
): Promise<string[]> {
  const result = await nexoraApi<{ unlocked_ids: string[] }>('unlock_eligible_achievements');
  return result.unlocked_ids.filter((id) => !unlockedIds.has(id));
}

export async function fetchOrgPendingRequests(orgId: string) {
  return nexoraApi<Array<{ id: string; orgId: string; uid: string; username: string; status: string; createdAt: string }>>('fetch_org_pending_requests', { orgId });
}
