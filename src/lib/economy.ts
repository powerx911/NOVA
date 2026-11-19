import {
  BASE_MARKET_TAX_RATE,
  DAILY_STIPEND_BASE,
  ITEM_MAP,
  REPUTATION_TIERS,
  ROLE_DEFAULT_PERMISSIONS,
} from '../data/catalog';
import type {
  Company,
  MarketListing,
  ManufacturingRecipe,
  OrganizationMember,
  OrgPermission,
  OrgRole,
  ReputationTier,
  SkillsMap,
  WorldEvent,
} from '../types/game';

/**
 * Safely converts timestamp-like values, plain { seconds } objects, numbers, or ISO strings to epoch milliseconds.
 */
export function timestampToMs(ts: unknown, fallback = 0): number {
  if (ts === null || ts === undefined) return fallback;
  if (typeof ts === 'number') return Number.isFinite(ts) ? ts : fallback;
  if (typeof ts === 'string') {
    const parsed = Date.parse(ts);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
  if (typeof ts === 'object') {
    if ('toMillis' in ts && typeof (ts as { toMillis: unknown }).toMillis === 'function') {
      return (ts as { toMillis: () => number }).toMillis();
    }
    if ('seconds' in ts && typeof (ts as { seconds: unknown }).seconds === 'number') {
      return (ts as { seconds: number }).seconds * 1000;
    }
  }
  return fallback;
}

/**
 * Computes player level, remaining XP toward next level, and threshold.
 * Level 1 -> 2 costs 200 XP; each level scales smoothly by +120 XP.
 */
export function xpForLevel(level: number): number {
  if (level <= 1) return 0;
  let total = 0;
  for (let l = 1; l < level; l++) {
    total += 200 + (l - 1) * 120;
  }
  return total;
}

export function xpStepForLevel(level: number): number {
  return 200 + Math.max(0, level - 1) * 120;
}

export function calculateLevelProgress(totalXp: number): {
  level: number;
  currentLevelXp: number;
  nextLevelXp: number;
  progressPercent: number;
} {
  let level = 1;
  let remaining = Math.max(0, Math.floor(totalXp));
  while (level < 200) {
    const step = xpStepForLevel(level);
    if (remaining < step) {
      return {
        level,
        currentLevelXp: remaining,
        nextLevelXp: step,
        progressPercent: Math.min(100, Math.round((remaining / step) * 100)),
      };
    }
    remaining -= step;
    level += 1;
  }
  return { level: 200, currentLevelXp: 0, nextLevelXp: 1, progressPercent: 100 };
}

/**
 * Resolves the player's current Reputation Tier and next milestone tier.
 */
export function getReputationTier(reputation: number): ReputationTier {
  const rep = Math.max(0, Number.isFinite(reputation) ? reputation : 0);
  let current = REPUTATION_TIERS[0];
  for (const tier of REPUTATION_TIERS) {
    if (rep >= tier.minReputation) {
      current = tier;
    }
  }
  return current;
}

export function getNextReputationTier(reputation: number): ReputationTier | null {
  const rep = Math.max(0, Number.isFinite(reputation) ? reputation : 0);
  for (const tier of REPUTATION_TIERS) {
    if (rep < tier.minReputation) {
      return tier;
    }
  }
  return null;
}

/**
 * Filters World Events by active flag, optional startsAt/endsAt time bounds, and deduplicates
 * by stackGroup (max 3 simultaneous active events to prevent compound inflation exploits).
 */
export function getActiveWorldEvents(
  worldEvents: WorldEvent[],
  nowMs = Date.now()
): WorldEvent[] {
  const seenGroups = new Set<string>();
  const active: WorldEvent[] = [];

  for (const evt of worldEvents) {
    if (!evt.active) continue;
    const startMs = timestampToMs(evt.startsAt, 0);
    const endMs = timestampToMs(evt.endsAt, 0);
    if (startMs > 0 && nowMs < startMs) continue;
    if (endMs > 0 && nowMs >= endMs) continue;

    const groupKey = evt.stackGroup || evt.effectType || evt.id;
    if (seenGroups.has(groupKey)) continue;
    seenGroups.add(groupKey);
    active.push(evt);
    if (active.length >= 3) break;
  }

  return active;
}

/**
 * Calculates effective market tax rate factoring in Trade skill & active World Events.
 * Clamped between 1% and 12% to prevent zero-tax exploits or punitive spikes.
 */
export function calculateMarketTaxRate(
  tradeSkillLevel: number,
  worldEvents: WorldEvent[],
  nowMs = Date.now()
): number {
  const skillDiscount = Math.max(0, tradeSkillLevel) * 0.004;
  const eventDelta = getActiveWorldEvents(worldEvents, nowMs).reduce(
    (acc, e) => acc + (e.taxDelta || 0),
    0
  );
  const raw = BASE_MARKET_TAX_RATE - skillDiscount + eventDelta;
  return Number(Math.max(0.01, Math.min(0.12, raw)).toFixed(4));
}

/**
 * Computes dynamic market reference price based on supply volume and active world events.
 * Combined event price multiplier is capped to [0.6, 1.45] so severe negative events remain meaningful.
 */
export function calculateDynamicItemPrice(
  itemId: string,
  activeSupplyQty: number,
  worldEvents: WorldEvent[],
  nowMs = Date.now()
): number {
  const item = ITEM_MAP[itemId];
  if (!item) return 0;
  // A continuous scarcity curve avoids exploitable price jumps at fixed supply thresholds.
  const safeSupply = Math.max(0, Number.isFinite(activeSupplyQty) ? activeSupplyQty : 0);
  const supplyFactor = 0.9 + 0.25 * Math.exp(-safeSupply / 200);

  let eventMultiplier = 1.0;
  for (const evt of getActiveWorldEvents(worldEvents, nowMs)) {
    if (!evt.targetItemId || evt.targetItemId === itemId) {
      eventMultiplier *= evt.priceMultiplier || 1.0;
    }
  }
  const boundedMultiplier = Math.max(0.6, Math.min(1.45, eventMultiplier));
  return Math.max(1, Math.round(item.basePrice * supplyFactor * boundedMultiplier));
}

export interface MarketItemAnalytics {
  itemId: string;
  indexPrice: number;
  totalSupply: number;
  listingCount: number;
  lowestAsk: number | null;
  avgAsk: number | null;
  spreadPercentVsIndex: number | null;
  supplyStatus: 'scarce' | 'balanced' | 'abundant';
  activeEventApplied: boolean;
}

export function calculateMarketItemAnalytics(
  itemId: string,
  listings: MarketListing[],
  worldEvents: WorldEvent[],
  nowMs = Date.now()
): MarketItemAnalytics {
  const itemListings = listings.filter(
    (l) => l.status === 'active' && l.remainingQty > 0 && l.itemId === itemId
  );
  const totalSupply = itemListings.reduce((sum, l) => sum + l.remainingQty, 0);
  const indexPrice = calculateDynamicItemPrice(itemId, totalSupply, worldEvents, nowMs);

  let lowestAsk: number | null = null;
  let weightedPriceSum = 0;
  for (const l of itemListings) {
    if (lowestAsk === null || l.unitPrice < lowestAsk) lowestAsk = l.unitPrice;
    weightedPriceSum += l.unitPrice * l.remainingQty;
  }

  const avgAsk = totalSupply > 0 ? Math.round(weightedPriceSum / totalSupply) : null;
  const spreadPercentVsIndex =
    lowestAsk !== null && indexPrice > 0
      ? Math.round(((lowestAsk - indexPrice) / indexPrice) * 100)
      : null;

  const supplyStatus: MarketItemAnalytics['supplyStatus'] =
    totalSupply <= 50 ? 'scarce' : totalSupply >= 300 ? 'abundant' : 'balanced';

  const activeEventApplied = getActiveWorldEvents(worldEvents, nowMs).some(
    (e) => e.targetItemId === itemId && Math.abs((e.priceMultiplier ?? 1) - 1) > 0.001
  );

  return {
    itemId,
    indexPrice,
    totalSupply,
    listingCount: itemListings.length,
    lowestAsk,
    avgAsk,
    spreadPercentVsIndex,
    supplyStatus,
    activeEventApplied,
  };
}

/**
 * Computes net hourly company profit factoring in Management, Finance, and active sector World Events.
 */
export function calculateCompanyHourlyNet(
  company: Pick<Company, 'baseRevenuePerHour' | 'expensePerHour' | 'level'> &
    Partial<Pick<Company, 'sector'>>,
  skills: Pick<SkillsMap, 'management' | 'finance'>,
  worldEvents: WorldEvent[] = [],
  nowMs = Date.now(),
  reputation = 0,
  organizationIncomeBonusRate = 0
): {
  grossHourly: number;
  expenseHourly: number;
  netHourly: number;
  levelMultiplier: number;
  mgmtBonus: number;
  financeReduction: number;
  sectorEventMultiplier: number;
  reputationBonus: number;
} {
  const levelMultiplier = 1 + (company.level - 1) * 0.32;
  const mgmtBonus = 1 + Math.max(0, skills.management) * 0.08;
  const repTier = getReputationTier(reputation);
  const reputationBonus = 1 + repTier.companyYieldBonusRate;

  let rawEventMult = 1.0;
  if (company.sector) {
    for (const evt of getActiveWorldEvents(worldEvents, nowMs)) {
      if (evt.affectedSectors?.includes(company.sector) && evt.revenueMultiplier) {
        rawEventMult *= evt.revenueMultiplier;
      }
    }
  }
  const sectorEventMultiplier = Number(Math.max(0.75, Math.min(1.4, rawEventMult)).toFixed(3));

  const grossHourly = Math.round(
    company.baseRevenuePerHour *
      levelMultiplier *
      mgmtBonus *
      sectorEventMultiplier *
      reputationBonus * (1 + Math.max(0, Math.min(0.05, organizationIncomeBonusRate)))
  );

  const rawExpense =
    company.expensePerHour * (1 + (company.level - 1) * 0.2);
  const financeReduction = Math.min(0.45, Math.max(0, skills.finance) * 0.05);
  const expenseHourly = Math.round(rawExpense * (1 - financeReduction));

  return {
    grossHourly,
    expenseHourly,
    netHourly: Math.max(15, grossHourly - expenseHourly),
    levelMultiplier,
    mgmtBonus,
    financeReduction,
    sectorEventMultiplier,
    reputationBonus,
  };
}

/**
 * Computes manufacturing cost after Industry skill discount.
 */
export function calculateManufacturingCost(
  recipe: ManufacturingRecipe,
  industrySkill: number
): number {
  const discount = Math.min(0.45, Math.max(0, industrySkill) * 0.06);
  return Math.max(10, Math.round(recipe.processingCost * (1 - discount)));
}

/**
 * Computes contract payout factoring in Negotiation skill and Reputation Tier bonus (capped at 2500).
 */
export function calculateContractPayout(
  baseCredits: number,
  negotiationSkill: number,
  reputation = 0
): number {
  const negBonus = 1 + Math.max(0, negotiationSkill) * 0.07;
  const tier = getReputationTier(reputation);
  const repBonus = 1 + tier.contractBonusRate;
  return Math.min(2500, Math.round(baseCredits * negBonus * repBonus));
}

/**
 * Computes daily stipend factoring in Finance skill and player level.
 */
export function calculateDailyStipend(level: number, financeSkill: number): number {
  const amount = DAILY_STIPEND_BASE + (level - 1) * 35 + financeSkill * 25;
  return Math.min(1500, Math.max(DAILY_STIPEND_BASE, Math.round(amount)));
}

/**
 * Checks if a member has a given organization permission (server/client parity).
 */
export function hasOrgPermission(
  member: Pick<OrganizationMember, 'role' | 'permissions'> | null | undefined,
  permission: OrgPermission
): boolean {
  if (!member) return false;
  if (member.role === 'leader') return true;
  if (member.permissions.includes(permission)) return true;
  return ROLE_DEFAULT_PERMISSIONS[member.role]?.includes(permission) ?? false;
}

export const ORG_MAX_LEVEL = 10;

export function calculateOrgUpgradeCost(level: number): number {
  const safeLevel = Math.max(1, Math.min(ORG_MAX_LEVEL, Math.floor(level)));
  return 12_000 * safeLevel * safeLevel;
}

export function calculateOrgUpgradeDurationMs(targetLevel: number): number {
  const safeTarget = Math.max(2, Math.min(ORG_MAX_LEVEL, Math.floor(targetLevel)));
  return Math.round(8 * 60 * 60 * 1000 * Math.pow(1.5, safeTarget - 2));
}

export const ORG_RESEARCH_DEFINITIONS = {
  commerce: { baseCost: 25_000, titleAr: 'شبكة التجارة', titleEn: 'Trade Network', effectAr: 'زيادة دخل المشاريع 0.5% لكل مستوى بحث (حتى 5%).', effectEn: 'Project income +0.5% per research level (up to 5%).' },
  engineering: { baseCost: 30_000, titleAr: 'الهندسة المتقدمة', titleEn: 'Advanced Engineering', effectAr: 'تقليل مدة تطوير المنظمة 0.5% لكل مستوى (حتى 5%).', effectEn: 'Organization upgrade time -0.5% per level (up to 5%).' },
  expansion: { baseCost: 20_000, titleAr: 'التوسع الإداري', titleEn: 'Administrative Expansion', effectAr: 'إضافة عضو واحد للسعة لكل مستوى بحث (حتى 10 أعضاء).', effectEn: 'Adds one member of capacity per research level (up to 10).' },
  finance: { baseCost: 35_000, titleAr: 'الهندسة المالية', titleEn: 'Financial Engineering', effectAr: 'تقليل تكلفة تطوير المنظمة 0.5% لكل مستوى (حتى 5%).', effectEn: 'Organization upgrade cost -0.5% per level (up to 5%).' },
  diplomacy: { baseCost: 18_000, titleAr: 'العلاقات العامة', titleEn: 'Public Relations', effectAr: 'زيادة السمعة المكتسبة من التبرعات 1% لكل مستوى (حتى 10%).', effectEn: 'Donation reputation gain +1% per level (up to 10%).' },
} as const;

export function calculateOrgResearchCost(researchId: keyof typeof ORG_RESEARCH_DEFINITIONS, currentLevel: number): number {
  const level = Math.max(0, Math.min(9, Math.floor(currentLevel)));
  return ORG_RESEARCH_DEFINITIONS[researchId].baseCost * (level + 1) * (level + 1);
}

export function getOrgMemberCapacity(level: number, expansionResearchLevel = 0): number {
  const safeLevel = Math.max(1, Math.min(ORG_MAX_LEVEL, Math.floor(level)));
  const researchBonus = Math.max(0, Math.min(10, Math.floor(expansionResearchLevel)));
  return Math.min(80, 20 + (safeLevel - 1) * 5 + researchBonus);
}

const ROLE_WEIGHT: Record<OrgRole, number> = {
  leader: 4,
  deputy: 3,
  officer: 2,
  member: 1,
};

export function canManageOrgMember(actorRole: OrgRole, targetRole: OrgRole): boolean {
  if (targetRole === 'leader') return false;
  return ROLE_WEIGHT[actorRole] > ROLE_WEIGHT[targetRole];
}

/**
 * Validates transfer parameters before submission to prevent negative balances or self-transfers.
 */
export function validateTransfer(
  senderUid: string,
  recipientUid: string,
  senderBalance: number,
  amount: number
): { valid: boolean; reason?: string } {
  if (!recipientUid || senderUid === recipientUid) {
    return { valid: false, reason: 'SELF_OR_MISSING_RECIPIENT' };
  }
  if (!Number.isFinite(amount) || amount <= 0) {
    return { valid: false, reason: 'INVALID_AMOUNT' };
  }
  if (amount > senderBalance) {
    return { valid: false, reason: 'INSUFFICIENT_FUNDS' };
  }
  return { valid: true };
}

/**
 * Validates username format (3-24 alphanumeric or underscore, no spaces).
 */
export function isValidUsername(username: string): boolean {
  return /^[a-zA-Z0-9_]{3,24}$/.test(username.trim());
}

/**
 * Computes accrued payout since last collection timestamp (capped at 12 hours per claim).
 */
export function calculateAccruedPayout(
  netPerHour: number,
  lastCollectedMs: number,
  nowMs: number
): number {
  if (netPerHour <= 0 || !Number.isFinite(lastCollectedMs) || !Number.isFinite(nowMs)) return 0;
  const elapsedMs = Math.max(0, nowMs - lastCollectedMs);
  const cappedHours = Math.min(12, elapsedMs / 3_600_000);
  return Math.max(0, Math.floor(netPerHour * cappedHours));
}

export const COMPANY_VAULT_CAPACITIES = [3500, 7000, 14000, 25000, 40000] as const;
export const COMPANY_VAULT_MAX_LEVEL = COMPANY_VAULT_CAPACITIES.length;
export const COMPANY_VAULT_UPGRADES = [
  { fromLevel: 1, cost: 1500, materials: { copper_wire: 20, crude_alloy: 10 } },
  { fromLevel: 2, cost: 4000, materials: { silicon_ore: 20, energy_cells: 15 } },
  { fromLevel: 3, cost: 10000, materials: { carbon_fiber: 15, precision_frame: 10 } },
  { fromLevel: 4, cost: 25000, materials: { rare_minerals: 20, quantum_server: 5 } },
] as const;

export function getCompanyVaultLevel(company: { vaultLevel?: number }): number {
  const rawLevel = company.vaultLevel;
  if (typeof rawLevel !== 'number' || !Number.isFinite(rawLevel)) return 1;
  return Math.max(1, Math.min(COMPANY_VAULT_MAX_LEVEL, Math.floor(rawLevel)));
}

export function getCompanyVaultCapacity(level: number): number {
  const safeLevel = Number.isFinite(level) ? Math.floor(level) : 1;
  const index = Math.max(0, Math.min(COMPANY_VAULT_MAX_LEVEL - 1, safeLevel - 1));
  return COMPANY_VAULT_CAPACITIES[index];
}

export function calculateCompanyVaultBalance(
  company: { vaultLevel?: number; vaultBalance?: number; lastCollectedAt: unknown },
  netPerHour: number,
  nowMs: number
): number {
  const level = getCompanyVaultLevel(company);
  const capacity = getCompanyVaultCapacity(level);
  const safeNowMs = Number.isFinite(nowMs) ? nowMs : 0;
  const stored = typeof company.vaultBalance === 'number' && Number.isFinite(company.vaultBalance)
    ? Math.max(0, company.vaultBalance)
    : 0;
  const lastMs = timestampToMs(company.lastCollectedAt, safeNowMs);
  const elapsedMs = Math.max(0, safeNowMs - lastMs);
  const safeNetPerHour = Number.isFinite(netPerHour) ? Math.max(0, netPerHour) : 0;
  const accrued = Math.floor((safeNetPerHour * elapsedMs) / 3_600_000);
  return Math.min(capacity, stored + Math.max(0, accrued));
}

export function getPlayerInventoryCapacity(level: number): number {
  const safeLevel = Number.isFinite(level) ? Math.max(1, Math.min(200, Math.floor(level))) : 1;
  return 250 + (safeLevel - 1) * 15;
}

export interface MarketPriceBounds {
  minPrice: number;
  maxPrice: number;
}

/** Keeps player listings within 50%-200% of the catalog reference price. */
export const MARKET_RAW_ITEM_IDS = [
  'silicon_ore', 'copper_wire', 'energy_cells', 'crude_alloy', 'carbon_fiber', 'rare_minerals',
] as const;

const MARKET_LISTABLE_ITEM_IDS = new Set<string>(MARKET_RAW_ITEM_IDS);

export function getMarketPriceBounds(itemId: string): MarketPriceBounds | null {
  if (!MARKET_LISTABLE_ITEM_IDS.has(itemId)) return null;
  const basePrice = ITEM_MAP[itemId]?.basePrice;
  if (!Number.isFinite(basePrice) || basePrice <= 0) return null;
  return {
    minPrice: Math.max(1, Math.floor(basePrice * 0.5)),
    maxPrice: Math.max(1, Math.ceil(basePrice * 2)),
  };
}

export const COMPANY_MAX_LEVEL = 100;
export const LISTING_MAX_QTY = 10_000;
export const LISTING_MAX_PRICE = 1_000_000;

export function sanitizePositiveInt(raw: unknown, fallback = 1, max = Number.MAX_SAFE_INTEGER): number {
  const num = typeof raw === 'number' ? raw : Number(raw);
  if (!Number.isFinite(num)) return fallback;
  return Math.min(max, Math.max(1, Math.floor(num)));
}

export function getMissionProgress(
  metric: 'trades' | 'companies' | 'produced' | 'level' | 'org' | 'properties' | 'weekly_trades' | 'daily_market_buys' | 'daily_manufacturing' | 'daily_company_collections' | 'daily_market_spend' | 'weekly_market_buys' | 'weekly_manufacturing' | 'weekly_market_spend' | 'weekly_company_collections' | 'seasonal_market_buys' | 'seasonal_manufacturing' | 'seasonal_market_spend' | 'seasonal_company_collections',
  profile: {
    level: number;
    orgId?: string | null;
    stats: {
      tradesCount: number;
      companiesOwned: number;
      totalProduced: number;
      propertiesOwned?: number;
    };
    weeklyTradesCount?: number;
    dailyTradesCount?: number; dailyManufacturingCount?: number; dailyCompanyCollectionsCount?: number; dailyMarketSpend?: number;
    weeklyManufacturingCount?: number; weeklyCompanyCollectionsCount?: number; weeklyMarketSpend?: number;
    seasonalMarketBuys?: number; seasonalManufacturingCount?: number; seasonalCompanyCollectionsCount?: number; seasonalMarketSpend?: number;
  }
): number {
  switch (metric) {
    case 'trades':
      return profile.stats.tradesCount;
    case 'companies':
      return profile.stats.companiesOwned;
    case 'produced':
      return profile.stats.totalProduced;
    case 'org':
      return profile.orgId ? 1 : 0;
    case 'properties':
      return profile.stats.propertiesOwned ?? 0;
    case 'weekly_trades':
    case 'weekly_market_buys': return profile.weeklyTradesCount ?? 0;
    case 'daily_market_buys': return profile.dailyTradesCount ?? 0;
    case 'daily_manufacturing': return profile.dailyManufacturingCount ?? 0;
    case 'daily_company_collections': return profile.dailyCompanyCollectionsCount ?? 0;
    case 'daily_market_spend': return profile.dailyMarketSpend ?? 0;
    case 'weekly_manufacturing': return profile.weeklyManufacturingCount ?? 0;
    case 'weekly_company_collections': return profile.weeklyCompanyCollectionsCount ?? 0;
    case 'weekly_market_spend': return profile.weeklyMarketSpend ?? 0;
    case 'seasonal_market_buys': return profile.seasonalMarketBuys ?? 0;
    case 'seasonal_manufacturing': return profile.seasonalManufacturingCount ?? 0;
    case 'seasonal_company_collections': return profile.seasonalCompanyCollectionsCount ?? 0;
    case 'seasonal_market_spend': return profile.seasonalMarketSpend ?? 0;
    case 'level':
    default:
      return profile.level;
  }
}

export function getAchievementProgress(
  metric: 'trades' | 'companies' | 'produced' | 'level' | 'reputation' | 'spent' | 'revenue',
  profile: {
    level: number;
    reputation: number;
    companyRevenueTotal?: number;
    totalSpent?: number;
    stats: {
      tradesCount: number;
      companiesOwned: number;
      totalProduced: number;
    };
  }
): number {
  switch (metric) {
    case 'trades':
      return profile.stats.tradesCount;
    case 'companies':
      return profile.stats.companiesOwned;
    case 'produced':
      return profile.stats.totalProduced;
    case 'reputation': return profile.reputation;
    case 'spent': return profile.totalSpent ?? 0;
    case 'revenue': return profile.companyRevenueTotal ?? 0;
    case 'level':
    default:
      return profile.level;
  }
}


