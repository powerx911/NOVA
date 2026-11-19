import {
  FileCheck2,
  Search,
  Send,
  ShoppingBag,
  Tag,
} from 'lucide-react';
import { useState } from 'react';
import { ConfirmDialog } from '../../components/ui/ConfirmDialog';
import { ManufacturingPanel } from './ManufacturingPanel';
import { useToast } from '../../components/ui/ToastProvider';
import { BRAND_ASSETS, CATALOG_ITEMS, ITEM_MAP, TRADE_CONTRACTS } from '../../data/catalog';
import { ResourceIcon } from '../../components/ui/ResourceIcon';
import { useTranslations } from '../../i18n/translations';
import {
  calculateContractPayout,
  calculateDynamicItemPrice,
  calculateMarketItemAnalytics,
  calculateMarketTaxRate,
  LISTING_MAX_PRICE,
  LISTING_MAX_QTY,
  sanitizePositiveInt,
} from '../../lib/economy';
import {
  buyMarketListing,
  cancelMarketListing,
  createMarketListing,
  fulfillTradeContract,
  getUtcDateKey,
  transferCredits,
} from '../../services/gameService';
import type {
  InventoryItem,
  ItemTier,
  Language,
  MarketListing,
  MarketSubTab,
  PlayerProfile,
  Wallet,
  WorldEvent,
} from '../../types/game';

interface MarketHubViewProps {
  profile: PlayerProfile;
  wallet: Wallet | null;
  inventory: InventoryItem[];
  marketListings: MarketListing[];
  worldEvents: WorldEvent[];
  claimedContractsToday: Set<string>;
  language: Language;
}

export function MarketHubView({
  profile,
  wallet,
  inventory,
  marketListings,
  worldEvents,
  claimedContractsToday,
  language,
}: MarketHubViewProps) {
  const t = useTranslations(language);
  const { showToast } = useToast();

  const [subTab, setSubTab] = useState<MarketSubTab>('exchange');
  const [searchQuery, setSearchQuery] = useState('');
  const [tierFilter, setTierFilter] = useState<'all' | ItemTier>('all');
  const [buyQuantities, setBuyQuantities] = useState<Record<string, number>>({});
  const [busyKey, setBusyKey] = useState<string | null>(null);

  // Create Sell Listing form
  const ownedStacks = inventory.filter((i) => i.quantity > 0);
  const initialSellId = ownedStacks[0]?.itemId || 'silicon_ore';
  const [sellItemId, setSellItemId] = useState(initialSellId);
  const [sellQty, setSellQty] = useState(1);
  const [sellPrice, setSellPrice] = useState(ITEM_MAP[initialSellId]?.basePrice || 40);

  // Bank Transfer form
  const [recipientName, setRecipientName] = useState('');
  const [transferAmount, setTransferAmount] = useState(100);
  const [transferNote, setTransferNote] = useState('');
  const [confirmTransferOpen, setConfirmTransferOpen] = useState(false);

  const taxRate = calculateMarketTaxRate(profile.skills.trade || 0, worldEvents);
  const invMap = new Map<string, number>();
  inventory.forEach((i) => invMap.set(i.itemId, i.quantity));
  const todayKey = getUtcDateKey();

  // Compute live supply per item across active listings
  const supplyByItem = new Map<string, number>();
  for (const l of marketListings) {
    if (l.status === 'active' && l.remainingQty > 0) {
      supplyByItem.set(l.itemId, (supplyByItem.get(l.itemId) || 0) + l.remainingQty);
    }
  }

  const pulseItems = CATALOG_ITEMS.slice(0, 4).map((item) =>
    calculateMarketItemAnalytics(item.id, marketListings, worldEvents)
  );

  const filteredListings = marketListings.filter((l) => {
    const item = ITEM_MAP[l.itemId];
    if (!item || l.status !== 'active' || l.remainingQty <= 0) return false;
    if (tierFilter !== 'all' && item.tier !== tierFilter) return false;
    if (searchQuery.trim()) {
      const q = searchQuery.trim().toLowerCase();
      return (
        item.nameAr.toLowerCase().includes(q) ||
        item.nameEn.toLowerCase().includes(q) ||
        l.sellerName.toLowerCase().includes(q)
      );
    }
    return true;
  });

  async function handleBuy(listing: MarketListing) {
    const qty = Math.min(
      listing.remainingQty,
      sanitizePositiveInt(buyQuantities[listing.id], 1, listing.remainingQty)
    );
    setBusyKey(`buy_${listing.id}`);
    try {
      await buyMarketListing(profile.uid, listing.id, qty, taxRate);
      showToast(
        language === 'ar'
          ? `تم شراء ${qty} وحدة بنجاح.`
          : `Purchased ${qty} units successfully.`,
        'success'
      );
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      showToast(
        code === 'INSUFFICIENT_FUNDS'
          ? language === 'ar'
            ? 'رصيدك غير كافٍ.'
            : 'Insufficient balance.'
          : code === 'CANNOT_BUY_OWN_LISTING'
          ? language === 'ar'
            ? 'لا يمكنك شراء عرضك الخاص.'
            : 'You cannot purchase your own listing.'
          : code === 'INSUFFICIENT_LISTING_QTY'
          ? language === 'ar'
            ? 'الكمية المتبقية في العرض لم تعد كافية.'
            : 'Requested quantity is no longer available.'
          : language === 'ar'
          ? 'تعذر إتمام الشراء.'
          : 'Purchase failed.',
        'error'
      );
    } finally {
      setBusyKey(null);
    }
  }

  async function handleCreateListing(e: React.FormEvent) {
    e.preventDefault();
    const cleanQty = sanitizePositiveInt(sellQty, 1, LISTING_MAX_QTY);
    const cleanPrice = sanitizePositiveInt(sellPrice, 1, LISTING_MAX_PRICE);
    setBusyKey('sell_create');
    try {
      await createMarketListing(profile.uid, profile.username, sellItemId, cleanQty, cleanPrice);
      showToast(
        language === 'ar' ? 'تم نشر عرض البيع في السوق.' : 'Sell offer published on market.',
        'success'
      );
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      showToast(
        code === 'INVALID_LISTING_PARAMS'
          ? language === 'ar'
            ? 'تأكد من إدخال كمية وسعر صالحين ضمن الحدود المسموحة.'
            : 'Enter a valid quantity and unit price within market limits.'
          : language === 'ar'
          ? 'تأكد من توفر الكمية في مخزونك.'
          : 'Verify you have enough inventory to list.',
        'error'
      );
    } finally {
      setBusyKey(null);
    }
  }

  async function handleCancelListing(listingId: string) {
    setBusyKey(`can_${listingId}`);
    try {
      await cancelMarketListing(profile.uid, listingId);
      showToast(
        language === 'ar' ? 'تم إلغاء العرض وإعادة الكمية للمخزون.' : 'Listing cancelled and stock returned.',
        'info'
      );
    } catch {
      showToast(language === 'ar' ? 'تعذر إلغاء العرض.' : 'Could not cancel listing.', 'error');
    } finally {
      setBusyKey(null);
    }
  }

  async function handleFulfillContract(contractId: string) {
    setBusyKey(`ctr_${contractId}`);
    try {
      const payout = await fulfillTradeContract(profile.uid, contractId);
      showToast(
        language === 'ar'
          ? `تم تنفيذ العقد واستلام +${payout} $.`
          : `Contract fulfilled: +${payout} $.`,
        'success'
      );
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      showToast(
        code === 'MISSING_INPUTS'
          ? language === 'ar'
            ? 'المنتج المطلوب غير متوفر في المخزون.'
            : 'Required product missing from inventory.'
          : code === 'CONTRACT_ALREADY_FULFILLED'
          ? language === 'ar'
            ? 'تم تنفيذ هذا العقد اليوم بالفعل.'
            : 'Contract already fulfilled today.'
          : language === 'ar'
          ? 'تعذر تنفيذ العقد التجاري.'
          : 'Could not fulfill trade contract.',
        'error'
      );
    } finally {
      setBusyKey(null);
    }
  }

  async function executeTransfer() {
    const cleanAmount = sanitizePositiveInt(transferAmount, 0);
    if (cleanAmount <= 0) {
      setConfirmTransferOpen(false);
      showToast(
        language === 'ar' ? 'أدخل مبلغ تحويل صحيح.' : 'Enter a valid transfer amount.',
        'error'
      );
      return;
    }

    setBusyKey('transfer');
    try {
      await transferCredits(profile.uid, recipientName, cleanAmount, transferNote);
      setConfirmTransferOpen(false);
      setRecipientName('');
      setTransferNote('');
      showToast(
        language === 'ar' ? 'تم تنفيذ التحويل المالي بنجاح.' : 'Transfer completed.',
        'success'
      );
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      if (code === 'SELF_OR_MISSING_RECIPIENT' || code === 'INVALID_AMOUNT') {
        setConfirmTransferOpen(false);
      }
      showToast(
        code === 'RECIPIENT_NOT_FOUND'
          ? language === 'ar'
            ? 'اسم المستخدم غير موجود.'
            : 'Recipient username not found.'
          : code === 'SELF_OR_MISSING_RECIPIENT'
          ? language === 'ar'
            ? 'لا يمكنك التحويل لنفسك أو لحساب فارغ.'
            : 'Cannot transfer to your own account.'
          : code === 'INSUFFICIENT_FUNDS'
          ? language === 'ar'
            ? 'الرصيد غير كافٍ.'
            : 'Insufficient funds.'
          : language === 'ar'
          ? 'بيانات التحويل غير صالحة.'
          : 'Invalid transfer details.',
        'error'
      );
    } finally {
      setBusyKey(null);
    }
  }

  const subTabs: { id: MarketSubTab; label: string }[] = [
    { id: 'exchange', label: t.subExchange },
    { id: 'contracts', label: t.subContracts },
    { id: 'bank', label: t.subBank },
    { id: 'manufacturing', label: t.subManufacturing },
  ];

  return (
    <div className="space-y-5">
      {/* Sub-navigation */}
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

      {/* 1. OPEN EXCHANGE */}
      {subTab === 'exchange' && (
        <div className="space-y-5">
          {/* Market Banner Card */}
          <div className="relative overflow-hidden rounded-2xl border border-white/10 bg-[#141821]">
            <img
              src={BRAND_ASSETS.marketBanner}
              alt="NOVA Global Exchange"
              referrerPolicy="no-referrer"
              className="w-full h-36 sm:h-44 object-cover"
            />
            <div className="absolute inset-0 bg-gradient-to-t from-[#0B0D12] via-[#0B0D12]/55 to-transparent flex items-end p-5">
              <div className="w-full flex flex-wrap items-end justify-between gap-3">
                <div>
                  <h1 className="text-lg font-bold text-[#F4F5F7]">
                    {language === 'ar' ? 'سوق NOVA المفتوح' : 'NOVA Open Exchange'}
                  </h1>
                  <p className="text-xs text-[#9299A6] mt-0.5">
                    {t.marketTax}:{' '}
                    <span className="font-mono-num text-[#F4F5F7]">
                      {(taxRate * 100).toFixed(1)}%
                    </span>{' '}
                    ·{' '}
                    <span className="font-mono-num text-[#F4F5F7]">
                      {marketListings.length}
                    </span>{' '}
                    {language === 'ar' ? 'عروض نشطة' : 'active offers'}
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Supply & Demand Pulse Strip */}
          <div className="bg-[#141821] border border-white/8 rounded-2xl p-4 space-y-3">
            <h2 className="text-xs font-semibold text-[#9299A6] uppercase tracking-wider">
              {t.marketPulse}
            </h2>
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
              {pulseItems.map((ana) => {
                const item = ITEM_MAP[ana.itemId];
                if (!item) return null;
                const statusLabel =
                  ana.supplyStatus === 'scarce'
                    ? t.supplyScarce
                    : ana.supplyStatus === 'abundant'
                    ? t.supplyAbundant
                    : t.supplyBalanced;
                const statusColor =
                  ana.supplyStatus === 'scarce'
                    ? 'text-[#E04455]'
                    : ana.supplyStatus === 'abundant'
                    ? 'text-emerald-400'
                    : 'text-[#F4F5F7]';
                return (
                  <div
                    key={ana.itemId}
                    className="p-3 rounded-xl bg-[#0B0D12] border border-white/6 space-y-1"
                  >
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex min-w-0 items-center gap-2">
                        <ResourceIcon itemId={ana.itemId} size="sm" />
                        <span className="text-xs font-semibold text-[#EAF1FF] truncate">
                          {language === 'ar' ? item.nameAr : item.nameEn}
                        </span>
                      </div>
                      <span className={`text-[11px] font-medium ${statusColor}`}>
                        {statusLabel}
                      </span>
                    </div>
                    <div className="flex items-center justify-between text-[11px] text-[#9299A6]">
                      <span>{t.indexPrice}: <span className="font-mono-num text-[#F4F5F7]">{ana.indexPrice}</span></span>
                      <span>
                        {t.lowestAsk}:{' '}
                        <span className="font-mono-num text-[#F4F5F7]">
                          {ana.lowestAsk !== null ? ana.lowestAsk : '—'}
                        </span>
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
            {/* Post Sell Listing Form */}
            <form
              onSubmit={handleCreateListing}
              className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-4 h-fit"
            >
              <div className="flex items-center justify-between">
                <h2 className="text-base font-semibold text-[#F4F5F7]">{t.createListing}</h2>
                <Tag className="w-4 h-4 text-[#E04455]" />
              </div>

              <div className="space-y-1.5">
                <label className="text-xs text-[#9299A6]">
                  {language === 'ar' ? 'العنصر من المخزون' : 'Item from Inventory'}
                </label>
                <select
                  value={sellItemId}
                  onChange={(e) => {
                    const id = e.target.value;
                    setSellItemId(id);
                    const base = ITEM_MAP[id]?.basePrice || 40;
                    setSellPrice(base);
                  }}
                  className="w-full min-h-[44px] px-3 rounded-xl bg-[#0B0D12] border border-white/10 text-sm text-[#F4F5F7] focus:outline-none focus:border-[#E04455]"
                >
                  {CATALOG_ITEMS.map((item) => {
                    const owned = invMap.get(item.id) || 0;
                    return (
                      <option key={item.id} value={item.id}>
                        {language === 'ar' ? item.nameAr : item.nameEn} ({owned})
                      </option>
                    );
                  })}
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1.5">
                  <label className="text-xs text-[#9299A6]">{t.quantity}</label>
                  <input
                    type="number"
                    min={1}
                    max={Math.min(LISTING_MAX_QTY, Math.max(1, invMap.get(sellItemId) || 1))}
                    value={sellQty || ''}
                    onChange={(e) => {
                      const v = e.target.value;
                      setSellQty(v === '' ? 0 : sanitizePositiveInt(v, 1, LISTING_MAX_QTY));
                    }}
                    onBlur={() => setSellQty((v) => sanitizePositiveInt(v, 1, LISTING_MAX_QTY))}
                    className="w-full min-h-[44px] px-3 rounded-xl bg-[#0B0D12] border border-white/10 text-sm font-mono-num text-[#F4F5F7] focus:outline-none focus:border-[#E04455]"
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="text-xs text-[#9299A6]">{t.unitPrice}</label>
                  <input
                    type="number"
                    min={1}
                    max={LISTING_MAX_PRICE}
                    value={sellPrice || ''}
                    onChange={(e) => {
                      const v = e.target.value;
                      setSellPrice(v === '' ? 0 : sanitizePositiveInt(v, 1, LISTING_MAX_PRICE));
                    }}
                    onBlur={() => setSellPrice((v) => sanitizePositiveInt(v, 1, LISTING_MAX_PRICE))}
                    className="w-full min-h-[44px] px-3 rounded-xl bg-[#0B0D12] border border-white/10 text-sm font-mono-num text-[#F4F5F7] focus:outline-none focus:border-[#E04455]"
                  />
                </div>
              </div>

              <button
                type="submit"
                disabled={
                  busyKey === 'sell_create' ||
                  sellQty < 1 ||
                  sellPrice < 1 ||
                  (invMap.get(sellItemId) || 0) < sellQty
                }
                className="w-full min-h-[44px] px-4 rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-sm font-semibold transition-colors disabled:bg-[#1B2230] disabled:text-[#9299A6]"
              >
                {busyKey === 'sell_create' ? '...' : t.createListing}
              </button>
            </form>

            {/* Market Orderbook */}
            <div className="lg:col-span-2 space-y-3.5">
              {/* Search & Tier Filter */}
              <div className="flex flex-col sm:flex-row gap-2.5">
                <div className="relative flex-1">
                  <Search className="w-4 h-4 text-[#9299A6] absolute top-1/2 -translate-y-1/2 start-3.5" />
                  <input
                    type="text"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    placeholder={t.searchPlaceholder}
                    className="w-full min-h-[42px] ps-10 pe-3.5 rounded-xl bg-[#141821] border border-white/8 text-sm text-[#F4F5F7] placeholder:text-[#9299A6]/70 focus:outline-none focus:border-[#E04455]"
                  />
                </div>
                <div className="flex items-center gap-1 bg-[#141821] border border-white/8 rounded-xl p-1">
                  {(['all', 'raw', 'intermediate', 'final'] as const).map((tier) => (
                    <button
                      key={tier}
                      type="button"
                      onClick={() => setTierFilter(tier)}
                      className={`px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap transition-colors ${
                        tierFilter === tier
                          ? 'bg-[#1B2230] text-[#F4F5F7]'
                          : 'text-[#9299A6] hover:text-[#F4F5F7]'
                      }`}
                    >
                      {tier === 'all'
                        ? t.allTiers
                        : tier === 'raw'
                        ? t.tierRaw
                        : tier === 'intermediate'
                        ? t.tierIntermediate
                        : t.tierFinal}
                    </button>
                  ))}
                </div>
              </div>

              {/* Listings */}
              {filteredListings.length === 0 ? (
                <div className="bg-[#141821] border border-white/8 rounded-2xl p-8 text-center">
                  <p className="text-sm text-[#9299A6]">
                    {language === 'ar'
                      ? 'لا توجد عروض مطابقة للبحث حالياً.'
                      : 'No active listings match your current filters.'}
                  </p>
                </div>
              ) : (
                <div className="space-y-2.5">
                  {filteredListings.map((listing) => {
                    const item = ITEM_MAP[listing.itemId];
                    if (!item) return null;
                    const isMine = listing.sellerUid === profile.uid;
                    const effectiveBuyQty = Math.min(
                      listing.remainingQty,
                      sanitizePositiveInt(buyQuantities[listing.id], 1, listing.remainingQty)
                    );
                    const totalItemSupply = supplyByItem.get(listing.itemId) || listing.remainingQty;
                    const refPrice = calculateDynamicItemPrice(
                      listing.itemId,
                      totalItemSupply,
                      worldEvents
                    );
                    const spreadPct =
                      refPrice > 0
                        ? Math.round(((listing.unitPrice - refPrice) / refPrice) * 100)
                        : 0;

                    return (
                      <div
                        key={listing.id}
                        className="bg-[#141821] border border-white/8 rounded-2xl p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-4"
                      >
                        <div className="flex min-w-0 items-center gap-3">
                          <ResourceIcon itemId={listing.itemId} size="md" />
                          <div className="min-w-0 space-y-1">
                            <h3 className="text-sm font-bold text-[#EAF1FF]">
                              {language === 'ar' ? item.nameAr : item.nameEn}
                            </h3>
                          <p className="text-xs text-[#9299A6]">
                            {listing.sellerName} ·{' '}
                            <span className="font-mono-num text-[#F4F5F7]">
                              {listing.remainingQty}
                            </span>{' '}
                            {language === 'ar' ? 'متاح' : 'avail'} ·{' '}
                            {language === 'ar' ? 'السعر المرجعي:' : 'Index:'}{' '}
                            <span className="font-mono-num">{refPrice}</span>{' '}
                            {spreadPct !== 0 && (
                              <span
                                className={`font-mono-num font-semibold ${
                                  spreadPct < 0 ? 'text-emerald-400' : 'text-amber-300'
                                }`}
                              >
                                ({spreadPct > 0 ? `+${spreadPct}%` : `${spreadPct}%`})
                              </span>
                            )}
                          </p>
                          </div>
                        </div>

                        <div className="flex items-center gap-2.5 shrink-0">
                          <div className="text-end me-1">
                            <p className="text-sm font-mono-num font-bold text-[#F4F5F7]">
                              {'$'}{listing.unitPrice.toLocaleString()}
                            </p>
                            <p className="text-[11px] text-[#9299A6]">{language === 'ar' ? 'لكل وحدة' : 'per unit'}</p>
                          </div>

                          {isMine ? (
                            <button
                              type="button"
                              disabled={busyKey === `can_${listing.id}`}
                              onClick={() => handleCancelListing(listing.id)}
                              className="min-h-[40px] px-3.5 rounded-xl bg-[#1B2230] hover:bg-[#232C3E] text-[#F4F5F7] text-xs font-semibold whitespace-nowrap"
                            >
                              {t.cancelListing}
                            </button>
                          ) : (
                            <>
                              <input
                                type="number"
                                min={1}
                                max={listing.remainingQty}
                                value={effectiveBuyQty}
                                onChange={(e) =>
                                  setBuyQuantities((prev) => ({
                                    ...prev,
                                    [listing.id]: sanitizePositiveInt(
                                      e.target.value,
                                      1,
                                      listing.remainingQty
                                    ),
                                  }))
                                }
                                aria-label={t.quantity}
                                className="w-16 min-h-[40px] px-2 rounded-xl bg-[#0B0D12] border border-white/10 text-center text-xs font-mono-num text-[#F4F5F7]"
                              />
                              <button
                                type="button"
                                disabled={
                                  busyKey === `buy_${listing.id}` ||
                                  (wallet?.balance ?? 0) < listing.unitPrice * effectiveBuyQty
                                }
                                onClick={() => handleBuy(listing)}
                                className="min-h-[40px] px-4 rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-xs font-semibold whitespace-nowrap disabled:bg-[#1B2230] disabled:text-[#9299A6]"
                              >
                                {busyKey === `buy_${listing.id}`
                                  ? '...'
                                  : `${t.buyNow} (${(
                                      listing.unitPrice * effectiveBuyQty
                                    ).toLocaleString()})`}
                              </button>
                            </>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* 2. TRADE CONTRACTS */}
      {subTab === 'contracts' && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {TRADE_CONTRACTS.map((ctr) => {
            const item = ITEM_MAP[ctr.requiredItemId];
            const owned = invMap.get(ctr.requiredItemId) || 0;
            const claimed = claimedContractsToday.has(`${ctr.id}_${todayKey}`);
            const payout = calculateContractPayout(
              ctr.payoutCredits,
              profile.skills.negotiation || 0,
              profile.reputation
            );

            return (
              <div
                key={ctr.id}
                className="bg-[#141821] border border-white/8 rounded-2xl p-5 flex flex-col justify-between gap-4"
              >
                <div className="space-y-1.5">
                  <div className="flex items-center justify-between gap-2">
                    <h3 className="text-base font-bold text-[#F4F5F7]">
                      {language === 'ar' ? ctr.titleAr : ctr.titleEn}
                    </h3>
                    <FileCheck2 className="w-4 h-4 text-[#E04455] shrink-0" />
                  </div>
                  <p className="text-xs text-[#9299A6]">
                    {language === 'ar' ? ctr.clientAr : ctr.clientEn}
                  </p>
                </div>

                <div className="bg-[#0B0D12] border border-white/6 rounded-xl p-3.5 space-y-2 text-xs">
                  <div className="flex items-center justify-between">
                    <span className="text-[#9299A6]">
                      {language === 'ar' ? item.nameAr : item.nameEn}
                    </span>
                    <span
                      className={`font-mono-num font-semibold ${
                        owned >= ctr.requiredQty ? 'text-emerald-400' : 'text-[#E04455]'
                      }`}
                    >
                      {owned} / {ctr.requiredQty}
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-[#9299A6]">{language === 'ar' ? 'العائد' : 'Payout'}</span>
                    <span className="font-mono-num font-bold text-emerald-400">
                      +{'$'}{payout.toLocaleString()}
                    </span>
                  </div>
                </div>

                <button
                  type="button"
                  disabled={claimed || owned < ctr.requiredQty || busyKey === `ctr_${ctr.id}`}
                  onClick={() => handleFulfillContract(ctr.id)}
                  className="w-full min-h-[44px] px-4 rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-xs font-semibold transition-colors disabled:bg-[#1B2230] disabled:text-[#9299A6]"
                >
                  {claimed ? t.claimed : busyKey === `ctr_${ctr.id}` ? '...' : t.executeContract}
                </button>
              </div>
            );
          })}
        </div>
      )}

      {/* 3. BANK & TRANSFERS */}
      {subTab === 'bank' && (
        <div className="max-w-lg bg-[#141821] border border-white/8 rounded-2xl p-6 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-bold text-[#F4F5F7]">{t.transferTitle}</h2>
            <Send className="w-4 h-4 text-[#E04455]" />
          </div>

          <div className="space-y-1.5">
            <label className="text-xs text-[#9299A6]">{t.recipientUsername}</label>
            <input
              type="text"
              value={recipientName}
              onChange={(e) => setRecipientName(e.target.value)}
              dir="ltr"
              placeholder="Username"
              className="w-full min-h-[44px] px-3.5 rounded-xl bg-[#0B0D12] border border-white/10 text-sm text-[#F4F5F7] focus:outline-none focus:border-[#E04455]"
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-xs text-[#9299A6]">{t.transferAmount}</label>
            <input
              type="number"
              min={1}
              max={wallet?.balance ?? 0}
              value={transferAmount || ''}
              onChange={(e) => {
                const v = e.target.value;
                setTransferAmount(v === '' ? 0 : sanitizePositiveInt(v, 1));
              }}
              onBlur={() => setTransferAmount((v) => sanitizePositiveInt(v, 1))}
              className="w-full min-h-[44px] px-3.5 rounded-xl bg-[#0B0D12] border border-white/10 text-sm font-mono-num text-[#F4F5F7] focus:outline-none focus:border-[#E04455]"
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-xs text-[#9299A6]">
              {language === 'ar' ? 'مرجع العملية (اختياري)' : 'Reference Note (Optional)'}
            </label>
            <input
              type="text"
              value={transferNote}
              onChange={(e) => setTransferNote(e.target.value)}
              maxLength={120}
              className="w-full min-h-[44px] px-3.5 rounded-xl bg-[#0B0D12] border border-white/10 text-sm text-[#F4F5F7] focus:outline-none focus:border-[#E04455]"
            />
          </div>

          <button
            type="button"
            disabled={!recipientName.trim() || transferAmount <= 0 || transferAmount > (wallet?.balance ?? 0)}
            onClick={() => setConfirmTransferOpen(true)}
            className="w-full min-h-[46px] px-4 rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-sm font-semibold transition-colors disabled:bg-[#1B2230] disabled:text-[#9299A6]"
          >
            {t.sendTransfer}
          </button>
        </div>
      )}

      {subTab === 'manufacturing' && (
        <ManufacturingPanel
          profile={profile}
          wallet={wallet}
          inventory={inventory}
          language={language}
          onNavigateToExchange={() => setSubTab('exchange')}
        />
      )}

      <ConfirmDialog
        open={confirmTransferOpen}
        title={t.confirmTitle}
        description={
          language === 'ar'
            ? `سيتم تحويل ${transferAmount.toLocaleString()} $ بشكل فوري وغير قابل للاسترجاع إلى ${recipientName}.`
            : `Transfer ${transferAmount.toLocaleString()} $ immediately to ${recipientName}?`
        }
        confirmLabel={t.confirmBtn}
        cancelLabel={t.cancelBtn}
        busy={busyKey === 'transfer'}
        onConfirm={executeTransfer}
        onCancel={() => setConfirmTransferOpen(false)}
      />
    </div>
  );
}
