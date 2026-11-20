import { useEffect, useState } from 'react';
import { Package } from 'lucide-react';
import { ResourceIcon } from '../../components/ui/ResourceIcon';
import { ITEM_MAP } from '../../data/catalog';
import type { InventoryItem, Language, MarketListing } from '../../types/game';
import { fetchInventoryCapacityUsage } from '../../services/gameService';

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
    <div className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-4">
      <div className="flex items-center justify-between">
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
  );
}
