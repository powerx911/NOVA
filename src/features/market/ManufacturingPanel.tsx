import { Factory, Timer } from 'lucide-react';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useToast } from '../../components/ui/ToastProvider';
import { BuyMissingResourcesButton } from './BuyMissingResourcesButton';
import { ConfirmDialog } from '../../components/ui/ConfirmDialog';
import { ITEM_MAP, MANUFACTURING_RECIPES } from '../../data/catalog';
import { ResourceIcon } from '../../components/ui/ResourceIcon';
import { useTranslations } from '../../i18n/translations';
import { calculateManufacturingCost } from '../../lib/economy';
import { cancelManufacturingJob, completeManufacturingJob, getManufacturingJob, manufactureRecipe, type ManufacturingJob } from '../../services/gameService';
import type { InventoryItem, Language, PlayerProfile, Wallet } from '../../types/game';

interface ManufacturingPanelProps {
  profile: PlayerProfile;
  wallet: Wallet | null;
  inventory: InventoryItem[];
  language: Language;
  onNavigateToExchange: () => void;
}

const formatDuration = (seconds: number, isAr: boolean) => {
  const safe = Math.max(0, Math.ceil(seconds));
  const minutes = Math.floor(safe / 60);
  const remaining = safe % 60;
  return minutes > 0 ? (isAr ? `${minutes}د ${remaining}ث` : `${minutes}m ${remaining}s`) : (isAr ? `${remaining}ث` : `${remaining}s`);
};

export function ManufacturingPanel({ profile, wallet, inventory, language, onNavigateToExchange }: ManufacturingPanelProps) {
  const t = useTranslations(language);
  const { showToast } = useToast();
  const isAr = language === 'ar';
  const [recipeQuantities, setRecipeQuantities] = useState<Record<string, number>>({});
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [activeJob, setActiveJob] = useState<ManufacturingJob | null>(null);
  const [nowMs, setNowMs] = useState(() => Date.now());
  const [jobLoading, setJobLoading] = useState(true);
  const [cancelDialogOpen, setCancelDialogOpen] = useState(false);
  const [cancelBusy, setCancelBusy] = useState(false);
  const completionAttempted = useRef<string | null>(null);
  const inventoryMap = useMemo(() => new Map<string, number>(inventory.map((item) => [item.itemId, item.quantity] as [string, number])), [inventory]);

  useEffect(() => {
    let mounted = true;
    void getManufacturingJob()
      .then((job) => { if (mounted) setActiveJob(job); })
      .catch(() => { if (mounted) showToast(isAr ? 'تعذر تحميل حالة التصنيع الحالية.' : 'Could not load current manufacturing status.', 'error'); })
      .finally(() => { if (mounted) setJobLoading(false); });
    const timer = window.setInterval(() => setNowMs(Date.now()), 1000);
    return () => { mounted = false; window.clearInterval(timer); };
  }, [isAr, showToast]);

  const finishJob = useCallback(async (job: ManufacturingJob, silent = false) => {
    if (completionAttempted.current === job.id) return;
    completionAttempted.current = job.id;
    try {
      await completeManufacturingJob(job.id);
      setActiveJob(null);
      completionAttempted.current = null;
      window.dispatchEvent(new Event('nova:refresh-game'));
      if (!silent) showToast(isAr ? 'اكتمل التصنيع وأضيفت المنتجات إلى مخزونك.' : 'Manufacturing completed and items added to inventory.', 'success');
    } catch (error) {
      const code = error instanceof Error ? error.message : '';
      if (code === 'INVENTORY_CAPACITY_EXCEEDED') {
        showToast(isAr ? 'اكتمل التصنيع، لكن مخزونك ممتلئ. بع بعض الموارد ثم استلم الإنتاج.' : 'Production is ready, but your inventory is full. Sell some items, then collect it.', 'error');
      } else if (code !== 'MANUFACTURING_JOB_NOT_FINISHED') {
        showToast(isAr ? 'تعذر استلام الإنتاج. حاول مجدداً.' : 'Could not collect production. Please try again.', 'error');
      }
      if (code !== 'INVENTORY_CAPACITY_EXCEEDED') { completionAttempted.current = null; if (code === 'MANUFACTURING_JOB_NOT_FINISHED') setNowMs(Date.now() + 1000); }
    }
  }, [isAr, showToast]);

  const jobEndsAt = activeJob ? Date.parse(activeJob.ends_at) : 0;
  const jobRemainingSeconds = activeJob ? Math.max(0, Math.ceil((jobEndsAt - nowMs) / 1000)) : 0;
  const jobReady = Boolean(activeJob && jobRemainingSeconds === 0);

  useEffect(() => {
    if (activeJob && jobReady && completionAttempted.current !== activeJob.id) {
      void finishJob(activeJob, true);
    }
  }, [activeJob, jobReady, finishJob]);

  async function handleCancelJob() {
    if (!activeJob || jobReady || cancelBusy) return;
    setCancelBusy(true);
    try {
      await cancelManufacturingJob(activeJob.id);
      setCancelDialogOpen(false);
      setActiveJob(null);
      completionAttempted.current = null;
      window.dispatchEvent(new Event('nova:refresh-game'));
      showToast(isAr ? 'تم إلغاء التصنيع وإرجاع جميع المواد إلى مخزونك.' : 'Manufacturing cancelled and all input materials returned to inventory.', 'success');
    } catch (error) {
      const code = error instanceof Error ? error.message : '';
      if (code === 'MANUFACTURING_JOB_ALREADY_FINISHED') {
        setCancelDialogOpen(false);
        setNowMs(Date.now() + 1000);
        showToast(isAr ? 'انتهى وقت التصنيع بالفعل؛ جارٍ استلام الإنتاج.' : 'The production timer has ended; collecting the output now.', 'info');
      } else if (code === 'MANUFACTURING_JOB_ALREADY_COMPLETED' || code === 'MANUFACTURING_JOB_CANCELLED') {
        setCancelDialogOpen(false);
        setActiveJob(null);
        window.dispatchEvent(new Event('nova:refresh-game'));
      } else {
        showToast(isAr ? 'تعذر إلغاء التصنيع. لم تُخصم مواد إضافية.' : 'Could not cancel manufacturing. No additional materials were consumed.', 'error');
      }
    } finally {
      setCancelBusy(false);
    }
  }

  function getRecipeQuantity(recipeId: string) { return Math.max(1, Math.min(999, Math.floor(recipeQuantities[recipeId] || 1))); }

  async function handleManufacture(recipeId: string) {
    const batches = getRecipeQuantity(recipeId);
    setBusyKey(recipeId);
    try {
      const job = await manufactureRecipe(profile.uid, recipeId, batches);
      completionAttempted.current = null;
      setActiveJob(job);
      showToast(isAr ? 'بدأ التصنيع. سيصل الإنتاج بعد انتهاء المؤقت.' : 'Production started. Your items will be ready when the timer ends.', 'success');
    } catch (error) {
      const code = error instanceof Error ? error.message : '';
      const messages: Record<string, string> = {
        MISSING_INPUTS: isAr ? 'الموارد غير كافية في المخزون.' : 'Insufficient resources in inventory.',
        INDUSTRY_SKILL_TOO_LOW: isAr ? 'مستوى مهارة الصناعة غير كافٍ لهذه الوصفة.' : 'Industry skill level too low for this recipe.',
        INSUFFICIENT_FUNDS: isAr ? 'الرصيد غير كافٍ لتكلفة التشغيل.' : 'Insufficient credits for processing cost.',
        MANUFACTURING_JOB_IN_PROGRESS: isAr ? 'لديك عملية تصنيع جارية بالفعل.' : 'You already have a manufacturing job in progress.',
      };
      showToast(messages[code] || (isAr ? 'تعذر بدء التصنيع.' : 'Could not start manufacturing.'), 'error');
    } finally {
      setBusyKey(null);
    }
  }

  return (
    <div className="space-y-4">
      {activeJob && (
        <div className="rounded-2xl border border-[#397BFF]/40 bg-[#111C2E] p-4 space-y-3">
          <div className="flex items-center justify-between gap-3">
            <div className="flex items-center gap-2">
              <Timer className="h-5 w-5 text-[#63A5FF]" />
              <h3 className="text-sm font-bold text-white">{isAr ? 'عملية تصنيع جارية' : 'Manufacturing in progress'}</h3>
            </div>
            <span className="text-xs font-mono-num text-[#9CBFFF]">{jobReady ? (isAr ? 'جاهز للاستلام' : 'Ready to collect') : formatDuration(jobRemainingSeconds, isAr)}</span>
          </div>
          <div className="flex items-center gap-3">
            <ResourceIcon itemId={activeJob.output_item_id} size="lg" />
            <div className="min-w-0">
              <p className="text-sm font-semibold text-white">{ITEM_MAP[activeJob.output_item_id] ? (isAr ? ITEM_MAP[activeJob.output_item_id].nameAr : ITEM_MAP[activeJob.output_item_id].nameEn) : activeJob.output_item_id} ×{activeJob.output_qty}</p>
              <p className="text-xs text-[#9AAAC7]">{isAr ? 'تُضاف المنتجات تلقائيًا عند انتهاء العداد حتى لو أغلقت اللعبة.' : 'Output is added automatically when the timer ends, even if you close the game.'}</p>
            </div>
          </div>
          {jobReady ? (
            <button type="button" onClick={() => { completionAttempted.current = null; void finishJob(activeJob); }} className="w-full min-h-[42px] rounded-xl bg-[#397BFF] hover:bg-[#2F6DE0] text-white text-xs font-semibold">
              {isAr ? 'استلام الإنتاج' : 'Collect production'}
            </button>
          ) : (
            <button type="button" onClick={() => setCancelDialogOpen(true)} disabled={cancelBusy} className="w-full min-h-[42px] rounded-xl border border-rose-500/40 bg-rose-950/30 hover:bg-rose-900/50 text-rose-200 text-xs font-semibold disabled:opacity-50">
              {isAr ? 'إلغاء التصنيع وإرجاع المواد' : 'Cancel manufacturing and return materials'}
            </button>
          )}
        </div>
      )}

      {jobLoading && <p className="text-xs text-[#9299A6]">{isAr ? 'جارٍ تحميل حالة التصنيع…' : 'Loading manufacturing status…'}</p>}

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {MANUFACTURING_RECIPES.map((recipe) => {
          const quantity = getRecipeQuantity(recipe.id);
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
          const secondsPerUnit = output.tier === 'final' ? 60 : 30;
          const processingSeconds = secondsPerUnit * recipe.outputQty * quantity;
          return (
            <article key={recipe.id} className="bg-[#141821] border border-white/8 rounded-2xl p-5 flex flex-col justify-between gap-4">
              <div className="flex items-start justify-between gap-3">
                <div className="flex min-w-0 items-center gap-3">
                  <ResourceIcon itemId={recipe.outputItemId} size="lg" />
                  <div className="min-w-0">
                    <h3 className="text-base font-bold text-[#EAF1FF]">{isAr ? output.nameAr : output.nameEn} ×{recipe.outputQty * quantity}</h3>
                    <p className="text-xs text-[#9AAAC7] mt-0.5">{isAr ? 'مهارة الصناعة المطلوبة:' : 'Required Industry:'} <span className="font-mono-num text-[#F4F5F7]">Lv.{recipe.requiredIndustrySkill}</span> · +{recipe.xpReward * quantity} XP</p>
                  </div>
                </div>
                <Factory className="w-5 h-5 text-[#63A5FF] shrink-0" />
              </div>
              <div className="rounded-xl border border-white/8 bg-[#0B0D12] p-3 space-y-2">
                <div className="flex items-center justify-between"><span className="text-xs text-[#9299A6]">{isAr ? 'كمية التصنيع' : 'Batch quantity'}</span><span className="text-sm font-mono-num font-bold text-[#F4F5F7]">×{quantity}</span></div>
                <div className="grid grid-cols-3 gap-2">
                  {[1, 5, 10].map((value) => <button key={value} type="button" onClick={() => setRecipeQuantities((previous) => ({ ...previous, [recipe.id]: value }))} className={`min-h-[36px] rounded-lg border text-xs font-semibold ${quantity === value ? 'bg-[#B91C32] border-[#E04455] text-white' : 'bg-[#141821] border-white/10 text-[#C5CAD3]'}`}>×{value}</button>)}
                </div>
                <input aria-label={isAr ? 'كمية هذه الوصفة' : 'Quantity for this recipe'} type="number" min="1" max="999" step="1" value={quantity} onChange={(event) => setRecipeQuantities((previous) => ({ ...previous, [recipe.id]: Math.max(1, Math.min(999, Number(event.target.value) || 1)) }))} className="w-full min-h-[40px] rounded-lg border border-white/10 bg-[#141821] px-3 text-sm text-[#F4F5F7]" />
              </div>
              <div className="space-y-2 bg-[#0B0D12] border border-white/6 rounded-xl p-3.5">
                {recipe.inputs.map((input) => {
                  const item = ITEM_MAP[input.itemId];
                  const owned = inventoryMap.get(input.itemId) || 0;
                  const required = input.qty * quantity;
                  const enough = owned >= required;
                  return <div key={input.itemId} className="flex items-center justify-between text-xs"><span className="flex min-w-0 items-center gap-2 text-[#9AAAC7]">{item && <ResourceIcon itemId={input.itemId} size="sm" />}{item ? (isAr ? item.nameAr : item.nameEn) : input.itemId}</span><span className={`font-mono-num font-semibold ${enough ? 'text-emerald-400' : 'text-rose-300'}`}>{owned} / {required}</span></div>;
                })}
                <div className="flex items-center justify-between text-xs pt-2 border-t border-white/6"><span className="text-[#9299A6]">{t.processingCost}</span><span className="font-mono-num font-semibold text-[#F4F5F7]">${totalCost.toLocaleString()}</span></div>
                <div className="flex items-center justify-between text-xs"><span className="text-[#9299A6]">{isAr ? 'مدة التصنيع' : 'Production time'}</span><span className="font-mono-num font-semibold text-[#F4F5F7]">{formatDuration(processingSeconds, isAr)}</span></div>
                <div className="flex items-center justify-between text-xs"><span className="text-[#9299A6]">{t.estMarketValue}</span><span className="font-mono-num text-[#F4F5F7]">~${outputValue.toLocaleString()}</span></div>
                <div className="flex items-center justify-between text-xs"><span className="text-[#9299A6]">{t.estNetMargin}</span><span className={`font-mono-num font-semibold ${margin >= 0 ? 'text-emerald-400' : 'text-[#E04455]'}`}>{margin >= 0 ? '+' : ''}{margin.toLocaleString()}</span></div>
              </div>
              <div className="flex items-center gap-2.5">
                <button type="button" disabled={jobLoading || Boolean(activeJob) || !hasSkill || !hasInputs || !canAfford || busyKey === recipe.id} onClick={() => void handleManufacture(recipe.id)} className="flex-1 min-h-[44px] px-4 rounded-xl bg-[#397BFF] hover:bg-[#63A5FF] text-white text-xs font-semibold transition-colors disabled:bg-[#162642] disabled:text-[#9AAAC7]">
                  {busyKey === recipe.id ? '...' : activeJob ? (isAr ? 'انتظر انتهاء التصنيع' : 'Manufacturing busy') : !hasSkill ? (isAr ? 'مهارة غير كافية' : 'Skill too low') : !hasInputs ? t.missingInputs : !canAfford ? (isAr ? 'رصيد غير كافٍ' : 'Insufficient balance') : (isAr ? `بدء التصنيع ×${quantity}` : `Start ×${quantity}`)}
                </button>
                {!hasInputs && !activeJob && (
                  <>
                    <BuyMissingResourcesButton
                      uid={profile.uid}
                      requirements={recipe.inputs.map((input) => ({ itemId: input.itemId, quantity: input.qty * quantity }))}
                      inventory={inventory}
                      wallet={wallet}
                      language={language}
                    />
                    <button type="button" onClick={onNavigateToExchange} className="min-h-[44px] px-3.5 rounded-xl bg-[#1B2230] hover:bg-[#232C3E] text-[#F4F5F7] text-xs font-medium whitespace-nowrap">{isAr ? 'فتح السوق' : 'Open market'}</button>
                  </>
                )}
              </div>
            </article>
          );
        })}
      </div>
      <ConfirmDialog
        open={cancelDialogOpen}
        title={isAr ? 'إلغاء عملية التصنيع؟' : 'Cancel manufacturing?'}
        description={isAr
          ? 'ستُعاد جميع المواد التي استُخدمت في هذه العملية إلى مخزونك. تكلفة التشغيل لا تُسترد، ولا يمكن إلغاء العملية بعد انتهاء المؤقت.'
          : 'All materials used by this job will be returned to your inventory. Processing credits are not refunded, and the job cannot be cancelled after its timer ends.'}
        confirmLabel={isAr ? 'تأكيد الإلغاء' : 'Confirm cancellation'}
        cancelLabel={isAr ? 'متابعة التصنيع' : 'Keep manufacturing'}
        onConfirm={() => void handleCancelJob()}
        onCancel={() => setCancelDialogOpen(false)}
        busy={cancelBusy}
        destructive
      />
    </div>
  );
}
