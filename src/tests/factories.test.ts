import { describe, expect, it } from 'vitest';
import { factoryOutputMultiplier } from '../lib/businessEconomy';
import { COMPANY_SECTORS, FACTORY_RESOURCES, ITEM_MAP, MANUFACTURING_RECIPES } from '../data/catalog';

describe('Raw resource factories', () => {
  it('only produces catalog resources classified as raw', () => {
    for (const factory of FACTORY_RESOURCES) {
      expect(ITEM_MAP[factory.resourceId]?.tier).toBe('raw');
    }
  });

  it('scales founding cost and rarity upward while production becomes more specialized', () => {
    for (let index = 1; index < FACTORY_RESOURCES.length; index += 1) {
      expect(FACTORY_RESOURCES[index].foundingCost).toBeGreaterThan(FACTORY_RESOURCES[index - 1].foundingCost);
      expect(FACTORY_RESOURCES[index].rarityFactor).toBeGreaterThan(FACTORY_RESOURCES[index - 1].rarityFactor);
      expect(FACTORY_RESOURCES[index].productionPerHour).toBeLessThan(FACTORY_RESOURCES[index - 1].productionPerHour);
    }
  });

  it('keeps even advanced factory operating costs within a controlled ceiling', () => {
    for (const factory of FACTORY_RESOURCES) {
      expect(factory.operatingCostPerHour).toBeLessThanOrEqual(650);
    }
  });

  it('keeps starter factory net income below starter company net income', () => {
    const lowestCompanyNetIncome = Math.min(...COMPANY_SECTORS.map((sector) => sector.baseRevenuePerHour - sector.baseExpensePerHour));
    for (const factory of FACTORY_RESOURCES) {
      const grossValue = factory.productionPerHour * ITEM_MAP[factory.resourceId].basePrice;
      expect(grossValue).toBeGreaterThan(factory.operatingCostPerHour);
      expect(grossValue - factory.operatingCostPerHour).toBeLessThan(lowestCompanyNetIncome);
    }
  });

  it('uses distinct, convex, bounded progression curves for all ten resources', () => {
    const level100Multipliers = FACTORY_RESOURCES.map((factory) =>
      factoryOutputMultiplier(factory.resourceId, 100)
    );
    expect(new Set(level100Multipliers.map((value) => value.toFixed(5))).size).toBe(10);

    for (const factory of FACTORY_RESOURCES) {
      const multiplier = (level: number) => factoryOutputMultiplier(factory.resourceId, level);
      const gain = (from: number, to: number) => multiplier(to) - multiplier(from);
      expect(gain(2, 3)).toBeLessThan(gain(41, 42));
      expect(gain(41, 42)).toBeLessThan(gain(75, 76));
      expect(multiplier(100)).toBeGreaterThan(5.7);
      expect(multiplier(100)).toBeLessThan(9.3);
    }

    expect(factoryOutputMultiplier('copper_wire', 100)).toBeCloseTo(5.7322, 4);
    expect(factoryOutputMultiplier('quantum_dust', 100)).toBeCloseTo(9.27838, 5);
  });

  it('keeps raw-resource production margins controlled', () => {
    for (const factory of FACTORY_RESOURCES) {
      const grossValue = factory.productionPerHour * ITEM_MAP[factory.resourceId].basePrice;
      const marginRatio = grossValue / factory.operatingCostPerHour;
      expect(marginRatio).toBeGreaterThan(1);
      expect(marginRatio).toBeLessThanOrEqual(1.3);
    }
  });

  it('gives every advanced raw resource a real manufacturing use', () => {
    const advancedResources = ['titanium_ore', 'polymer_resin', 'biotech_gel', 'quantum_dust'];
    for (const resourceId of advancedResources) {
      expect(MANUFACTURING_RECIPES.some((recipe) => recipe.inputs.some((input) => input.itemId === resourceId))).toBe(true);
    }
  });
});
