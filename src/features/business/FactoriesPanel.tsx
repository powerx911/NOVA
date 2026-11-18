import { ArrowUpCircle, Factory, Package, Pause, Play, Wrench } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { useToast } from '../../components/ui/ToastProvider';
import { FACTORY_RESOURCES, ITEM_MAP } from '../../data/catalog';
import { timestampToMs } from '../../services/gameService';
import { completeFactoryUpgrade, foundFactory, setFactoryActive, syncFactory, upgradeFactory, upgradeFactorySkill, withdrawFactoryWarehouse } from '../../services/gameService';
import type { Factory as FactoryRecord, FactoryResourceId, InventoryItem, Language, PlayerProfile, Wallet } from '../../types/game';

interface FactoriesPanelProps {
  factories: FactoryRecord[];
  inventory: InventoryItem[];
  profile: PlayerProfile;
  wallet: Wallet | null;
  language: Language;
}

export function FactoriesPanel({ factories, inventory, profile, wallet, language }: FactoriesPanelProps) {
  const { showToast } = useToast();
  const isAr = language === 'ar';
  const [factoryName, setFactoryName] = useState('');
  const [resourceId, setResourceId] = useState<FactoryResourceId>('copper_wire');
  const [selectedId, setSelectedId] = useState('');
  const [withdrawAmount, setWithdrawAmount] = useState(1);
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [now, setNow] = useState(Date.now());
  const inventoryMap = useMemo(() => new Map(inventory.map((item) => [item.itemId, item.quantity])), [inventory]);
  const selected = factories.find((factory) => factory.id === selectedId) ?? factories[0] ?? null;
  const selectedResource = selected ? FACTORY_RESOURCES.find((item) => item.resourceId === selected.resourceId) : null;
  const selectedUpgradeEnd = selected?.upgradeEndsAt ? timestampToMs(selected.upgradeEndsAt) : 0;
  const resourceItem = selected ? ITEM_MAP[selected.resourceId] : null;
  const productionRate = selected && selectedResource
    ? selectedResource.productionPerHour * (1 + (selected.level - 1) * 0.12) * (1 + selected.skillLevel * 0.03)
    : 0;
  const operatingCost = selected && selectedResource
    ? selectedResource.operatingCostPerHour * (1 + (selected.level - 1) * 0.10) * (1 - selected.skillLevel * 0.015)
    : 0;
  const warehouseCapacity = selected ? 150 + selected.level * 100 : 0;
  const selectedResourceOwned = selected ? inventoryMap.get(selected.resourceId) ?? 0 : 0;
  const upgradeCost = selected && selectedResource ? Math.ceil(selectedResource.foundingCost * 0.65 * Math.pow(selected.level, 1.55)) : 0;
  const upgradeMaterials = selected && selectedResource ? Math.ceil(selected.level * selectedResource.rarityFactor * 2) : 0;
  const skillCost = selected && selectedResource ? Math.ceil(selectedResource.foundingCost * 0.18 * Math.pow(selected.skillLevel + 1, 1.35)) : 0;
  const skillMaterials = selected && selectedResource ? Math.ceil((selected.skillLevel + 1) * selectedResource.rarityFactor) : 0;

  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, []);

  const factoryIds = factories.map((factory) => factory.id).join('|');
  useEffect(() => {
    if (!factoryIds) return;
    let active = true;
    const refreshProduction = async () => {
      const ids = factoryIds.split('|').filter(Boolean);
      for (const id of ids) {
        if (!active) return;
        await syncFactory(id).catch(() => undefined);
      }
    };
    void refreshProduction();
    const timer = window.setInterval(() => void refreshProduction(), 60_000);
    return () => { active = false; window.clearInterval(timer); };
  }, [factoryIds]);

  useEffect(() => {
    for (const factory of factories) {
      const endsAt = factory.upgradeEndsAt ? timestampToMs(factory.upgradeEndsAt) : 0;
      if (endsAt > 0 && endsAt <= now && busyKey !== `complete_${factory.id}`) {
        setBusyKey(`complete_${factory.id}`);
        void completeFactoryUpgrade(factory.id)
          .then(() => showToast(isAr ? 'اكتمل تطوير المصنع!' : 'Factory upgrade completed!', 'success'))
          .catch((error) => {
            const message = error instanceof Error ? error.message : '';
            if (message !== 'UPGRADE_NOT_FINISHED') showToast(isAr ? 'تعذر إكمال تطوير المصنع.' : 'Could not complete factory upgrade.', 'error');
          })
          .finally(() => setBusyKey((current) => current === `complete_${factory.id}` ? null : current));
      }
    }
  }, [factories, now, busyKey, isAr, showToast]);

  async function handleFoundFactory(event: React.FormEvent) {
    event.preventDefault();
    setBusyKey('found');
    try {
      await foundFactory(factoryName, resourceId);
      setFactoryName('');
      showToast(isAr ? 'تم تأسيس المصنع بنجاح.' : 'Factory founded successfully.', 'success');
    } catch (error) {
      const message = error instanceof Error ? error.message : '';
      showToast(message === 'FACTORY_CAPACITY_REACHED'
        ? (isAr ? 'وصلت إلى الحد الأقصى: 3 مصانع.' : 'You have reached the three-factory limit.')
        : message === 'INSUFFICIENT_FUNDS'
          ? (isAr ? 'رصيدك لا يكفي لتأسيس هذا المصنع.' : 'Insufficient credits to found this factory.')
          : (isAr ? 'تعذر تأسيس المصنع.' : 'Could not found the factory.'), 'error');
    } finally {
      setBusyKey(null);
    }
  }

  async function runAction(key: string, action: () => Promise<void>, success: string) {
    setBusyKey(key);
    try {
      await action();
      showToast(success, 'success');
    } catch (error) {
      const message = error instanceof Error ? error.message : '';
      const messages: Record<string, string> = {
        INSUFFICIENT_FUNDS: isAr ? 'الرصيد غير كافٍ لتغطية التكلفة.' : 'Insufficient credits for this operation.',
        MISSING_FACTORY_MATERIALS: isAr ? 'المواد الخام المطلوبة غير متوفرة في مخزونك.' : 'Required raw materials are missing from your inventory.',
        MAX_LEVEL: isAr ? 'وصل المصنع إلى المستوى الأقصى.' : 'Factory is already at maximum level.',
        SKILL_MAXED: isAr ? 'وصلت مهارة المصنع إلى الحد الأقصى.' : 'Factory skill is already at maximum level.',
        WAREHOUSE_INSUFFICIENT_STOCK: isAr ? 'الكمية المطلوبة غير متوفرة في المستودع.' : 'The warehouse does not contain that quantity.',
        UPGRADE_IN_PROGRESS: isAr ? 'هناك تطوير جارٍ بالفعل.' : 'An upgrade is already in progress.',
      };
      showToast(messages[message] ?? (isAr ? 'تعذرت العملية.' : 'Operation failed.'), 'error');
    } finally {
      setBusyKey(null);
    }
  }

  const remainingMs = selectedUpgradeEnd ? Math.max(0, selectedUpgradeEnd - now) : 0;
  const remainingMinutes = Math.ceil(remainingMs / 60_000);
  const selectedWarehousePercent = selected && warehouseCapacity > 0 ? Math.min(100, selected.warehouseQty / warehouseCapacity * 100) : 0;

  return (
    <div className="space-y-4">
      <section className="rounded-2xl border border-white/8 bg-[#141821] p-4 sm:p-5 space-y-3">
        <div className="flex items-center justify-between gap-3">
          <div>
            <h2 className="text-base font-bold text-[#F4F5F7]">{isAr ? 'مصانعي' : 'My factories'}</h2>
            <p className="mt-1 text-xs text-[#9299A6]">{isAr ? 'كل مصنع ينتج مورداً خاماً واحداً فقط، والحد الأقصى 3 مصانع.' : 'Each factory produces one raw resource only. Maximum ownership: 3 factories.'}</p>
          </div>
          <span className="rounded-lg bg-[#0B0D12] px-3 py-1.5 text-xs font-mono-num text-[#E5A0A8]">{factories.length}/3</span>
        </div>
        {factories.length > 0 && (
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
            {factories.map((factory) => {
              const resource = FACTORY_RESOURCES.find((item) => item.resourceId === factory.resourceId);
              return <button key={factory.id} type="button" onClick={() => setSelectedId(factory.id)} className={`rounded-xl border p-3 text-start transition-colors ${selected?.id === factory.id ? 'border-[#E04455] bg-[#1B2230]' : 'border-white/8 bg-[#0B0D12] hover:border-white/20'}`}>
                <span className="flex items-center gap-2"><Factory className="h-4 w-4 text-[#E04455]" /><span className="truncate text-sm font-semibold text-[#F4F5F7]">{factory.name}</span></span>
                <span className="mt-1 block text-[11px] text-[#9299A6]">{isAr ? resource?.nameAr : resource?.nameEn} · Lv.{factory.level}</span>
                <span className="mt-1 block text-[11px] text-emerald-300">{factory.warehouseQty.toLocaleString()} {isAr ? 'وحدة بالمستودع' : 'in warehouse'}</span>
              </button>;
            })}
          </div>
        )}
        {selected && selectedResource && (
          <div className="rounded-xl border border-white/8 bg-[#0B0D12] p-4 space-y-3">
            <div className="flex flex-wrap items-start justify-between gap-2">
              <div><h3 className="text-sm font-bold text-[#F4F5F7]">{selected.name}</h3><p className="mt-1 text-xs text-[#9299A6]">{isAr ? selectedResource.nameAr : selectedResource.nameEn} · {isAr ? 'المستوى' : 'Level'} {selected.level}/50</p></div>
              <span className="rounded-lg bg-[#141821] px-2.5 py-1 text-[10px] text-[#E5A0A8]">{isAr ? 'مصنع موارد خام' : 'Raw-resource factory'}</span>
              <span className={`rounded-lg px-2.5 py-1 text-[10px] ${selected.isActive ? 'bg-emerald-500/10 text-emerald-300' : 'bg-amber-500/10 text-amber-300'}`}>{selected.isActive ? (isAr ? 'الإنتاج يعمل' : 'Production active') : (isAr ? 'الإنتاج متوقف' : 'Production paused')}</span>
            </div>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
              <div className="rounded-lg bg-[#141821] p-3"><p className="text-[10px] text-[#9299A6]">{isAr ? 'الإنتاج / ساعة' : 'Output / hour'}</p><p className="mt-1 text-sm font-bold text-emerald-300">{productionRate.toFixed(2)}</p></div>
              <div className="rounded-lg bg-[#141821] p-3"><p className="text-[10px] text-[#9299A6]">{isAr ? 'التشغيل / ساعة' : 'Operating / hour'}</p><p className="mt-1 text-sm font-bold text-rose-300">${Math.ceil(operatingCost).toLocaleString()}</p></div>
              <div className="rounded-lg bg-[#141821] p-3"><p className="text-[10px] text-[#9299A6]">{isAr ? 'مهارة التشغيل' : 'Operator skill'}</p><p className="mt-1 text-sm font-bold text-[#F4F5F7]">{selected.skillLevel}/10</p></div>
              <div className="rounded-lg bg-[#141821] p-3"><p className="text-[10px] text-[#9299A6]">{isAr ? 'التكلفة التأسيسية' : 'Founding cost'}</p><p className="mt-1 text-sm font-bold text-[#F4F5F7]">${selectedResource.foundingCost.toLocaleString()}</p></div>
            </div>
            <div className="space-y-1.5">
              <div className="flex items-center justify-between text-xs"><span className="text-[#9299A6]">{isAr ? 'المستودع' : 'Warehouse'} · {resourceItem ? (isAr ? resourceItem.nameAr : resourceItem.nameEn) : selected.resourceId}</span><span className="font-mono-num text-[#F4F5F7]">{selected.warehouseQty.toLocaleString()} / {warehouseCapacity.toLocaleString()}</span></div>
              <div className="h-2 overflow-hidden rounded-full bg-white/8"><div className="h-full rounded-full bg-[#B91C32]" style={{ width: `${selectedWarehousePercent}%` }} /></div>
            </div>
            {selectedUpgradeEnd > 0 && <p className="text-xs text-amber-300">{remainingMs > 0 ? (isAr ? `التطوير جارٍ · متبقٍ نحو ${remainingMinutes} دقيقة` : `Upgrade in progress · about ${remainingMinutes} min left`) : (isAr ? 'اكتمل الوقت، جارٍ إنهاء التطوير.' : 'Timer complete; finalizing upgrade.')}</p>}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              <button type="button" disabled={busyKey === `sync_${selected.id}`} onClick={() => void runAction(`sync_${selected.id}`, () => syncFactory(selected.id), isAr ? 'تم تحديث الإنتاج وخصم مصاريف التشغيل.' : 'Production synchronized and operating costs charged.')} className="min-h-[42px] rounded-xl bg-[#1B2230] px-3 text-xs font-semibold text-[#F4F5F7] hover:bg-[#263247] disabled:opacity-50">{isAr ? 'تحديث الإنتاج' : 'Sync production'}</button>
              <button type="button" disabled={busyKey === `active_${selected.id}`} onClick={() => void runAction(`active_${selected.id}`, () => setFactoryActive(selected.id, !selected.isActive), selected.isActive ? (isAr ? 'تم إيقاف المصنع ولن تُخصم مصاريف إنتاج أثناء التوقف.' : 'Factory paused; production costs stop while paused.') : (isAr ? 'تم تشغيل المصنع.' : 'Factory activated.'))} className="min-h-[42px] rounded-xl border border-white/10 bg-[#141821] px-3 text-xs font-semibold text-[#F4F5F7] disabled:opacity-50">{selected.isActive ? <><Pause className="me-1 inline h-4 w-4" />{isAr ? 'إيقاف الإنتاج' : 'Pause production'}</> : <><Play className="me-1 inline h-4 w-4" />{isAr ? 'تشغيل الإنتاج' : 'Resume production'}</>}</button>
              <button type="button" disabled={selected.level >= 50 || Boolean(selectedUpgradeEnd > now) || selectedResourceOwned < upgradeMaterials || busyKey === `upgrade_${selected.id}`} onClick={() => void runAction(`upgrade_${selected.id}`, () => upgradeFactory(selected.id), isAr ? 'بدأ تطوير المصنع، وسيكتمل تلقائياً.' : 'Factory upgrade started and will complete automatically.')} className="min-h-[42px] rounded-xl bg-[#B91C32] px-3 text-xs font-semibold text-white hover:bg-[#E04455] disabled:opacity-40"><ArrowUpCircle className="me-1 inline h-4 w-4" />{isAr ? `تطوير المصنع · ${upgradeCost.toLocaleString()}` : `Upgrade · ${upgradeCost.toLocaleString()}`}</button>
              <button type="button" disabled={selected.skillLevel >= 10 || selectedResourceOwned < skillMaterials || busyKey === `skill_${selected.id}`} onClick={() => void runAction(`skill_${selected.id}`, () => upgradeFactorySkill(selected.id), isAr ? 'تم تطوير مهارة تشغيل المصنع.' : 'Factory operator skill upgraded.')} className="min-h-[42px] rounded-xl border border-white/10 bg-[#141821] px-3 text-xs font-semibold text-[#F4F5F7] disabled:opacity-40"><Wrench className="me-1 inline h-4 w-4" />{isAr ? `تطوير المهارة · ${skillCost.toLocaleString()}` : `Train skill · ${skillCost.toLocaleString()}`}</button>
            </div>
            <p className="text-[11px] text-[#77808F]">{isAr ? `ترقية المصنع تستهلك ${upgradeMaterials} من ${selectedResource.nameAr}. وتطوير المهارة يستهلك ${skillMaterials} من المورد نفسه.` : `Factory upgrade consumes ${upgradeMaterials} units of ${selectedResource.nameEn}; skill training consumes ${skillMaterials}.`}</p>
            <div className="flex flex-wrap items-end gap-2 border-t border-white/8 pt-3">
              <label className="min-w-0 flex-1 space-y-1"><span className="text-[11px] text-[#9299A6]">{isAr ? 'سحب من المستودع إلى حقيبتك' : 'Withdraw to inventory'}</span><input type="number" min="1" max={selected.warehouseQty} value={withdrawAmount} onChange={(event) => setWithdrawAmount(Math.max(1, Math.min(1_000_000, Number(event.target.value) || 1)))} className="w-full min-h-[40px] rounded-lg border border-white/10 bg-[#141821] px-3 text-sm text-[#F4F5F7]" /></label>
              <button type="button" disabled={selected.warehouseQty < 1 || withdrawAmount > selected.warehouseQty || busyKey === `withdraw_${selected.id}`} onClick={() => void runAction(`withdraw_${selected.id}`, () => withdrawFactoryWarehouse(selected.id, withdrawAmount), isAr ? 'تم نقل الموارد إلى حقيبتك.' : 'Resources moved to your inventory.')} className="min-h-[40px] rounded-lg bg-[#1B2230] px-4 text-xs font-semibold text-[#F4F5F7] disabled:opacity-40"><Package className="me-1 inline h-4 w-4" />{isAr ? 'سحب الموارد' : 'Withdraw'}</button>
            </div>
          </div>
        )}
      </section>

      <section className="rounded-2xl border border-white/8 bg-[#141821] p-4 sm:p-5 space-y-3">
        <div><h3 className="text-sm font-bold text-[#F4F5F7]">{isAr ? 'تأسيس مصنع جديد' : 'Found a new factory'}</h3><p className="mt-1 text-xs text-[#9299A6]">{isAr ? 'المصانع لا تنتج أموالاً؛ تنتج موارد خاماً وتستهلك مصاريف تشغيل مرتفعة.' : 'Factories do not generate credits; they produce raw resources and incur substantial operating costs.'}</p></div>
        <form onSubmit={handleFoundFactory} className="space-y-3">
          <label className="block space-y-1"><span className="text-xs text-[#9299A6]">{isAr ? 'اسم المصنع' : 'Factory name'}</span><input value={factoryName} onChange={(event) => setFactoryName(event.target.value)} minLength={2} maxLength={48} required placeholder={isAr ? 'مصنع النحاس المتقدم' : 'Advanced Copper Works'} className="w-full min-h-[44px] rounded-xl border border-white/10 bg-[#0B0D12] px-3 text-sm text-[#F4F5F7]" /></label>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
            {FACTORY_RESOURCES.map((resource) => (
              <button key={resource.resourceId} type="button" onClick={() => setResourceId(resource.resourceId)} className={`rounded-xl border p-3 text-start transition-colors ${resourceId === resource.resourceId ? 'border-[#E04455] bg-[#1B2230]' : 'border-white/8 bg-[#0B0D12]'}`}>
                <span className="block text-xs font-semibold text-[#F4F5F7]">{isAr ? resource.nameAr : resource.nameEn}</span>
                <span className="mt-1 block text-[11px] text-[#9299A6]">{isAr ? resource.descriptionAr : resource.descriptionEn}</span>
                <span className="mt-2 block text-xs font-bold text-[#E5A0A8]">${resource.foundingCost.toLocaleString()} · {resource.productionPerHour} {isAr ? 'وحدة/ساعة' : 'units/hr'}</span>
              </button>
            ))}
          </div>
          <button type="submit" disabled={factories.length >= 3 || busyKey === 'found' || !factoryName.trim() || (wallet?.balance ?? 0) < (FACTORY_RESOURCES.find((item) => item.resourceId === resourceId)?.foundingCost ?? Infinity)} className="w-full min-h-[44px] rounded-xl bg-[#B91C32] px-4 text-sm font-semibold text-white hover:bg-[#E04455] disabled:opacity-40">{busyKey === 'found' ? '...' : factories.length >= 3 ? (isAr ? 'اكتمل الحد الأقصى (3 مصانع)' : 'Three-factory limit reached') : (isAr ? `تأسيس المصنع · ${(FACTORY_RESOURCES.find((item) => item.resourceId === resourceId)?.foundingCost ?? 0).toLocaleString()}` : `Found factory · ${(FACTORY_RESOURCES.find((item) => item.resourceId === resourceId)?.foundingCost ?? 0).toLocaleString()}`)}</button>
        </form>
      </section>
    </div>
  );
}
