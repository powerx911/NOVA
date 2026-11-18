export type ServerWorldEventEffectType =
  | 'demand_surge'
  | 'supply_shortage'
  | 'tax_cut'
  | 'industrial_boom'
  | 'service_crisis'
  | 'logistics_boom';

export type ServerCompanySector = 'trade' | 'manufacturing' | 'services' | 'tech' | 'logistics';

export interface ServerWorldEventTemplate {
  id: string;
  titleAr: string;
  titleEn: string;
  descriptionAr: string;
  descriptionEn: string;
  effectType: ServerWorldEventEffectType;
  targetItemId: string;
  affectedSectors: ServerCompanySector[];
  priceMultiplier: number;
  revenueMultiplier: number;
  taxDelta: number;
  stackGroup: string;
  durationHours: number;
}

export const SERVER_WORLD_EVENT_TEMPLATES: ServerWorldEventTemplate[] = [
  {
    id: 'evt_silicon_boom',
    titleAr: 'طفرة الطلب على الرقائق',
    titleEn: 'Silicon & Microchip Demand Surge',
    descriptionAr:
      'ارتفاع الطلب العالمي على أشباه الموصلات يرفع تقييم الرقائق (+18%) وعوائد شركات التقنية (+15%).',
    descriptionEn:
      'Global semiconductor demand boosts Microchip index (+18%) and Tech company yields (+15%).',
    effectType: 'demand_surge',
    targetItemId: 'microchips',
    affectedSectors: ['tech'],
    priceMultiplier: 1.18,
    revenueMultiplier: 1.15,
    taxDelta: 0,
    stackGroup: 'sector_tech',
    durationHours: 24,
  },
  {
    id: 'evt_raw_shortage',
    titleAr: 'شح المعادن والخامات',
    titleEn: 'Raw Material Supply Squeeze',
    descriptionAr:
      'تباطؤ الإمدادات العالمية يرفع قيمة خام السيليكون (+22%) ويضغط على هوامش التصنيع (-6%).',
    descriptionEn:
      'Global extraction bottleneck elevates Silicon Ore value (+22%) while tightening factory margins (-6%).',
    effectType: 'supply_shortage',
    targetItemId: 'silicon_ore',
    affectedSectors: ['manufacturing'],
    priceMultiplier: 1.22,
    revenueMultiplier: 0.94,
    taxDelta: 0.01,
    stackGroup: 'supply_raw',
    durationHours: 18,
  },
  {
    id: 'evt_industrial_surge',
    titleAr: 'ذروة الطلب الصناعي',
    titleEn: 'Industrial Compute Expansion',
    descriptionAr:
      'موجة توسع في مراكز البيانات ترفع قيمة الخادم الكمومي (+15%) وعائد قطاعي التصنيع والتقنية (+18%).',
    descriptionEn:
      'Data-center expansion lifts Quantum Server prices (+15%) and Tech/Manufacturing output (+18%).',
    effectType: 'industrial_boom',
    targetItemId: 'quantum_server',
    affectedSectors: ['manufacturing', 'tech'],
    priceMultiplier: 1.15,
    revenueMultiplier: 1.18,
    taxDelta: 0,
    stackGroup: 'sector_industry',
    durationHours: 24,
  },
  {
    id: 'evt_service_crisis',
    titleAr: 'تباطؤ قطاع الخدمات',
    titleEn: 'Service Sector Contraction',
    descriptionAr:
      'انخفاض مؤقت في الإنفاق المؤسسي يخفض عوائد قطاعي الخدمات والتجارة (-15%) ويرفع الرسوم 1%.',
    descriptionEn:
      'Temporary corporate spending pullback trims Services & Trade yields (-15%) and nudges fees +1%.',
    effectType: 'service_crisis',
    targetItemId: '',
    affectedSectors: ['services', 'trade'],
    priceMultiplier: 0.92,
    revenueMultiplier: 0.85,
    taxDelta: 0.01,
    stackGroup: 'macro_demand',
    durationHours: 12,
  },
  {
    id: 'evt_tax_holiday',
    titleAr: 'حافز التجارة الحرة',
    titleEn: 'Free Trade Tax Incentive',
    descriptionAr:
      'خفض مؤقت لضريبة معاملات السوق بمقدار 1% مع دفعة تشجيعية لقطاع التجارة (+8%).',
    descriptionEn:
      'Temporary 1% market transaction tax cut with a +8% Trade sector liquidity boost.',
    effectType: 'tax_cut',
    targetItemId: '',
    affectedSectors: ['trade'],
    priceMultiplier: 1.0,
    revenueMultiplier: 1.08,
    taxDelta: -0.01,
    stackGroup: 'fiscal_policy',
    durationHours: 24,
  },
  {
    id: 'evt_logistics_boom',
    titleAr: 'ازدهار النقل والإمداد',
    titleEn: 'Global Logistics & Freight Boom',
    descriptionAr:
      'تسارع حركة الشحن العالمية يرفع قيمة طائرات الشحن (+14%) وعوائد النقل والتجارة (+16%).',
    descriptionEn:
      'Surging freight corridors boost Logistics Drone valuations (+14%) and Logistics/Trade yields (+16%).',
    effectType: 'logistics_boom',
    targetItemId: 'logistics_drone',
    affectedSectors: ['logistics', 'trade'],
    priceMultiplier: 1.14,
    revenueMultiplier: 1.16,
    taxDelta: 0,
    stackGroup: 'sector_logistics',
    durationHours: 24,
  },
];

export interface ExistingWorldEventRecord {
  id: string;
  active: boolean;
  stackGroup?: string;
  endsAtMs: number | null;
}

export interface WorldEventActivation {
  template: ServerWorldEventTemplate;
  startsAtMs: number;
  endsAtMs: number;
}

export interface WorldEventRotationPlan {
  toDeactivateIds: string[];
  toActivate: WorldEventActivation[];
}

export function buildWorldEventRotationPlan(
  existingEvents: ExistingWorldEventRecord[],
  nowMs: number,
  targetActiveCount = 3
): WorldEventRotationPlan {
  const cappedTarget = Math.max(1, Math.min(3, targetActiveCount));
  const toDeactivateIds: string[] = [];
  const remainingActive: ExistingWorldEventRecord[] = [];
  const justExpiredIds = new Set<string>();

  for (const evt of existingEvents) {
    if (!evt.active) continue;
    const isExpired = evt.endsAtMs !== null && evt.endsAtMs <= nowMs;
    if (isExpired) {
      toDeactivateIds.push(evt.id);
      justExpiredIds.add(evt.id);
    } else {
      remainingActive.push(evt);
    }
  }

  const usedGroups = new Set<string>();
  const keptActiveIds = new Set<string>();

  for (const evt of remainingActive) {
    const group = evt.stackGroup || evt.id;
    if (keptActiveIds.size >= cappedTarget || usedGroups.has(group)) {
      toDeactivateIds.push(evt.id);
    } else {
      usedGroups.add(group);
      keptActiveIds.add(evt.id);
    }
  }

  const slotsNeeded = Math.max(0, cappedTarget - keptActiveIds.size);
  const toActivate: WorldEventActivation[] = [];

  if (slotsNeeded > 0) {
    const count = SERVER_WORLD_EVENT_TEMPLATES.length;
    const rotationOffset = Math.floor(nowMs / (6 * 3_600_000)) % count;
    const orderedCandidates: ServerWorldEventTemplate[] = [];
    for (let i = 0; i < count; i++) {
      orderedCandidates.push(SERVER_WORLD_EVENT_TEMPLATES[(rotationOffset + i) % count]);
    }

    // Prefer fresh non-just-expired events first, then fall back if needed
    const prioritized = [
      ...orderedCandidates.filter((t) => !justExpiredIds.has(t.id)),
      ...orderedCandidates.filter((t) => justExpiredIds.has(t.id)),
    ];

    for (const tpl of prioritized) {
      if (toActivate.length >= slotsNeeded) break;
      if (keptActiveIds.has(tpl.id) || usedGroups.has(tpl.stackGroup)) continue;
      usedGroups.add(tpl.stackGroup);
      keptActiveIds.add(tpl.id);
      toActivate.push({
        template: tpl,
        startsAtMs: nowMs,
        endsAtMs: nowMs + tpl.durationHours * 3_600_000,
      });
    }
  }

  return { toDeactivateIds, toActivate };
}
