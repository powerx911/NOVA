import { describe, expect, it } from 'vitest';
import {
  companyLevelMultiplier,
  companyUpgradeCost,
  companyUpgradeDurationMs,
  getCompanySectorLevelGain,
  factoryOutputMultiplier,
  factoryOperatingCostMultiplier,
  factoryUpgradeCost,
  factoryUpgradeDurationSeconds,
  VAULT_UPGRADE_COSTS,
  WAREHOUSE_UPGRADE_COSTS,
} from '../lib/businessEconomy';

describe('business and factory economy curves', () => {
  it('increases company income and upgrade cost by level', () => {
    expect(companyLevelMultiplier(5)).toBeGreaterThan(companyLevelMultiplier(1));
    expect(companyLevelMultiplier(100)).toBeLessThan(10);
    expect(companyUpgradeCost(4200, 2)).toBeGreaterThan(companyUpgradeCost(4200, 1));
    expect(companyUpgradeCost(9000, 12, getCompanySectorLevelGain('tech'))).toBe(1956);
    expect(companyUpgradeDurationMs(12)).toBe(6_522_011);
    expect(companyUpgradeDurationMs(5)).toBeGreaterThan(companyUpgradeDurationMs(2));
  });

  it('keeps factory growth profitable and progressive', () => {
    expect(factoryOutputMultiplier(5)).toBeGreaterThan(factoryOutputMultiplier(1));
    expect(factoryOperatingCostMultiplier(5)).toBeGreaterThan(factoryOperatingCostMultiplier(1));
    expect(factoryUpgradeCost(4200, 4)).toBeGreaterThan(factoryUpgradeCost(4200, 1));
    expect(factoryUpgradeDurationSeconds(5)).toBeGreaterThan(factoryUpgradeDurationSeconds(2));
  });

  it('uses matching four-step storage upgrade schedules', () => {
    expect(VAULT_UPGRADE_COSTS).toEqual([2500, 7000, 18000, 45000]);
    expect(WAREHOUSE_UPGRADE_COSTS).toEqual([2500, 7000, 18000, 45000]);
  });
});
