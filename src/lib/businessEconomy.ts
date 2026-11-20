import type { FactoryResourceId } from '../types/game';

export const COMPANY_LEVEL_MAX = 100;
export const FACTORY_LEVEL_MAX = 100;
export const VAULT_LEVEL_MAX = 5;
export const WAREHOUSE_LEVEL_MAX = 5;
export const COMPANY_SECTOR_LEVEL_GAINS: Record<string, number> = {
  trade: 37.8,
  services: 47,
  logistics: 60,
  manufacturing: 76.8,
  tech: 97.8,
};

export function getCompanySectorLevelGain(sector?: string): number {
  return COMPANY_SECTOR_LEVEL_GAINS[sector ?? ''] ?? COMPANY_SECTOR_LEVEL_GAINS.trade;
}

/** Smooth income growth: meaningful early upgrades, controlled late-game scaling. */
export function companyLevelMultiplier(level: number): number {
  const safeLevel = Math.max(1, Math.min(COMPANY_LEVEL_MAX, Math.floor(level)));
  return 1 + 0.12 * Math.pow(safeLevel - 1, 0.9);
}

export function companyUpgradeCost(foundingCost: number, currentLevel: number, levelGain?: number): number {
  const level = Math.max(1, Math.min(COMPANY_LEVEL_MAX - 1, Math.floor(currentLevel)));
  const inferredGain = Math.max(37.8, foundingCost * 0.011);
  const gain = Math.max(1, levelGain ?? inferredGain);
  return Math.ceil(gain * (8 + 2.411 * level));
}

export function companyUpgradeDurationMs(targetLevel: number): number {
  const level = Math.max(2, Math.min(COMPANY_LEVEL_MAX, Math.floor(targetLevel)));
  return Math.round(11 * 60_000 * Math.pow(level / 13, 0.85));
}

const FACTORY_RESOURCE_GROWTH_CURVES: Record<FactoryResourceId, { linear: number; quadratic: number }> = {
  copper_wire: { linear: 0.028, quadratic: 0.00020 },
  silicon_ore: { linear: 0.030, quadratic: 0.00022 },
  energy_cells: { linear: 0.032, quadratic: 0.00024 },
  crude_alloy: { linear: 0.034, quadratic: 0.00026 },
  carbon_fiber: { linear: 0.036, quadratic: 0.00028 },
  rare_minerals: { linear: 0.038, quadratic: 0.00030 },
  titanium_ore: { linear: 0.040, quadratic: 0.00032 },
  polymer_resin: { linear: 0.042, quadratic: 0.00034 },
  biotech_gel: { linear: 0.044, quadratic: 0.00036 },
  quantum_dust: { linear: 0.046, quadratic: 0.00038 },
};

/** Mirrors nexora.factory_progression_multiplier for the selected raw resource. */
export function factoryOutputMultiplier(resourceId: FactoryResourceId, level: number): number {
  const safeLevel = Math.max(1, Math.min(FACTORY_LEVEL_MAX, Math.floor(level)));
  const step = safeLevel - 1;
  const curve = FACTORY_RESOURCE_GROWTH_CURVES[resourceId];
  return 1 + curve.linear * step + curve.quadratic * step * step;
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
