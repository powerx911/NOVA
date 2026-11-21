import { useEffect, useState } from 'react';
import { ArrowLeft, Package, ShoppingBag } from 'lucide-react';
import { ResourceIcon } from '../../components/ui/ResourceIcon';
import { ITEM_MAP } from '../../data/catalog';
import type { InventoryItem, Language, MarketListing } from '../../types/game';
import { fetchInventoryCapacityUsage, fetchNexoraDailySales, sellToNexora } from '../../services/gameService';

interface InventoryPanelProps {
  inventory: InventoryItem[];
  marketListings: MarketListing[];
  uid: string;
  language: Language;
  title: string;
  marketLabel: string;
  onGoToMarket: () => void;
  capacity: number;
}

export function InventoryPanel({ inventory, marketListings, uid, language, title, marketLabel, onGoToMarket, capacity }: InventoryPanelProps) {
  const [serverInventoryUsage, setServerInventoryUsage] = useState<number | null>(null);
  const [merchantOpen, setMerchantOpen] = useState(false);
  const [merchantStep, setMerchantStep] = useState<'welcome' | 'choose' | 'sell'>('welcome');
  const [merchantItemId, setMerchantItemId] = useState<string | null>(null);
  const [merchantQuantity, setMerchantQuantity] = useState(1);
  const [merchantBusy, setMerchantBusy] = useState(false);
  const [merchantNotice, setMerchantNotice] = useState('');
  const [merchantDailySold, setMerchantDailySold] = useState<number | null>(null);
  useEffect(() => {
    if (!merchantOpen) return;
    let active = true;
    void fetchNexoraDailySales().then((sold) => {
      if (active) setMerchantDailySold((current) => Math.max(current ?? 0, sold));
    }).catch(() => undefined);
    return () => { active = false; };
  }, [merchantOpen]);
  const selectedInv = inventory.find((entry) => entry.itemId === merchantItemId && entry.quantity > 0);
  const selectedItem = merchantItemId ? ITEM_MAP[merchantItemId] : null;
  const merchantPrice = selectedItem ? Math.round(selectedItem.basePrice * 0.6) : 0;
  const merchantMax = selectedInv ? Math.min(1500, selectedInv.quantity) : 0;
  const resetMerchant = () => { setMerchantStep('welcome'); setMerchantItemId(null); setMerchantQuantity(1); setMerchantNotice(''); };
  const submitMerchantSale = async () => {
    if (!merchantItemId || merchantQuantity < 1 || merchantQuantity > merchantMax || merchantBusy) return;
    setMerchantBusy(true); setMerchantNotice('');
    try { const result = await sellToNexora(merchantItemId, merchantQuantity); setMerchantDailySold(result.daily_sold); setMerchantNotice((language === 'ar' ? 'تم البيع بنجاح! استلمت ' : 'Sale complete! You received ') + result.total.toLocaleString() + (language === 'ar' ? ' رصيد.' : ' credits.')); setMerchantStep('welcome'); setMerchantItemId(null); }
    catch (e) { const code = e instanceof Error ? e.message : 'NEXORA_SALE_FAILED'; const ar: Record<string,string> = { DAILY_SALE_LIMIT:'وصلت إلى حد البيع اليومي لدى NEXORA.', INSUFFICIENT_INVENTORY:'الكمية لم تعد متوفرة في مخزونك.', INVALID_QUANTITY:'الكمية المحددة غير صالحة.' }; setMerchantNotice(language === 'ar' ? (ar[code] || 'تعذر إتمام البيع. حاول مرة أخرى.') : code.replaceAll('_',' ').toLowerCase()); }
    finally { setMerchantBusy(false); }
  };
  const inventoryQuantity = inventory.reduce((sum, item) => sum + Math.max(0, item.quantity), 0);
  const fallbackListedQuantity = marketListings.reduce((sum, listing) => sum + (listing.sellerUid === uid && listing.status === 'active' ? Math.max(0, listing.remainingQty) : 0), 0);
  useEffect(() => {
    let active = true;
    const refresh = () => {
      void fetchInventoryCapacityUsage().then((usage) => {
        if (active && Number.isFinite(usage)) setServerInventoryUsage(Math.max(0, usage));
      }).catch(() => undefined);
    };
    refresh();
    const timer = window.setInterval(refresh, 30_000);
    window.addEventListener('nova:refresh-game', refresh);
    return () => { active = false; window.clearInterval(timer); window.removeEventListener('nova:refresh-game', refresh); };
  }, [uid]);
  const totalQuantity = serverInventoryUsage === null ? inventoryQuantity + fallbackListedQuantity : Math.max(inventoryQuantity, serverInventoryUsage);
  const listedQuantity = Math.max(0, totalQuantity - inventoryQuantity);
  const capacityPercent = capacity > 0 ? Math.min(100, (totalQuantity / capacity) * 100) : 0;
  const availableItems = inventory.filter((item) => item.quantity > 0);

  return (
    <>
        {merchantOpen && <div className="fixed inset-0 z-[100] h-[100dvh] overflow-y-auto overscroll-contain bg-[#0B0D12] text-[#F4F5F7] pb-[env(safe-area-inset-bottom)]" dir={language === 'ar' ? 'rtl' : 'ltr'}>
      <div className="mx-auto flex min-h-[100dvh] max-w-6xl flex-col px-4 pt-[max(1rem,env(safe-area-inset-top))] pb-5 sm:px-8">
        <header className="flex items-center justify-between border-b border-white/10 pb-5"><button onClick={() => setMerchantOpen(false)} className="inline-flex items-center gap-2 rounded-xl border border-white/10 px-4 py-2.5 text-sm"><ArrowLeft size={18}/>{language === 'ar' ? 'رجوع للمخزون' : 'Back to inventory'}</button><div className="text-end"><p className="text-xs tracking-[.3em] text-cyan-300">NEXORA</p><p className="mt-1 text-[10px] text-[#9299A6]">متجر نيكسورا · سوق الموارد</p></div></header>
        <main className="flex flex-1 items-center py-8"><div className="mx-auto grid w-full max-w-5xl gap-8 md:grid-cols-2 md:items-center">
          <section className="rounded-2xl border border-white/8 bg-[#141821] p-6 text-center"><img src={`${import.meta.env.BASE_URL}nexora-merchant.svg`} alt={language === 'ar' ? 'الصورة الشخصية لنيكسورا' : 'Nexora merchant portrait'} className="mx-auto h-40 w-40 rounded-full border border-white/10 object-cover shadow-xl" /><p className="mt-6 text-[10px] tracking-[.3em] text-[#63A5FF]/70">NEXORA CITY · MERCHANT</p><h2 className="mt-3 text-2xl font-semibold">{language === 'ar' ? 'أهلاً بك في متجري، ماذا لديك اليوم؟' : 'Welcome to my store. What do you have today?'}</h2><p className="mt-3 text-sm text-white/50">{language === 'ar' ? 'أشتري مواردك مباشرةً وأضيف عائدات البيع إلى رصيدك.' : 'I buy your resources directly and add the proceeds to your balance.'}</p></section>
          <section className="rounded-2xl border border-white/8 bg-[#141821] p-5 sm:p-8">
            {merchantStep === 'welcome' && <div className="space-y-4"><p className="text-xs tracking-widest text-white/40">{language === 'ar' ? 'اختر ما تريد فعله' : 'CHOOSE AN ACTION'}</p><button onClick={() => { setMerchantStep('choose'); setMerchantNotice(''); }} className="w-full rounded-2xl border border-white/8 bg-[#0B0D12] p-5 text-start hover:border-[#397BFF]/50"><span className="block text-lg font-semibold">{language === 'ar' ? 'لدي بعض الموارد' : 'I have some resources'}</span><span className="mt-1 block text-sm text-white/45">{language === 'ar' ? 'اعرض الموارد المتاحة للبيع' : 'Browse resources available to sell'}</span></button><button onClick={() => setMerchantOpen(false)} className="w-full rounded-2xl border border-white/10 p-5 text-start hover:bg-white/5"><span className="block text-lg font-semibold">{language === 'ar' ? 'سأعود لاحقاً' : 'I’ll come back later'}</span></button>{merchantNotice && <p role="status" className="rounded-xl bg-emerald-400/10 p-3 text-sm text-emerald-200">{merchantNotice}</p>}</div>}
            {merchantStep === 'choose' && <div className="space-y-4"><button onClick={() => setMerchantStep('welcome')} className="text-sm text-cyan-200">← {language === 'ar' ? 'عودة للحوار' : 'Back'}</button><h3 className="text-xl font-semibold">{language === 'ar' ? 'اختر المورد الذي تريد بيعه' : 'Choose a resource to sell'}</h3><div className="max-h-[55vh] space-y-2 overflow-y-auto">{availableItems.map((inv) => { const item = ITEM_MAP[inv.itemId]; if (!item) return null; return <button key={inv.itemId} onClick={() => { setMerchantItemId(inv.itemId); setMerchantQuantity(1); setMerchantNotice(''); setMerchantStep('sell'); }} className="flex w-full items-center justify-between gap-3 rounded-xl border border-white/10 bg-[#0B0D12] p-3 text-start hover:border-[#397BFF]/50"><span className="flex items-center gap-3"><ResourceIcon itemId={inv.itemId} size="md"/><span><span className="block text-sm font-semibold">{language === 'ar' ? item.nameAr : item.nameEn}</span><span className="mt-1 block text-xs text-white/45">{language === 'ar' ? 'سعر الوحدة' : 'Unit price'}: {Math.round(item.basePrice*.6)} · {language === 'ar' ? 'المتاح' : 'Available'}: {inv.quantity}</span></span></span><span className="text-cyan-200">›</span></button>; })}{availableItems.length===0 && <p className="text-sm text-white/50">{language === 'ar' ? 'لا توجد موارد متاحة للبيع.' : 'No resources available to sell.'}</p>}</div></div>}
            {merchantStep === 'sell' && selectedItem && <div className="space-y-5"><button onClick={() => setMerchantStep('choose')} className="text-sm text-cyan-200">← {language === 'ar' ? 'اختيار مورد آخر' : 'Choose another resource'}</button><div className="flex items-center gap-3"><ResourceIcon itemId={merchantItemId || ''} size="lg"/><div><h3 className="text-xl font-semibold">{language === 'ar' ? selectedItem.nameAr : selectedItem.nameEn}</h3><p className="mt-1 text-sm text-white/45">{language === 'ar' ? 'سعر الوحدة' : 'Unit price'}: {merchantPrice} {language === 'ar' ? 'رصيد' : 'credits'}</p><p className="mt-1 text-xs text-white/45">{language === 'ar' ? 'المتاح' : 'Available'}: {selectedInv?.quantity ?? 0}</p></div></div><label className="block text-sm text-white/60">{language === 'ar' ? 'الكمية' : 'Quantity'}<input type="number" min={1} max={merchantMax} value={merchantQuantity} onChange={e => setMerchantQuantity(Math.max(1, Math.min(merchantMax || 1, Number(e.target.value)||1)))} className="mt-2 w-full rounded-xl border border-white/10 bg-[#090C12] px-4 py-3 text-lg text-white"/></label><div className="rounded-xl bg-white/[.04] p-4"><div className="flex justify-between text-sm"><span>{language === 'ar' ? 'إجمالي البيع' : 'Sale total'}</span><span>{(merchantPrice*merchantQuantity).toLocaleString()} {language === 'ar' ? 'رصيد' : 'credits'}</span></div><p className="mt-2 text-xs text-white/40">{language === 'ar' ? 'حد البيع اليومي: 1500' : 'Daily sale limit: 1500'}{merchantDailySold !== null ? `/${merchantDailySold}` : ''} {language === 'ar' ? 'وحدة مورد' : 'resource units'}</p></div>{merchantNotice && <p role="alert" className="rounded-xl bg-rose-400/10 p-3 text-sm text-rose-200">{merchantNotice}</p>}<button disabled={merchantBusy || merchantMax<1 || merchantQuantity>merchantMax} onClick={() => void submitMerchantSale()} className="w-full rounded-xl bg-[#397BFF] px-5 py-3.5 font-semibold text-white disabled:opacity-40">{merchantBusy ? (language === 'ar' ? 'جارٍ البيع…' : 'Selling…') : (language === 'ar' ? 'تأكيد البيع' : 'Confirm sale')}</button></div>}
          </section></div></main><footer className="border-t border-white/10 pt-4 text-center text-[11px] text-white/30">NEXORA CITY · {language === 'ar' ? 'تجارة مباشرة وآمنة' : 'Direct, secure trade'}</footer>
      </div>
    </div>}
    <div className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-4">
      <div className="flex items-center justify-between">
        <button type="button" onClick={() => { resetMerchant(); setMerchantDailySold(null); setMerchantOpen(true); }} className="inline-flex items-center gap-2 rounded-xl border border-cyan-200/20 bg-cyan-200/[.06] px-3 py-2 text-xs font-semibold text-[#9CBFFF] hover:bg-cyan-200/10"><ShoppingBag size={15} />{language === 'ar' ? 'البيع لـ NEXORA' : 'Sell to NEXORA'}</button>
        <h2 className="text-base font-semibold text-[#F4F5F7]">{title}</h2>
        <Package className="w-4 h-4 text-[#63A5FF]" />
      </div>
      <div className="space-y-2 rounded-xl border border-white/8 bg-[#0B0D12] p-3.5">
        <div className="flex items-center justify-between gap-2 text-xs">
          <span className="text-[#9299A6]">{language === 'ar' ? 'سعة المخزون' : 'Inventory capacity'}</span>
          <span className="font-mono-num font-semibold text-[#F4F5F7]">{totalQuantity.toLocaleString()} / {capacity.toLocaleString()}</span>
        </div>
        <div className="h-2 overflow-hidden rounded-full bg-white/8">
          <div className={`h-full rounded-full transition-all ${capacityPercent >= 95 ? 'bg-rose-400' : 'bg-[#397BFF]'}`} style={{ width: `${capacityPercent}%` }} />
        </div>
        <div className="flex items-center justify-between gap-2 text-[10px] text-[#77808F]"><span>{language === 'ar' ? 'داخل المخزون' : 'In inventory'}: {inventoryQuantity.toLocaleString()}</span><span>{language === 'ar' ? 'معروض في السوق' : 'Listed on market'}: {listedQuantity.toLocaleString()}</span></div>
        <p className="text-[10px] text-[#77808F]">{language === 'ar' ? 'تُحسب الموارد المعروضة للبيع ضمن السعة حتى يتم شراؤها أو إلغاء العرض.' : 'Listed stock still uses capacity until it is sold or the listing is cancelled.'}</p>
      </div>
      {availableItems.length === 0 ? (
        <div className="py-10 text-center space-y-3">
          <p className="text-sm text-[#9299A6]">
            {language === 'ar'
              ? (listedQuantity > 0 ? `لا توجد موارد متاحة في الحقيبة؛ لديك ${listedQuantity.toLocaleString()} وحدة معروضة في السوق.` : 'مخزونك فارغ حالياً. اشترِ موارد أولية من السوق للبدء.')
              : (listedQuantity > 0 ? `${listedQuantity.toLocaleString()} units are currently listed on the market; no stock is available in your bag.` : 'Your inventory is empty. Purchase raw resources from the Market.')}
          </p>
          <button
            type="button"
            onClick={onGoToMarket}
            className="min-h-[42px] px-5 rounded-xl bg-[#397BFF] hover:bg-[#2F6DE0] text-white text-xs font-semibold"
          >
            {marketLabel}
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {availableItems.map((inv) => {
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
                    <p className="text-xs text-[#9299A6] mt-0.5">~{'$'}{item.basePrice}</p>
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
    </>
  );
}
