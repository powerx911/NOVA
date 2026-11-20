export const COMPANY_LEVEL_MAX = 100;
export const FACTORY_LEVEL_MAX = 100;
export const VAULT_LEVEL_MAX = 5;
export const WAREHOUSE_LEVEL_MAX = 5;

/** Smooth income growth: meaningful early upgrades, controlled late-game scaling. */
export function companyLevelMultiplier(level: number): number {
  const safeLevel = Math.max(1, Math.min(COMPANY_LEVEL_MAX, Math.floor(level)));
  return 1 + 0.12 * Math.pow(safeLevel - 1, 0.9);
}

export function companyUpgradeCost(foundingCost: number, currentLevel: number): number {
  const level = Math.max(1, Math.min(COMPANY_LEVEL_MAX - 1, Math.floor(currentLevel)));
  return Math.ceil(foundingCost * 0.3 * Math.pow(level, 1.18));
}

export function companyUpgradeDurationMs(targetLevel: number): number {
  const level = Math.max(2, Math.min(COMPANY_LEVEL_MAX, Math.floor(targetLevel)));
  return Math.round(8 * 60_000 * Math.pow(level, 1.3));
}

export function factoryOutputMultiplier(level: number): number {
  const safeLevel = Math.max(1, Math.min(FACTORY_LEVEL_MAX, Math.floor(level)));
  const step = safeLevel - 1;
  return 1 + 0.04 * step + 0.0003 * step * step;
}

export function factoryOperatingCostMultiplier(level: number): number {
  return 1 + 0.018 * Math.max(0, Math.min(FACTORY_LEVEL_MAX, Math.floor(level)) - 1);
}

export function factoryUpgradeCost(foundingCost: number, currentLevel: number): number {
  const level = Math.max(1, Math.min(FACTORY_LEVEL_MAX - 1, Math.floor(currentLevel)));
  return Math.ceil(foundingCost * 0.22 * Math.pow(level, 1.22));
}

export function factoryUpgradeDurationSeconds(targetLevel: number): number {
  const level = Math.max(2, Math.min(FACTORY_LEVEL_MAX, Math.floor(targetLevel)));
  return Math.round(10 * 60 * Math.pow(level, 1.35));
}

export const WAREHOUSE_UPGRADE_COSTS = [2500, 7000, 18000, 45000];
export const WAREHOUSE_UPGRADE_DURATION_MINUTES = [30, 90, 240, 720];
export const VAULT_UPGRADE_COSTS = [2500, 7000, 18000, 45000];
export const VAULT_UPGRADE_DURATION_MINUTES = [20, 75, 240, 720];

export function warehouseUpgradeCost(currentLevel: number): number {
  return WAREHOUSE_UPGRADE_COSTS[Math.max(1, Math.min(4, Math.floor(currentLevel))) - 1] ?? 0;
}

export function warehouseUpgradeDurationSeconds(targetLevel: number): number {
  return (WAREHOUSE_UPGRADE_DURATION_MINUTES[Math.max(2, Math.min(5, Math.floor(targetLevel))) - 2] ?? 0) * 60;
}

export function vaultUpgradeCost(currentLevel: number): number {
  return VAULT_UPGRADE_COSTS[Math.max(1, Math.min(4, Math.floor(currentLevel))) - 1] ?? 0;
}

export function vaultUpgradeDurationSeconds(targetLevel: number): number {
  return (VAULT_UPGRADE_DURATION_MINUTES[Math.max(2, Math.min(5, Math.floor(targetLevel))) - 2] ?? 0) * 60;
}
