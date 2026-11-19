#!/usr/bin/env node
/**
 * Deterministic 10,000-offer economy simulation for the baseline personal board.
 * Tier odds are the editable personal_tier_weights config (90/9/1).
 * Daily cash injection is net of the 4% processing fee sink.
 */
const SEED = 20261119;
let state = SEED >>> 0;
const random = () => {
  state = (1664525 * state + 1013904223) >>> 0;
  return state / 0x100000000;
};
const round = (value) => Math.floor(value + 0.5);
const tiers = {
  common: {
    items: { silicon_ore: 35, copper_wire: 28, energy_cells: 45, crude_alloy: 40, carbon_fiber: 55, rare_minerals: 70, titanium_ore: 85, polymer_resin: 95, biotech_gel: 120, quantum_dust: 160 },
    min: 4, max: 8, multiplier: 1.12, weight: 90,
  },
  uncommon: {
    items: { microchips: 145, precision_frame: 175, synth_polymer: 190 },
    min: 2, max: 4, multiplier: 1.18, weight: 9,
  },
  rare: {
    items: { quantum_server: 560, logistics_drone: 620, bio_module: 680 },
    min: 1, max: 2, multiplier: 1.25, weight: 1,
  },
};
const pickWeighted = (entries, weights) => {
  const total = weights.reduce((sum, value) => sum + value, 0);
  let roll = random() * total;
  for (let i = 0; i < entries.length; i += 1) {
    roll -= weights[i];
    if (roll <= 0) return entries[i];
  }
  return entries[entries.length - 1];
};

const OFFER_COUNT = 10_000;
let totalPayout = 0;
let totalFee = 0;
let totalRatio = 0;
for (let i = 0; i < OFFER_COUNT; i += 1) {
  const tier = pickWeighted(Object.entries(tiers), Object.values(tiers).map((tier) => tier.weight))[0];
  const config = tiers[tier];
  const items = Object.entries(config.items);
  // A modest inverse-price weighting keeps the five-attempt daily sink in range.
  const [, basePrice] = pickWeighted(items, items.map(([, price]) => price ** -0.30));
  const quantity = config.min + Math.floor(random() * (config.max - config.min + 1));
  const marketValue = quantity * basePrice;
  const payout = Math.min(2500, round(marketValue * config.multiplier * (0.95 + random() * 0.10)));
  const fee = round(payout * 0.04);
  totalPayout += payout;
  totalFee += fee;
  totalRatio += payout / marketValue;
}

const averagePayout = totalPayout / OFFER_COUNT;
const averagePayoutToMarket = totalRatio / OFFER_COUNT;
const averageFiveDailyNet = 5 * (totalPayout - totalFee) / OFFER_COUNT;
console.log(`Simulated offers: ${OFFER_COUNT}`);
console.log(`Average payout: ${averagePayout.toFixed(2)}`);
console.log(`Average payout / market value: ${averagePayoutToMarket.toFixed(4)}`);
console.log(`Average net injection from 5 personal daily contracts: ${averageFiveDailyNet.toFixed(2)}`);
if (averagePayoutToMarket < 1.05 || averagePayoutToMarket > 1.45) {
  throw new Error('PAYOUT_TO_MARKET_RATIO_OUT_OF_RANGE');
}
if (averageFiveDailyNet < 2000 || averageFiveDailyNet > 2300) {
  throw new Error('DAILY_CONTRACT_INJECTION_OUT_OF_RANGE');
}
