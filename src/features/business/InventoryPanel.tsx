import { Package } from 'lucide-react';
import { ResourceIcon } from '../../components/ui/ResourceIcon';
import { ITEM_MAP } from '../../data/catalog';
import type { InventoryItem, Language } from '../../types/game';

interface InventoryPanelProps {
  inventory: InventoryItem[];
  language: Language;
  title: string;
  marketLabel: string;
  onGoToMarket: () => void;
}

export function InventoryPanel({ inventory, language, title, marketLabel, onGoToMarket }: InventoryPanelProps) {
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
        <p className="text-[10px] text-[#77808F]">{language === 'ar' ? 'تزداد السعة تلقائياً مع كل مستوى لاعب.' : 'Capacity increases automatically with each player level.'}</p>
      </div>
      {availableItems.length === 0 ? (
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
