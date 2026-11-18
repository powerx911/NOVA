export type Language = 'ar' | 'en';

export type MainTab = 'home' | 'business' | 'market' | 'organization' | 'social' | 'profile';

export type BusinessSubTab = 'companies' | 'auction' | 'factories' | 'inventory' | 'financials';
export type MarketSubTab = 'exchange' | 'contracts' | 'bank' | 'manufacturing';
export type ProfileSubTab = 'overview' | 'skills' | 'missions' | 'rankings' | 'settings' | 'diagnostics';

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
  | 'company_collect'
  | 'company_vault_upgrade'
  | 'company_auction_escrow'
  | 'company_auction_refund'
  | 'company_auction_sale'
  | 'manufacturing'
  | 'skill_reset'
  | 'factory_create'
  | 'factory_operating'
  | 'factory_upgrade'
  | 'factory_skill'
  | 'org_create'
  | 'org_deposit'
  | 'org_withdraw'
  | 'contract_deal';

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
  companyId: string;
  companyName: string;
  companySector: CompanySector;
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

export type FactoryResourceId = 'copper_wire' | 'silicon_ore' | 'energy_cells' | 'crude_alloy' | 'carbon_fiber' | 'rare_minerals';
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
  metric: 'trades' | 'companies' | 'produced' | 'level' | 'org';
}

export interface PlayerMissionClaim {
  uid: string;
  missionId: string;
  category: MissionCategory;
  rewardCredits: number;
  rewardXp: number;
  claimedAt: unknown;
}

export interface AchievementDefinition {
  id: string;
  titleAr: string;
  titleEn: string;
  descriptionAr: string;
  descriptionEn: string;
  metric: 'trades' | 'companies' | 'produced' | 'level' | 'reputation';
  threshold: number;
}

export type WorldEventEffectType =
  | 'demand_surge'
  | 'supply_shortage'
  | 'tax_cut'
  | 'industrial_boom'
  | 'service_crisis'
  | 'logistics_boom';

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
