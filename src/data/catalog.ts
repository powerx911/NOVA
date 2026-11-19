import type {
  AchievementDefinition,
  CatalogItem,
  CompanySector,
  FactoryResourceId,
  ManufacturingRecipe,
  MissionDefinition,
  OrgPermission,
  OrgRole,
  ReputationTier,
  SkillKey,
  TradeContract,
  WorldEventEffectType,
} from '../types/game';

// Import images as build assets so every deployment contains the exact
// image files for its own commit (no dependency on GitHub's mutable branch URL).
const emblemImage = new URL('../../nova-icon.svg', import.meta.url).href;
const marketBannerImage = new URL('../assets/images/world_market_banner_1794737994643.jpg', import.meta.url).href;
const strategistAvatar = new URL('../assets/images/avatar_strategist_1794737993416.jpg', import.meta.url).href;
const industrialistAvatar = new URL('../assets/images/avatar_industrialist_1794737993767.jpg', import.meta.url).href;
const financierAvatar = new URL('../assets/images/avatar_financier_1794737994701.jpg', import.meta.url).href;

export const BRAND_ASSETS = {
  emblem: emblemImage,
  marketBanner: marketBannerImage,
};

export const AVATARS = [
  {
    id: 'strategist',
    labelAr: 'المخطط الاستراتيجي',
    labelEn: 'Corporate Strategist',
    src: strategistAvatar,
  },
  {
    id: 'industrialist',
    labelAr: 'الرائد الصناعي',
    labelEn: 'Tech Industrialist',
    src: industrialistAvatar,
  },
  {
    id: 'financier',
    labelAr: 'المهندس المالي',
    labelEn: 'Executive Financier',
    src: financierAvatar,
  },
];

export const STARTING_CREDITS = 2500;
export const BASE_MARKET_TAX_RATE = 0.05; // 5%
export const ORG_CREATION_COST = 1000;
export const DAILY_STIPEND_BASE = 450;

export interface SkillDefinition {
  key: SkillKey;
  nameAr: string;
  nameEn: string;
  effectAr: string;
  effectEn: string;
  maxLevel: number;
}

export const SKILL_DEFINITIONS: SkillDefinition[] = [
  {
    key: 'trade',
    nameAr: 'التجارة',
    nameEn: 'Trade',
    effectAr: 'تخفض ضريبة السوق بمقدار 0.4% لكل مستوى وتزيد أرباح التبادل.',
    effectEn: 'Reduces market tax by 0.4% per level and boosts trade margin.',
    maxLevel: 10,
  },
  {
    key: 'management',
    nameAr: 'الإدارة',
    nameEn: 'Management',
    effectAr: 'ترفع كفاءة وإيرادات الشركات بنسبة 8% لكل مستوى.',
    effectEn: 'Increases company hourly revenue efficiency by 8% per level.',
    maxLevel: 10,
  },
  {
    key: 'industry',
    nameAr: 'الصناعة',
    nameEn: 'Industry',
    effectAr: 'تقلل تكلفة التشغيل التصنيعي بنسبة 6% لكل مستوى وتفتح الوصفات المتقدمة.',
    effectEn: 'Cuts manufacturing processing cost by 6% per level and unlocks recipes.',
    maxLevel: 10,
  },
  {
    key: 'negotiation',
    nameAr: 'التفاوض',
    nameEn: 'Negotiation',
    effectAr: 'ترفع مكافآت العقود التجارية بنسبة 7% لكل مستوى.',
    effectEn: 'Boosts trade contract payouts by 7% per level.',
    maxLevel: 10,
  },
  {
    key: 'finance',
    nameAr: 'التحليل المالي',
    nameEn: 'Financial Analysis',
    effectAr: 'تخفض مصاريف تشغيل الشركات بنسبة 5% لكل مستوى وتزيد مكافأة التشغيل اليومي.',
    effectEn: 'Reduces company expenses by 5% per level and boosts daily stipend.',
    maxLevel: 10,
  },
  {
    key: 'leadership',
    nameAr: 'القيادة',
    nameEn: 'Leadership',
    effectAr: 'تزيد مكاسب النفوذ والسمعة من المهام والمنظمات بنسبة 10% لكل مستوى.',
    effectEn: 'Increases Reputation and Influence gains by 10% per level.',
    maxLevel: 10,
  },
];

export const CATALOG_ITEMS: CatalogItem[] = [
  {
    id: 'silicon_ore',
    nameAr: 'خام السيليكون',
    nameEn: 'Silicon Ore',
    tier: 'raw',
    basePrice: 35,
    unitWeight: 1,
    descriptionAr: 'معدن أساسي لتصنيع الرقائق الدقيقة وأنظمة الحوسبة.',
    descriptionEn: 'Primary mineral for microchips and computing architecture.',
  },
  {
    id: 'copper_wire',
    nameAr: 'أسلاك النحاس',
    nameEn: 'Copper Wire',
    tier: 'raw',
    basePrice: 28,
    unitWeight: 1,
    descriptionAr: 'موصلات كهربائية عالية النقاء للوحات والطاقة.',
    descriptionEn: 'High-purity electrical conductors for boards and power grids.',
  },
  {
    id: 'energy_cells',
    nameAr: 'خلايا الطاقة',
    nameEn: 'Energy Cells',
    tier: 'raw',
    basePrice: 45,
    unitWeight: 1,
    descriptionAr: 'وحدات طاقة مركزة لتشغيل خطوط الإنتاج المتقدمة.',
    descriptionEn: 'Concentrated power units driving advanced production lines.',
  },
  {
    id: 'crude_alloy',
    nameAr: 'سبائك خام',
    nameEn: 'Crude Alloy',
    tier: 'raw',
    basePrice: 40,
    unitWeight: 2,
    descriptionAr: 'معادن مصهورة لهياكل الآلات والمركبات اللوجستية.',
    descriptionEn: 'Smelted metals for machinery frames and logistics vehicles.',
  },
  {
    id: 'carbon_fiber',
    nameAr: 'ألياف الكربون',
    nameEn: 'Carbon Fiber',
    tier: 'raw',
    basePrice: 55,
    unitWeight: 1,
    descriptionAr: 'مادة خفيفة عالية المتانة للمعدات الجوية والصناعية.',
    descriptionEn: 'Lightweight high-tensile material for aerial and industrial rigs.',
  },
  {
    id: 'rare_minerals',
    nameAr: 'معادن نادرة',
    nameEn: 'Rare Minerals',
    tier: 'raw',
    basePrice: 70,
    unitWeight: 1,
    descriptionAr: 'عناصر دقيقة تدخل في البوليمرات والأنظمة الحيوية.',
    descriptionEn: 'Precision elements used in polymers and bio-systems.',
  },
  {
    id: 'titanium_ore',
    nameAr: 'خام التيتانيوم',
    nameEn: 'Titanium Ore',
    tier: 'raw',
    basePrice: 85,
    unitWeight: 2,
    descriptionAr: 'معدن خفيف وعالي الصلابة لصناعة الهياكل المتقدمة.',
    descriptionEn: 'Lightweight, high-strength metal for advanced structural components.',
  },
  {
    id: 'polymer_resin',
    nameAr: 'راتنج البوليمر',
    nameEn: 'Polymer Resin',
    tier: 'raw',
    basePrice: 95,
    unitWeight: 1,
    descriptionAr: 'مادة كيميائية أساسية لإنتاج المركبات الصناعية المتطورة.',
    descriptionEn: 'A core chemical feedstock for advanced industrial composites.',
  },
  {
    id: 'biotech_gel',
    nameAr: 'هلام حيوي',
    nameEn: 'Biotech Gel',
    tier: 'raw',
    basePrice: 120,
    unitWeight: 1,
    descriptionAr: 'مركب حيوي نقي يدخل في التقنيات الطبية والحيوية.',
    descriptionEn: 'A refined bio-compound used in medical and biotechnology systems.',
  },
  {
    id: 'quantum_dust',
    nameAr: 'غبار كمومي',
    nameEn: 'Quantum Dust',
    tier: 'raw',
    basePrice: 160,
    unitWeight: 1,
    descriptionAr: 'مادة نادرة لتشغيل الأنظمة الكمومية فائقة الدقة.',
    descriptionEn: 'A rare material for ultra-precision quantum systems.',
  },
  {
    id: 'microchips',
    nameAr: 'رقائق دقيقة',
    nameEn: 'Microchips',
    tier: 'intermediate',
    basePrice: 145,
    unitWeight: 1,
    descriptionAr: 'معالجات منطقية وسيطة تدخل في الخوادم والطائرات المسيرة.',
    descriptionEn: 'Intermediate logic processors for servers and autonomous drones.',
  },
  {
    id: 'precision_frame',
    nameAr: 'هياكل دقيقة',
    nameEn: 'Precision Frame',
    tier: 'intermediate',
    basePrice: 175,
    unitWeight: 2,
    descriptionAr: 'هياكل هندسية مقاومة للإجهاد الحراري والميكانيكي.',
    descriptionEn: 'Engineered chassis resistant to thermal and mechanical stress.',
  },
  {
    id: 'synth_polymer',
    nameAr: 'بوليمر صناعي',
    nameEn: 'Synth Polymer',
    tier: 'intermediate',
    basePrice: 190,
    unitWeight: 1,
    descriptionAr: 'مركب صناعي فائق العزل للاستخدامات الطبية والتقنية.',
    descriptionEn: 'High-insulation industrial compound for tech and bio modules.',
  },
  {
    id: 'quantum_server',
    nameAr: 'خادم كمومي',
    nameEn: 'Quantum Server',
    tier: 'final',
    basePrice: 560,
    unitWeight: 3,
    descriptionAr: 'منتج نهائي عالي القيمة لمراكز البيانات والشركات التقنية.',
    descriptionEn: 'High-value final product for data centers and tech firms.',
  },
  {
    id: 'logistics_drone',
    nameAr: 'طائرة شحن ذاتية',
    nameEn: 'Logistics Drone',
    tier: 'final',
    basePrice: 620,
    unitWeight: 3,
    descriptionAr: 'مركبة نقل جوي مستقلة ترفع كفاءة سلاسل الإمداد.',
    descriptionEn: 'Autonomous cargo aircraft elevating supply chain throughput.',
  },
  {
    id: 'bio_module',
    nameAr: 'وحدة حيوية متقدمة',
    nameEn: 'Bio-Tech Module',
    tier: 'final',
    basePrice: 680,
    unitWeight: 2,
    descriptionAr: 'منظومة حيوية دقيقة ذات طلب مرتفع في الأسواق العالمية.',
    descriptionEn: 'Precision bio-system commanding strong global market demand.',
  },
];

export const ITEM_MAP: Record<string, CatalogItem> = Object.fromEntries(
  CATALOG_ITEMS.map((item) => [item.id, item])
);

export const MANUFACTURING_RECIPES: ManufacturingRecipe[] = [
  {
    id: 'rec_microchips',
    outputItemId: 'microchips',
    outputQty: 2,
    inputs: [
      { itemId: 'silicon_ore', qty: 2 },
      { itemId: 'copper_wire', qty: 2 },
    ],
    processingCost: 40,
    xpReward: 45,
    requiredIndustrySkill: 0,
  },
  {
    id: 'rec_precision_frame',
    outputItemId: 'precision_frame',
    outputQty: 2,
    inputs: [
      { itemId: 'crude_alloy', qty: 2 },
      { itemId: 'carbon_fiber', qty: 1 },
    ],
    processingCost: 50,
    xpReward: 55,
    requiredIndustrySkill: 0,
  },
  {
    id: 'rec_synth_polymer',
    outputItemId: 'synth_polymer',
    outputQty: 2,
    inputs: [
      { itemId: 'energy_cells', qty: 2 },
      { itemId: 'rare_minerals', qty: 1 },
    ],
    processingCost: 60,
    xpReward: 65,
    requiredIndustrySkill: 1,
  },
  {
    id: 'rec_quantum_server',
    outputItemId: 'quantum_server',
    outputQty: 1,
    inputs: [
      { itemId: 'microchips', qty: 2 },
      { itemId: 'energy_cells', qty: 1 },
    ],
    processingCost: 90,
    xpReward: 110,
    requiredIndustrySkill: 1,
  },
  {
    id: 'rec_logistics_drone',
    outputItemId: 'logistics_drone',
    outputQty: 1,
    inputs: [
      { itemId: 'precision_frame', qty: 2 },
      { itemId: 'microchips', qty: 1 },
    ],
    processingCost: 110,
    xpReward: 125,
    requiredIndustrySkill: 2,
  },
  {
    id: 'rec_bio_module',
    outputItemId: 'bio_module',
    outputQty: 1,
    inputs: [
      { itemId: 'synth_polymer', qty: 2 },
      { itemId: 'rare_minerals', qty: 2 },
    ],
    processingCost: 125,
    xpReward: 140,
    requiredIndustrySkill: 2,
  },
  {
    id: 'rec_titanium_frame',
    outputItemId: 'precision_frame',
    outputQty: 2,
    inputs: [
      { itemId: 'titanium_ore', qty: 2 },
      { itemId: 'carbon_fiber', qty: 1 },
    ],
    processingCost: 80,
    xpReward: 75,
    requiredIndustrySkill: 1,
  },
  {
    id: 'rec_polymer_composite',
    outputItemId: 'synth_polymer',
    outputQty: 2,
    inputs: [
      { itemId: 'polymer_resin', qty: 2 },
      { itemId: 'energy_cells', qty: 1 },
    ],
    processingCost: 90,
    xpReward: 85,
    requiredIndustrySkill: 1,
  },
  {
    id: 'rec_biotech_module',
    outputItemId: 'bio_module',
    outputQty: 1,
    inputs: [
      { itemId: 'biotech_gel', qty: 2 },
      { itemId: 'rare_minerals', qty: 1 },
    ],
    processingCost: 320,
    xpReward: 155,
    requiredIndustrySkill: 2,
  },
  {
    id: 'rec_quantum_server_advanced',
    outputItemId: 'quantum_server',
    outputQty: 1,
    inputs: [
      { itemId: 'quantum_dust', qty: 2 },
      { itemId: 'microchips', qty: 1 },
    ],
    processingCost: 60,
    xpReward: 180,
    requiredIndustrySkill: 3,
  },
];

export interface CompanySectorSpec {
  sector: CompanySector;
  nameAr: string;
  nameEn: string;
  foundingCost: number;
  baseRevenuePerHour: number;
  baseExpensePerHour: number;
}

export interface FactoryResourceSpec {
  resourceId: FactoryResourceId;
  nameAr: string;
  nameEn: string;
  foundingCost: number;
  productionPerHour: number;
  operatingCostPerHour: number;
  rarityFactor: number;
  descriptionAr: string;
  descriptionEn: string;
}

export const FACTORY_RESOURCES: FactoryResourceSpec[] = [
  { resourceId: 'copper_wire', nameAr: 'أسلاك النحاس', nameEn: 'Copper Wire', foundingCost: 1800, productionPerHour: 1.1, operatingCostPerHour: 25, rarityFactor: 1, descriptionAr: 'مصنع موارد أساسية بإنتاج سريع وتكلفة تطوير منخفضة.', descriptionEn: 'An entry-level resource factory with faster output and lower upgrade costs.' },
  { resourceId: 'silicon_ore', nameAr: 'خام السيليكون', nameEn: 'Silicon Ore', foundingCost: 2400, productionPerHour: 1.03, operatingCostPerHour: 28, rarityFactor: 1.2, descriptionAr: 'إنتاج خام مهم لسلاسل التقنية وأشباه الموصلات.', descriptionEn: 'A key raw material for technology and semiconductor supply chains.' },
  { resourceId: 'energy_cells', nameAr: 'خلايا الطاقة', nameEn: 'Energy Cells', foundingCost: 3200, productionPerHour: 0.92, operatingCostPerHour: 32, rarityFactor: 1.4, descriptionAr: 'إنتاج متوسط الصعوبة مع مصاريف تشغيل مرتفعة.', descriptionEn: 'Mid-tier production with higher operating expenses.' },
  { resourceId: 'crude_alloy', nameAr: 'سبائك خام', nameEn: 'Crude Alloy', foundingCost: 4200, productionPerHour: 0.89, operatingCostPerHour: 35, rarityFactor: 1.65, descriptionAr: 'يتطلب استثماراً أكبر وإدارة تشغيلية أدق.', descriptionEn: 'Requires greater investment and more demanding operations.' },
  { resourceId: 'carbon_fiber', nameAr: 'ألياف الكربون', nameEn: 'Carbon Fiber', foundingCost: 6000, productionPerHour: 0.88, operatingCostPerHour: 42, rarityFactor: 2.1, descriptionAr: 'مورد متقدم بإنتاج أبطأ وتطوير مكلف.', descriptionEn: 'An advanced material with slower output and expensive upgrades.' },
  { resourceId: 'rare_minerals', nameAr: 'معادن نادرة', nameEn: 'Rare Minerals', foundingCost: 9000, productionPerHour: 0.87, operatingCostPerHour: 50, rarityFactor: 3.6, descriptionAr: 'أعلى المصانع تكلفة وصعوبة، وإنتاجه محدود لقيمة المورد.', descriptionEn: 'The most expensive and demanding factory, with deliberately limited output.' },
  { resourceId: 'titanium_ore', nameAr: 'خام التيتانيوم', nameEn: 'Titanium Ore', foundingCost: 12000, productionPerHour: 0.86, operatingCostPerHour: 60, rarityFactor: 4, descriptionAr: 'مورد متقدم لصناعات الطيران والهياكل الثقيلة.', descriptionEn: 'An advanced material for aerospace and high-strength structures.' },
  { resourceId: 'polymer_resin', nameAr: 'راتنج البوليمر', nameEn: 'Polymer Resin', foundingCost: 15000, productionPerHour: 0.85, operatingCostPerHour: 65, rarityFactor: 4.5, descriptionAr: 'مادة صناعية متخصصة ذات قيمة سوقية مرتفعة.', descriptionEn: 'A specialist industrial material with high market value.' },
  { resourceId: 'biotech_gel', nameAr: 'هلام حيوي', nameEn: 'Biotech Gel', foundingCost: 22000, productionPerHour: 0.84, operatingCostPerHour: 80, rarityFactor: 5, descriptionAr: 'مورد نادر لسلاسل التقنية الحيوية.', descriptionEn: 'A rare feedstock for biotechnology supply chains.' },
  { resourceId: 'quantum_dust', nameAr: 'غبار كمومي', nameEn: 'Quantum Dust', foundingCost: 30000, productionPerHour: 0.83, operatingCostPerHour: 110, rarityFactor: 6, descriptionAr: 'أندر موارد المصانع وأعلاها قيمة مع التطوير.', descriptionEn: 'The rarest factory resource, with the highest late-game value.' },
];

export const COMPANY_SECTORS: CompanySectorSpec[] = [
  {
    sector: 'trade',
    nameAr: 'التجارة والتوزيع',
    nameEn: 'Trade & Distribution',
    foundingCost: 900,
    baseRevenuePerHour: 140,
    baseExpensePerHour: 35,
  },
  {
    sector: 'services',
    nameAr: 'الخدمات المؤسسية',
    nameEn: 'Corporate Services',
    foundingCost: 1100,
    baseRevenuePerHour: 175,
    baseExpensePerHour: 45,
  },
  {
    sector: 'logistics',
    nameAr: 'النقل والخدمات اللوجستية',
    nameEn: 'Transport & Logistics',
    foundingCost: 1400,
    baseRevenuePerHour: 225,
    baseExpensePerHour: 60,
  },
  {
    sector: 'manufacturing',
    nameAr: 'التصنيع المتقدم',
    nameEn: 'Advanced Manufacturing',
    foundingCost: 1800,
    baseRevenuePerHour: 290,
    baseExpensePerHour: 80,
  },
  {
    sector: 'tech',
    nameAr: 'التكنولوجيا والأنظمة',
    nameEn: 'Technology & Systems',
    foundingCost: 2200,
    baseRevenuePerHour: 365,
    baseExpensePerHour: 95,
  },
];

export const TRADE_CONTRACTS: TradeContract[] = [
  {
    id: 'ctr_chip_batch',
    titleAr: 'توريد رقائق لمعامل السحابة',
    titleEn: 'Cloud Lab Microchip Supply',
    clientAr: 'مجموعة المدار التقنية',
    clientEn: 'Orbit Tech Group',
    requiredItemId: 'microchips',
    requiredQty: 2,
    payoutCredits: 420,
    xpReward: 75,
    reputationReward: 12,
  },
  {
    id: 'ctr_drone_fleet',
    titleAr: 'تجهيز أسطول شحن سريع',
    titleEn: 'Express Cargo Drone Fleet',
    clientAr: 'تحالف الموانئ الحرة',
    clientEn: 'Freeport Logistics Alliance',
    requiredItemId: 'logistics_drone',
    requiredQty: 1,
    payoutCredits: 890,
    xpReward: 145,
    reputationReward: 24,
  },
  {
    id: 'ctr_quantum_node',
    titleAr: 'تركيب عقدة خادم كمومي',
    titleEn: 'Quantum Node Deployment',
    clientAr: 'مصرف الأفق المركزي',
    clientEn: 'Horizon Central Bank',
    requiredItemId: 'quantum_server',
    requiredQty: 1,
    payoutCredits: 840,
    xpReward: 135,
    reputationReward: 22,
  },
];

export const MISSIONS: MissionDefinition[] = [
  {
    id: 'tut_first_trade',
    category: 'tutorial',
    titleAr: 'دخول السوق المفتوح',
    titleEn: 'Enter the Open Market',
    descriptionAr: 'نفّذ أول صفقة شراء أو بيع في سوق NOVA.',
    descriptionEn: 'Complete your first buy or sell trade on the NOVA market.',
    rewardCredits: 450,
    rewardXp: 90,
    rewardReputation: 10,
    targetCount: 1,
    metric: 'trades',
  },
  {
    id: 'tut_first_production',
    category: 'tutorial',
    titleAr: 'تشغيل خط الإنتاج',
    titleEn: 'Start Production Line',
    descriptionAr: 'قم بتصنيع عنصر واحد على الأقل من المواد الخام.',
    descriptionEn: 'Manufacture at least 1 intermediate or final item from raw resources.',
    rewardCredits: 550,
    rewardXp: 110,
    rewardReputation: 15,
    targetCount: 1,
    metric: 'produced',
  },
  {
    id: 'tut_first_company',
    category: 'tutorial',
    titleAr: 'تأسيس الكيان التجاري',
    titleEn: 'Found Your First Company',
    descriptionAr: 'أنشئ شركتك الأولى في أحد القطاعات الاقتصادية.',
    descriptionEn: 'Establish your first company in any economic sector.',
    rewardCredits: 850,
    rewardXp: 160,
    rewardReputation: 25,
    targetCount: 1,
    metric: 'companies',
  },
  {
    id: 'daily_active_trader',
    category: 'daily',
    titleAr: 'تاجر اليوم النشط',
    titleEn: 'Active Market Trader',
    descriptionAr: 'أتمم 3 صفقات في السوق لتنشيط السيولة.',
    descriptionEn: 'Complete 3 market trades to drive liquidity.',
    rewardCredits: 600,
    rewardXp: 120,
    rewardReputation: 14,
    targetCount: 3,
    metric: 'trades',
  },
  {
    id: 'seasonal_syndicate',
    category: 'seasonal',
    titleAr: 'تحالف النخبة الاقتصادي',
    titleEn: 'Economic Syndicate Alliance',
    descriptionAr: 'انضم إلى منظمة أو أسّس منظمتك الخاصة.',
    descriptionEn: 'Join an organization or establish your own syndicate.',
    rewardCredits: 1200,
    rewardXp: 260,
    rewardReputation: 35,
    targetCount: 1,
    metric: 'org',
  },
];

export const ACHIEVEMENTS: AchievementDefinition[] = [
  {
    id: 'ach_merchant',
    titleAr: 'تاجر السوق',
    titleEn: 'Market Merchant',
    descriptionAr: 'إتمام 5 صفقات تجارية ناجحة.',
    descriptionEn: 'Complete 5 successful market trades.',
    metric: 'trades',
    threshold: 5,
  },
  {
    id: 'ach_industrial_pioneer',
    titleAr: 'رائد التصنيع',
    titleEn: 'Industrial Pioneer',
    descriptionAr: 'إنتاج 5 وحدات صناعية.',
    descriptionEn: 'Manufacture 5 industrial units.',
    metric: 'produced',
    threshold: 5,
  },
  {
    id: 'ach_tycoon',
    titleAr: 'مؤسس إمبراطورية',
    titleEn: 'Corporate Founder',
    descriptionAr: 'امتلاك شركتين أو أكثر.',
    descriptionEn: 'Own 2 or more companies.',
    metric: 'companies',
    threshold: 2,
  },
  {
    id: 'ach_level_5',
    titleAr: 'قيادي صاعد',
    titleEn: 'Rising Executive',
    descriptionAr: 'الوصول إلى المستوى 5.',
    descriptionEn: 'Reach player Level 5.',
    metric: 'level',
    threshold: 5,
  },
  {
    id: 'ach_reputation_100',
    titleAr: 'اسم موثوق',
    titleEn: 'Trusted Name',
    descriptionAr: 'تجاوز 100 نقطة سمعة.',
    descriptionEn: 'Exceed 100 Reputation points.',
    metric: 'reputation',
    threshold: 100,
  },
];

export const ROLE_DEFAULT_PERMISSIONS: Record<OrgRole, OrgPermission[]> = {
  leader: ['manage_members', 'manage_roles', 'manage_treasury', 'manage_org'],
  deputy: ['manage_members', 'manage_roles', 'manage_treasury'],
  officer: ['manage_members'],
  member: [],
};

export const SEED_MARKET_LISTINGS = [
  { id: 'seed_silicon_ore', itemId: 'silicon_ore', quantity: 250, unitPrice: 35 },
  { id: 'seed_copper_wire', itemId: 'copper_wire', quantity: 250, unitPrice: 28 },
  { id: 'seed_energy_cells', itemId: 'energy_cells', quantity: 200, unitPrice: 45 },
  { id: 'seed_crude_alloy', itemId: 'crude_alloy', quantity: 200, unitPrice: 40 },
  { id: 'seed_carbon_fiber', itemId: 'carbon_fiber', quantity: 160, unitPrice: 55 },
  { id: 'seed_rare_minerals', itemId: 'rare_minerals', quantity: 140, unitPrice: 70 },
];

export const REPUTATION_TIERS: ReputationTier[] = [
  {
    id: 'tier_emerging',
    minReputation: 0,
    titleAr: 'رائد صاعد',
    titleEn: 'Emerging Founder',
    contractBonusRate: 0,
    companyYieldBonusRate: 0,
  },
  {
    id: 'tier_trusted',
    minReputation: 60,
    titleAr: 'شريك موثوق',
    titleEn: 'Trusted Partner',
    contractBonusRate: 0.04,
    companyYieldBonusRate: 0.02,
  },
  {
    id: 'tier_accredited',
    minReputation: 160,
    titleAr: 'مستثمر معتمد',
    titleEn: 'Accredited Executive',
    contractBonusRate: 0.08,
    companyYieldBonusRate: 0.04,
  },
  {
    id: 'tier_magnate',
    minReputation: 350,
    titleAr: 'قطب سوقي',
    titleEn: 'Market Magnate',
    contractBonusRate: 0.12,
    companyYieldBonusRate: 0.06,
  },
  {
    id: 'tier_sovereign',
    minReputation: 700,
    titleAr: 'سيادي النخبة',
    titleEn: 'Syndicate Sovereign',
    contractBonusRate: 0.15,
    companyYieldBonusRate: 0.08,
  },
];

export interface WorldEventTemplate {
  id: string;
  titleAr: string;
  titleEn: string;
  descriptionAr: string;
  descriptionEn: string;
  effectType: WorldEventEffectType;
  targetItemId: string;
  affectedSectors: CompanySector[];
  priceMultiplier: number;
  revenueMultiplier: number;
  taxDelta: number;
  stackGroup: string;
  durationHours: number;
}

export const WORLD_EVENT_TEMPLATES: WorldEventTemplate[] = [
  {
    id: 'evt_silicon_boom',
    titleAr: 'طفرة الطلب على الرقائق',
    titleEn: 'Silicon & Microchip Demand Surge',
    descriptionAr: 'ارتفاع الطلب العالمي على أشباه الموصلات يرفع تقييم الرقائق (+18%) وعوائد شركات التقنية (+15%).',
    descriptionEn: 'Global semiconductor demand boosts Microchip index (+18%) and Tech company yields (+15%).',
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
    descriptionAr: 'تباطؤ الإمدادات العالمية يرفع قيمة خام السيليكون (+22%) ويضغط على هوامش التصنيع (-6%).',
    descriptionEn: 'Global extraction bottleneck elevates Silicon Ore value (+22%) while tightening factory margins (-6%).',
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
    descriptionAr: 'موجة توسع في مراكز البيانات ترفع قيمة الخادم الكمومي (+15%) وعائد قطاعي التصنيع والتقنية (+18%).',
    descriptionEn: 'Data-center expansion lifts Quantum Server prices (+15%) and Tech/Manufacturing output (+18%).',
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
    descriptionAr: 'انخفاض مؤقت في الإنفاق المؤسسي يخفض عوائد قطاعي الخدمات والتجارة (-15%) ويرفع الرسوم 1%.',
    descriptionEn: 'Temporary corporate spending pullback trims Services & Trade yields (-15%) and nudges fees +1%.',
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
    descriptionAr: 'خفض مؤقت لضريبة معاملات السوق بمقدار 1% مع دفعة تشجيعية لقطاع التجارة (+8%).',
    descriptionEn: 'Temporary 1% market transaction tax cut with a +8% Trade sector liquidity boost.',
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
    descriptionAr: 'تسارع حركة الشحن العالمية يرفع قيمة طائرات الشحن (+14%) وعوائد النقل والتجارة (+16%).',
    descriptionEn: 'Surging freight corridors boost Logistics Drone valuations (+14%) and Logistics/Trade yields (+16%).',
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

export const SEED_WORLD_EVENTS = WORLD_EVENT_TEMPLATES.filter((t) =>
  ['evt_silicon_boom', 'evt_tax_holiday', 'evt_logistics_boom'].includes(t.id)
).map((t) => ({
  id: t.id,
  titleAr: t.titleAr,
  titleEn: t.titleEn,
  descriptionAr: t.descriptionAr,
  descriptionEn: t.descriptionEn,
  effectType: t.effectType,
  targetItemId: t.targetItemId,
  affectedSectors: t.affectedSectors,
  priceMultiplier: t.priceMultiplier,
  revenueMultiplier: t.revenueMultiplier,
  taxDelta: t.taxDelta,
  stackGroup: t.stackGroup,
  durationHours: t.durationHours,
  active: true,
}));

