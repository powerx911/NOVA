import {
  Building,
  Coins,
  Factory,
  Package,
  Plus,
  TrendingUp,
} from 'lucide-react';
import { useEffect, useState } from 'react';
import { useToast } from '../../components/ui/ToastProvider';
import {
  COMPANY_SECTORS,
  ITEM_MAP,
  MANUFACTURING_RECIPES,
} from '../../data/catalog';
import { useTranslations } from '../../i18n/translations';
import {
  calculateAccruedPayout,
  calculateCompanyHourlyNet,
  calculateManufacturingCost,
  COMPANY_MAX_LEVEL,
  COMPANY_VAULT_MAX_LEVEL,
  COMPANY_VAULT_UPGRADES,
  calculateCompanyVaultBalance,
  getCompanyVaultCapacity,
  getCompanyVaultLevel,
} from '../../lib/economy';
import {
  collectCompanyRevenue,
  completeCompanyUpgrade,
  completeCompanyVaultUpgrade,
  foundCompany,
  manufactureRecipe,
  upgradeCompany,
  upgradeCompanyVault,
} from '../../services/gameService';
import type {
  BusinessSubTab,
  Company,
  CompanyLog,
  CompanySector,
  InventoryItem,
  Language,
  PlayerProfile,
  Wallet,
  WorldEvent,
} from '../../types/game';

interface BusinessHubViewProps {
  profile: PlayerProfile;
  wallet: Wallet | null;
  companies: Company[];
  companyLogs: CompanyLog[];
  inventory: InventoryItem[];
  worldEvents: WorldEvent[];
  language: Language;
  onGoToMarket: () => void;
  organizationIncomeBonusRate?: number;
}

export function BusinessHubView({
  profile,
  wallet,
  companies,
  companyLogs,
  inventory,
  worldEvents,
  language,
  onGoToMarket,
  organizationIncomeBonusRate = 0,
}: BusinessHubViewProps) {
  const t = useTranslations(language);
  const { showToast } = useToast();

  const [subTab, setSubTab] = useState<BusinessSubTab>('companies');
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [nowMs, setNowMs] = useState(() => Date.now());
  const [manufactureQuantity, setManufactureQuantity] = useState(1);

  // Found Company form
  const [newCompName, setNewCompName] = useState('');
  const [newCompSector, setNewCompSector] = useState<CompanySector>('trade');

  useEffect(() => {
    const timer = setInterval(() => setNowMs(Date.now()), 1000);
    return () => clearInterval(timer);
  }, []);

  useEffect(() => {
    for (const company of companies) {
      if (company.levelUpgradeEndsAt && company.levelUpgradeEndsAt <= nowMs && busyKey !== `complete_company_${company.id}`) {
        setBusyKey(`complete_company_${company.id}`);
        void completeCompanyUpgrade(profile.uid, company.id).then(() => showToast(language === 'ar' ? 'اكتمل تطوير الشركة!' : 'Company upgrade completed!', 'success')).catch(() => undefined).finally(() => setBusyKey((current) => current === `complete_company_${company.id}` ? null : current));
      }
      if (company.vaultUpgradeEndsAt && company.vaultUpgradeEndsAt <= nowMs && busyKey !== `complete_vault_${company.id}`) {
        setBusyKey(`complete_vault_${company.id}`);
        void completeCompanyVaultUpgrade(profile.uid, company.id).then(() => showToast(language === 'ar' ? 'اكتمل تطوير الخزينة!' : 'Vault upgrade completed!', 'success')).catch(() => undefined).finally(() => setBusyKey((current) => current === `complete_vault_${company.id}` ? null : current));
      }
    }
  }, [companies, nowMs, busyKey, profile.uid, language, showToast]);

  const invMap = new Map<string, number>();
  inventory.forEach((item) => invMap.set(item.itemId, item.quantity));

  const totalCompanyNetHr = companies.reduce((sum, c) => {
    const { netHourly } = calculateCompanyHourlyNet(
      c,
      {
        management: profile.skills.management || 0,
        finance: profile.skills.finance || 0,
      },
      worldEvents,
      nowMs,
      profile.reputation,
      organizationIncomeBonusRate
    );
    return sum + netHourly;
  }, 0);

  async function handleFoundCompany(e: React.FormEvent) {
    e.preventDefault();
    setBusyKey('found_company');
    try {
      await foundCompany(profile.uid, profile.username, newCompName, newCompSector);
      setNewCompName('');
      showToast(
        language === 'ar' ? 'تم تأسيس الشركة بنجاح!' : 'Company founded successfully!',
        'success'
      );
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      showToast(
        code === 'INSUFFICIENT_FUNDS'
          ? language === 'ar'
            ? 'رصيدك غير كافٍ.'
            : 'Insufficient funds.'
          : language === 'ar'
          ? 'تأكد من إدخال اسم شركة صالح.'
          : 'Please enter a valid company name.',
        'error'
      );
    } finally {
      setBusyKey(null);
    }
  }

  async function handleCollectCompany(companyId: string) {
    setBusyKey(`col_${companyId}`);
    try {
      const earned = await collectCompanyRevenue(profile.uid, companyId);
      showToast(
        language === 'ar' ? `تم تحصيل +${earned} $.` : `Collected +${earned} $.`,
        'success'
      );
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      showToast(
        code === 'NOTHING_TO_COLLECT'
          ? language === 'ar'
            ? 'انتظر قليلاً لتراكم العائد التشغيلي.'
            : 'Wait briefly for hourly revenue to accrue.'
          : language === 'ar'
          ? 'تعذر التحصيل.'
          : 'Collection failed.',
        'error'
      );
    } finally {
      setBusyKey(null);
    }
  }

  async function handleUpgradeCompany(companyId: string) {
    setBusyKey(`upg_${companyId}`);
    try {
      await upgradeCompany(profile.uid, companyId);
      showToast(language === 'ar' ? 'تمت ترقية الشركة.' : 'Company upgraded.', 'success');
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      const firebaseErrorCode = ['permission-denied', 'failed-precondition', 'not-found', 'unauthenticated', 'unavailable', 'deadline-exceeded', 'aborted', 'internal', 'invalid-argument', 'resource-exhausted'].find((errorCode) => code.toLowerCase().includes(errorCode));
      const fallbackMessage = language === 'ar'
        ? `تعذر ترقية الشركة${firebaseErrorCode ? ` (رمز: ${firebaseErrorCode})` : ''}.`
        : `Company upgrade failed${firebaseErrorCode ? ` (code: ${firebaseErrorCode})` : ''}.`;
      showToast(
        code === 'MAX_LEVEL'
          ? language === 'ar'
            ? `وصلت الشركة إلى الحد الأقصى للمستوى (${COMPANY_MAX_LEVEL}).`
            : `Company reached maximum level (${COMPANY_MAX_LEVEL}).`
          : code === 'INSUFFICIENT_FUNDS'
          ? language === 'ar'
            ? 'الرصيد غير كافٍ للترقية.'
            : 'Insufficient funds to upgrade.'
          : fallbackMessage,
        'error'
      );
    } finally {
      setBusyKey(null);
    }
  }

  async function handleUpgradeCompanyVault(companyId: string) {
    setBusyKey(`vault_${companyId}`);
    try {
      await upgradeCompanyVault(profile.uid, companyId);
      showToast(language === 'ar' ? 'تم تطوير خزينة الشركة مع الاحتفاظ بالأرباح.' : 'Company vault upgraded; accrued profits preserved.', 'success');
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      const message = code === 'MISSING_VAULT_MATERIALS'
        ? (language === 'ar' ? 'المواد المطلوبة لتطوير الخزينة غير متوفرة.' : 'Required vault upgrade materials are missing.')
        : code === 'INSUFFICIENT_FUNDS'
        ? (language === 'ar' ? 'الرصيد غير كافٍ لتطوير الخزينة.' : 'Insufficient credits to upgrade the vault.')
        : code === 'VAULT_MAX_LEVEL'
        ? (language === 'ar' ? 'وصلت الخزينة إلى أقصى مستوى.' : 'The vault is already at maximum level.')
        : (language === 'ar' ? 'تعذر تطوير الخزينة.' : 'Vault upgrade failed.');
      showToast(message, 'error');
    } finally {
      setBusyKey(null);
    }
  }

  async function handleManufacture(recipeId: string) {
    const quantity = Math.max(1, Math.min(999, Math.floor(manufactureQuantity || 1)));
    setBusyKey(`mfg_${recipeId}`);
    try {
      await manufactureRecipe(profile.uid, recipeId, quantity);
      showToast(language === 'ar' ? 'تم الإنتاج بنجاح!' : 'Production completed!', 'success');
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      showToast(
        code === 'MISSING_INPUTS'
          ? language === 'ar'
            ? 'المدخلات غير كافية في المخزون.'
            : 'Insufficient input materials in inventory.'
          : code === 'INDUSTRY_SKILL_TOO_LOW'
          ? language === 'ar'
            ? 'مستوى مهارة الصناعة غير كافٍ لهذه الوصفة.'
            : 'Industry skill level too low for this recipe.'
          : language === 'ar'
          ? 'الرصيد غير كافٍ لتكلفة التشغيل.'
          : 'Insufficient credits for processing cost.',
        'error'
      );
    } finally {
      setBusyKey(null);
    }
  }

  const subTabs: { id: BusinessSubTab; label: string }[] = [
    { id: 'companies', label: t.subCompanies },
    { id: 'manufacturing', label: t.subManufacturing },
    { id: 'inventory', label: t.subInventory },
    { id: 'financials', label: t.subFinancials },
  ];

  return (
    <div className="space-y-5">
      {/* Segmented Sub-Navigation */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-1">
        {subTabs.map((tab) => (
          <button
            key={tab.id}
            type="button"
            onClick={() => setSubTab(tab.id)}
            className={`min-h-[40px] px-4 py-2 rounded-xl text-xs font-semibold whitespace-nowrap shrink-0 transition-colors ${
              subTab === tab.id
                ? 'bg-[#B91C32] text-white'
                : 'bg-[#141821] text-[#9299A6] border border-white/8 hover:text-[#F4F5F7]'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* 1. COMPANIES */}
      {subTab === 'companies' && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
          {/* Found New Company Form */}
          <form
            onSubmit={handleFoundCompany}
            className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-4 h-fit"
          >
            <div className="flex items-center justify-between">
              <h2 className="text-base font-semibold text-[#F4F5F7]">{t.foundCompany}</h2>
              <Building className="w-4 h-4 text-[#E04455]" />
            </div>

            <div className="space-y-1.5">
              <label className="text-xs text-[#9299A6]">{t.companyName}</label>
              <input
                type="text"
                value={newCompName}
                onChange={(e) => setNewCompName(e.target.value)}
                maxLength={48}
                required
                placeholder={language === 'ar' ? 'شركة الأفق للتجارة' : 'Horizon Trade Corp'}
                className="w-full min-h-[44px] px-3.5 rounded-xl bg-[#0B0D12] border border-white/10 text-sm text-[#F4F5F7] focus:outline-none focus:border-[#E04455]"
              />
            </div>

            <div className="space-y-1.5">
              <label className="text-xs text-[#9299A6]">{t.companySector}</label>
              <div className="space-y-2">
                {COMPANY_SECTORS.map((s) => (
                  <button
                    key={s.sector}
                    type="button"
                    onClick={() => setNewCompSector(s.sector)}
                    className={`w-full p-3 rounded-xl border text-start flex items-center justify-between transition-colors ${
                      newCompSector === s.sector
                        ? 'bg-[#1B2230] border-[#E04455]'
                        : 'bg-[#0B0D12] border-white/8 hover:border-white/20'
                    }`}
                  >
                    <div>
                      <p className="text-xs font-semibold text-[#F4F5F7]">
                        {language === 'ar' ? s.nameAr : s.nameEn}
                      </p>
                      <p className="text-[11px] text-[#9299A6] mt-0.5 font-mono-num">
                        +{s.baseRevenuePerHour - s.baseExpensePerHour}/hr
                      </p>
                    </div>
                    <span className="text-xs font-mono-num font-semibold text-[#E04455]">
                      {'$'}{s.foundingCost.toLocaleString()}
                    </span>
                  </button>
                ))}
              </div>
            </div>

            <button
              type="submit"
              disabled={busyKey === 'found_company'}
              className="w-full min-h-[44px] px-4 rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-sm font-semibold flex items-center justify-center gap-2 transition-colors disabled:opacity-50"
            >
              <Plus className="w-4 h-4" />
              <span>{busyKey === 'found_company' ? '...' : t.foundCompany}</span>
            </button>
          </form>

          {/* Owned Companies List */}
          <div className="lg:col-span-2 space-y-4">
            {companies.length === 0 ? (
              <div className="bg-[#141821] border border-white/8 rounded-2xl p-8 text-center">
                <p className="text-sm text-[#9299A6]">
                  {language === 'ar'
                    ? 'لا تمتلك أي شركة بعد. أسس شركتك الأولى لبدء توليد الإيرادات.'
                    : 'No companies owned yet. Found your first enterprise to generate hourly revenue.'}
                </p>
              </div>
            ) : (
              companies.map((c) => {
                const breakdown = calculateCompanyHourlyNet(
                  c,
                  {
                    management: profile.skills.management || 0,
                    finance: profile.skills.finance || 0,
                  },
                  worldEvents,
                  nowMs,
                  profile.reputation,
                  organizationIncomeBonusRate
                );
                const { netHourly, grossHourly, expenseHourly, sectorEventMultiplier } = breakdown;
                const accrued = calculateCompanyVaultBalance(c, netHourly, nowMs);
                const vaultLevel = getCompanyVaultLevel(c);
                const vaultCapacity = getCompanyVaultCapacity(vaultLevel);
                const vaultUpgrade = COMPANY_VAULT_UPGRADES[vaultLevel - 1];
                const vaultMaterialsAvailable = vaultUpgrade
                  ? Object.entries(vaultUpgrade.materials).every(([itemId, qty]) => (invMap.get(itemId) || 0) >= qty)
                  : false;
                const vaultProgress = Math.min(100, (accrued / vaultCapacity) * 100);
                const upgradeCost = c.level * 550;
                const companyUpgradeRemaining = c.levelUpgradeEndsAt ? Math.max(0, c.levelUpgradeEndsAt - nowMs) : 0;
                const vaultUpgradeRemaining = c.vaultUpgradeEndsAt ? Math.max(0, c.vaultUpgradeEndsAt - nowMs) : 0;
                const formatRemaining = (ms: number) => { const total = Math.ceil(ms / 1000); const days = Math.floor(total / 86400); const hours = Math.floor((total % 86400) / 3600); const minutes = Math.floor((total % 3600) / 60); const seconds = total % 60; return days > 0 ? `${days}d ${hours}h` : hours > 0 ? `${hours}h ${minutes}m` : minutes > 0 ? `${minutes}m ${seconds}s` : `${seconds}s`; };
                const isMaxLevel = c.level >= COMPANY_MAX_LEVEL;
                const sectorSpec = COMPANY_SECTORS.find((s) => s.sector === c.sector);

                return (
                  <div
                    key={c.id}
                    className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-4"
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <h3 className="text-base font-bold text-[#F4F5F7]">{c.name}</h3>
                        <p className="text-xs text-[#9299A6] mt-0.5">
                          {language === 'ar' ? sectorSpec?.nameAr : sectorSpec?.nameEn} · {t.level}{' '}
                          <span className="font-mono-num text-[#F4F5F7]">{c.level}</span>
                          {Math.abs(sectorEventMultiplier - 1) > 0.001 && (
                            <span
                              className={`ms-2 font-mono-num font-semibold ${
                                sectorEventMultiplier >= 1 ? 'text-emerald-400' : 'text-amber-300'
                              }`}
                            >
                              · {t.sectorEventFactor} ×{sectorEventMultiplier.toFixed(2)}
                            </span>
                          )}
                        </p>
                      </div>
                      <div className="text-end">
                        <p className="text-xs text-[#9299A6]">{t.netPerHour}</p>
                        <p className="text-sm font-mono-num font-bold text-emerald-400">
                          +{'$'}{netHourly.toLocaleString()}
                        </p>
                      </div>
                    </div>

                    <div className="grid grid-cols-2 sm:grid-cols-5 gap-3 bg-[#0B0D12] border border-white/6 rounded-xl p-3.5 text-xs">
                      <div>
                        <p className="text-[#9299A6]">{t.grossRevenueHr}</p>
                        <p className="font-mono-num font-semibold text-emerald-400 mt-0.5">
                          +{'$'}{grossHourly.toLocaleString()}
                        </p>
                      </div>
                      <div>
                        <p className="text-[#9299A6]">{t.operatingExpenseHr}</p>
                        <p className="font-mono-num font-semibold text-[#E04455] mt-0.5">
                          -{'$'}{expenseHourly.toLocaleString()}
                        </p>
                      </div>
                      <div>
                        <p className="text-[#9299A6]">{language === 'ar' ? 'الإيراد المتراكم' : 'Accrued'}</p>
                        <p className="font-mono-num font-semibold text-[#F4F5F7] mt-0.5">
                          {'$'}{accrued.toLocaleString()}
                        </p>
                      </div>
                      <div>
                        <p className="text-[#9299A6]">{language === 'ar' ? 'إجمالي العوائد' : 'Lifetime Rev'}</p>
                        <p className="font-mono-num font-semibold text-[#F4F5F7] mt-0.5">
                          {'$'}{c.totalRevenue.toLocaleString()}
                        </p>
                      </div>
                      <div>
                        <p className="text-[#9299A6]">{language === 'ar' ? 'تكلفة التطوير' : 'Upgrade Cost'}</p>
                        <p className="font-mono-num font-semibold text-[#F4F5F7] mt-0.5">
                          {isMaxLevel ? t.maxLevelReached : `$${upgradeCost.toLocaleString()}`}
                        </p>
                      </div>
                    </div>

                    <div className="rounded-xl border border-cyan-400/15 bg-[#0B111A] p-4 space-y-3">
                      <div className="flex items-center justify-between gap-2">
                        <div>
                          <p className="text-sm font-bold text-cyan-200">{language === 'ar' ? 'خزينة الأرباح' : 'Profit Vault'}</p>
                          <p className="text-[11px] text-[#9299A6]">{language === 'ar' ? `المستوى ${vaultLevel} من ${COMPANY_VAULT_MAX_LEVEL}` : `Level ${vaultLevel} of ${COMPANY_VAULT_MAX_LEVEL}`}</p>
                        </div>
                        <p className="font-mono-num text-sm font-bold text-[#F4F5F7]">
                          ${accrued.toLocaleString()} / ${vaultCapacity.toLocaleString()}
                        </p>
                      </div>
                      <div className="h-2.5 rounded-full bg-[#202938] overflow-hidden">
                        <div className="h-full rounded-full bg-cyan-400 transition-all" style={{ width: `${vaultProgress}%` }} />
                      </div>
                      <div className="flex justify-between text-[11px] text-[#9299A6]">
                        <span>{language === 'ar' ? 'السعة المستخدمة' : 'Capacity used'}</span>
                        <span>{vaultProgress.toFixed(1)}%</span>
                      </div>
                      <p className={`text-[11px] ${accrued >= vaultCapacity ? 'text-amber-300' : 'text-[#9299A6]'}`}>
                        {accrued >= vaultCapacity
                          ? language === 'ar'
                            ? 'الخزينة ممتلئة؛ توقف تراكم الأرباح حتى التحصيل أو تطوير الخزينة.'
                            : 'Vault full; profit accumulation pauses until collection or an upgrade.'
                          : language === 'ar'
                          ? 'يتوقف تراكم الأرباح تلقائياً عند بلوغ سعة الخزينة.'
                          : 'Profit accumulation pauses automatically when the vault reaches capacity.'}
                      </p>
                      {vaultUpgrade ? (
                        <div className="space-y-2 border-t border-white/8 pt-3">
                          <div className="flex items-center justify-between gap-2">
                            <p className="text-xs font-semibold text-[#F4F5F7]">{language === 'ar' ? `تطوير الخزينة إلى المستوى ${vaultLevel + 1}` : `Upgrade vault to level ${vaultLevel + 1}`}</p>
                            <span className="text-xs font-mono-num text-amber-300">${vaultUpgrade.cost.toLocaleString()}</span>
                          </div>
                          <div className="flex flex-wrap gap-2">
                            {Object.entries(vaultUpgrade.materials).map(([itemId, qty]) => {
                              const item = ITEM_MAP[itemId];
                              const owned = invMap.get(itemId) || 0;
                              return (
                                <span key={itemId} className={`rounded-lg px-2 py-1 text-[11px] ${owned >= qty ? 'bg-emerald-500/10 text-emerald-300' : 'bg-rose-500/10 text-rose-300'}`}>
                                  {language === 'ar' ? item?.nameAr : item?.nameEn}: {owned}/{qty}
                                </span>
                              );
                            })}
                          </div>
                          <button
                            type="button"
                            disabled={vaultUpgradeRemaining > 0 || (wallet?.balance ?? 0) < vaultUpgrade.cost || !vaultMaterialsAvailable || busyKey === `vault_${c.id}`}
                            onClick={() => handleUpgradeCompanyVault(c.id)}
                            className="w-full min-h-[40px] rounded-xl bg-cyan-700/80 hover:bg-cyan-600 text-white text-xs font-semibold disabled:opacity-40 transition-colors"
                          >
                            {vaultUpgradeRemaining > 0 ? (language === 'ar' ? `جارٍ التطوير: ${formatRemaining(vaultUpgradeRemaining)}` : `Upgrading: ${formatRemaining(vaultUpgradeRemaining)}`) : (language === 'ar' ? 'بدء تطوير الخزينة' : 'Start Vault Upgrade')}
                          </button>
                        </div>
                      ) : (
                        <p className="text-xs font-semibold text-emerald-300">{language === 'ar' ? 'وصلت الخزينة إلى أقصى مستوى' : 'Maximum vault level reached'}</p>
                      )}
                    </div>

                    <div className="flex flex-wrap items-center gap-2.5">
                      <button
                        type="button"
                        disabled={accrued < 1 || busyKey === `col_${c.id}`}
                        onClick={() => handleCollectCompany(c.id)}
                        className="flex-1 min-h-[42px] px-4 rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-xs font-semibold whitespace-nowrap disabled:bg-[#1B2230] disabled:text-[#9299A6] transition-colors"
                      >
                        {t.collectRevenue} ({accrued})
                      </button>
                      <button
                        type="button"
                        disabled={isMaxLevel || companyUpgradeRemaining > 0 || busyKey === `upg_${c.id}` || (wallet?.balance ?? 0) < upgradeCost}
                        onClick={() => handleUpgradeCompany(c.id)}
                        className="min-h-[42px] px-3.5 rounded-xl bg-[#1B2230] hover:bg-[#232C3E] text-[#F4F5F7] text-xs font-semibold whitespace-nowrap disabled:opacity-50 transition-colors"
                      >
                        {isMaxLevel ? t.maxLevelReached : companyUpgradeRemaining > 0 ? (language === 'ar' ? `جارٍ التطوير: ${formatRemaining(companyUpgradeRemaining)}` : `Upgrading: ${formatRemaining(companyUpgradeRemaining)}`) : (language === 'ar' ? 'بدء تطوير الشركة' : 'Start Company Upgrade')}
                      </button>
                    </div>
                  </div>
                );
              })
            )}

            {companyLogs.length > 0 && (
              <div className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-3">
                <h3 className="text-sm font-semibold text-[#F4F5F7]">
                  {language === 'ar' ? 'سجل عمليات الشركات' : 'Company Operations Log'}
                </h3>
                <div className="space-y-2">
                  {companyLogs.slice(0, 6).map((log) => (
                    <div
                      key={log.id}
                      className="flex items-center justify-between text-xs py-2 border-b border-white/6 last:border-0"
                    >
                      <span className="text-[#9299A6]">{log.details}</span>
                      <span
                        className={`font-mono-num font-semibold ${
                          log.amount >= 0 ? 'text-emerald-400' : 'text-[#E04455]'
                        }`}
                      >
                        {log.amount >= 0 ? `+${log.amount}` : log.amount}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* 2. MANUFACTURING */}
      {subTab === 'manufacturing' && (
        <div className="space-y-4">
          <div className="bg-[#141821] border border-white/8 rounded-2xl p-4 space-y-3">
            <div className="flex items-center justify-between gap-3">
              <div>
                <h2 className="text-sm font-bold text-[#F4F5F7]">{language === 'ar' ? 'كمية التصنيع' : 'Batch quantity'}</h2>
                <p className="text-xs text-[#9299A6] mt-1">{language === 'ar' ? 'اختر عدد الدفعات لكل وصفة' : 'Choose how many batches to run per recipe'}</p>
              </div>
              <span className="text-sm font-mono-num font-bold text-[#E04455]">×{manufactureQuantity}</span>
            </div>
            <div className="grid grid-cols-3 gap-2">
              {[1, 5, 10].map((qty) => (
                <button key={qty} type="button" onClick={() => setManufactureQuantity(qty)}
                  className={`min-h-[42px] rounded-xl border text-sm font-semibold transition-colors ${manufactureQuantity === qty ? 'bg-[#B91C32] border-[#E04455] text-white' : 'bg-[#0B0D12] border-white/10 text-[#C5CAD3]'}`}>
                  ×{qty}
                </button>
              ))}
            </div>
            <label className="block space-y-1.5">
              <span className="text-xs text-[#9299A6]">{language === 'ar' ? 'أو أدخل كمية مخصصة (1–999)' : 'Or enter a custom quantity (1–999)'}</span>
              <input type="number" min="1" max="999" step="1" value={manufactureQuantity}
                onChange={(e) => setManufactureQuantity(Math.max(1, Math.min(999, Number(e.target.value) || 1)))}
                className="w-full min-h-[44px] px-3.5 rounded-xl bg-[#0B0D12] border border-white/10 text-sm text-[#F4F5F7] focus:outline-none focus:border-[#E04455]" />
            </label>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {MANUFACTURING_RECIPES.map((rec) => {
              const outputItem = ITEM_MAP[rec.outputItemId];
              const costPerBatch = calculateManufacturingCost(rec, profile.skills.industry || 0);
              const totalCost = costPerBatch * manufactureQuantity;
              const hasSkill = (profile.skills.industry || 0) >= rec.requiredIndustrySkill;
              const hasAllInputs = rec.inputs.every((inp) => (invMap.get(inp.itemId) || 0) >= inp.qty * manufactureQuantity);
              const canAfford = (wallet?.balance ?? 0) >= totalCost;
              const estOutputValue = outputItem.basePrice * rec.outputQty * manufactureQuantity;
              const inputIndexCost = rec.inputs.reduce((sum, inp) => sum + (ITEM_MAP[inp.itemId]?.basePrice || 0) * inp.qty * manufactureQuantity, 0);
              const estNetMargin = estOutputValue - inputIndexCost - totalCost;

              return (
                <div key={rec.id} className="bg-[#141821] border border-white/8 rounded-2xl p-5 flex flex-col justify-between gap-4">
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <h3 className="text-base font-bold text-[#F4F5F7]">{language === 'ar' ? outputItem.nameAr : outputItem.nameEn} ×{rec.outputQty * manufactureQuantity}</h3>
                      <p className="text-xs text-[#9299A6] mt-0.5">
                        {language === 'ar' ? 'مهارة الصناعة المطلوبة:' : 'Required Industry:'} <span className="font-mono-num text-[#F4F5F7]">Lv.{rec.requiredIndustrySkill}</span> · +{rec.xpReward * manufactureQuantity} XP
                      </p>
                    </div>
                    <Factory className="w-5 h-5 text-[#E04455] shrink-0" />
                  </div>
                  <div className="space-y-2 bg-[#0B0D12] border border-white/6 rounded-xl p-3.5">
                    {rec.inputs.map((inp) => {
                      const inpItem = ITEM_MAP[inp.itemId];
                      const owned = invMap.get(inp.itemId) || 0;
                      const required = inp.qty * manufactureQuantity;
                      const ok = owned >= required;
                      return (
                        <div key={inp.itemId} className="flex items-center justify-between text-xs">
                          <span className="text-[#9299A6]">{language === 'ar' ? inpItem.nameAr : inpItem.nameEn}</span>
                          <span className={`font-mono-num font-semibold ${ok ? 'text-emerald-400' : 'text-[#E04455]'}`}>{owned} / {required}</span>
                        </div>
                      );
                    })}
                    <div className="flex items-center justify-between text-xs pt-2 border-t border-white/6">
                      <span className="text-[#9299A6]">{t.processingCost}</span>
                      <span className="font-mono-num font-semibold text-[#F4F5F7]">${totalCost.toLocaleString()}</span>
                    </div>
                    <div className="flex items-center justify-between text-xs">
                      <span className="text-[#9299A6]">{t.estMarketValue}</span>
                      <span className="font-mono-num text-[#F4F5F7]">~${estOutputValue.toLocaleString()}</span>
                    </div>
                    <div className="flex items-center justify-between text-xs">
                      <span className="text-[#9299A6]">{t.estNetMargin}</span>
                      <span className={`font-mono-num font-semibold ${estNetMargin >= 0 ? 'text-emerald-400' : 'text-[#E04455]'}`}>{estNetMargin >= 0 ? `+${estNetMargin.toLocaleString()}` : estNetMargin.toLocaleString()}</span>
                    </div>
                  </div>
                  <div className="flex items-center gap-2.5">
                    <button type="button" disabled={!hasSkill || !hasAllInputs || !canAfford || busyKey === `mfg_${rec.id}`}
                      onClick={() => handleManufacture(rec.id)}
                      className="flex-1 min-h-[44px] px-4 rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-xs font-semibold transition-colors disabled:bg-[#1B2230] disabled:text-[#9299A6]">
                      {busyKey === `mfg_${rec.id}` ? '...' : !hasSkill ? (language === 'ar' ? 'مهارة غير كافية' : 'Skill too low') : !hasAllInputs ? t.missingInputs : !canAfford ? (language === 'ar' ? 'رصيد غير كافٍ' : 'Insufficient balance') : (language === 'ar' ? `تصنيع ×${manufactureQuantity}` : `Produce ×${manufactureQuantity}`)}
                    </button>
                    {!hasAllInputs && (
                      <button type="button" onClick={onGoToMarket} className="min-h-[44px] px-3.5 rounded-xl bg-[#1B2230] hover:bg-[#232C3E] text-[#F4F5F7] text-xs font-medium whitespace-nowrap">{t.navMarket}</button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* 4. INVENTORY */}
      {subTab === 'inventory' && (
        <div className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-semibold text-[#F4F5F7]">{t.subInventory}</h2>
            <Package className="w-4 h-4 text-[#E04455]" />
          </div>
          {inventory.filter((i) => i.quantity > 0).length === 0 ? (
            <div className="py-10 text-center space-y-3">
              <p className="text-sm text-[#9299A6]">
                {language === 'ar'
                  ? 'مخزونك فارغ حالياً. اشترِ موارد أولية من السوق للبدء.'
                  : 'Your inventory is empty. Purchase raw resources from the Market.'}
              </p>
              <button
                type="button"
                onClick={onGoToMarket}
                className="min-h-[42px] px-5 rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-xs font-semibold"
              >
                {t.navMarket}
              </button>
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
              {inventory
                .filter((i) => i.quantity > 0)
                .map((inv) => {
                  const item = ITEM_MAP[inv.itemId];
                  if (!item) return null;
                  return (
                    <div
                      key={inv.itemId}
                      className="p-4 rounded-xl bg-[#0B0D12] border border-white/6 flex items-center justify-between gap-3"
                    >
                      <div>
                        <p className="text-sm font-semibold text-[#F4F5F7]">
                          {language === 'ar' ? item.nameAr : item.nameEn}
                        </p>
                        <p className="text-xs text-[#9299A6] mt-0.5">
                          ~{'$'}{item.basePrice}
                        </p>
                      </div>
                      <span className="text-lg font-mono-num font-bold text-[#E04455]">
                        ×{inv.quantity}
                      </span>
                    </div>
                  );
                })}
            </div>
          )}
        </div>
      )}

      {/* 5. FINANCIAL SUMMARY */}
      {subTab === 'financials' && (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          <div className="bg-[#141821] border border-white/8 rounded-2xl p-5">
            <div className="flex items-center justify-between text-xs text-[#9299A6]">
              <span>{language === 'ar' ? 'إجمالي الدخل التراكمي' : 'Total Lifetime Earned'}</span>
              <TrendingUp className="w-4 h-4 text-emerald-400" />
            </div>
            <p className="text-xl font-bold font-mono-num text-[#F4F5F7] mt-2">
              {'$'}{(wallet?.totalEarned ?? 0).toLocaleString()}
            </p>
          </div>

          <div className="bg-[#141821] border border-white/8 rounded-2xl p-5">
            <div className="flex items-center justify-between text-xs text-[#9299A6]">
              <span>{language === 'ar' ? 'إجمالي المصروفات' : 'Total Lifetime Spent'}</span>
              <Coins className="w-4 h-4 text-[#E04455]" />
            </div>
            <p className="text-xl font-bold font-mono-num text-[#F4F5F7] mt-2">
              {'$'}{(wallet?.totalSpent ?? 0).toLocaleString()}
            </p>
          </div>

          <div className="bg-[#141821] border border-white/8 rounded-2xl p-5">
            <div className="flex items-center justify-between text-xs text-[#9299A6]">
              <span>{language === 'ar' ? 'صافي دخل الشركات / ساعة' : 'Companies Net / hr'}</span>
              <Building className="w-4 h-4 text-[#9299A6]" />
            </div>
            <p className="text-xl font-bold font-mono-num text-emerald-400 mt-2">
              +{'$'}{totalCompanyNetHr.toLocaleString()}
            </p>
          </div>


        </div>
      )}
    </div>
  );
}
