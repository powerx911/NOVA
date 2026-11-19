export type ServerWorldEventEffectType =
  | 'demand_surge'
  | 'supply_shortage'
  | 'tax_cut'
  | 'industrial_boom'
  | 'service_crisis'
  | 'logistics_boom'
  | 'economic_recession'
  | 'supply_glut'
  | 'logistics_disruption';

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
    eventClass: 'positive',
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
    eventClass: 'positive',
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
    eventClass: 'positive',
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
    eventClass: 'negative',
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
    eventClass: 'positive',
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
    eventClass: 'positive',
  },

  {
    id: 'evt_global_recession',
    titleAr: 'ركود اقتصادي عالمي',
    titleEn: 'Global Economic Recession',
    descriptionAr: 'انكماش حاد في الطلب العالمي يخفض مؤشر الرقائق إلى 60% ويقلص عوائد قطاعات الاقتصاد.',
    descriptionEn: 'A sharp global demand contraction cuts the Microchip market index to 60% and reduces company yields across sectors.',
    effectType: 'economic_recession',
    targetItemId: 'microchips',
    affectedSectors: ['trade', 'manufacturing', 'services', 'tech', 'logistics'],
    priceMultiplier: 0.6,
    revenueMultiplier: 0.72,
    taxDelta: 0.01,
    stackGroup: 'macro_demand',
    durationHours: 12,
    eventClass: 'negative',
  },
  {
    id: 'evt_raw_material_glut',
    titleAr: 'تخمة المعروض من الخامات',
    titleEn: 'Raw Material Supply Glut',
    descriptionAr: 'وفرة مفاجئة في المعروض تضغط على أسعار خام السيليكون إلى 70% وتضعف عوائد التصنيع.',
    descriptionEn: 'A sudden supply glut pushes Silicon Ore prices to 70% and softens manufacturing yields.',
    effectType: 'supply_glut',
    targetItemId: 'silicon_ore',
    affectedSectors: ['manufacturing'],
    priceMultiplier: 0.7,
    revenueMultiplier: 0.88,
    taxDelta: 0,
    stackGroup: 'supply_raw',
    durationHours: 12,
    eventClass: 'negative',
  },
  {
    id: 'evt_logistics_disruption',
    titleAr: 'تعطل سلاسل الإمداد',
    titleEn: 'Global Logistics Disruption',
    descriptionAr: 'تعطل الشحن يرفع تكاليف التشغيل ويخفض عوائد قطاعي النقل والتجارة إلى 75%.',
    descriptionEn: 'Shipping disruption increases operating pressure and cuts Logistics and Trade yields to 75%.',
    effectType: 'logistics_disruption',
    targetItemId: 'logistics_drone',
    affectedSectors: ['logistics', 'trade'],
    priceMultiplier: 0.82,
    revenueMultiplier: 0.75,
    taxDelta: 0.01,
    stackGroup: 'sector_logistics',
    durationHours: 10,
    eventClass: 'negative',
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
    const rotationIndex = Math.floor(nowMs / (6 * 3_600_000));
    const positiveTemplates = SERVER_WORLD_EVENT_TEMPLATES.filter((t) => t.eventClass === 'positive');
    const negativeTemplates = SERVER_WORLD_EVENT_TEMPLATES.filter((t) => t.eventClass === 'negative');
    const rotationOffset = rotationIndex % positiveTemplates.length;
    const orderedPositive: ServerWorldEventTemplate[] = [];
    for (let i = 0; i < positiveTemplates.length; i++) {
      orderedPositive.push(positiveTemplates[(rotationOffset + i) % positiveTemplates.length]);
    }

    // One in five six-hour rotations may introduce a single negative event.
    // All other rotations draw exclusively from positive events.
    const negativeWindow = rotationIndex % 5 === 4;
    const negativeCandidate = negativeWindow && negativeTemplates.length > 0
      ? [negativeTemplates[Math.floor(rotationIndex / 5) % negativeTemplates.length]]
      : [];
    const orderedCandidates = [...negativeCandidate, ...orderedPositive];
    const prioritized = [
      ...orderedCandidates.filter((t) => !justExpiredIds.has(t.id)),
      ...orderedCandidates.filter((t) => justExpiredIds.has(t.id)),
    ];

    for (const tpl of prioritized) {
      if (toActivate.length >= slotsNeeded) break;
      if (keptActiveIds.has(tpl.id) || usedGroups.has(tpl.stackGroup)) continue;
      if (tpl.eventClass === 'negative' && toActivate.some((entry) => entry.template.eventClass === 'negative')) continue;
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
