export type Language = 'ar' | 'en';

export type MainTab = 'home' | 'business' | 'market' | 'organization' | 'social' | 'profile';

export type BusinessSubTab = 'companies' | 'auction' | 'factories' | 'inventory' | 'financials';
export type MarketSubTab = 'exchange' | 'contracts' | 'bank' | 'manufacturing' | 'records';
export type ProfileSubTab = 'overview' | 'skills' | 'missions' | 'achievements' | 'rankings' | 'settings' | 'diagnostics';

export type SkillKey =
  | 'trade'
  | 'management'
  | 'industry'
  | 'negotiation'
  | 'finance'
  | 'leadership';

export type SkillsMap = Record<SkillKey, number>;

export interface PlayerStats {
  missionsCompleted: number;
  tradesCount: number;
  companiesOwned: number;
  totalProduced: number;
  propertiesOwned?: number;
  weeklyTradesCount?: number;
}

export interface PlayerProfile {
  uid: string;
  username: string;
  usernameLower: string;
  avatarId: string;
  title: string;
  level: number;
  xp: number;
  reputation: number;
  influence: number;
  skillPoints: number;
  skills: SkillsMap;
  stats: PlayerStats;
  dailyTradesCount?: number;
  weeklyTradesCount?: number;
  dailyManufacturingCount?: number;
  dailyCompanyCollectionsCount?: number;
  dailyMarketSpend?: number;
  weeklyManufacturingCount?: number;
  weeklyCompanyCollectionsCount?: number;
  weeklyMarketSpend?: number;
  seasonalMarketBuys?: number;
  seasonalManufacturingCount?: number;
  seasonalCompanyCollectionsCount?: number;
  seasonalMarketSpend?: number;
  companyRevenueTotal?: number;
  orgId?: string | null;
  createdAt: unknown;
  updatedAt: unknown;
}

export interface UserPrivate {
  uid: string;
  email: string;
  language: Language;
  notificationsEnabled: boolean;
  createdAt: unknown;
  updatedAt: unknown;
}

export interface Wallet {
  uid: string;
  balance: number;
  totalEarned: number;
  totalSpent: number;
  lastTxId: string;
  createdAt: unknown;
  updatedAt: unknown;
}

export type TransactionType =
  | 'transfer'
  | 'market_buy'
  | 'mission_reward'
  | 'daily_stipend'
  | 'company_create'
  | 'company_upgrade'
  | 'company_upgrade_refund'
  | 'game_compensation'
  | 'company_upgrade_refund_reversal'
  | 'company_collect'
  | 'company_vault_upgrade'
  | 'company_auction_escrow'
  | 'company_auction_refund'
  | 'company_auction_sale'
  | 'factory_auction_sale'
  | 'auction_fee'
  | 'manufacturing'
  | 'skill_reset'
  | 'factory_create'
  | 'factory_operating'
  | 'factory_upgrade'
  | 'factory_skill'
  | 'org_create'
  | 'org_deposit'
  | 'org_withdraw'
  | 'contract_deal'
  | 'contract_fee'
  | 'contract_reward';

export interface TransactionRecord {
  id: string;
  fromUid: string;
  toUid: string;
  amount: number;
  fee: number;
  netAmount: number;
  type: TransactionType;
  referenceId: string;
  description: string;
  status: 'completed';
  createdAt: unknown;
}

export type ItemTier = 'raw' | 'intermediate' | 'final';

export interface CatalogItem {
  id: string;
  nameAr: string;
  nameEn: string;
  tier: ItemTier;
  basePrice: number;
  unitWeight: number;
  descriptionAr: string;
  descriptionEn: string;
}

export interface InventoryItem {
  uid: string;
  itemId: string;
  quantity: number;
  updatedAt: unknown;
}

export interface ManufacturingRecipe {
  id: string;
  outputItemId: string;
  outputQty: number;
  inputs: { itemId: string; qty: number }[];
  processingCost: number;
  xpReward: number;
  requiredIndustrySkill: number;
}

export interface MarketListing {
  id: string;
  sellerUid: string;
  sellerName: string;
  itemId: string;
  quantity: number;
  remainingQty: number;
  unitPrice: number;
  status: 'active' | 'sold' | 'cancelled';
  createdAt: unknown;
  updatedAt: unknown;
}

export interface MarketOrder {
  id: string;
  listingId: string;
  buyerUid: string;
  sellerUid: string;
  itemId: string;
  quantity: number;
  unitPrice: number;
  totalPrice: number;
  taxAmount: number;
  txId: string;
  createdAt: unknown;
}

export interface MarketActivityRecord extends MarketOrder {
  buyerName: string;
  sellerName: string;
}

export interface MarketPricePoint {
  itemId: string;
  unitPrice: number;
  quantity: number;
  createdAt: unknown;
}

export type CompanySector = 'trade' | 'manufacturing' | 'services' | 'tech' | 'logistics';

export interface Company {
  id: string;
  ownerUid: string;
  ownerName: string;
  name: string;
  sector: CompanySector;
  level: number;
  capital: number;
  baseRevenuePerHour: number;
  expensePerHour: number;
  totalRevenue: number;
  vaultLevel?: number;
  vaultBalance?: number;
  serverNetHourly?: number;
  serverCollectable?: number;
  levelUpgradeStartedAt?: number;
  levelUpgradeEndsAt?: number;
  levelUpgradeTargetLevel?: number;
  levelUpgradeCost?: number;
  vaultUpgradeStartedAt?: number;
  vaultUpgradeEndsAt?: number;
  vaultUpgradeTargetLevel?: number;
  lastCollectedAt: unknown;
  auctionId?: string | null;
  auctionEndsAt?: unknown;
  auctionStatus?: string | null;
  createdAt: unknown;
  updatedAt: unknown;
}

export interface CompanyAuction {
  id: string;
  assetType?: 'company' | 'factory';
  factoryId?: string | null;
  companyId: string | null;
  companyName: string;
  companySector: CompanySector | 'factory';
  companyLevel: number;
  sellerUid: string;
  sellerName: string;
  startingPrice: number;
  currentPrice: number;
  highestBidderUid: string | null;
  highestBidderName: string | null;
  startsAt: number;
  endsAt: number;
  status: 'active' | 'sold' | 'unsold' | 'cancelled';
  winningBid?: number | null;
  createdAt: number;
}

export interface CompanyLog {
  id: string;
  companyId: string;
  ownerUid: string;
  action: string;
  amount: number;
  details: string;
  createdAt: unknown;
}

export type FactoryResourceId = 'copper_wire' | 'silicon_ore' | 'energy_cells' | 'crude_alloy' | 'carbon_fiber' | 'rare_minerals' | 'titanium_ore' | 'polymer_resin' | 'biotech_gel' | 'quantum_dust';
export interface Factory {
  id: string;
  ownerUid: string;
  ownerName: string;
  name: string;
  resourceId: FactoryResourceId;
  level: number;
  skillLevel: number;
  isActive: boolean;
  warehouseQty: number;
  warehouseLevel?: number;
  warehouseUpgradeEndsAt?: number | null;
  warehouseUpgradeTargetLevel?: number | null;
  auctionId?: string | null;
  auctionEndsAt?: number | null;
  auctionStatus?: string | null;
  productionRemainder: number;
  operatingCostRemainder: number;
  lastProducedAt: number;
  upgradeStartedAt?: number | null;
  upgradeEndsAt?: number | null;
  upgradeTargetLevel?: number | null;
  upgradeCost?: number | null;
  createdAt: unknown;
  updatedAt: unknown;
}

export type OrgRole = 'leader' | 'deputy' | 'officer' | 'member';
export type OrgPermission = 'manage_members' | 'manage_roles' | 'manage_treasury' | 'manage_org';
export type OrganizationResearchId = 'commerce' | 'engineering' | 'expansion' | 'finance' | 'diplomacy';

export interface Organization {
  id: string;
  name: string;
  tag: string;
  description: string;
  leaderUid: string;
  leaderName: string;
  treasuryBalance: number;
  memberCount: number;
  reputation: number;
  level: number;
  memberCapacity?: number;
  research?: Partial<Record<OrganizationResearchId, number>>;
  upgradeStartedAt?: number;
  upgradeEndsAt?: number;
  upgradeTargetLevel?: number;
  createdAt: unknown;
  updatedAt: unknown;
}

export interface OrganizationMember {
  orgId: string;
  uid: string;
  username: string;
  role: OrgRole;
  permissions: OrgPermission[];
  joinedAt: unknown;
}

export interface OrganizationRequest {
  id: string;
  orgId: string;
  uid: string;
  username: string;
  status: 'pending' | 'approved' | 'rejected';
  createdAt: unknown;
}

export interface OrganizationTransaction {
  id: string;
  orgId: string;
  uid: string;
  username: string;
  type: 'deposit' | 'withdraw' | 'upgrade';
  amount: number;
  note: string;
  createdAt: unknown;
}

export type MissionCategory = 'tutorial' | 'daily' | 'weekly' | 'seasonal';

export interface MissionDefinition {
  id: string;
  category: MissionCategory;
  titleAr: string;
  titleEn: string;
  descriptionAr: string;
  descriptionEn: string;
  rewardCredits: number;
  rewardXp: number;
  rewardReputation: number;
  targetCount: number;
  metric: 'trades' | 'companies' | 'produced' | 'level' | 'org' | 'properties' | 'weekly_trades' | 'daily_market_buys' | 'daily_manufacturing' | 'daily_company_collections' | 'daily_market_spend' | 'weekly_market_buys' | 'weekly_manufacturing' | 'weekly_market_spend' | 'weekly_company_collections' | 'seasonal_market_buys' | 'seasonal_manufacturing' | 'seasonal_market_spend' | 'seasonal_company_collections';
}

export interface PlayerMissionClaim {
  uid: string;
  missionId: string;
  category: MissionCategory;
  rewardCredits: number;
  rewardXp: number;
  claimedAt: unknown;
  periodKey?: string;
}

export interface AchievementDefinition {
  id: string;
  titleAr: string;
  titleEn: string;
  descriptionAr: string;
  descriptionEn: string;
  metric: 'trades' | 'companies' | 'produced' | 'level' | 'reputation' | 'spent' | 'revenue';
  threshold: number;
  group: 'whale' | 'market' | 'industry' | 'enterprise';
  tierLevel: 1 | 2 | 3 | 4;
  tier?: 'bronze' | 'silver' | 'gold' | 'platinum';
  rewardCredits?: number;
}

export type WorldEventEffectType =
  | 'demand_surge'
  | 'supply_shortage'
  | 'tax_cut'
  | 'industrial_boom'
  | 'service_crisis'
  | 'logistics_boom'
  | 'economic_recession'
  | 'supply_glut'
  | 'logistics_disruption';

export interface WorldEvent {
  id: string;
  titleAr: string;
  titleEn: string;
  descriptionAr: string;
  descriptionEn: string;
  effectType: WorldEventEffectType;
  targetItemId?: string;
  affectedSectors?: CompanySector[];
  priceMultiplier: number;
  revenueMultiplier?: number;
  taxDelta: number;
  stackGroup?: string;
  startsAt?: unknown;
  endsAt?: unknown;
  active: boolean;
  createdAt: unknown;
}

export interface ReputationTier {
  id: string;
  minReputation: number;
  titleAr: string;
  titleEn: string;
  contractBonusRate: number;
  companyYieldBonusRate: number;
}

export interface GameNotification {
  id: string;
  uid: string;
  title: string;
  body: string;
  type: 'economy' | 'market' | 'org' | 'mission' | 'system';
  read: boolean;
  createdAt: unknown;
  eventKey?: string | null;
}

export interface TradeContract {
  id: string;
  titleAr: string;
  titleEn: string;
  clientAr: string;
  clientEn: string;
  requiredItemId: string;
  requiredQty: number;
  payoutCredits: number;
  xpReward: number;
  reputationReward: number;
}


export type DynamicContractScope = 'personal' | 'organization';
export type DynamicContractTier = 'common' | 'uncommon' | 'rare' | 'epic';
export type DynamicContractStatus = 'offered' | 'accepted' | 'processing' | 'ready' | 'completed' | 'expired' | 'abandoned';

export interface DynamicContractOffer {
  id: string;
  scope: DynamicContractScope;
  user_id: string | null;
  org_id: string | null;
  slot_no: number;
  slot_generation: number;
  board_date: string;
  event_id: string | null;
  item_id: string;
  tier: DynamicContractTier;
  quantity: number;
  base_price: number;
  payout: number;
  reputation_reward: number;
  org_reputation_reward: number;
  processing_minutes: number;
  event_premium: number;
  status: DynamicContractStatus;
  offer_expires_at: string;
  accepted_at: string | null;
  deadline_at: string | null;
  deadline_remaining_secs: number | null;
  ready_at: string | null;
  claimed_by: string | null;
  fee_paid: number;
}

export interface DynamicContractCooldown {
  slot_no: number;
  board_date: string;
  cooldown_until: string;
}

export interface DynamicContractBoard {
  personal: DynamicContractOffer[];
  organization: DynamicContractOffer[];
  active_personal: number;
  daily_used: number;
  daily_limit: number;
  org_daily_used?: number;
  org_daily_limit?: number;
  offer_expires_at: string;
  organization_slots?: number;
  organization_max_slots?: number;
  cooldowns?: { server_now: string; can_refresh_org?: boolean; personal_refresh_used?: number; personal_refresh_limit?: number; org_refresh_used?: number; org_refresh_limit?: number; personal: DynamicContractCooldown[]; organization: DynamicContractCooldown[] };
}

export interface OrgGoalContribution {
  uid: string;
  username: string | null;
  amount: number;
}

export interface OrgWeeklyGoal {
  id: string;
  type: 'produce_units' | 'trade_volume' | 'contracts_completed' | 'treasury_donations' | 'personal_contracts_completed' | 'org_contracts_completed' | 'company_revenue' | 'factory_upgrades' | 'company_upgrades' | 'companies_founded' | 'factories_founded';
  difficulty: 'easy' | 'medium' | 'hard';
  target: number;
  current: number;
  rewardReputation: number;
  status: 'active' | 'completed';
  weekStart: string;
  completedAt: string | null;
  contributions: OrgGoalContribution[];
}

export interface OrgWeeklyGoals {
  weekStart: string;
  goals: OrgWeeklyGoal[];
}
