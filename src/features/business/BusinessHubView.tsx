import {
  ArrowLeft,
  Building,
  Clock,
  Coins,
  Gavel,
  Package,
  Plus,
  TrendingUp,
  Trash2,
} from 'lucide-react';
import { useEffect, useState } from 'react';
import { useToast } from '../../components/ui/ToastProvider';
import { FactoriesPanel } from './FactoriesPanel';
import {
  COMPANY_SECTORS,
  ITEM_MAP,
} from '../../data/catalog';
import { ResourceIcon } from '../../components/ui/ResourceIcon';
import { useTranslations } from '../../i18n/translations';
import {
  calculateAccruedPayout,
  calculateCompanyHourlyNet,
  COMPANY_MAX_LEVEL,
  COMPANY_VAULT_MAX_LEVEL,
  COMPANY_VAULT_UPGRADES,
  calculateCompanyVaultBalance,
  getCompanyVaultCapacity,
  getCompanyVaultLevel,
} from '../../lib/economy';
import {
  collectCompanyRevenue,
  deleteCompany,
  fetchCompanyAuctions,
  listCompanyForAuction,
  listFactoryForAuction,
  placeCompanyAuctionBid,
  placeFactoryAuctionBid,
  timestampToMs,
  completeCompanyUpgrade,
  completeCompanyVaultUpgrade,
  foundCompany,
  upgradeCompany,
  upgradeCompanyVault,
} from '../../services/gameService';
import type {
  BusinessSubTab,
  Company,
  Factory,
  CompanyAuction,
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
  factories: Factory[];
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
  factories,
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
  const [companyView, setCompanyView] = useState<'overview' | 'found' | 'detail'>('overview');
  const [selectedCompanyId, setSelectedCompanyId] = useState('');
  const [deletedCompanyIds, setDeletedCompanyIds] = useState<string[]>([]);
  const [auctions, setAuctions] = useState<CompanyAuction[]>([]);
  const [startingPrices, setStartingPrices] = useState<Record<string, string>>({});
  const [bidDrafts, setBidDrafts] = useState<Record<string, string>>({});


  // Found Company form
  const [newCompName, setNewCompName] = useState('');
  const [newCompSector, setNewCompSector] = useState<CompanySector>('trade');

  useEffect(() => {
    const timer = setInterval(() => setNowMs(Date.now()), 1000);
    return () => clearInterval(timer);
  }, []);

  useEffect(() => {
    for (const company of companies) {
      const companyEndsAt = company.levelUpgradeEndsAt ? timestampToMs(company.levelUpgradeEndsAt) : 0;
      if (companyEndsAt > 0 && companyEndsAt <= nowMs && busyKey !== `complete_company_${company.id}`) {
        setBusyKey(`complete_company_${company.id}`);
        void completeCompanyUpgrade(profile.uid, company.id).then(() => showToast(language === 'ar' ? 'اكتمل تطوير الشركة!' : 'Company upgrade completed!', 'success')).catch(() => undefined).finally(() => setBusyKey((current) => current === `complete_company_${company.id}` ? null : current));
      }
      const vaultEndsAt = company.vaultUpgradeEndsAt ? timestampToMs(company.vaultUpgradeEndsAt) : 0;
      if (vaultEndsAt > 0 && vaultEndsAt <= nowMs && busyKey !== `complete_vault_${company.id}`) {
        setBusyKey(`complete_vault_${company.id}`);
        void completeCompanyVaultUpgrade(profile.uid, company.id).then(() => showToast(language === 'ar' ? 'اكتمل تطوير الخزينة!' : 'Vault upgrade completed!', 'success')).catch(() => undefined).finally(() => setBusyKey((current) => current === `complete_vault_${company.id}` ? null : current));
      }
    }
  }, [companies, nowMs, busyKey, profile.uid, language, showToast]);

  useEffect(() => {
    let active = true;
    const refresh = async () => { try { const rows = await fetchCompanyAuctions(); if (active) setAuctions(rows); } catch { /* optional auction refresh */ } };
    void refresh();
    const timer = window.setInterval(() => { void refresh(); }, 15000);
    return () => { active = false; window.clearInterval(timer); };
  }, []);
  const visibleCompanies = companies.filter((company) => !deletedCompanyIds.includes(company.id));
  const activeAuctions = auctions.filter((auction) => auction.status === 'active');
  const companyBidReservations = activeAuctions.filter((auction) => auction.assetType !== 'factory' && auction.highestBidderUid === profile.uid).length;
  const factoryBidReservations = activeAuctions.filter((auction) => auction.assetType === 'factory' && auction.highestBidderUid === profile.uid).length;
  const activeBidReservations = companyBidReservations + factoryBidReservations;
  const occupiedCompanySlots = visibleCompanies.length + companyBidReservations;
  const hasCompanySlot = occupiedCompanySlots < 3;
  const hasFactorySlot = factories.length + factoryBidReservations < 3;
  const canFoundCompany = hasCompanySlot && activeBidReservations === 0;
  const refreshAuctions = async () => setAuctions(await fetchCompanyAuctions());
  const formatAuctionRemaining = (endsAt: number) => {
    const remaining = Math.max(0, endsAt - nowMs);
    const hours = Math.floor(remaining / 3600000);
    const minutes = Math.floor((remaining % 3600000) / 60000);
    const seconds = Math.floor((remaining % 60000) / 1000);
    return hours > 0 ? hours + 'س ' + minutes + 'د' : minutes > 0 ? minutes + 'د ' + seconds + 'ث' : seconds + 'ث';
  };
  async function handleListCompany(companyId: string) {
    setBusyKey('auction_list_' + companyId);
    try {
      await listCompanyForAuction(companyId, Number(startingPrices[companyId] || '10000'));
      await refreshAuctions();
      showToast(language === 'ar' ? 'تم إدراج الشركة في المزاد لمدة 24 ساعة.' : 'Company listed in the 24-hour auction.', 'success');
    } catch (error) {
      const code = error instanceof Error ? error.message : '';
      const messages: Record<string, string> = {
        COMPANY_LEVEL_TOO_LOW: language === 'ar' ? 'يجب أن يكون مستوى الشركة 50 أو أعلى.' : 'Company level must be 50 or higher.',
        COMPANY_ALREADY_LISTED: language === 'ar' ? 'الشركة مدرجة بالفعل في مزاد.' : 'This company is already listed.',
        COMPANY_UPGRADE_IN_PROGRESS: language === 'ar' ? 'انتظر انتهاء تطوير الشركة قبل إدراجها.' : 'Wait for the company upgrade to finish before listing.',
        INVALID_STARTING_PRICE: language === 'ar' ? 'أدخل سعر بداية صحيحاً أكبر من صفر.' : 'Enter a valid starting price above zero.',
      };
      showToast(messages[code] || (language === 'ar' ? 'تعذر إدراج الشركة في المزاد.' : 'Could not list the company.'), 'error');
    } finally { setBusyKey(null); }
  }
  async function handleListFactory(factoryId: string) {
    setBusyKey('auction_list_' + factoryId);
    try {
      await listFactoryForAuction(factoryId, Number(startingPrices[factoryId] || '10000'));
      await refreshAuctions();
      showToast(language === 'ar' ? 'تم إدراج المصنع في مزاد الأعمال لمدة 24 ساعة.' : 'Factory listed in the 24-hour business auction.', 'success');
    } catch (error) {
      const code = error instanceof Error ? error.message : '';
      const messages: Record<string, string> = {
        FACTORY_LEVEL_TOO_LOW: language === 'ar' ? 'يجب أن يكون مستوى المصنع 50 أو أعلى.' : 'Factory level must be 50 or higher.',
        FACTORY_ALREADY_LISTED: language === 'ar' ? 'المصنع مدرج بالفعل في المزاد.' : 'This factory is already listed.',
        FACTORY_UPGRADE_IN_PROGRESS: language === 'ar' ? 'انتظر انتهاء تطوير المصنع قبل إدراجه.' : 'Wait for the factory upgrade to finish before listing.',
        INVALID_STARTING_PRICE: language === 'ar' ? 'أدخل سعر بداية صحيحاً.' : 'Enter a valid starting price.',
      };
      showToast(messages[code] || (language === 'ar' ? 'تعذر إدراج المصنع.' : 'Could not list the factory.'), 'error');
    } finally { setBusyKey(null); }
  }
  async function handlePlaceBid(auction: CompanyAuction) {
    const raw = bidDrafts[auction.id] || String(auction.highestBidderUid ? auction.currentPrice + 1 : auction.startingPrice);
    setBusyKey('auction_bid_' + auction.id);
    try {
      if (auction.assetType === 'factory') await placeFactoryAuctionBid(auction.id, Number(raw));
      else await placeCompanyAuctionBid(auction.id, Number(raw));
      await refreshAuctions();
      setBidDrafts((previous) => ({ ...previous, [auction.id]: '' }));
      showToast(language === 'ar' ? 'تم حجز مبلغ عرضك في الضمان بنجاح.' : 'Your bid was placed and secured in escrow.', 'success');
    } catch (error) {
      const code = error instanceof Error ? error.message : '';
      const messages: Record<string, string> = {
        FACTORY_CAPACITY_REACHED: language === 'ar' ? 'وصلت إلى الحد الأقصى لامتلاك 3 مصانع.' : 'You have reached the three-factory limit.',
        CANNOT_BID_OWN_FACTORY: language === 'ar' ? 'لا يمكنك المزايدة على مصنعك.' : 'You cannot bid on your own factory.',
        BID_TOO_LOW: language === 'ar' ? 'العرض أقل من الحد المطلوب. ارفع قيمة المزايدة.' : 'Bid is below the minimum. Increase your offer.',
        INSUFFICIENT_FUNDS: language === 'ar' ? 'رصيدك المتاح لا يكفي لهذا العرض.' : 'Your available balance is too low for this bid.',
        COMPANY_CAPACITY_REACHED: language === 'ar' ? 'وصلت إلى الحد الأقصى (3 شركات) بين شركاتك وعروضك الأعلى حالياً.' : 'You have reached the 3-company limit across owned companies and leading bids.',
        CANNOT_BID_OWN_COMPANY: language === 'ar' ? 'لا يمكنك المزايدة على شركتك.' : 'You cannot bid on your own company.',
        AUCTION_NOT_ACTIVE: language === 'ar' ? 'انتهى هذا المزاد أو لم يعد متاحاً.' : 'This auction has ended or is no longer active.',
        AUCTION_ENDED: language === 'ar' ? 'انتهى المزاد.' : 'The auction has ended.',
      };
      showToast(messages[code] || (language === 'ar' ? 'تعذرت المزايدة. حدّث القائمة وحاول مجدداً.' : 'Bid failed. Refresh the list and try again.'), 'error');
      await refreshAuctions().catch(() => undefined);
    } finally { setBusyKey(null); }
  }
  async function handleDeleteCompany(company: Company) {
    const confirmed = window.confirm(language === 'ar'
      ? 'هل أنت متأكد من حذف شركة "' + company.name + '" نهائياً؟ لا يمكن التراجع عن هذا الإجراء.'
      : 'Delete "' + company.name + '" permanently? This cannot be undone.');
    if (!confirmed) return;
    setBusyKey('delete_company_' + company.id);
    try {
      await deleteCompany(company.id);
      setDeletedCompanyIds((previous) => [...previous, company.id]);
      setCompanyView('overview'); setSelectedCompanyId('');
      showToast(language === 'ar' ? 'تم حذف الشركة.' : 'Company deleted.', 'success');
    } catch (error) {
      const code = error instanceof Error ? error.message : '';
      showToast(code === 'COMPANY_IN_AUCTION'
        ? (language === 'ar' ? 'لا يمكن حذف شركة أثناء وجودها في المزاد.' : 'A company cannot be deleted while it is in an auction.')
        : (language === 'ar' ? 'تعذر حذف الشركة.' : 'Could not delete the company.'), 'error');
    } finally { setBusyKey(null); }
  }

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
      setCompanyView('overview');
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
          : code === 'COMPANY_AUCTION_PENDING'
          ? language === 'ar'
            ? 'لا يمكنك تأسيس شركة جديدة ما دام عرضك هو الأعلى في مزاد نشط.'
            : 'You cannot found a company while you are leading an active auction bid.'
          : code === 'COMPANY_CAPACITY_REACHED'
          ? language === 'ar'
            ? 'لا يمكنك تأسيس شركة إضافية؛ الحد الأقصى 3 شركات.'
            : 'You cannot found another company; the limit is three companies.'
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
      showToast(language === 'ar' ? 'بدأ تطوير الشركة، وسيكتمل تلقائياً عند انتهاء المؤقت.' : 'Company upgrade started; it will complete when the timer ends.', 'success');
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
      showToast(language === 'ar' ? 'بدأ تطوير الخزينة مع الاحتفاظ بالأرباح المتراكمة.' : 'Vault upgrade started; accrued profits are preserved.', 'success');
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


  const subTabs: { id: BusinessSubTab; label: string }[] = [
    { id: 'companies', label: t.subCompanies },
    { id: 'auction', label: language === 'ar' ? 'مزاد الأعمال' : 'Business Auction' },
    { id: 'factories', label: language === 'ar' ? 'المصانع' : 'Factories' },
    { id: 'inventory', label: t.subInventory },
  ];

  return (
    <div className="space-y-5">
      {/* Segmented Sub-Navigation */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-1">
        {subTabs.map((tab) => (
          <button
            key={tab.id}
            type="button"
            onClick={() => { setSubTab(tab.id); if (tab.id === 'companies') setCompanyView('overview'); }}
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
        <div className="space-y-4">
          {companyView === 'overview' && (
            <div className="space-y-4">
              <button type="button" disabled={!canFoundCompany} onClick={() => setCompanyView('found')} className="w-full min-h-[64px] rounded-2xl border border-dashed border-[#E04455]/50 bg-[#141821] px-5 py-4 flex items-center justify-between text-start disabled:opacity-40">
                <span><span className="block text-sm font-bold text-[#F4F5F7]">{language === 'ar' ? 'تأسيس' : 'Found'}</span><span className="block text-xs text-[#9299A6] mt-1">{activeBidReservations > 0 ? (language === 'ar' ? 'لا يمكنك تأسيس شركة ما دام لديك عرض شراء هو الأعلى في المزاد.' : 'You cannot found a company while you are leading an active auction bid.') : canFoundCompany ? (language === 'ar' ? 'ابدأ مشروعاً جديداً' : 'Start a new enterprise') : (language === 'ar' ? 'اكتمل الحد الأقصى لثلاث شركات.' : 'You have reached the three-company limit.')}</span></span><Plus className="w-5 h-5 text-[#E04455]" />
              </button>
              <section className="bg-[#141821] border border-white/8 rounded-2xl p-4 space-y-3">
                <div className="flex items-center justify-between"><h2 className="text-sm font-bold text-[#F4F5F7]">{language === 'ar' ? 'شركاتي' : 'My companies'}</h2><span className="text-xs text-[#9299A6] font-mono-num">{occupiedCompanySlots}/3</span></div>
                {visibleCompanies.length === 0 ? <p className="py-6 text-center text-sm text-[#9299A6]">{language === 'ar' ? 'لا تمتلك شركات حالياً.' : 'You do not own any companies yet.'}</p> : visibleCompanies.map((company) => (
                  <button key={company.id} type="button" onClick={() => { setSelectedCompanyId(company.id); setCompanyView('detail'); }} className="w-full rounded-xl bg-[#0B0D12] border border-white/8 px-4 py-3 flex items-center justify-between gap-3 text-start hover:border-[#E04455]/50 transition-colors">
                    <span className="min-w-0"><span className="block truncate text-sm font-semibold text-[#F4F5F7]">{company.name}</span><span className="block mt-1 text-xs text-[#9299A6]">{language === 'ar' ? 'المستوى' : 'Level'} <span className="font-mono-num text-[#F4F5F7]">{company.level}</span></span></span><ArrowLeft className="w-4 h-4 text-[#9299A6] shrink-0" />
                  </button>
                ))}
              </section>
            </div>
          )}
          {companyView === 'found' && (
            <div className="space-y-3">
              <button type="button" onClick={() => setCompanyView('overview')} className="inline-flex items-center gap-2 min-h-[40px] px-3 rounded-xl bg-[#1B2230] text-[#F4F5F7] text-xs font-semibold"><ArrowLeft className="w-4 h-4" />{language === 'ar' ? 'العودة إلى الأعمال' : 'Back to Business'}</button>
                        <form
            onSubmit={handleFoundCompany}
            className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-4 max-w-2xl"
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


            </div>
          )}
          {companyView === 'detail' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between gap-2">
                <button type="button" onClick={() => setCompanyView('overview')} className="inline-flex items-center gap-2 min-h-[40px] px-3 rounded-xl bg-[#1B2230] text-[#F4F5F7] text-xs font-semibold"><ArrowLeft className="w-4 h-4" />{language === 'ar' ? 'شركاتي' : 'My companies'}</button>
                {visibleCompanies.find((c) => c.id === selectedCompanyId) && <button type="button" disabled={busyKey === 'delete_company_' + selectedCompanyId} onClick={() => { const selected = visibleCompanies.find((c) => c.id === selectedCompanyId); if (selected) void handleDeleteCompany(selected); }} className="inline-flex items-center gap-2 min-h-[40px] px-3 rounded-xl border border-rose-500/30 bg-rose-500/10 text-rose-300 text-xs font-semibold disabled:opacity-50"><Trash2 className="w-4 h-4" />{language === 'ar' ? 'حذف الشركة' : 'Delete company'}</button>}
              </div>
              <div className="space-y-4">
                {visibleCompanies.filter((c) => c.id === selectedCompanyId).length === 0 ? <p className="text-sm text-[#9299A6]">{language === 'ar' ? 'الشركة غير متاحة.' : 'Company not found.'}</p> : (              visibleCompanies.filter((c) => c.id === selectedCompanyId).map((c) => {
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
                const companyUpgradeEndsAt = c.levelUpgradeEndsAt ? timestampToMs(c.levelUpgradeEndsAt) : 0;
                const vaultUpgradeEndsAt = c.vaultUpgradeEndsAt ? timestampToMs(c.vaultUpgradeEndsAt) : 0;
                const companyUpgradeRemaining = companyUpgradeEndsAt ? Math.max(0, companyUpgradeEndsAt - nowMs) : 0;
                const vaultUpgradeRemaining = vaultUpgradeEndsAt ? Math.max(0, vaultUpgradeEndsAt - nowMs) : 0;
                const companyUpgradePending = Boolean(c.levelUpgradeStartedAt || c.levelUpgradeEndsAt || c.levelUpgradeTargetLevel);
                const vaultUpgradePending = Boolean(c.vaultUpgradeStartedAt || c.vaultUpgradeEndsAt || c.vaultUpgradeTargetLevel);
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
                            disabled={vaultUpgradePending || (wallet?.balance ?? 0) < vaultUpgrade.cost || !vaultMaterialsAvailable || busyKey === `vault_${c.id}`}
                            onClick={() => handleUpgradeCompanyVault(c.id)}
                            className="w-full min-h-[40px] rounded-xl bg-cyan-700/80 hover:bg-cyan-600 text-white text-xs font-semibold disabled:opacity-40 transition-colors"
                          >
                            {vaultUpgradePending ? (vaultUpgradeRemaining > 0 ? (language === 'ar' ? `جارٍ التطوير: ${formatRemaining(vaultUpgradeRemaining)}` : `Upgrading: ${formatRemaining(vaultUpgradeRemaining)}`) : (language === 'ar' ? 'جارٍ إكمال التطوير...' : 'Finishing upgrade...')) : (language === 'ar' ? 'بدء تطوير الخزينة' : 'Start Vault Upgrade')}
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
                        disabled={isMaxLevel || companyUpgradePending || busyKey === `upg_${c.id}` || (wallet?.balance ?? 0) < upgradeCost}
                        onClick={() => handleUpgradeCompany(c.id)}
                        className="min-h-[42px] px-3.5 rounded-xl bg-[#1B2230] hover:bg-[#232C3E] text-[#F4F5F7] text-xs font-semibold whitespace-nowrap disabled:opacity-50 transition-colors"
                      >
                        {isMaxLevel ? t.maxLevelReached : companyUpgradePending ? (companyUpgradeRemaining > 0 ? (language === 'ar' ? `جارٍ التطوير: ${formatRemaining(companyUpgradeRemaining)}` : `Upgrading: ${formatRemaining(companyUpgradeRemaining)}`) : (language === 'ar' ? 'جارٍ إكمال التطوير...' : 'Finishing upgrade...')) : (language === 'ar' ? 'بدء تطوير الشركة' : 'Start Company Upgrade')}
                      </button>
                    </div>
                  </div>
                );
              }))}
              </div>
                          {companyLogs.filter((log) => log.companyId === selectedCompanyId).length > 0 && (
              <div className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-3">
                <h3 className="text-sm font-semibold text-[#F4F5F7]">
                  {language === 'ar' ? 'سجل عمليات الشركة' : 'Company Operations Log'}
                </h3>
                <div className="space-y-2">
                  {companyLogs.filter((log) => log.companyId === selectedCompanyId).slice(0, 20).map((log) => (
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
          )}
        </div>
      )}

      {subTab === 'auction' && (
        <div className="space-y-4">
          <section className="rounded-2xl border border-amber-400/20 bg-[#141821] p-4 space-y-2">
            <div className="flex items-center gap-2 text-sm font-bold text-amber-200"><Gavel className="w-4 h-4" />{language === 'ar' ? 'مزاد الأعمال' : 'Business Auction'}</div>
            <p className="text-xs text-[#AAB1BD]">{language === 'ar' ? 'الشركات والمصانع من المستوى 50 فأعلى. مدة المزاد 24 ساعة، ويُحجز مبلغ العرض في الضمان حتى الفوز أو تجاوزه.' : 'Level 50+ companies and factories. Auctions last 24 hours; bids are held in escrow until settlement or being outbid.'}</p>
            <p className="text-xs text-[#9299A6]">{language === 'ar' ? 'المساحات المستخدمة: ' + occupiedCompanySlots + '/3 (الشركات المملوكة والعروض الأعلى)' : 'Company slots used: ' + occupiedCompanySlots + '/3 (owned companies and leading bids)'}</p>
          </section>
          <section className="rounded-2xl border border-white/8 bg-[#141821] p-4 space-y-3">
            <h3 className="text-sm font-bold text-[#F4F5F7]">{language === 'ar' ? 'إدراج شركة في المزاد' : 'List a company'}</h3>
            {visibleCompanies.filter((company) => company.level >= 50 && !company.auctionId).length === 0 ? <p className="text-xs text-[#9299A6]">{language === 'ar' ? 'لا توجد شركة مؤهلة حالياً. تحتاج الشركة إلى المستوى 50 على الأقل.' : 'No eligible company yet. A company must be level 50 or higher.'}</p> : visibleCompanies.filter((company) => company.level >= 50 && !company.auctionId).map((company) => (
              <div key={company.id} className="rounded-xl bg-[#0B0D12] border border-white/8 p-3 space-y-2">
                <div className="flex items-center justify-between gap-2"><span className="text-sm font-semibold text-[#F4F5F7]">{company.name}</span><span className="text-xs text-amber-200">Lv.{company.level}</span></div>
                <div className="flex gap-2"><input type="number" min="1" step="1" value={startingPrices[company.id] ?? '10000'} onChange={(e) => setStartingPrices((previous) => ({ ...previous, [company.id]: e.target.value }))} placeholder={language === 'ar' ? 'سعر البداية' : 'Starting price'} className="min-w-0 flex-1 min-h-[42px] rounded-xl bg-[#141821] border border-white/10 px-3 text-sm text-[#F4F5F7]" />
                  <button type="button" disabled={busyKey === 'auction_list_' + company.id} onClick={() => void handleListCompany(company.id)} className="min-h-[42px] px-4 rounded-xl bg-[#B91C32] text-white text-xs font-semibold disabled:opacity-50">{language === 'ar' ? 'إدراج' : 'List'}</button></div>
              </div>
            ))}
          </section>
          <section className="rounded-2xl border border-white/8 bg-[#141821] p-4 space-y-3">
            <h3 className="text-sm font-bold text-[#F4F5F7]">{language === 'ar' ? 'إدراج مصنع في المزاد' : 'List a factory'}</h3>
            {factories.filter((factory) => factory.level >= 50 && !factory.auctionId).length === 0 ? <p className="text-xs text-[#9299A6]">{language === 'ar' ? 'لا يوجد مصنع مؤهل حالياً. يحتاج المصنع إلى المستوى 50 على الأقل.' : 'No eligible factory. Factories must be level 50 or higher.'}</p> : factories.filter((factory) => factory.level >= 50 && !factory.auctionId).map((factory) => (
              <div key={factory.id} className="rounded-xl bg-[#0B0D12] border border-white/8 p-3 space-y-2">
                <div className="flex items-center justify-between gap-2"><span className="text-sm font-semibold text-[#F4F5F7]">{factory.name}</span><span className="text-xs text-amber-200">Lv.{factory.level}</span></div>
                <div className="flex gap-2"><input type="number" min="1" step="1" value={startingPrices[factory.id] ?? '10000'} onChange={(e) => setStartingPrices((previous) => ({ ...previous, [factory.id]: e.target.value }))} placeholder={language === 'ar' ? 'سعر البداية' : 'Starting price'} className="min-w-0 flex-1 min-h-[42px] rounded-xl bg-[#141821] border border-white/10 px-3 text-sm text-[#F4F5F7]" />
                  <button type="button" disabled={busyKey === 'auction_list_' + factory.id} onClick={() => void handleListFactory(factory.id)} className="min-h-[42px] px-4 rounded-xl bg-[#B91C32] text-white text-xs font-semibold disabled:opacity-50">{language === 'ar' ? 'إدراج' : 'List'}</button></div>
              </div>
            ))}
          </section>
          <section className="space-y-3">
            <h3 className="text-sm font-bold text-[#F4F5F7]">{language === 'ar' ? 'المزادات المتاحة' : 'Available auctions'}</h3>
            {activeAuctions.length === 0 ? <div className="rounded-2xl border border-white/8 bg-[#141821] p-8 text-center text-sm text-[#9299A6]">{language === 'ar' ? 'لا توجد مزادات نشطة حالياً.' : 'There are no active auctions right now.'}</div> : activeAuctions.map((auction) => {
              const isLeading = auction.highestBidderUid === profile.uid;
              const isSeller = auction.sellerUid === profile.uid;
              const minBid = auction.highestBidderUid ? auction.currentPrice + 1 : auction.startingPrice;
              const canBid = !isSeller && (isLeading || (auction.assetType === 'factory' ? hasFactorySlot : hasCompanySlot));
              return (
                <article key={auction.id} className="rounded-2xl border border-white/8 bg-[#141821] p-4 space-y-3">
                  <div className="flex items-start justify-between gap-3"><div><h4 className="text-sm font-bold text-[#F4F5F7]">{auction.companyName}</h4><p className="mt-1 text-xs text-[#9299A6]">{auction.assetType === 'factory' ? (language === 'ar' ? 'مصنع' : 'Factory') : (language === 'ar' ? 'شركة' : 'Company')} · {language === 'ar' ? 'البائع' : 'Seller'}: {auction.sellerName} · Lv.{auction.companyLevel}</p></div>{isLeading && <span className="rounded-lg bg-emerald-500/10 px-2 py-1 text-[10px] text-emerald-300">{language === 'ar' ? 'أنت الأعلى' : 'You lead'}</span>}</div>
                  <div className="grid grid-cols-2 gap-2 rounded-xl bg-[#0B0D12] p-3">
                    <div><p className="text-[10px] text-[#9299A6]">{language === 'ar' ? 'سعر البداية' : 'Starting price'}</p><p className="text-sm font-mono-num font-semibold text-[#F4F5F7]">{'$'}{auction.startingPrice.toLocaleString()}</p></div>
                    <div><p className="text-[10px] text-[#9299A6]">{language === 'ar' ? 'أعلى عرض' : 'Highest bid'}</p><p className="text-sm font-mono-num font-semibold text-amber-200">{'$'}{auction.currentPrice.toLocaleString()}</p></div>
                  </div>
                  <div className="flex items-center gap-2 text-xs text-[#9299A6]"><Clock className="w-3.5 h-3.5" />{language === 'ar' ? 'ينتهي خلال' : 'Ends in'} {formatAuctionRemaining(auction.endsAt)}</div>
                  {auction.highestBidderName && <p className="text-[11px] text-[#9299A6]">{language === 'ar' ? 'صاحب أعلى عرض:' : 'Leading bidder:'} {auction.highestBidderName}</p>}
                  {!isSeller && <div className="space-y-2">
                    <input type="number" min={minBid} step="1" value={bidDrafts[auction.id] ?? String(minBid)} onChange={(e) => setBidDrafts((previous) => ({ ...previous, [auction.id]: e.target.value }))} disabled={!canBid || busyKey === 'auction_bid_' + auction.id} className="w-full min-h-[42px] rounded-xl bg-[#0B0D12] border border-white/10 px-3 text-sm text-[#F4F5F7] disabled:opacity-50" />
                    <button type="button" disabled={!canBid || busyKey === 'auction_bid_' + auction.id} onClick={() => void handlePlaceBid(auction)} className="w-full min-h-[42px] rounded-xl bg-[#B91C32] text-white text-xs font-semibold disabled:opacity-40">{busyKey === 'auction_bid_' + auction.id ? '...' : isLeading ? (language === 'ar' ? 'ارفع عرضك' : 'Raise your bid') : (language === 'ar' ? 'تقديم عرض شراء' : 'Place bid')}</button>
                    {!canBid && <p className="text-[11px] text-rose-300">{language === 'ar' ? 'لا توجد مساحة متاحة ضمن حد 3 شركات.' : 'No free company slot under the three-company limit.'}</p>}
                  </div>}
                  <p className="text-[10px] text-[#77808F]">{language === 'ar' ? 'يُحجز كامل عرضك في الضمان. عند تجاوزك أو إلغاء البيع يُعاد المبلغ تلقائياً.' : 'Your full bid is held in escrow and automatically refunded if outbid or the sale is cancelled.'}</p>
                </article>
              );
            })}
          </section>
        </div>
      )}

      {subTab === 'factories' && (
        <FactoriesPanel
          factories={factories}
          inventory={inventory}
          profile={profile}
          wallet={wallet}
          language={language}
        />
      )}

      {/* 4. INVENTORY */}
      {subTab === 'inventory' && (
        <div className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-semibold text-[#F4F5F7]">{t.subInventory}</h2>
            <Package className="w-4 h-4 text-[#63A5FF]" />
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
                className="min-h-[42px] px-5 rounded-xl bg-[#397BFF] hover:bg-[#2F6DE0] text-white text-xs font-semibold"
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
                      <div className="flex min-w-0 items-center gap-3">
                        <ResourceIcon itemId={inv.itemId} size="lg" />
                        <div className="min-w-0">
                          <p className="truncate text-sm font-semibold text-[#F4F5F7]">
                          {language === 'ar' ? item.nameAr : item.nameEn}
                        </p>
                          <p className="text-xs text-[#9299A6] mt-0.5">
                            ~{'$'}{item.basePrice}
                          </p>
                        </div>
                      </div>
                      <span className="shrink-0 text-lg font-mono-num font-bold text-[#63A5FF]">
                        ×{inv.quantity}
                      </span>
                    </div>
                  );
                })}
            </div>
          )}
        </div>
      )}

      </div>
  );
}
