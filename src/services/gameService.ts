import {
  COMPANY_SECTORS,
  ITEM_MAP,
  MANUFACTURING_RECIPES,
  FACTORY_RESOURCES,
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
  FactoryResourceId,
  CompanySector,
  CompanyAuction,
  DynamicContractBoard,
  OrgWeeklyGoals,
  InventoryItem,
  Language,
  MarketListing,
  MarketActivityRecord,
  MarketPricePoint,
  Organization,
  OrganizationMember,
  OrgRole,
  PlayerProfile,
  SkillKey,
  Wallet,
} from '../types/game';

export type OrgDonationRankEntry = { uid: string; username: string; amount: number };
export async function getOrgDonationRanking(orgId: string): Promise<OrgDonationRankEntry[]> {
  return (await nexoraApi<{ ranking: OrgDonationRankEntry[] }>('get_org_donation_ranking', { orgId })).ranking;
}

export interface PlayerPresence { uid: string; isOnline: boolean; onlineSince: number | null; lastSeenAt: number | null }
export async function getPlayersPresence(userIds: string[]): Promise<PlayerPresence[]> {
  if (!userIds.length) return [];
  const result = await nexoraApi<{ players: PlayerPresence[] }>('get_players_presence', { userIds: userIds.slice(0, 60) });
  return result.players ?? [];
}

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
  // Global market listings and world events are provisioned in the NOVA Supabase schema.
}

export async function isUsernameAvailable(username: string): Promise<boolean> {
  const clean = username.trim();
  if (!isValidUsername(clean)) return false;
  const result = await nexoraApi<{ available: boolean }>('username_available', { username: clean });
  if (typeof result?.available !== 'boolean') throw new Error('USERNAME_CHECK_FAILED');
  return result.available;
}

export async function validateTransferRecipient(username: string): Promise<{ exists: boolean; isSelf: boolean }> {
  const clean = username.trim();
  if (!/^[a-zA-Z0-9_]{3,24}$/.test(clean)) return { exists: false, isSelf: false };
  return nexoraApi<{ exists: boolean; isSelf: boolean }>('validate_transfer_recipient', { username: clean });
}

export async function claimAchievementReward(_uid: string, achievementId: string): Promise<void> {
  if (!/^nova_(whale|market|industry|enterprise)_(i|ii|iii|iv)$/.test(achievementId)) throw new Error('INVALID_ACHIEVEMENT');
  try {
    await nexoraApi('claim_achievement_reward', { achievementId });
    if (typeof window !== 'undefined') window.dispatchEvent(new Event('nova:refresh-game'));
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'ACHIEVEMENT_CLAIM_FAILED'));
    throw error;
  }
}

export async function refreshPlayerAchievements(): Promise<void> {
  await nexoraApi('refresh_achievements');
  if (typeof window !== 'undefined') window.dispatchEvent(new Event('nova:refresh-game'));
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
    if (typeof window !== 'undefined') window.dispatchEvent(new Event('nova:refresh-game'));
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

export async function resetSkills(_uid: string): Promise<void> {
  try {
    await nexoraApi('reset_skills');
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'SKILL_RESET_FAILED'));
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

export async function fetchMarketListings(): Promise<MarketListing[]> {
  return nexoraApi<MarketListing[]>('fetch_market_listings');
}

export async function fetchMarketActivity(): Promise<MarketActivityRecord[]> {
  return nexoraApi<MarketActivityRecord[]>('fetch_market_activity');
}

export async function fetchMarketPriceHistory(): Promise<MarketPricePoint[]> {
  return nexoraApi<MarketPricePoint[]>('fetch_market_price_history');
}

export interface NexoraSaleResult { quantity: number; unit_price: number; total: number; daily_sold: number; daily_remaining: number; }

export async function sellToNexora(itemId: string, quantity: number): Promise<NexoraSaleResult> {
  if (!ITEM_MAP[itemId] || !Number.isInteger(quantity) || quantity < 1 || quantity > 1500) throw new Error('INVALID_QUANTITY');
  try {
    const result = await nexoraApi<NexoraSaleResult>('sell_to_nexora', { itemId, quantity });
    if (typeof window !== 'undefined') window.dispatchEvent(new Event('nova:refresh-game'));
    return result;
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'NEXORA_SALE_FAILED'));
    throw error;
  }
}

export async function fetchInventoryCapacityUsage(): Promise<number> {
  return nexoraApi<number>('fetch_inventory_capacity_usage');
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

export interface MissingResourcePurchaseItem {
  listingId: string;
  itemId: string;
  quantity: number;
  expectedUnitPrice: number;
}

export async function buyMarketListing(
  _buyerUid: string,
  listingId: string,
  buyQtyRaw: number,
  _taxRate: number,
  expectedUnitPrice: number
): Promise<void> {
  const quantity = Number.isFinite(buyQtyRaw) ? Math.floor(buyQtyRaw) : 0;
  if (quantity < 1 || !Number.isFinite(expectedUnitPrice) || expectedUnitPrice < 1) throw new Error('INVALID_QUANTITY');
  try {
    await nexoraApi('buy_market_listing', { listingId, quantity, expectedUnitPrice });
    if (typeof window !== 'undefined') window.dispatchEvent(new Event('nova:refresh-game'));
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'MARKET_PURCHASE_FAILED'));
    throw error;
  }
}

export async function buyMissingResources(items: MissingResourcePurchaseItem[], requirements: Array<{ itemId: string; quantity: number }>): Promise<void> {
  if (!items.length || items.length > 100) throw new Error('INVALID_PURCHASE_PLAN');
  const normalized = items.map((item) => ({
    listingId: item.listingId,
    itemId: item.itemId,
    quantity: Math.floor(item.quantity),
    expectedUnitPrice: Math.floor(item.expectedUnitPrice),
  }));
  if (normalized.some((item) => !item.listingId || !item.itemId || item.quantity < 1 || item.expectedUnitPrice < 1)) {
    throw new Error('INVALID_PURCHASE_PLAN');
  }
  try {
    await nexoraApi('buy_missing_resources', { items: normalized, requirements });
    if (typeof window !== 'undefined') window.dispatchEvent(new Event('nova:refresh-game'));
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'MISSING_RESOURCE_PURCHASE_FAILED'));
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

export interface ManufacturingJob {
  id: string;
  recipe_id: string;
  output_item_id: string;
  output_qty: number;
  started_at: string;
  ends_at: string;
  status: 'running';
}

export async function manufactureRecipe(_uid: string, recipeId: string, batchQuantity = 1): Promise<ManufacturingJob> {
  if (!MANUFACTURING_RECIPES.some((recipe) => recipe.id === recipeId)) throw new Error('INVALID_RECIPE');
  if (!Number.isInteger(batchQuantity) || batchQuantity < 1 || batchQuantity > 999) throw new Error('INVALID_QUANTITY');
  try {
    return await nexoraApi<ManufacturingJob>('manufacture_recipe', { recipeId, batches: batchQuantity });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'MANUFACTURING_FAILED'));
    throw error;
  }
}

export async function getManufacturingJob(): Promise<ManufacturingJob | null> {
  return nexoraApi<ManufacturingJob | null>('get_manufacturing_job');
}

export async function completeManufacturingJob(jobId: string): Promise<void> {
  if (!jobId) throw new Error('MANUFACTURING_JOB_NOT_FOUND');
  try {
    await nexoraApi('complete_manufacturing_job', { jobId });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'MANUFACTURING_COMPLETION_FAILED'));
    throw error;
  }
}

export async function cancelManufacturingJob(jobId: string): Promise<void> {
  if (!jobId) throw new Error('MANUFACTURING_JOB_NOT_FOUND');
  try {
    await nexoraApi('cancel_manufacturing_job', { jobId });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'MANUFACTURING_CANCELLATION_FAILED'));
    throw error;
  }
}

export async function getDynamicContractBoard(): Promise<DynamicContractBoard> {
  return nexoraApi<DynamicContractBoard>('get_dynamic_contract_board');
}

export async function getOrgWeeklyGoals(): Promise<OrgWeeklyGoals> {
  return nexoraApi<OrgWeeklyGoals>('get_org_weekly_goals');
}

async function runDynamicContractAction<T = Record<string, unknown>>(action: string, contractId: string): Promise<T> {
  try {
    return await nexoraApi<T>(action, { contractId });
  } catch (error) {
    if (error instanceof Error && 'code' in error) {
      throw new Error(String((error as { code?: unknown }).code ?? 'DYNAMIC_CONTRACT_FAILED'));
    }
    throw error;
  }
}

export async function refreshDynamicContract(contractId: string): Promise<void> {
  await runDynamicContractAction("refresh_dynamic_contract", contractId);
}

export async function acceptDynamicContract(contractId: string): Promise<void> {
  await runDynamicContractAction('accept_dynamic_contract', contractId);
}

export async function deliverDynamicContract(contractId: string): Promise<void> {
  await runDynamicContractAction('deliver_dynamic_contract', contractId);
}

export async function abandonDynamicContract(contractId: string): Promise<void> {
  await runDynamicContractAction('abandon_dynamic_contract', contractId);
}

export async function claimDynamicContract(contractId: string): Promise<void> {
  await runDynamicContractAction('claim_dynamic_contract', contractId);
  if (typeof window !== 'undefined') window.dispatchEvent(new Event('nova:refresh-game'));
}

/** @deprecated Legacy fixed-contract RPC; the NOVA UI uses dynamic contracts. */
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
  if (typeof window !== 'undefined') window.dispatchEvent(new Event('nova:refresh-game'));
}

export async function completeCompanyUpgrade(_uid: string, companyId: string): Promise<void> {
  await callSupabaseCompanyAction('company_complete', companyId);
}

export async function completeCompanyVaultUpgrade(_uid: string, companyId: string): Promise<void> {
  await callSupabaseCompanyAction('vault_complete', companyId);
  if (typeof window !== 'undefined') window.dispatchEvent(new Event('nova:refresh-game'));
}

export async function collectCompanyRevenue(_uid: string, companyId: string): Promise<number> {
  const result = await callSupabaseCompanyAction<{ payout: number }>('company_collect', companyId);
  if (typeof window !== 'undefined') window.dispatchEvent(new Event('nova:refresh-game'));
  return result.payout;
}

export async function fetchCompanyAuctions(): Promise<CompanyAuction[]> {
  return nexoraApi<CompanyAuction[]>('fetch_company_auctions');
}

export async function listCompanyForAuction(companyId: string, startingPriceRaw: number): Promise<void> {
  const startingPrice = Number.isFinite(startingPriceRaw) ? Math.floor(startingPriceRaw) : 0;
  if (!companyId || startingPrice < 1) throw new Error('INVALID_STARTING_PRICE');
  try {
    await nexoraApi('list_company_for_auction', { companyId, startingPrice });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'COMPANY_AUCTION_LIST_FAILED'));
    throw error;
  }
}

export async function listFactoryForAuction(factoryId: string, startingPriceRaw: number): Promise<void> {
  const startingPrice = Number.isFinite(startingPriceRaw) ? Math.floor(startingPriceRaw) : 0;
  if (!factoryId || startingPrice < 1) throw new Error('INVALID_STARTING_PRICE');
  try {
    await nexoraApi('list_factory_for_auction', { factoryId, startingPrice });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'FACTORY_AUCTION_LIST_FAILED'));
    throw error;
  }
}

export async function placeCompanyAuctionBid(auctionId: string, amountRaw: number): Promise<void> {
  const amount = Number.isFinite(amountRaw) ? Math.floor(amountRaw) : 0;
  if (!auctionId || amount < 1) throw new Error('INVALID_BID');
  try {
    const result = await nexoraApi<{ ended?: boolean }>('place_company_auction_bid', { auctionId, amount });
    if (result.ended) throw new Error('AUCTION_ENDED');
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'COMPANY_AUCTION_BID_FAILED'));
    throw error;
  }
}

export async function placeFactoryAuctionBid(auctionId: string, amountRaw: number): Promise<void> {
  const amount = Number.isFinite(amountRaw) ? Math.floor(amountRaw) : 0;
  if (!auctionId || amount < 1) throw new Error('INVALID_BID');
  try {
    const result = await nexoraApi<{ ended?: boolean }>('place_factory_auction_bid', { auctionId, amount });
    if (result.ended) throw new Error('AUCTION_ENDED');
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'FACTORY_AUCTION_BID_FAILED'));
    throw error;
  }
}

export async function deleteCompany(companyId: string): Promise<void> {
  try {
    await nexoraApi('delete_company', { companyId });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'COMPANY_DELETE_FAILED'));
    throw error;
  }
}

export async function foundFactory(name: string, resourceId: FactoryResourceId): Promise<void> {
  const cleanName = name.trim();
  if (cleanName.length < 2 || cleanName.length > 48) throw new Error('INVALID_NAME');
  if (!FACTORY_RESOURCES.some((resource) => resource.resourceId === resourceId)) throw new Error('INVALID_RESOURCE');
  try {
    await nexoraApi('found_factory', { name: cleanName, resourceId });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'FACTORY_FOUNDING_FAILED'));
    throw error;
  }
}

async function callFactoryAction<T>(action: string, factoryId: string, extra: Record<string, unknown> = {}): Promise<T> {
  try {
    return await nexoraApi<T>(action, { factoryId, ...extra });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'FACTORY_OPERATION_FAILED'));
    throw error;
  }
}

export async function syncFactory(factoryId: string): Promise<void> {
  await callFactoryAction('sync_factory', factoryId);
}
export async function upgradeFactory(factoryId: string): Promise<void> {
  await callFactoryAction('upgrade_factory', factoryId);
}
export async function completeFactoryUpgrade(factoryId: string): Promise<void> {
  await callFactoryAction('complete_factory_upgrade', factoryId);
}
export async function upgradeFactoryWarehouse(factoryId: string): Promise<void> {
  await callFactoryAction('upgrade_factory_warehouse', factoryId);
  if (typeof window !== 'undefined') window.dispatchEvent(new Event('nova:refresh-game'));
}
export async function completeFactoryWarehouseUpgrade(factoryId: string): Promise<void> {
  await callFactoryAction('complete_factory_warehouse_upgrade', factoryId);
  if (typeof window !== 'undefined') window.dispatchEvent(new Event('nova:refresh-game'));
}
export async function upgradeFactorySkill(factoryId: string): Promise<void> {
  await callFactoryAction('upgrade_factory_skill', factoryId);
}
export async function setFactoryActive(factoryId: string, active: boolean): Promise<void> {
  await callFactoryAction('set_factory_active', factoryId, { active });
}
export async function withdrawFactoryWarehouse(factoryId: string, quantityRaw: number): Promise<void> {
  const quantity = Number.isFinite(quantityRaw) ? Math.floor(quantityRaw) : 0;
  if (quantity < 1) throw new Error('INVALID_QUANTITY');
  await callFactoryAction('withdraw_factory_warehouse', factoryId, { quantity });
  if (typeof window !== 'undefined') window.dispatchEvent(new Event('nova:refresh-game'));
}

export async function claimMissionReward(_uid: string, missionId: string): Promise<void> {
  if (!MISSIONS.some((mission) => mission.id === missionId)) throw new Error('INVALID_MISSION');
  try {
    await nexoraApi('claim_mission_reward', { missionId });
    if (typeof window !== 'undefined') window.dispatchEvent(new Event('nova:refresh-game'));
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

export async function deletePlayerAccount(): Promise<void> {
  await nexoraApi('delete_account');
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
