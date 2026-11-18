import { Factory } from 'lucide-react';
import { useState } from 'react';
import { useToast } from '../../components/ui/ToastProvider';
import { ITEM_MAP, MANUFACTURING_RECIPES } from '../../data/catalog';
import { useTranslations } from '../../i18n/translations';
import { calculateManufacturingCost } from '../../lib/economy';
import { manufactureRecipe } from '../../services/gameService';
import type { InventoryItem, Language, PlayerProfile, Wallet } from '../../types/game';

interface ManufacturingPanelProps {
  profile: PlayerProfile;
  wallet: Wallet | null;
  inventory: InventoryItem[];
  language: Language;
  onNavigateToExchange: () => void;
}

export function ManufacturingPanel({ profile, wallet, inventory, language, onNavigateToExchange }: ManufacturingPanelProps) {
  const t = useTranslations(language);
  const { showToast } = useToast();
  const [quantity, setQuantity] = useState(1);
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const inventoryMap = new Map<string, number>(inventory.map((item) => [item.itemId, item.quantity] as [string, number]));

  async function handleManufacture(recipeId: string) {
    const batches = Math.max(1, Math.min(999, Math.floor(quantity || 1)));
    setBusyKey(recipeId);
    try {
      await manufactureRecipe(profile.uid, recipeId, batches);
      showToast(language === 'ar' ? 'تم الإنتاج بنجاح!' : 'Production completed!', 'success');
    } catch (error) {
      const code = error instanceof Error ? error.message : '';
      showToast(
        code === 'MISSING_INPUTS'
          ? (language === 'ar' ? 'المدخلات غير كافية في المخزون.' : 'Insufficient input materials in inventory.')
          : code === 'INDUSTRY_SKILL_TOO_LOW'
            ? (language === 'ar' ? 'مستوى مهارة الصناعة غير كافٍ لهذه الوصفة.' : 'Industry skill level too low for this recipe.')
            : (language === 'ar' ? 'الرصيد غير كافٍ لتكلفة التشغيل.' : 'Insufficient credits for processing cost.'),
        'error',
      );
    } finally {
      setBusyKey(null);
    }
  }

  return (
    <div className="space-y-4">
      <div className="bg-[#141821] border border-white/8 rounded-2xl p-4 space-y-3">
        <div className="flex items-center justify-between gap-3">
          <div>
            <h2 className="text-sm font-bold text-[#F4F5F7]">{language === 'ar' ? 'كمية التصنيع' : 'Batch quantity'}</h2>
            <p className="text-xs text-[#9299A6] mt-1">{language === 'ar' ? 'اختر عدد الدفعات لكل وصفة' : 'Choose how many batches to run per recipe'}</p>
          </div>
          <span className="text-sm font-mono-num font-bold text-[#E04455]">×{quantity}</span>
        </div>
        <div className="grid grid-cols-3 gap-2">
          {[1, 5, 10].map((value) => (
            <button key={value} type="button" onClick={() => setQuantity(value)} className={`min-h-[42px] rounded-xl border text-sm font-semibold transition-colors ${quantity === value ? 'bg-[#B91C32] border-[#E04455] text-white' : 'bg-[#0B0D12] border-white/10 text-[#C5CAD3]'}`}>×{value}</button>
          ))}
        </div>
        <label className="block space-y-1.5">
          <span className="text-xs text-[#9299A6]">{language === 'ar' ? 'أو أدخل كمية مخصصة (1–999)' : 'Or enter a custom quantity (1–999)'}</span>
          <input type="number" min="1" max="999" step="1" value={quantity} onChange={(event) => setQuantity(Math.max(1, Math.min(999, Number(event.target.value) || 1)))} className="w-full min-h-[44px] px-3.5 rounded-xl bg-[#0B0D12] border border-white/10 text-sm text-[#F4F5F7] focus:outline-none focus:border-[#E04455]" />
        </label>
        <p className="text-[11px] text-[#9299A6]">{language === 'ar' ? 'التصنيع يستهلك المواد الخام ويحوّلها إلى منتجات وسيطة أو نهائية.' : 'Manufacturing consumes raw materials and turns them into intermediate or final goods.'}</p>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {MANUFACTURING_RECIPES.map((recipe) => {
          const output = ITEM_MAP[recipe.outputItemId];
          if (!output) return null;
          const unitCost = calculateManufacturingCost(recipe, profile.skills.industry || 0);
          const totalCost = unitCost * quantity;
          const hasSkill = (profile.skills.industry || 0) >= recipe.requiredIndustrySkill;
          const hasInputs = recipe.inputs.every((input) => (inventoryMap.get(input.itemId) || 0) >= input.qty * quantity);
          const canAfford = (wallet?.balance ?? 0) >= totalCost;
          const outputValue = output.basePrice * recipe.outputQty * quantity;
          const inputValue = recipe.inputs.reduce((sum, input) => sum + (ITEM_MAP[input.itemId]?.basePrice || 0) * input.qty * quantity, 0);
          const margin = outputValue - inputValue - totalCost;
          return (
            <article key={recipe.id} className="bg-[#141821] border border-white/8 rounded-2xl p-5 flex flex-col justify-between gap-4">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <h3 className="text-base font-bold text-[#F4F5F7]">{language === 'ar' ? output.nameAr : output.nameEn} ×{recipe.outputQty * quantity}</h3>
                  <p className="text-xs text-[#9299A6] mt-0.5">{language === 'ar' ? 'مهارة الصناعة المطلوبة:' : 'Required Industry:'} <span className="font-mono-num text-[#F4F5F7]">Lv.{recipe.requiredIndustrySkill}</span> · +{recipe.xpReward * quantity} XP</p>
                </div>
                <Factory className="w-5 h-5 text-[#E04455] shrink-0" />
              </div>
              <div className="space-y-2 bg-[#0B0D12] border border-white/6 rounded-xl p-3.5">
                {recipe.inputs.map((input) => {
                  const item = ITEM_MAP[input.itemId];
                  const owned = inventoryMap.get(input.itemId) || 0;
                  const required = input.qty * quantity;
                  const enough = owned >= required;
                  return <div key={input.itemId} className="flex items-center justify-between text-xs"><span className="text-[#9299A6]">{item ? (language === 'ar' ? item.nameAr : item.nameEn) : input.itemId}</span><span className={`font-mono-num font-semibold ${enough ? 'text-emerald-400' : 'text-[#E04455]'}`}>{owned} / {required}</span></div>;
                })}
                <div className="flex items-center justify-between text-xs pt-2 border-t border-white/6"><span className="text-[#9299A6]">{t.processingCost}</span><span className="font-mono-num font-semibold text-[#F4F5F7]">${totalCost.toLocaleString()}</span></div>
                <div className="flex items-center justify-between text-xs"><span className="text-[#9299A6]">{t.estMarketValue}</span><span className="font-mono-num text-[#F4F5F7]">~${outputValue.toLocaleString()}</span></div>
                <div className="flex items-center justify-between text-xs"><span className="text-[#9299A6]">{t.estNetMargin}</span><span className={`font-mono-num font-semibold ${margin >= 0 ? 'text-emerald-400' : 'text-[#E04455]'}`}>{margin >= 0 ? '+' : ''}{margin.toLocaleString()}</span></div>
              </div>
              <div className="flex items-center gap-2.5">
                <button type="button" disabled={!hasSkill || !hasInputs || !canAfford || busyKey === recipe.id} onClick={() => void handleManufacture(recipe.id)} className="flex-1 min-h-[44px] px-4 rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-xs font-semibold transition-colors disabled:bg-[#1B2230] disabled:text-[#9299A6]">
                  {busyKey === recipe.id ? '...' : !hasSkill ? (language === 'ar' ? 'مهارة غير كافية' : 'Skill too low') : !hasInputs ? t.missingInputs : !canAfford ? (language === 'ar' ? 'رصيد غير كافٍ' : 'Insufficient balance') : (language === 'ar' ? `تصنيع ×${quantity}` : `Produce ×${quantity}`)}
                </button>
                {!hasInputs && <button type="button" onClick={onNavigateToExchange} className="min-h-[44px] px-3.5 rounded-xl bg-[#1B2230] hover:bg-[#232C3E] text-[#F4F5F7] text-xs font-medium whitespace-nowrap">{language === 'ar' ? 'شراء المواد' : 'Buy materials'}</button>}
              </div>
            </article>
          );
        })}
      </div>
    </div>
  );
}
