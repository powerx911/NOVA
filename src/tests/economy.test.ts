import { describe, expect, it } from 'vitest';
import { ITEM_MAP, MANUFACTURING_RECIPES } from '../data/catalog';
import {
  calculateAccruedPayout,
  calculateCompanyHourlyNet,
  calculateCompanyVaultBalance,
  getCompanyVaultCapacity,
  getCompanyVaultLevel,
  getPlayerInventoryCapacity,
  calculateDailyStipend,
  calculateDynamicItemPrice,
  calculateLevelProgress,
  calculateManufacturingCost,
  calculateMarketTaxRate,
  hasOrgPermission,
  isValidUsername,
  validateTransfer,
} from '../lib/economy';
import type { WorldEvent } from '../types/game';

const sampleEvents: WorldEvent[] = [
  {
    id: 'evt_silicon_boom',
    titleAr: 'طفرة الرقائق',
    titleEn: 'Chip Boom',
    descriptionAr: 'زيادة الطلب',
    descriptionEn: 'Surge',
    effectType: 'demand_surge',
    targetItemId: 'microchips',
    priceMultiplier: 1.2,
    taxDelta: 0,
    active: true,
    createdAt: null,
  },
  {
    id: 'evt_tax_holiday',
    titleAr: 'خفض ضريبي',
    titleEn: 'Tax Cut',
    descriptionAr: 'خصم 1%',
    descriptionEn: '1% off',
    effectType: 'tax_cut',
    priceMultiplier: 1.0,
    taxDelta: -0.01,
    active: true,
    createdAt: null,
  },
];

describe('Company Profit Vault', () => {
  const hour = 3_600_000;

  it('uses independent configured capacities for all five levels', () => {
    expect([1, 2, 3, 4, 5].map(getCompanyVaultCapacity)).toEqual([3500, 7000, 14000, 25000, 40000]);
  });

  it('defaults legacy companies to vault level 1', () => {
    expect(getCompanyVaultLevel({})).toBe(1);
    expect(getCompanyVaultCapacity(getCompanyVaultLevel({}))).toBe(3500);
  });

  it('adds elapsed net revenue to the stored vault balance', () => {
    expect(calculateCompanyVaultBalance(
      { vaultLevel: 2, vaultBalance: 1200, lastCollectedAt: 10_000 },
      200,
      10_000 + hour * 3
    )).toBe(1800);
  });

  it('stops accrual at capacity without exceeding the vault limit', () => {
    expect(calculateCompanyVaultBalance(
      { vaultLevel: 1, vaultBalance: 3400, lastCollectedAt: 0 },
      500,
      hour * 24
    )).toBe(3500);
  });

  it('preserves the stored balance when no additional time has elapsed', () => {
    expect(calculateCompanyVaultBalance(
      { vaultLevel: 3, vaultBalance: 8250, lastCollectedAt: hour * 5 },
      250,
      hour * 5
    )).toBe(8250);
  });

  it('does not accrue for negative or non-finite revenue and sanitizes invalid stored balances', () => {
    expect(calculateCompanyVaultBalance(
      { vaultLevel: 1, vaultBalance: Number.NaN, lastCollectedAt: 0 },
      Number.NaN,
      hour * 4
    )).toBe(0);
    expect(calculateCompanyVaultBalance(
      { vaultLevel: 1, vaultBalance: 500, lastCollectedAt: 0 },
      -100,
      hour * 4
    )).toBe(500);
  });

  it('clamps invalid and out-of-range vault levels safely', () => {
    expect(getCompanyVaultLevel({ vaultLevel: Number.NaN })).toBe(1);
    expect(getCompanyVaultLevel({ vaultLevel: 99 })).toBe(5);
    expect(getCompanyVaultCapacity(-3)).toBe(3500);
    expect(getCompanyVaultCapacity(Number.NaN)).toBe(3500);
  });
});

describe('Player Inventory Capacity', () => {
  it('grows smoothly with player level and clamps invalid levels', () => {
    expect(getPlayerInventoryCapacity(1)).toBe(250);
    expect(getPlayerInventoryCapacity(2)).toBe(265);
    expect(getPlayerInventoryCapacity(10)).toBe(385);
    expect(getPlayerInventoryCapacity(200)).toBe(3235);
    expect(getPlayerInventoryCapacity(0)).toBe(250);
    expect(getPlayerInventoryCapacity(Number.NaN)).toBe(250);
  });
});

describe('NOVA Core Economy & Security Invariants', () => {
  it('validates usernames strictly (3-24 chars, alphanumeric + underscore)', () => {
    expect(isValidUsername('Khalid_01')).toBe(true);
    expect(isValidUsername('ab')).toBe(false);
    expect(isValidUsername('bad name!')).toBe(false);
    expect(isValidUsername('a'.repeat(25))).toBe(false);
  });

  it('computes XP and multi-level progression accurately', () => {
    expect(calculateLevelProgress(0)).toEqual({
      level: 1,
      currentLevelXp: 0,
      nextLevelXp: 200,
      progressPercent: 0,
    });
    const lv2 = calculateLevelProgress(200);
    expect(lv2.level).toBe(2);
    expect(lv2.currentLevelXp).toBe(0);
    expect(lv2.nextLevelXp).toBe(320);

    const lv3 = calculateLevelProgress(520);
    expect(lv3.level).toBe(3);
  });

  it('prevents negative balances, zero/negative amounts, and self-transfers', () => {
    expect(validateTransfer('u1', 'u1', 2500, 100)).toEqual({
      valid: false,
      reason: 'SELF_OR_MISSING_RECIPIENT',
    });
    expect(validateTransfer('u1', 'u2', 2500, 0)).toEqual({
      valid: false,
      reason: 'INVALID_AMOUNT',
    });
    expect(validateTransfer('u1', 'u2', 2500, -50)).toEqual({
      valid: false,
      reason: 'INVALID_AMOUNT',
    });
    expect(validateTransfer('u1', 'u2', 500, 600)).toEqual({
      valid: false,
      reason: 'INSUFFICIENT_FUNDS',
    });
    expect(validateTransfer('u1', 'u2', 2500, 500)).toEqual({ valid: true });
  });

  it('calculates market tax rate factoring in Trade skill and World Events with floor/ceiling', () => {
    // Base 5% - 1% event = 4%
    expect(calculateMarketTaxRate(0, sampleEvents)).toBeCloseTo(0.04, 4);
    // Max trade skill Lv.10 (-4%) + -1% event -> clamped at 1% floor
    expect(calculateMarketTaxRate(10, sampleEvents)).toBeCloseTo(0.01, 4);
  });

  it('adjusts dynamic item prices by supply scarcity and active world events', () => {
    const scarcePrice = calculateDynamicItemPrice('microchips', 10, sampleEvents);
    const abundantPrice = calculateDynamicItemPrice('microchips', 500, sampleEvents);
    expect(scarcePrice).toBeGreaterThan(abundantPrice);
  });

  it('moves the supply price index smoothly across former threshold boundaries', () => {
    const boundaryPairs = [[19, 20], [20, 21], [99, 100], [100, 101], [399, 400], [400, 401]];
    const boundaryPrices = boundaryPairs.map(([quantity]) =>
      calculateDynamicItemPrice('microchips', quantity, [], 1_000)
    );
    const adjacentPrices = boundaryPairs.map(([, quantity]) =>
      calculateDynamicItemPrice('microchips', quantity, [], 1_000)
    );

    expect(calculateDynamicItemPrice('microchips', 0, [], 1_000))
      .toBeGreaterThan(calculateDynamicItemPrice('microchips', 800, [], 1_000));
    const maxRoundedStep = Math.ceil(ITEM_MAP.microchips.basePrice * 0.0015) + 1;
    for (let index = 0; index < boundaryPairs.length; index += 1) {
      expect(Math.abs(adjacentPrices[index] - boundaryPrices[index])).toBeLessThanOrEqual(maxRoundedStep);
    }
  });

  it('calculates company hourly net profit with Management and Finance skills', () => {
    const base = calculateCompanyHourlyNet(
      { baseRevenuePerHour: 200, expensePerHour: 60, level: 1 },
      { management: 0, finance: 0 }
    );
    const skilled = calculateCompanyHourlyNet(
      { baseRevenuePerHour: 200, expensePerHour: 60, level: 2 },
      { management: 3, finance: 4 }
    );
    expect(skilled.netHourly).toBeGreaterThan(base.netHourly);
    expect(skilled.expenseHourly).toBeGreaterThan(0);
  });

  it('reduces manufacturing processing cost based on Industry skill with a 10 N-Credit floor', () => {
    const recipe = MANUFACTURING_RECIPES[0];
    const baseCost = calculateManufacturingCost(recipe, 0);
    const skilledCost = calculateManufacturingCost(recipe, 5);
    expect(skilledCost).toBeLessThan(baseCost);
    expect(skilledCost).toBeGreaterThanOrEqual(10);
  });

  it('enforces organization RBAC permissions strictly', () => {
    expect(hasOrgPermission({ role: 'leader', permissions: [] }, 'manage_treasury')).toBe(true);
    expect(
      hasOrgPermission({ role: 'deputy', permissions: ['manage_members', 'manage_treasury'] }, 'manage_treasury')
    ).toBe(true);
    expect(hasOrgPermission({ role: 'officer', permissions: ['manage_members'] }, 'manage_treasury')).toBe(false);
    expect(hasOrgPermission({ role: 'member', permissions: [] }, 'manage_members')).toBe(false);
  });

  it('caps accrued hourly payout at 12 hours and scales daily stipend cleanly', () => {
    const oneHour = 3_600_000;
    expect(calculateAccruedPayout(120, 0, oneHour * 2)).toBe(240);
    expect(calculateAccruedPayout(120, 0, oneHour * 30)).toBe(1440); // capped at 12h
    expect(calculateDailyStipend(5, 3)).toBeGreaterThan(calculateDailyStipend(1, 0));
  });
  it('keeps market prices within the configured event multiplier bounds', () => {
    const extremeHigh: WorldEvent[] = Array.from({ length: 5 }, (_, index) => ({
      ...sampleEvents[0],
      id: `evt_high_${index}`,
      stackGroup: `high_${index}`,
      priceMultiplier: 2,
    }));
    const extremeLow: WorldEvent[] = Array.from({ length: 5 }, (_, index) => ({
      ...sampleEvents[0],
      id: `evt_low_${index}`,
      stackGroup: `low_${index}`,
      priceMultiplier: 0.1,
    }));

    // Compare against the unrounded supply-adjusted reference so the event
    // multiplier is bounded before the final integer rounding in production.
    const supplyAdjustedPrice = ITEM_MAP.microchips.basePrice * 1.05;
    const high = calculateDynamicItemPrice('microchips', 100, extremeHigh, 1_000);
    const low = calculateDynamicItemPrice('microchips', 100, extremeLow, 1_000);

    expect(high).toBeLessThanOrEqual(Math.round(supplyAdjustedPrice * 1.45));
    expect(low).toBeGreaterThanOrEqual(Math.round(supplyAdjustedPrice * 0.6));
  });

  it('clamps market tax even when world events apply extreme modifiers', () => {
    const extremeEvents: WorldEvent[] = [
      { ...sampleEvents[0], id: 'evt_tax_extreme_low', taxDelta: -1 },
      { ...sampleEvents[1], id: 'evt_tax_extreme_high', taxDelta: 1, stackGroup: 'tax_high' },
    ];

    expect(calculateMarketTaxRate(0, extremeEvents, 1_000)).toBeGreaterThanOrEqual(0.01);
    expect(calculateMarketTaxRate(0, extremeEvents, 1_000)).toBeLessThanOrEqual(0.12);
  });

  it('limits active world events to three unique effect groups', async () => {
    const { getActiveWorldEvents } = await import('../lib/economy');
    const events: WorldEvent[] = Array.from({ length: 5 }, (_, index) => ({
      ...sampleEvents[0],
      id: `evt_group_${index}`,
      stackGroup: `group_${index}`,
    }));

    const active = getActiveWorldEvents(events, 1_000);
    expect(active).toHaveLength(3);
    expect(new Set(active.map((event) => event.stackGroup)).size).toBe(3);
  });

});
