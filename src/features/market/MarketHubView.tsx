import {
  Search,
  Send,
  ShoppingBag,
  Tag,
  History,
  ArrowDownLeft,
  ArrowUpRight,
} from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { ConfirmDialog } from '../../components/ui/ConfirmDialog';
import { ManufacturingPanel } from './ManufacturingPanel';
import { DynamicContractsPanel } from './DynamicContractsPanel';
import { useToast } from '../../components/ui/ToastProvider';
import { BRAND_ASSETS, CATALOG_ITEMS, ITEM_MAP } from '../../data/catalog';
import { ResourceIcon } from '../../components/ui/ResourceIcon';
import { NotificationBadge } from '../../components/ui/NotificationBadge';
import { useTranslations } from '../../i18n/translations';
import {
  calculateDynamicItemPrice,
  calculateMarketItemAnalytics,
  calculateMarketTaxRate,
  getMarketPriceBounds,
  LISTING_MAX_PRICE,
  LISTING_MAX_QTY,
  sanitizePositiveInt,
} from '../../lib/economy';
import {
  buyMarketListing,
  cancelMarketListing,
  createMarketListing,
  fetchMarketListings,
  fetchMarketActivity,
  fetchMarketPriceHistory,
  transferCredits,
  validateTransferRecipient,
} from '../../services/gameService';
import type {
  InventoryItem,
  Language,
  MarketListing,
  MarketActivityRecord,
  MarketPricePoint,
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
  notifications: import('../../types/game').GameNotification[];
  language: Language;
}

export function MarketHubView({
  profile,
  wallet,
  inventory,
  marketListings,
  worldEvents,
  notifications,
  language,
}: MarketHubViewProps) {
  const t = useTranslations(language);
  const { showToast } = useToast();

  const [subTab, setSubTab] = useState<MarketSubTab>('exchange');
  const [searchQuery, setSearchQuery] = useState('');
  const [itemFilter, setItemFilter] = useState<string>('all');
  const [buyQuantities, setBuyQuantities] = useState<Record<string, number>>({});
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [liveListings, setLiveListings] = useState(marketListings);
  const [marketActivity, setMarketActivity] = useState<MarketActivityRecord[]>([]);
  const [activityLoading, setActivityLoading] = useState(false);
  const [activityFilter, setActivityFilter] = useState<'all' | 'purchases' | 'sales'>('all');
  const [marketPriceHistory, setMarketPriceHistory] = useState<MarketPricePoint[]>([]);
  const marketListingsFetchInFlight = useRef(false);
  const marketHistoryFetchInFlight = useRef(false);
  const marketActivityFetchInFlight = useRef(false);

  useEffect(() => {
    let active = true;
    const refresh = () => {
      if (document.visibilityState !== 'visible' || marketListingsFetchInFlight.current) return;
      marketListingsFetchInFlight.current = true;
      void fetchMarketListings()
        .then((rows) => { if (active) setLiveListings(rows); })
        .catch(() => undefined)
        .finally(() => { marketListingsFetchInFlight.current = false; });
    };
    refresh();
    const timer = window.setInterval(refresh, 15_000);
    document.addEventListener('visibilitychange', refresh);
    window.addEventListener('nova:refresh-game', refresh);
    return () => { active = false; window.clearInterval(timer); document.removeEventListener('visibilitychange', refresh); window.removeEventListener('nova:refresh-game', refresh); };
  }, []);

  useEffect(() => {
    let active = true;
    const refresh = () => {
      if (document.visibilityState !== 'visible' || marketHistoryFetchInFlight.current) return;
      marketHistoryFetchInFlight.current = true;
      void fetchMarketPriceHistory()
        .then((rows) => { if (active) setMarketPriceHistory(rows); })
        .catch(() => undefined)
        .finally(() => { marketHistoryFetchInFlight.current = false; });
    };
    refresh();
    const timer = window.setInterval(refresh, 5 * 60_000);
    document.addEventListener('visibilitychange', refresh);
    window.addEventListener('nova:refresh-game', refresh);
    return () => { active = false; window.clearInterval(timer); document.removeEventListener('visibilitychange', refresh); window.removeEventListener('nova:refresh-game', refresh); };
  }, []);

  useEffect(() => { setLiveListings(marketListings); }, [marketListings]);

  useEffect(() => {
    if (subTab !== 'records') return;
    let active = true;
    const refresh = () => {
      if (document.visibilityState !== 'visible' || marketActivityFetchInFlight.current) return;
      marketActivityFetchInFlight.current = true;
      setActivityLoading(true);
      void fetchMarketActivity()
        .then((rows) => { if (active) setMarketActivity(rows); })
        .catch(() => undefined)
        .finally(() => {
          marketActivityFetchInFlight.current = false;
          if (active) setActivityLoading(false);
        });
    };
    refresh();
    const timer = window.setInterval(refresh, 15_000);
    window.addEventListener('nova:refresh-game', refresh);
    return () => { active = false; window.clearInterval(timer); window.removeEventListener('nova:refresh-game', refresh); };
  }, [subTab]);

  async function refreshListings() {
    const rows = await fetchMarketListings();
    setLiveListings(rows);
  }

  // Create Sell Listing form
  const ownedStacks = inventory.filter((i) => i.quantity > 0 && getMarketPriceBounds(i.itemId) !== null);
  const initialSellId = ownedStacks[0]?.itemId || CATALOG_ITEMS.find((item) => getMarketPriceBounds(item.id) !== null)?.id || 'silicon_ore';
  const [sellItemId, setSellItemId] = useState(initialSellId);
  const [sellQty, setSellQty] = useState(1);
  const [sellPrice, setSellPrice] = useState(ITEM_MAP[initialSellId]?.basePrice || 40);
  const sellPriceBounds = getMarketPriceBounds(sellItemId);

  // Bank Transfer form
  const [recipientName, setRecipientName] = useState('');
  const [transferAmount, setTransferAmount] = useState(100);
  const [transferNote, setTransferNote] = useState('');
  const [confirmTransferOpen, setConfirmTransferOpen] = useState(false);
  const [recipientCheck, setRecipientCheck] = useState<'idle' | 'checking' | 'valid' | 'invalid' | 'self'>('idle');
  const transferFeePreview = Math.round(transferAmount * 0.03);
  const transferNetPreview = Math.max(0, transferAmount - transferFeePreview);

  const taxRate = calculateMarketTaxRate(profile.skills.trade || 0, worldEvents);
  const invMap = new Map<string, number>();
  inventory.forEach((i) => invMap.set(i.itemId, i.quantity));

  // Compute live supply per item across active listings
  const supplyByItem = new Map<string, number>();
  for (const l of liveListings) {
    if (l.status === 'active' && l.remainingQty > 0) {
      supplyByItem.set(l.itemId, (supplyByItem.get(l.itemId) || 0) + l.remainingQty);
    }
  }

  const pulseItems = CATALOG_ITEMS.slice(0, 4).map((item) =>
    calculateMarketItemAnalytics(item.id, liveListings, worldEvents)
  );
  const marketTrendByItem = new Map<string, { points: number[]; changePct: number | null; trades: number }>();
  const historyNow = Date.now();
  for (const pulse of pulseItems) {
    const buckets = Array.from({ length: 7 }, () => ({ value: 0, quantity: 0, trades: 0 }));
    for (const point of marketPriceHistory) {
      if (point.itemId !== pulse.itemId) continue;
      const createdAt = typeof point.createdAt === 'number'
        ? point.createdAt
        : new Date(String(point.createdAt)).getTime();
      const age = historyNow - createdAt;
      if (!Number.isFinite(createdAt) || age < 0 || age >= 7 * 24 * 60 * 60 * 1000) continue;
      const bucket = buckets[6 - Math.floor(age / (24 * 60 * 60 * 1000))];
      bucket.value += point.unitPrice * point.quantity;
      bucket.quantity += point.quantity;
      bucket.trades += 1;
    }
    const points = buckets.map((bucket) => bucket.quantity ? bucket.value / bucket.quantity : 0);
    const first = points.find((value) => value > 0);
    const last = [...points].reverse().find((value) => value > 0);
    marketTrendByItem.set(pulse.itemId, {
      points,
      changePct: first && last ? ((last - first) / first) * 100 : null,
      trades: buckets.reduce((sum, bucket) => sum + bucket.trades, 0),
    });
  }

  const filteredListings = liveListings.filter((l) => {
    const item = ITEM_MAP[l.itemId];
    if (!item || getMarketPriceBounds(l.itemId) === null || l.status !== 'active' || l.remainingQty <= 0) return false;
    if (itemFilter !== 'all' && l.itemId !== itemFilter) return false;
    if (searchQuery.trim()) {
      const q = searchQuery.trim().toLowerCase();
      return (
        item.nameAr.toLowerCase().includes(q) ||
        item.nameEn.toLowerCase().includes(q) ||
        l.sellerName.toLowerCase().includes(q)
      );
    }
    return true;
  }).sort((a, b) => a.unitPrice - b.unitPrice || a.id.localeCompare(b.id));

  async function handleBuy(listing: MarketListing) {
    const qty = Math.min(
      listing.remainingQty,
      sanitizePositiveInt(buyQuantities[listing.id], 1, listing.remainingQty)
    );
    setBusyKey(`buy_${listing.id}`);
    try {
      await buyMarketListing(profile.uid, listing.id, qty, taxRate, listing.unitPrice);
      await refreshListings().catch(() => undefined);
      showToast(
        language === 'ar'
          ? `تم شراء ${qty} وحدة بنجاح.`
          : `Purchased ${qty} units successfully.`,
        'success'
      );
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      if (code === 'MARKET_QUOTE_CHANGED') await refreshListings().catch(() => undefined);
      showToast(
        code === 'MARKET_QUOTE_CHANGED'
          ? language === 'ar'
            ? 'تغير سعر العرض. تم تحديث السوق؛ راجع السعر ثم أعد الشراء.'
            : 'The listing price changed. The market was refreshed; review the new price and retry.'
          : code === 'PRICE_BELOW_MINIMUM' || code === 'PRICE_ABOVE_MAXIMUM'
          ? language === 'ar'
            ? 'هذا العرض خارج حدود الأسعار المعتمدة. على البائع إعادة نشره بسعر ضمن الحدود.'
            : 'This listing is outside the allowed price range. The seller must relist it within the limits.'
          : code === 'INSUFFICIENT_FUNDS'
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
          : code === 'INVENTORY_CAPACITY_EXCEEDED'
          ? language === 'ar'
            ? 'مخزونك ممتلئ. ارفع مستواك أو بع بعض الموارد قبل الشراء.'
            : 'Your inventory is full. Level up or sell some items before buying.'
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
    const cleanPrice = sanitizePositiveInt(sellPrice, sellPriceBounds?.minPrice ?? 1, sellPriceBounds?.maxPrice ?? LISTING_MAX_PRICE);
    setBusyKey('sell_create');
    try {
      await createMarketListing(profile.uid, profile.username, sellItemId, cleanQty, cleanPrice);
      await refreshListings();
      showToast(
        language === 'ar' ? 'تم نشر عرض البيع في السوق.' : 'Sell offer published on market.',
        'success'
      );
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      showToast(
        code === 'PRICE_BELOW_MINIMUM'
          ? language === 'ar'
            ? `السعر أقل من الحد الأدنى المسموح: ${sellPriceBounds?.minPrice ?? 1}.`
            : `Price is below the minimum allowed: ${sellPriceBounds?.minPrice ?? 1}.`
          : code === 'PRICE_ABOVE_MAXIMUM'
          ? language === 'ar'
            ? `السعر أعلى من الحد الأقصى المسموح: ${sellPriceBounds?.maxPrice ?? LISTING_MAX_PRICE}.`
            : `Price exceeds the maximum allowed: ${sellPriceBounds?.maxPrice ?? LISTING_MAX_PRICE}.`
          : code === 'ACTIVE_LISTING_EXISTS'
          ? language === 'ar'
            ? 'لديك عرض نشط لهذا المورد بالفعل. ألغِ العرض الحالي أو انتظر نفاده قبل إنشاء عرض جديد.'
            : 'You already have an active offer for this resource. Cancel it or wait until it sells out before creating another.'
          : code === 'INVALID_LISTING_PARAMS'
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
      await refreshListings();
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

  async function checkTransferRecipient(): Promise<boolean> {
    const clean = recipientName.trim();
    if (!clean) {
      setRecipientCheck('invalid');
      return false;
    }
    setRecipientCheck('checking');
    try {
      const result = await validateTransferRecipient(clean);
      if (recipientName.trim() !== clean) {
        setRecipientCheck('idle');
        return false;
      }
      const status = !result.exists ? 'invalid' : result.isSelf ? 'self' : 'valid';
      setRecipientCheck(status);
      if (status === 'invalid') showToast(language === 'ar' ? 'اسم اللاعب غير موجود. تحقق من كتابة اسم المستخدم.' : 'Player not found. Check the username.', 'error');
      if (status === 'self') showToast(language === 'ar' ? 'لا يمكنك تحويل الأموال إلى نفسك.' : 'You cannot transfer credits to yourself.', 'error');
      return status === 'valid';
    } catch {
      setRecipientCheck('idle');
      showToast(language === 'ar' ? 'تعذر التحقق من اسم اللاعب. حاول مجدداً.' : 'Could not verify the player. Please try again.', 'error');
      return false;
    }
  }

  async function prepareTransfer() {
    if (transferAmount > 10000) {
      showToast(language === 'ar' ? 'الحد الأقصى للتحويل اليومي هو 10,000 قبل الرسوم.' : 'The daily transfer limit is 10,000 before fees.', 'error');
      return;
    }
    if (await checkTransferRecipient()) setConfirmTransferOpen(true);
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
      setRecipientCheck('idle');
      setTransferNote('');
      showToast(
        language === 'ar' ? 'تم تنفيذ التحويل المالي بنجاح.' : 'Transfer completed.',
        'success'
      );
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      if (['RECIPIENT_NOT_FOUND', 'SELF_OR_MISSING_RECIPIENT', 'INVALID_AMOUNT', 'TRANSFER_LEVEL_REQUIRED', 'TRANSFER_DAILY_LIMIT'].includes(code)) {
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
          : code === 'TRANSFER_LEVEL_REQUIRED'
          ? language === 'ar'
            ? 'يجب أن يصل مستواك إلى 10 على الأقل قبل التحويل.'
            : 'Reach level 10 before sending transfers.'
          : code === 'TRANSFER_DAILY_LIMIT'
          ? language === 'ar'
            ? 'وصلت إلى الحد اليومي للتحويلات البالغ 10,000.'
            : 'You have reached the 10,000-credit daily transfer limit.'
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
    { id: 'records', label: language === 'ar' ? 'السجلات' : 'Records' },
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
            {tab.label}{tab.id === 'contracts' && notifications.filter((n) => !n.read && (n.eventKey?.startsWith('contract-ready:') || n.title === 'العقد جاهز للاستلام' || n.title === 'Contract ready to claim' || n.title === 'CONTRACT_READY')).length > 0 && <NotificationBadge className="ms-1" count={notifications.filter((n) => !n.read && (n.eventKey?.startsWith('contract-ready:') || n.title === 'العقد جاهز للاستلام' || n.title === 'Contract ready to claim' || n.title === 'CONTRACT_READY')).length} />}
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
              loading="lazy"
              decoding="async"
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
                    className="p-3 rounded-xl bg-[#0B0D12] border border-white/6 space-y-2"
                  >
                    <div className="flex min-w-0 flex-col items-start gap-2">
                      <div className="flex min-w-0 w-full items-start gap-2">
                        <ResourceIcon itemId={ana.itemId} size="sm" />
                        <span className="min-w-0 flex-1 whitespace-normal break-words text-xs font-semibold leading-4 text-[#EAF1FF]">
                          {language === 'ar' ? item.nameAr : item.nameEn}
                        </span>
                      </div>
                      <span className={`self-start text-[10px] leading-4 font-medium whitespace-normal ${statusColor}`}>
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

          <section className="bg-[#141821] border border-white/8 rounded-2xl p-4 space-y-3">
            <div className="flex items-center justify-between gap-3">
              <h2 className="text-xs font-semibold text-[#9299A6] uppercase tracking-wider">{language === 'ar' ? 'اتجاه الأسعار · آخر 7 أيام' : 'Price trends · last 7 days'}</h2>
              <span className="text-[10px] text-[#74839A]">{language === 'ar' ? 'متوسط مرجّح بكمية التداول' : 'Volume-weighted trade prices'}</span>
            </div>
            {marketPriceHistory.length === 0 ? (
              <p className="py-3 text-center text-xs text-[#9299A6]">{language === 'ar' ? 'سيظهر الاتجاه بعد تسجيل عمليات تداول مكتملة.' : 'Trends appear after completed market trades are recorded.'}</p>
            ) : (
              <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
                {pulseItems.map((pulse) => {
                  const item = ITEM_MAP[pulse.itemId];
                  const trend = marketTrendByItem.get(pulse.itemId);
                  if (!item || !trend) return null;
                  const max = Math.max(1, ...trend.points);
                  const change = trend.changePct;
                  return (
                    <div key={pulse.itemId} className="rounded-xl border border-white/6 bg-[#0B0D12] p-3 space-y-2">
                      <div className="flex items-center gap-2 min-w-0"><ResourceIcon itemId={pulse.itemId} size="sm" /><span className="truncate text-xs font-semibold text-[#EAF1FF]">{language === 'ar' ? item.nameAr : item.nameEn}</span></div>
                      <div className="flex h-10 items-end gap-1" aria-label={language === 'ar' ? 'متوسطات الأسعار اليومية' : 'Daily average prices'}>
                        {trend.points.map((value, index) => <span key={index} className="flex-1 rounded-t bg-[#397BFF]/75" style={{ height: `${value > 0 ? Math.max(5, (value / max) * 36) : 3}px` }} />)}
                      </div>
                      <div className="flex items-center justify-between gap-2 text-[10px] text-[#9299A6]">
                        <span>{trend.trades} {language === 'ar' ? 'صفقات' : 'trades'}</span>
                        <span className={`font-mono-num font-semibold ${change === null ? 'text-[#9299A6]' : change > 0 ? 'text-emerald-400' : change < 0 ? 'text-rose-300' : 'text-[#F4F5F7]'}`}>
                          {change === null ? '—' : `${change > 0 ? '+' : ''}${change.toFixed(1)}%`}
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </section>

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
                  {CATALOG_ITEMS.filter((item) => getMarketPriceBounds(item.id) !== null).map((item) => {
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
                    min={sellPriceBounds?.minPrice ?? 1}
                    max={sellPriceBounds?.maxPrice ?? LISTING_MAX_PRICE}
                    step={1}
                    required
                    value={sellPrice || ''}
                    onChange={(e) => {
                      const v = e.target.value;
                      setSellPrice(v === '' ? 0 : sanitizePositiveInt(v, sellPriceBounds?.minPrice ?? 1, sellPriceBounds?.maxPrice ?? LISTING_MAX_PRICE));
                    }}
                    onBlur={() => setSellPrice((v) => sanitizePositiveInt(v, sellPriceBounds?.minPrice ?? 1, sellPriceBounds?.maxPrice ?? LISTING_MAX_PRICE))}
                    className="w-full min-h-[44px] px-3 rounded-xl bg-[#0B0D12] border border-white/10 text-sm font-mono-num text-[#F4F5F7] focus:outline-none focus:border-[#E04455]"
                  />
                </div>
              </div>
              <div className="rounded-lg border border-[#2A3445] bg-[#141B27] px-3 py-2 text-xs text-[#D5DCE7]">
                {language === 'ar'
                  ? `الحد الأدنى: ${sellPriceBounds?.minPrice ?? '—'} رصيد · الحد الأقصى: ${sellPriceBounds?.maxPrice ?? '—'} رصيد`
                  : `Minimum: ${sellPriceBounds?.minPrice ?? '—'} credits · Maximum: ${sellPriceBounds?.maxPrice ?? '—'} credits`}
              </div>

              <button
                type="submit"
                disabled={
                  busyKey === 'sell_create' ||
                  !sellPriceBounds ||
                  sellQty < 1 ||
                  sellPrice < (sellPriceBounds?.minPrice ?? 1) ||
                  sellPrice > (sellPriceBounds?.maxPrice ?? LISTING_MAX_PRICE) ||
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
                <div className="flex max-w-full items-center gap-1 overflow-x-auto bg-[#141821] border border-white/8 rounded-xl p-1">
                  <button type="button" onClick={() => setItemFilter('all')} className={`shrink-0 px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap transition-colors ${itemFilter === 'all' ? 'bg-[#1B2230] text-[#F4F5F7]' : 'text-[#9299A6] hover:text-[#F4F5F7]'}`}>{t.allTiers}</button>
                  {CATALOG_ITEMS.filter((item) => getMarketPriceBounds(item.id) !== null).map((item) => (
                    <button key={item.id} type="button" onClick={() => setItemFilter(item.id)} className={`shrink-0 px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap transition-colors ${itemFilter === item.id ? 'bg-[#1B2230] text-[#F4F5F7]' : 'text-[#9299A6] hover:text-[#F4F5F7]'}`}>
                      {language === 'ar' ? item.nameAr : item.nameEn}
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
                        data-testid="market-listing"
                        data-market-own={isMine ? 'true' : 'false'}
                        data-unit-price={listing.unitPrice}
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
                                data-testid="market-buy"
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

      {/* 2. DYNAMIC CONTRACTS */}
      {subTab === 'contracts' && (
        <DynamicContractsPanel
          profile={profile}
          inventory={inventory}
          wallet={wallet}
          language={language}
          notifications={notifications}
        />
      )}

      {/* 3. BANK & TRANSFERS */}
      {subTab === 'bank' && (
        <div className="max-w-lg bg-[#141821] border border-white/8 rounded-2xl p-6 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-bold text-[#F4F5F7]">{t.transferTitle}</h2>
            <Send className="w-4 h-4 text-[#E04455]" />
          </div>

          <div className="rounded-xl border border-amber-400/20 bg-amber-400/5 p-3 space-y-1.5">
            <p className="text-xs font-semibold text-amber-200">{language === 'ar' ? 'شروط التحويل' : 'Transfer requirements'}</p>
            <p className="text-xs text-[#C2C8D2]">{language === 'ar' ? 'المستوى المطلوب: 10 على الأقل · رسوم التحويل: 3% · الحد اليومي: 10,000 رصيد قبل الرسوم (بتوقيت UTC).' : 'Minimum level: 10 · Transfer fee: 3% · Daily limit: 10,000 credits before fees (UTC).'}</p>
          </div>
          <div className="space-y-1.5">
            <label className="text-xs text-[#9299A6]">{t.recipientUsername}</label>
            <input
              type="text"
              value={recipientName}
              onChange={(e) => { setRecipientName(e.target.value); setRecipientCheck('idle'); }}
              onBlur={() => { if (recipientName.trim()) void checkTransferRecipient(); }}
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
              max={Math.min(wallet?.balance ?? 0, 10000)}
              value={transferAmount || ''}
              onChange={(e) => {
                const v = e.target.value;
                setTransferAmount(v === '' ? 0 : sanitizePositiveInt(v, 1));
              }}
              onBlur={() => setTransferAmount((v) => sanitizePositiveInt(v, 1))}
              className="w-full min-h-[44px] px-3.5 rounded-xl bg-[#0B0D12] border border-white/10 text-sm font-mono-num text-[#F4F5F7] focus:outline-none focus:border-[#E04455]"
            />
          </div>

          <div className="rounded-xl bg-[#0B0D12] border border-white/8 p-3 grid grid-cols-3 gap-2 text-center">
            <div><p className="text-[10px] text-[#9299A6]">{language === 'ar' ? 'الرسوم 3%' : '3% fee'}</p><p className="text-sm font-mono-num text-amber-200">{transferFeePreview.toLocaleString()}</p></div>
            <div><p className="text-[10px] text-[#9299A6]">{language === 'ar' ? 'سيصل للمستلم' : 'Recipient gets'}</p><p className="text-sm font-mono-num text-emerald-300">{transferNetPreview.toLocaleString()}</p></div>
            <div><p className="text-[10px] text-[#9299A6]">{language === 'ar' ? 'سقف التحويل اليومي' : 'Daily transfer cap'}</p><p className="text-sm font-mono-num text-[#F4F5F7]">{(10000).toLocaleString()}</p></div>
          </div>
          {recipientCheck === 'invalid' && <p className="text-xs text-rose-300">{language === 'ar' ? 'لم نعثر على لاعب بهذا الاسم. لن يتم إرسال التحويل.' : 'No player matches this username. The transfer will not be sent.'}</p>}
          {recipientCheck === 'self' && <p className="text-xs text-rose-300">{language === 'ar' ? 'هذا اسم حسابك.' : 'This is your own username.'}</p>}
          {recipientCheck === 'valid' && <p className="text-xs text-emerald-300">{language === 'ar' ? 'تم التأكد من وجود اللاعب.' : 'Player account verified.'}</p>}
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
            disabled={!recipientName.trim() || transferAmount <= 0 || transferAmount > 10000 || transferAmount > (wallet?.balance ?? 0) || recipientCheck === 'checking'}
            onClick={() => void prepareTransfer()}
            className="w-full min-h-[46px] px-4 rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-sm font-semibold transition-colors disabled:bg-[#1B2230] disabled:text-[#9299A6]"
          >
            {recipientCheck === 'checking' ? (language === 'ar' ? 'جارٍ التحقق...' : 'Checking player...') : t.sendTransfer}
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

      {subTab === 'records' && (
        <section className="rounded-2xl border border-white/8 bg-[#141821] p-4 sm:p-5 space-y-4">
          <div className="flex items-start justify-between gap-3">
            <div>
              <h2 className="flex items-center gap-2 text-base font-bold text-[#F4F5F7]"><History className="h-4 w-4 text-[#63A5FF]" />{language === 'ar' ? 'سجلات السوق' : 'Market records'}</h2>
              <p className="mt-1 text-[11px] text-[#9299A6]">{language === 'ar' ? 'تُسجل هنا عمليات الشراء المكتملة والموارد التي اشتراها الآخرون منك فقط.' : 'Only completed purchases and sales to other players appear here.'}</p>
            </div>
            <span className="rounded-lg bg-[#0B0D12] px-2.5 py-1 text-[10px] font-mono-num text-[#A9B9D4]">{marketActivity.length}</span>
          </div>
          <div className="flex gap-2">
            {([
              ['all', language === 'ar' ? 'الكل' : 'All'],
              ['purchases', language === 'ar' ? 'مشترياتي' : 'Purchases'],
              ['sales', language === 'ar' ? 'مبيعاتي' : 'Sales'],
            ] as const).map(([value, label]) => (
              <button key={value} type="button" onClick={() => setActivityFilter(value)} className={activityFilter === value ? "min-h-9 rounded-lg px-3 text-xs font-semibold bg-[#2468D8] text-white" : "min-h-9 rounded-lg px-3 text-xs font-semibold border border-white/8 bg-[#0B0D12] text-[#9299A6] hover:text-white"}>{label}</button>
            ))}
          </div>
          {activityLoading && marketActivity.length === 0 ? (
            <p className="py-8 text-center text-xs text-[#9299A6]">{language === 'ar' ? 'جارٍ تحميل السجلات...' : 'Loading records...'}</p>
          ) : marketActivity.filter((record) => activityFilter === 'all' || (activityFilter === 'sales' ? record.sellerUid === profile.uid : record.buyerUid === profile.uid)).length === 0 ? (
            <div className="rounded-xl border border-white/8 bg-[#0B0D12] p-8 text-center text-xs text-[#9299A6]">{language === 'ar' ? 'لا توجد عمليات شراء أو بيع مكتملة بعد.' : 'No completed purchases or sales yet.'}</div>
          ) : (
            <div className="space-y-2">
              {marketActivity.filter((record) => activityFilter === 'all' || (activityFilter === 'sales' ? record.sellerUid === profile.uid : record.buyerUid === profile.uid)).map((record) => {
                const isSale = record.sellerUid === profile.uid;
                const item = ITEM_MAP[record.itemId];
                const otherParty = isSale ? record.buyerName : record.sellerName;
                const total = isSale ? Math.max(0, record.totalPrice - record.taxAmount) : record.totalPrice;
                const date = new Date(String(record.createdAt));
                const dateLabel = Number.isNaN(date.getTime()) ? '—' : date.toLocaleString(language === 'ar' ? 'ar' : 'en', { dateStyle: 'medium', timeStyle: 'short' });
                return (
                  <article key={record.id} className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-white/8 bg-[#0B0D12] p-3">
                    <div className="flex min-w-0 items-center gap-3">
                      <span className={isSale ? "flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-emerald-500/10 text-emerald-300" : "flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-sky-500/10 text-sky-300"}>
                        {isSale ? <ArrowUpRight className="h-4 w-4" /> : <ArrowDownLeft className="h-4 w-4" />}
                      </span>
                      <div className="min-w-0">
                        <p className="truncate text-sm font-semibold text-[#F4F5F7]">{item ? (language === 'ar' ? item.nameAr : item.nameEn) : record.itemId} · ×{record.quantity.toLocaleString()}</p>
                        <p className="mt-0.5 text-[10px] text-[#9299A6]">{isSale ? (language === 'ar' ? 'بيع إلى' : 'Sold to') : (language === 'ar' ? 'شراء من' : 'Bought from')} {otherParty} · {dateLabel}</p>
                      </div>
                    </div>
                    <div className="ms-auto text-end">
                      <p className={isSale ? "font-mono-num text-sm font-bold text-emerald-300" : "font-mono-num text-sm font-bold text-[#F4F5F7]"}>{isSale ? '+' : '−'}{total.toLocaleString()} {language === 'ar' ? 'رصيد' : 'credits'}</p>
                      <p className="text-[10px] text-[#9299A6]">{record.unitPrice.toLocaleString()} {language === 'ar' ? 'للوحدة' : 'per unit'}</p>
                    </div>
                  </article>
                );
              })}
            </div>
          )}
        </section>
      )}

      <ConfirmDialog
        open={confirmTransferOpen}
        title={t.confirmTitle}
        description={
          language === 'ar'
            ? `سيتم خصم ${transferAmount.toLocaleString()} $ من رصيدك، ويصل إلى ${recipientName} مبلغ ${transferNetPreview.toLocaleString()} $ بعد رسوم 3% (${transferFeePreview.toLocaleString()} $). لا يمكن استرجاع التحويل.`
            : `Send ${transferAmount.toLocaleString()} credits to ${recipientName}? A 3% fee (${transferFeePreview.toLocaleString()}) applies, so they receive ${transferNetPreview.toLocaleString()} credits.`
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
