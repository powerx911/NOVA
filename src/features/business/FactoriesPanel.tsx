import { ArrowLeft, ArrowUpCircle, Package, Wrench } from 'lucide-react';
import { useEffect, useMemo, useRef, useState } from 'react';
import { useToast } from '../../components/ui/ToastProvider';
import { FACTORY_RESOURCES, ITEM_MAP } from '../../data/catalog';
import { ResourceIcon } from '../../components/ui/ResourceIcon';
import { timestampToMs } from '../../services/gameService';
import { factoryOperatingCostMultiplier, factoryOutputMultiplier, factoryUpgradeCost, factoryUpgradeDurationSeconds, WAREHOUSE_UPGRADE_COSTS, WAREHOUSE_UPGRADE_DURATION_MINUTES, warehouseUpgradeCost } from '../../lib/businessEconomy';
import { completeFactoryUpgrade, completeFactoryWarehouseUpgrade, foundFactory, upgradeFactory, upgradeFactorySkill, upgradeFactoryWarehouse, withdrawFactoryWarehouse } from '../../services/gameService';
import type { Factory as FactoryRecord, FactoryResourceId, InventoryItem, Language, PlayerProfile, Wallet } from '../../types/game';

interface FactoriesPanelProps {
  factories: FactoryRecord[];
  inventory: InventoryItem[];
  profile: PlayerProfile;
  wallet: Wallet | null;
  language: Language;
  notifications: import('../../types/game').GameNotification[];
}

export function FactoriesPanel({ factories, inventory, profile, wallet, language, notifications }: FactoriesPanelProps) {
  const { showToast } = useToast();
  const isAr = language === 'ar';
  const [factoryName, setFactoryName] = useState('');
  const [resourceId, setResourceId] = useState<FactoryResourceId>('copper_wire');
  const [selectedId, setSelectedId] = useState('');
  const [factoryView, setFactoryView] = useState<'overview' | 'detail' | 'found'>('overview');
  const [withdrawAmount, setWithdrawAmount] = useState(1);
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [now, setNow] = useState(Date.now());
  const completionAttempts = useRef(new Set<string>());
  const inventoryMap = useMemo(() => new Map<string, number>(inventory.map((item) => [item.itemId, item.quantity] as [string, number])), [inventory]);
  const selected = factories.find((factory) => factory.id === selectedId) ?? null;
  const sortedFactories = [...factories].sort((a, b) => b.level - a.level || a.name.localeCompare(b.name));
  const selectedResource = selected ? FACTORY_RESOURCES.find((item) => item.resourceId === selected.resourceId) : null;
  const selectedUpgradeEnd = selected?.upgradeEndsAt ? timestampToMs(selected.upgradeEndsAt) : 0;
  const selectedWarehouseUpgradeEnd = selected?.warehouseUpgradeEndsAt ? timestampToMs(selected.warehouseUpgradeEndsAt) : 0;
  const resourceItem = selected ? ITEM_MAP[selected.resourceId] : null;
  const productionRate = selected && selectedResource
    ? selectedResource.productionPerHour * factoryOutputMultiplier(selected.resourceId, selected.level) * (1 + selected.skillLevel * 0.04)
    : 0;
  const operatingCost = selected && selectedResource
    ? selectedResource.operatingCostPerHour * factoryOperatingCostMultiplier(selected.level) * (1 - selected.skillLevel * 0.025)
    : 0;
  const warehouseLevel = Math.max(1, selected?.warehouseLevel ?? 1);
  const warehouseValueCaps = [3500, 7000, 14000, 25000, 40000];
  const warehouseUpgradeCosts = WAREHOUSE_UPGRADE_COSTS;
  const warehouseUnitPrice = resourceItem?.basePrice ?? 30;
  const warehouseCapacity = selected ? Math.floor(warehouseValueCaps[warehouseLevel - 1] / warehouseUnitPrice) : 0;
  const warehouseUpgradeCostValue = warehouseUpgradeCost(warehouseLevel);
  const selectedResourceOwned = selected ? inventoryMap.get(selected.resourceId) ?? 0 : 0;
  const upgradeCost = selected && selectedResource ? factoryUpgradeCost(selectedResource.foundingCost, selected.level) : 0;
  const upgradeDurationSeconds = selected ? factoryUpgradeDurationSeconds(selected.level + 1) : 0;
  const upgradeMaterials = selected && selectedResource ? Math.ceil(selected.level * selectedResource.rarityFactor * 2) : 0;
  const skillCost = selected && selectedResource ? Math.ceil(selectedResource.foundingCost * 0.18 * Math.pow(selected.skillLevel + 1, 1.35)) : 0;
  const skillMaterials = selected && selectedResource ? Math.ceil((selected.skillLevel + 1) * selectedResource.rarityFactor) : 0;

  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, []);

  // Factory production is synchronized centrally by the server cron every minute.
  // Client-side per-factory syncs caused one full game bootstrap per factory.

  useEffect(() => {
    for (const factory of factories) {
      const endsAt = factory.upgradeEndsAt ? timestampToMs(factory.upgradeEndsAt) : 0;
      const attemptKey = `factory-upgrade:${factory.id}:${endsAt}`;
      if (endsAt <= 0 || endsAt > now || completionAttempts.current.has(attemptKey)) continue;
      completionAttempts.current.add(attemptKey);
      setBusyKey(`complete_${factory.id}`);
      void completeFactoryUpgrade(factory.id)
        .then(() => {
          window.dispatchEvent(new Event('nova:refresh-game'));
          showToast(isAr ? 'اكتمل تطوير المصنع!' : 'Factory upgrade completed!', 'success');
        })
        .catch((error) => {
          const message = error instanceof Error ? error.message : '';
          if (message === 'UPGRADE_NOT_FINISHED') {
            window.setTimeout(() => completionAttempts.current.delete(attemptKey), 3000);
          } else if (message === 'NO_UPGRADE_IN_PROGRESS') {
            // Another request already completed the upgrade; refresh instead of showing a false failure.
            window.dispatchEvent(new Event('nova:refresh-game'));
          } else {
            showToast(isAr ? 'تعذر إكمال تطوير المصنع. حاول التحديث.' : 'Could not complete factory upgrade. Please refresh.', 'error');
          }
        })
        .finally(() => setBusyKey((current) => current === `complete_${factory.id}` ? null : current));
    }
  }, [factories, now, busyKey, isAr, showToast]);

  useEffect(() => {
    for (const factory of factories) {
      const endsAt = factory.warehouseUpgradeEndsAt ? timestampToMs(factory.warehouseUpgradeEndsAt) : 0;
      const attemptKey = `factory-warehouse-upgrade:${factory.id}:${endsAt}`;
      if (endsAt <= 0 || endsAt > now || completionAttempts.current.has(attemptKey)) continue;
      completionAttempts.current.add(attemptKey);
      setBusyKey(`warehouse_complete_${factory.id}`);
      void completeFactoryWarehouseUpgrade(factory.id)
        .then(() => {
          window.dispatchEvent(new Event('nova:refresh-game'));
          showToast(isAr ? 'اكتمل توسيع مستودع المصنع!' : 'Factory warehouse expansion completed!', 'success');
        })
        .catch((error) => {
          const message = error instanceof Error ? error.message : '';
          if (message === 'UPGRADE_NOT_FINISHED') {
            window.setTimeout(() => completionAttempts.current.delete(attemptKey), 3000);
          } else if (message === 'NO_UPGRADE_IN_PROGRESS') {
            window.dispatchEvent(new Event('nova:refresh-game'));
          } else {
            showToast(isAr ? 'تعذر إكمال توسيع المستودع. حاول التحديث.' : 'Could not complete warehouse expansion. Please refresh.', 'error');
          }
        })
        .finally(() => setBusyKey((current) => current === `warehouse_complete_${factory.id}` ? null : current));
    }
  }, [factories, now, busyKey, isAr, showToast]);

  async function handleFoundFactory(event: React.FormEvent) {
    event.preventDefault();
    setBusyKey('found');
    try {
      await foundFactory(factoryName, resourceId);
      setFactoryName('');
      setFactoryView('overview');
      window.dispatchEvent(new Event('nova:refresh-game'));
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
      window.dispatchEvent(new Event('nova:refresh-game'));
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
        UPGRADE_NOT_FINISHED: isAr ? 'اكتمل المؤقت؛ أكمل التطوير الحالي أولاً.' : 'The timer elapsed; complete the current upgrade first.',
      };
      showToast(messages[message] ?? (isAr ? 'تعذرت العملية.' : 'Operation failed.'), 'error');
    } finally {
      setBusyKey(null);
    }
  }

  const remainingMs = selectedUpgradeEnd ? Math.max(0, selectedUpgradeEnd - now) : 0;
  const remainingSeconds = Math.ceil(remainingMs / 1000);
  const remainingLabel = `${Math.floor(remainingSeconds / 60)}:${String(remainingSeconds % 60).padStart(2, '0')}`;
  const warehouseRemainingMs = selectedWarehouseUpgradeEnd > 0 ? Math.max(0, selectedWarehouseUpgradeEnd - now) : 0;
  const warehouseRemainingSeconds = Math.ceil(warehouseRemainingMs / 1000);
  const warehouseRemainingLabel = `${Math.floor(warehouseRemainingSeconds / 60)}:${String(warehouseRemainingSeconds % 60).padStart(2, '0')}`;
  const warehouseUpgradeDurationMinutes = warehouseUpgradeCosts[warehouseLevel - 1] === undefined ? 0 : WAREHOUSE_UPGRADE_DURATION_MINUTES[warehouseLevel - 1];
  const warehouseDurationLabel = warehouseUpgradeDurationMinutes < 60
    ? (isAr ? `${warehouseUpgradeDurationMinutes} دقيقة` : `${warehouseUpgradeDurationMinutes} min`)
    : (isAr ? `${warehouseUpgradeDurationMinutes / 60} ساعة` : `${warehouseUpgradeDurationMinutes / 60} hr`);
  const selectedWarehousePercent = selected && warehouseCapacity > 0 ? Math.min(100, selected.warehouseQty / warehouseCapacity * 100) : 0;

  return (
    <div className="space-y-4">
      <section className="rounded-2xl border border-white/8 bg-[#141821] p-4 sm:p-5 space-y-3">
        {factoryView === 'overview' && <>
          <div className="flex items-center justify-between gap-3">
            <h2 className="text-base font-bold text-[#F4F5F7]">{isAr ? 'مصانعي' : 'My factories'}</h2>
            <button type="button" disabled={factories.length >= 3} onClick={() => setFactoryView('found')} className="min-h-[38px] rounded-lg bg-[#397BFF] px-3 text-xs font-semibold text-white disabled:opacity-40">{isAr ? 'تأسيس مصنع' : 'Found factory'}</button>
          </div>
          <p className="text-[11px] text-[#9299A6]">{isAr ? `يمكنك امتلاك 3 مصانع كحد أقصى · المصانع الحالية: ${factories.length}/3` : `You can own up to 3 factories · Current factories: ${factories.length}/3`}</p>
          {factories.length > 0 && (
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
            {sortedFactories.map((factory) => {
              const resource = FACTORY_RESOURCES.find((item) => item.resourceId === factory.resourceId);
              return <button key={factory.id} type="button" onClick={() => { setSelectedId(factory.id); setFactoryView('detail'); }} className={`rounded-xl border p-3 text-start transition-colors ${selected?.id === factory.id ? 'border-[#397BFF] bg-[#1B2230]' : 'border-white/8 bg-[#0B0D12] hover:border-white/20'}`}>
                <span className="flex items-center gap-2"><ResourceIcon itemId={factory.resourceId} size="md" /><span className="truncate text-sm font-semibold text-[#F4F5F7]">{factory.name}{notifications.some((n) => n.eventKey?.startsWith('factory-warehouse-full:' + factory.id + ':') || (!n.read && (n.title === 'مستودع المصنع ممتلئ' || n.title === 'Factory warehouse is full') && n.body.includes(factory.name))) && <span className="ms-2 inline-block h-2 w-2 rounded-full bg-red-500" />}</span></span>
                <span className="mt-1 block text-[11px] text-[#9299A6]">{isAr ? resource?.nameAr : resource?.nameEn} · Lv.{factory.level}</span>
                <span className="mt-1 block text-[11px] text-emerald-300">{factory.warehouseQty.toLocaleString()} {isAr ? 'وحدة بالمستودع' : 'in warehouse'}</span>
              </button>;
            })}
          </div>
        )}
        </>}
        {factoryView === 'detail' && selected && selectedResource && (
          <>
            <button type="button" onClick={() => setFactoryView('overview')} className="inline-flex min-h-[40px] items-center gap-2 rounded-xl bg-[#1B2230] px-3 text-xs font-semibold text-[#F4F5F7]"><ArrowLeft className="h-4 w-4" />{isAr ? 'العودة إلى مصانعي' : 'Back to My factories'}</button>
          <div className="rounded-xl border border-white/8 bg-[#0B0D12] p-4 space-y-3">
            <div className="flex flex-wrap items-start justify-between gap-2">
              <div className="flex items-center gap-3"><ResourceIcon itemId={selected.resourceId} size="lg" /><div><h3 className="text-sm font-bold text-[#F4F5F7]">{selected.name}</h3><p className="mt-1 text-xs text-[#9299A6]">{isAr ? selectedResource.nameAr : selectedResource.nameEn} · {isAr ? 'المستوى' : 'Level'} {selected.level}/100</p></div></div>
              <span className="rounded-lg bg-[#141821] px-2.5 py-1 text-[10px] text-[#9CBFFF]">{isAr ? 'مصنع موارد خام' : 'Raw-resource factory'}</span>
              <span className={`rounded-lg px-2.5 py-1 text-[10px] ${selected.isActive ? 'bg-emerald-500/10 text-emerald-300' : 'bg-amber-500/10 text-amber-300'}`}>{selected.isActive ? (isAr ? 'الإنتاج يعمل تلقائيًا' : 'Automatic production active') : (isAr ? 'متوقف لنقص أموال التشغيل' : 'Paused: insufficient operating funds')}</span>
            </div>
            {!selected.isActive && <div role="status" className="rounded-xl border border-amber-500/25 bg-amber-500/10 p-3 text-xs leading-6 text-amber-100">{isAr ? 'توقف إنتاج هذا المصنع أثناء غيابك لأن رصيدك لم يكن كافيًا لتغطية تكاليف التشغيل. لن يُحتسب إنتاج خلال فترة التوقف؛ أضف رصيدًا كافيًا وسيستأنف المصنع الإنتاج تلقائيًا.' : 'This factory stopped producing while you were away because your balance could not cover operating costs. No production accrues while paused. Add enough credits and production will resume automatically.'}</div>}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
              <div className="rounded-lg bg-[#141821] p-3"><p className="text-[10px] text-[#9299A6]">{isAr ? 'الإنتاج / ساعة' : 'Output / hour'}</p><p className="mt-1 text-sm font-bold text-emerald-300">{productionRate.toFixed(2)}</p></div>
              <div className="rounded-lg bg-[#141821] p-3"><p className="text-[10px] text-[#9299A6]">{isAr ? 'التشغيل / ساعة' : 'Operating / hour'}</p><p className="mt-1 text-sm font-bold text-rose-300">${Math.ceil(operatingCost).toLocaleString()}</p></div>
              <div className="rounded-lg bg-[#141821] p-3"><p className="text-[10px] text-[#9299A6]">{isAr ? 'مهارة التشغيل' : 'Operator skill'}</p><p className="mt-1 text-sm font-bold text-[#F4F5F7]">{selected.skillLevel}/10</p></div>
              <div className="rounded-lg bg-[#141821] p-3"><p className="text-[10px] text-[#9299A6]">{isAr ? 'التكلفة التأسيسية' : 'Founding cost'}</p><p className="mt-1 text-sm font-bold text-[#F4F5F7]">${selectedResource.foundingCost.toLocaleString()}</p></div>
            </div>
            <div className="space-y-1.5">
              <div className="flex items-center justify-between text-xs"><span className="text-[#9299A6]">{isAr ? 'المستودع' : 'Warehouse'} · {resourceItem ? (isAr ? resourceItem.nameAr : resourceItem.nameEn) : selected.resourceId}</span><span className="font-mono-num text-[#F4F5F7]">{selected.warehouseQty.toLocaleString()} / {warehouseCapacity.toLocaleString()}</span></div>
              <div className="h-2 overflow-hidden rounded-full bg-white/8"><div className="h-full rounded-full bg-[#397BFF]" style={{ width: `${selectedWarehousePercent}%` }} /></div>
            </div>
            <div className="rounded-xl border border-white/8 bg-[#141821] p-3 space-y-2">
              <div className="flex items-center justify-between gap-2">
                <div><p className="text-xs font-semibold text-[#F4F5F7]">{isAr ? 'توسعة المستودع' : 'Warehouse expansion'} · Lv.{warehouseLevel}/5</p><p className="mt-1 text-[11px] text-[#9299A6]">{isAr ? 'السعة مرتبطة بقيمة المورد مثل خزينة أرباح الشركات.' : 'Capacity follows resource value, like company profit vault tiers.'}</p></div>
                <span className="text-xs font-mono-num text-emerald-300">{warehouseLevel < 5 ? '+' + Math.max(0, Math.floor(warehouseValueCaps[warehouseLevel] / warehouseUnitPrice) - warehouseCapacity) : 'MAX'}</span>
              </div>
              {selectedWarehouseUpgradeEnd > 0 ? <p className="text-xs text-amber-300">{warehouseRemainingMs > 0 ? (isAr ? `توسعة المستودع قيد التنفيذ · المتبقي ${warehouseRemainingLabel}` : `Warehouse expansion in progress · ${warehouseRemainingLabel} left`) : (isAr ? 'اكتمل الوقت، جارٍ إنهاء التوسعة.' : 'Timer complete; finalizing expansion.')}</p> : warehouseLevel < 5 ? <p className="text-xs text-[#A9B9D4]">{isAr ? `مدة التوسعة القادمة: ${warehouseDurationLabel}` : `Next expansion duration: ${warehouseDurationLabel}`}</p> : null}
              <button type="button" disabled={warehouseLevel >= 5 || selectedWarehouseUpgradeEnd > 0 || selectedUpgradeEnd > 0 || (wallet?.balance ?? 0) < warehouseUpgradeCostValue || busyKey === `warehouse_${selected.id}`} onClick={() => void runAction(`warehouse_${selected.id}`, () => upgradeFactoryWarehouse(selected.id), isAr ? 'بدأت توسعة المستودع.' : 'Warehouse expansion started.')} className="w-full min-h-[40px] rounded-lg border border-white/10 bg-[#0B0D12] px-3 text-xs font-semibold text-[#F4F5F7] disabled:opacity-40">{warehouseLevel >= 5 ? (isAr ? 'وصل المستودع إلى المستوى الأقصى' : 'Warehouse max level reached') : (isAr ? `توسعة المستودع · ${warehouseUpgradeCostValue.toLocaleString()} $` : `Expand warehouse · ${warehouseUpgradeCostValue.toLocaleString()} $`)}</button>
            </div>
            {selectedUpgradeEnd > 0 && <p className="text-xs text-amber-300">{remainingMs > 0 ? (isAr ? `التطوير جارٍ · متبقٍ ${remainingLabel}` : `Upgrade in progress · ${remainingLabel} left`) : (isAr ? 'اكتمل الوقت، جارٍ إنهاء التطوير.' : 'Timer complete; finalizing upgrade.')}</p>}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              <button type="button" disabled={selected.level >= 100 || Boolean(selectedUpgradeEnd > 0 || selectedWarehouseUpgradeEnd > 0) || selectedResourceOwned < upgradeMaterials || (wallet?.balance ?? 0) < upgradeCost || busyKey === `upgrade_${selected.id}`} onClick={() => void runAction(`upgrade_${selected.id}`, () => upgradeFactory(selected.id), isAr ? 'بدأ تطوير المصنع، وسيكتمل تلقائياً.' : 'Factory upgrade started and will complete automatically.')} className="min-h-[42px] rounded-xl bg-[#397BFF] px-3 text-xs font-semibold text-white hover:bg-[#2F6DE0] disabled:opacity-40"><ArrowUpCircle className="me-1 inline h-4 w-4" />{isAr ? `تطوير المصنع · ${upgradeCost.toLocaleString()} · ${Math.ceil(upgradeDurationSeconds / 60)} دقيقة` : `Upgrade · ${upgradeCost.toLocaleString()} · ${Math.ceil(upgradeDurationSeconds / 60)} min`}</button>
              <button type="button" disabled={selected.skillLevel >= 10 || selectedResourceOwned < skillMaterials || (wallet?.balance ?? 0) < skillCost || busyKey === `skill_${selected.id}`} onClick={() => void runAction(`skill_${selected.id}`, () => upgradeFactorySkill(selected.id), isAr ? 'تم تطوير مهارة تشغيل المصنع.' : 'Factory operator skill upgraded.')} className="min-h-[42px] rounded-xl border border-white/10 bg-[#141821] px-3 text-xs font-semibold text-[#F4F5F7] disabled:opacity-40"><Wrench className="me-1 inline h-4 w-4" />{isAr ? `تطوير المهارة · ${skillCost.toLocaleString()}` : `Train skill · ${skillCost.toLocaleString()}`}</button>
            </div>
            <p className="text-[11px] text-[#77808F]">{isAr ? 'يعمل المصنع تلقائيًا، وتتم مزامنة الإنتاج ومصاريفه دوريًا. عند نفاد رصيد التشغيل يتوقف مؤقتًا ويستأنف وحده عند توفر الرصيد.' : 'The factory runs automatically and synchronizes production and operating costs periodically. It pauses when funds run out and resumes automatically when funds are available.'}</p>
            <p className="text-[11px] text-[#77808F]">{isAr ? `ترقية المصنع تستهلك ${upgradeMaterials} من ${selectedResource.nameAr}. وتطوير المهارة يستهلك ${skillMaterials} من المورد نفسه.` : `Factory upgrade consumes ${upgradeMaterials} units of ${selectedResource.nameEn}; skill training consumes ${skillMaterials}.`}</p>
            <p className="text-[11px] text-[#77808F]">{isAr ? `كل مستوى في مهارة التشغيل يزيد الإنتاج 4% ويخفض مصاريف التشغيل 2.5%. المتوفر لديك: ${selectedResourceOwned} وحدة.` : `Each operator skill level increases output by 4% and reduces operating costs by 2.5%. You own ${selectedResourceOwned} units.`}</p>
            <p className="text-[11px] text-[#77808F]">{selected.skillLevel >= 10 ? (isAr ? 'وصلت المهارة إلى المستوى الأقصى (10).' : 'Operator skill is at the maximum level (10).') : (wallet?.balance ?? 0) < skillCost ? (isAr ? `تحتاج ${skillCost.toLocaleString()} رصيدًا للترقية التالية.` : `You need ${skillCost.toLocaleString()} credits for the next skill level.`) : selectedResourceOwned < skillMaterials ? (isAr ? `تحتاج ${skillMaterials} وحدة إضافية من ${selectedResource.nameAr} للترقية التالية.` : `You need ${skillMaterials} ${selectedResource.nameEn} units for the next skill level.`) : (isAr ? `متطلبات الترقية التالية: ${skillCost.toLocaleString()} رصيد و${skillMaterials} وحدة من المورد.` : `Next upgrade requires ${skillCost.toLocaleString()} credits and ${skillMaterials} resource units.`)}</p>
            <div className="flex flex-wrap items-end gap-2 border-t border-white/8 pt-3">
              <label className="min-w-0 flex-1 space-y-1"><span className="text-[11px] text-[#9299A6]">{isAr ? 'سحب من المستودع إلى حقيبتك' : 'Withdraw to inventory'}</span><input type="number" min="1" max={selected.warehouseQty} value={withdrawAmount} onChange={(event) => setWithdrawAmount(Math.max(1, Math.min(1_000_000, Number(event.target.value) || 1)))} className="w-full min-h-[40px] rounded-lg border border-white/10 bg-[#141821] px-3 text-sm text-[#F4F5F7]" /></label>
              <button type="button" disabled={selected.warehouseQty < 1 || withdrawAmount > selected.warehouseQty || busyKey === `withdraw_${selected.id}`} onClick={() => void runAction(`withdraw_${selected.id}`, () => withdrawFactoryWarehouse(selected.id, withdrawAmount), isAr ? 'تم نقل الموارد إلى حقيبتك.' : 'Resources moved to your inventory.')} className="min-h-[40px] rounded-lg bg-[#1B2230] px-4 text-xs font-semibold text-[#F4F5F7] disabled:opacity-40"><Package className="me-1 inline h-4 w-4" />{isAr ? 'سحب الموارد' : 'Withdraw'}</button>
              <button type="button" disabled={selected.warehouseQty < 1 || busyKey === `withdraw_all_${selected.id}`} onClick={() => void runAction(`withdraw_all_${selected.id}`, () => withdrawFactoryWarehouse(selected.id, selected.warehouseQty), isAr ? 'تم سحب كل الموارد إلى حقيبتك.' : 'All resources moved to your inventory.')} className="min-h-[40px] rounded-lg border border-white/10 bg-[#141821] px-4 text-xs font-semibold text-[#F4F5F7] disabled:opacity-40">{isAr ? 'سحب الكل' : 'Withdraw all'}</button>
            </div>
          </div>
          </>
        )}
      </section>

      {factoryView === 'found' && <section className="rounded-2xl border border-white/8 bg-[#141821] p-4 sm:p-5 space-y-3">
        <button type="button" onClick={() => setFactoryView('overview')} className="inline-flex min-h-[40px] items-center gap-2 rounded-xl bg-[#1B2230] px-3 text-xs font-semibold text-[#F4F5F7]"><ArrowLeft className="h-4 w-4" />{isAr ? 'العودة إلى مصانعي' : 'Back to My factories'}</button>
        <div><h3 className="text-sm font-bold text-[#F4F5F7]">{isAr ? 'تأسيس مصنع جديد' : 'Found a new factory'}</h3><p className="mt-1 text-xs text-[#9299A6]">{isAr ? 'المصانع لا تنتج أموالاً؛ تنتج موارد خاماً وتستهلك مصاريف تشغيل مرتفعة.' : 'Factories do not generate credits; they produce raw resources and incur substantial operating costs.'}</p></div>
        <form onSubmit={handleFoundFactory} className="space-y-3">
          <label className="block space-y-1"><span className="text-xs text-[#9299A6]">{isAr ? 'اسم المصنع' : 'Factory name'}</span><input value={factoryName} onChange={(event) => setFactoryName(event.target.value)} minLength={2} maxLength={48} required placeholder={isAr ? 'مصنع النحاس المتقدم' : 'Advanced Copper Works'} className="w-full min-h-[44px] rounded-xl border border-white/10 bg-[#0B0D12] px-3 text-sm text-[#F4F5F7]" /></label>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
            {FACTORY_RESOURCES.map((resource) => (
              <button key={resource.resourceId} type="button" onClick={() => setResourceId(resource.resourceId)} className={`rounded-xl border p-3 text-start transition-colors ${resourceId === resource.resourceId ? 'border-[#397BFF] bg-[#1B2230]' : 'border-white/8 bg-[#0B0D12]'}`}>
                <span className="mb-2 flex items-center gap-2"><ResourceIcon itemId={resource.resourceId} size="md" /><span className="text-xs font-semibold text-[#F4F5F7]">{isAr ? resource.nameAr : resource.nameEn}</span></span>
                <span className="mt-1 block text-[11px] text-[#9299A6]">{isAr ? resource.descriptionAr : resource.descriptionEn}</span>
                <span className="mt-2 block text-xs font-bold text-[#9CBFFF]">${resource.foundingCost.toLocaleString()} · {resource.productionPerHour} {isAr ? 'وحدة/ساعة' : 'units/hr'}</span>
              </button>
            ))}
          </div>
          <button type="submit" disabled={factories.length >= 3 || busyKey === 'found'} className="w-full min-h-[44px] rounded-xl bg-[#397BFF] px-4 text-sm font-semibold text-white hover:bg-[#2F6DE0] disabled:opacity-40">{busyKey === 'found' ? '...' : factories.length >= 3 ? (isAr ? 'اكتمل الحد الأقصى (3 مصانع)' : 'Three-factory limit reached') : (isAr ? `تأسيس المصنع · ${(FACTORY_RESOURCES.find((item) => item.resourceId === resourceId)?.foundingCost ?? 0).toLocaleString()}` : `Found factory · ${(FACTORY_RESOURCES.find((item) => item.resourceId === resourceId)?.foundingCost ?? 0).toLocaleString()}`)}</button>
        </form>
      </section>}
    </div>
  );
}
