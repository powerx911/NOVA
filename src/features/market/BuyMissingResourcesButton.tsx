import { useState } from 'react';
import { Loader2, ShoppingCart } from 'lucide-react';
import { ITEM_MAP } from '../../data/catalog';
import { ResourceIcon } from '../../components/ui/ResourceIcon';
import { useToast } from '../../components/ui/ToastProvider';
import { buyMissingResources, fetchMarketListings, type MissingResourcePurchaseItem } from '../../services/gameService';
import type { InventoryItem, Language, MarketListing, Wallet } from '../../types/game';

interface Requirement { itemId: string; quantity: number; }
interface PlanLine extends MissingResourcePurchaseItem { sellerName: string; }
interface Props { uid: string; requirements: Requirement[]; inventory: InventoryItem[]; wallet: Wallet | null; language: Language; }

function createPlan(requirements: Requirement[], inventory: InventoryItem[], listings: MarketListing[], uid: string): PlanLine[] {
  const owned = new Map(inventory.map((item) => [item.itemId, item.quantity]));
  const totals = new Map<string, number>();
  for (const requirement of requirements) {
    totals.set(requirement.itemId, (totals.get(requirement.itemId) ?? 0) + Math.max(0, Math.floor(requirement.quantity)));
  }
  const plan: PlanLine[] = [];
  for (const [itemId, required] of totals) {
    let missing = Math.max(0, required - (owned.get(itemId) ?? 0));
    if (!missing) continue;
    const offers = listings
      .filter((listing) => listing.itemId === itemId && listing.status === 'active' && listing.remainingQty > 0 && listing.sellerUid !== uid)
      .sort((a, b) => a.unitPrice - b.unitPrice || String(a.createdAt).localeCompare(String(b.createdAt)) || a.id.localeCompare(b.id));
    for (const offer of offers) {
      if (missing <= 0) break;
      const quantity = Math.min(missing, offer.remainingQty);
      plan.push({ listingId: offer.id, itemId, quantity, expectedUnitPrice: offer.unitPrice, sellerName: offer.sellerName });
      missing -= quantity;
    }
    if (missing > 0) throw new Error('MARKET_SUPPLY_SHORT');
  }
  return plan;
}

function planSignature(plan: PlanLine[]): string {
  return JSON.stringify(plan.map(({ listingId, itemId, quantity, expectedUnitPrice }) => ({ listingId, itemId, quantity, expectedUnitPrice })));
}

export function BuyMissingResourcesButton({ uid, requirements, inventory, wallet, language }: Props) {
  const isAr = language === 'ar';
  const { showToast } = useToast();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [quoteChanged, setQuoteChanged] = useState(false);
  const [plan, setPlan] = useState<PlanLine[]>([]);
  const subtotal = plan.reduce((sum, line) => sum + line.quantity * line.expectedUnitPrice, 0);

  async function openQuote() {
    setBusy(true);
    try {
      const next = createPlan(requirements, inventory, await fetchMarketListings(), uid);
      if (!next.length) {
        showToast(isAr ? 'كل المواد المطلوبة متوفرة بالفعل.' : 'All required materials are already available.', 'success');
        return;
      }
      setPlan(next);
      setQuoteChanged(false);
      setOpen(true);
    } catch (error) {
      const code = error instanceof Error ? error.message : '';
      showToast(code === 'MARKET_SUPPLY_SHORT'
        ? (isAr ? 'لا توجد كمية كافية من بعض المواد في السوق حالياً.' : 'The market does not have enough of one or more required materials.')
        : (isAr ? 'تعذر تجهيز قائمة شراء النواقص.' : 'Could not prepare the missing-resource quote.'), 'error');
    } finally { setBusy(false); }
  }

  async function confirmPurchase() {
    setBusy(true);
    try {
      const latestPlan = createPlan(requirements, inventory, await fetchMarketListings(), uid);
      if (planSignature(latestPlan) !== planSignature(plan)) {
        setPlan(latestPlan);
        setQuoteChanged(true);
        showToast(isAr
          ? 'تغيرت الأسعار أو الكميات. راجع الملخص الجديد ثم أكد الشراء مرة أخرى.'
          : 'Prices or quantities changed. Review the updated quote and confirm again.', 'info');
        return;
      }
      await buyMissingResources(
        plan.map(({ listingId, itemId, quantity, expectedUnitPrice }) => ({ listingId, itemId, quantity, expectedUnitPrice })),
        requirements,
      );
      setOpen(false);
      setQuoteChanged(false);
      showToast(isAr ? 'تم شراء المواد الناقصة بنجاح.' : 'Missing materials purchased successfully.', 'success');
    } catch (error) {
      const code = error instanceof Error ? error.message : '';
      if (code === 'INVENTORY_REQUIREMENT_CHANGED') {
        setOpen(false);
        if (typeof window !== 'undefined') window.dispatchEvent(new Event('nova:refresh-game'));
        showToast(isAr
          ? 'تغير مخزونك قبل الشراء. حدّثنا بياناتك؛ افتح عرض النواقص من جديد.'
          : 'Your inventory changed before purchase. Data is refreshing; reopen the missing-resource quote.', 'info');
      } else if (code === 'MARKET_QUOTE_CHANGED' || code === 'INSUFFICIENT_LISTING_QTY' || code === 'LISTING_NOT_FOUND') {
        try {
          const refreshedPlan = createPlan(requirements, inventory, await fetchMarketListings(), uid);
          if (!refreshedPlan.length) { setOpen(false); setPlan([]); }
          else { setPlan(refreshedPlan); setQuoteChanged(true); }
        } catch { setPlan([]); setOpen(false); }
        showToast(isAr
          ? 'تغيرت عروض السوق أثناء التأكيد. راجع الملخص الجديد وأكد من جديد.'
          : 'Market offers changed during confirmation. Review the updated quote and confirm again.', 'info');
      } else {
        showToast(code === 'INSUFFICIENT_FUNDS'
          ? (isAr ? 'رصيدك لا يكفي لإتمام الشراء مع ضريبة السوق.' : 'Your balance is not enough for the purchase and market tax.')
          : (isAr ? 'تعذر شراء المواد الناقصة.' : 'Could not purchase the missing materials.'), 'error');
      }
    } finally { setBusy(false); }
  }

  return (
    <>
      <button type="button" onClick={() => void openQuote()} disabled={busy}
        className="min-h-[44px] flex-1 px-3 rounded-xl bg-[#2468D8] hover:bg-[#347CF0] text-white text-xs font-semibold disabled:opacity-50">
        {busy && !open ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : <span className="inline-flex items-center justify-center gap-1.5"><ShoppingCart className="w-3.5 h-3.5" />{isAr ? 'شراء الموارد' : 'Buy resources'}</span>}
      </button>
      {open && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/70 p-4" role="presentation">
          <section role="dialog" aria-modal="true" aria-labelledby="buy-missing-title" className="w-full max-w-lg rounded-2xl border border-white/10 bg-[#111A2C] p-5 shadow-2xl space-y-4">
            <div className="flex items-center justify-between gap-3">
              <div>
                <h3 id="buy-missing-title" className="text-base font-bold text-white">{isAr ? 'تأكيد شراء المواد الناقصة' : 'Confirm missing-resource purchase'}</h3>
                <p className="mt-1 text-[11px] text-[#91A2BD]">{isAr ? 'تم اختيار أقل العروض سعراً، وسيعيد الخادم التحقق من كل عرض قبل الخصم.' : 'Cheapest offers are selected; the server revalidates every offer before charging.'}</p>
              </div>
              <button type="button" onClick={() => setOpen(false)} disabled={busy} className="rounded-lg px-2 py-1 text-[#9AAAC7] hover:text-white">✕</button>
            </div>
            <div className="max-h-64 overflow-y-auto space-y-2">
              {plan.map((line) => {
                const item = ITEM_MAP[line.itemId];
                return (
                  <div key={line.listingId} className="flex items-center justify-between gap-3 rounded-xl bg-[#0B1220] p-3">
                    <div className="flex min-w-0 items-center gap-2">
                      <ResourceIcon itemId={line.itemId} size="sm" />
                      <div className="min-w-0">
                        <p className="truncate text-xs font-semibold text-white">{item ? (isAr ? item.nameAr : item.nameEn) : line.itemId} ×{line.quantity}</p>
                        <p className="truncate text-[10px] text-[#8192AD]">{isAr ? 'البائع: ' : 'Seller: '}{line.sellerName}</p>
                      </div>
                    </div>
                    <div className="shrink-0 text-end">
                      <p className="font-mono-num text-xs font-semibold text-white">${(line.quantity * line.expectedUnitPrice).toLocaleString()}</p>
                      <p className="text-[10px] text-[#8192AD]">${line.expectedUnitPrice.toLocaleString()} / {isAr ? 'وحدة' : 'unit'}</p>
                    </div>
                  </div>
                );
              })}
            </div>
            <div className="flex items-center justify-between border-t border-white/10 pt-3">
              <div>
                <p className="text-xs text-[#A8B6CD]">{isAr ? 'الإجمالي قبل الضريبة' : 'Subtotal before tax'}</p>
                <p className="text-[10px] text-[#8192AD]">{isAr ? 'تُضاف ضريبة السوق حسب مهارتك والأحداث النشطة.' : 'Market tax is added according to your skill and active events.'}</p>
                <p className="text-[10px] text-[#8192AD]">{isAr ? 'الرصيد: ' : 'Balance: '}${(wallet?.balance ?? 0).toLocaleString()}</p>
              </div>
              <p className="font-mono-num text-lg font-bold text-white">${subtotal.toLocaleString()}</p>
            </div>
            <div className="flex gap-2">
              <button type="button" onClick={() => setOpen(false)} disabled={busy} className="min-h-11 flex-1 rounded-xl border border-white/10 bg-[#182338] text-xs font-semibold text-[#CBD5E1]">{isAr ? 'إلغاء' : 'Cancel'}</button>
              <button type="button" onClick={() => void confirmPurchase()} disabled={busy || !plan.length} className="min-h-11 flex-1 rounded-xl bg-[#2468D8] hover:bg-[#347CF0] text-xs font-bold text-white disabled:opacity-50">
                {busy ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : quoteChanged ? (isAr ? 'تأكيد السعر الجديد' : 'Confirm updated quote') : (isAr ? 'تأكيد الشراء' : 'Confirm purchase')}
              </button>
            </div>
          </section>
        </div>
      )}
    </>
  );
}
