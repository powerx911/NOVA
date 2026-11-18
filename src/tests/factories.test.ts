import { describe, expect, it } from 'vitest';
import { COMPANY_SECTORS, FACTORY_RESOURCES, ITEM_MAP } from '../data/catalog';

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

  it('keeps factory operating costs below the highest company base expense', () => {
    const highestCompanyExpense = Math.max(...COMPANY_SECTORS.map((sector) => sector.baseExpensePerHour));
    for (const factory of FACTORY_RESOURCES) {
      expect(factory.operatingCostPerHour).toBeLessThan(highestCompanyExpense);
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

  it('keeps raw-resource production margins controlled', () => {
    for (const factory of FACTORY_RESOURCES) {
      const grossValue = factory.productionPerHour * ITEM_MAP[factory.resourceId].basePrice;
      const marginRatio = grossValue / factory.operatingCostPerHour;
      expect(marginRatio).toBeGreaterThan(1);
      expect(marginRatio).toBeLessThanOrEqual(1.3);
    }
  });
});
