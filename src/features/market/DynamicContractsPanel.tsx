import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Building2, Loader2, RefreshCw,
  ShieldCheck, Timer,
} from 'lucide-react';
import { ResourceIcon } from '../../components/ui/ResourceIcon';
import { useToast } from '../../components/ui/ToastProvider';
import { ITEM_MAP } from '../../data/catalog';
import { useTranslations } from '../../i18n/translations';
import {
  acceptDynamicContract, abandonDynamicContract, claimDynamicContract,
  deliverDynamicContract, getDynamicContractBoard,
} from '../../services/gameService';
import type {
  DynamicContractOffer, Language, OrgWeeklyGoal, PlayerProfile, InventoryItem, Wallet,
} from '../../types/game';

interface DynamicContractsPanelProps {
  profile: PlayerProfile;
  inventory: InventoryItem[];
  wallet: Wallet | null;
  language: Language;
}

function remainingLabel(target: string | null | undefined, now: number): string {
  if (!target) return '—';
  const seconds = Math.max(0, Math.floor((new Date(target).getTime() - now) / 1000));
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;
  return hours > 0
    ? `${hours}:${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`
    : `${minutes}:${String(secs).padStart(2, '0')}`;
}

function secondsLabel(value: number | null): string {
  const seconds = Math.max(0, value ?? 0);
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;
  return hours > 0
    ? `${hours}:${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`
    : `${minutes}:${String(secs).padStart(2, '0')}`;
}

function statusText(status: DynamicContractOffer['status'], t: ReturnType<typeof useTranslations>) {
  const map: Record<DynamicContractOffer['status'], string> = {
    offered: t.contractOffered,
    accepted: t.contractAccepted,
    processing: t.contractProcessing,
    ready: t.contractReady,
    completed: t.contractCompleted,
    expired: t.contractExpired,
    abandoned: t.contractAbandoned,
  };
  return map[status];
}

function tierText(tier: DynamicContractOffer['tier'], t: ReturnType<typeof useTranslations>) {
  const map: Record<DynamicContractOffer['tier'], string> = {
    common: t.contractTierCommon,
    uncommon: t.contractTierUncommon,
    rare: t.contractTierRare,
    epic: t.contractTierEpic,
  };
  return map[tier];
}

export function DynamicContractsPanel({ profile, inventory, wallet, language }: DynamicContractsPanelProps) {
  const t = useTranslations(language);
  const { showToast } = useToast();
  const [contracts, setContracts] = useState<DynamicContractOffer[]>([]);
  const [orgContracts, setOrgContracts] = useState<DynamicContractOffer[]>([]);
  const [dailyUsed, setDailyUsed] = useState(0);
  const [dailyLimit, setDailyLimit] = useState(5);
  const [activePersonal, setActivePersonal] = useState(0);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [now, setNow] = useState(Date.now());
  const [activeContractTab, setActiveContractTab] = useState<'personal' | 'organization'>('personal');
  const inventoryMap = useMemo(
    () => new Map<string, number>(inventory.map((item) => [item.itemId, item.quantity] as [string, number])),
    [inventory],
  );

  const refresh = useCallback(async () => {
    try {
      const board = await getDynamicContractBoard();
      setContracts(board.personal ?? []);
      setOrgContracts(board.organization ?? []);
      setDailyUsed(board.daily_used ?? 0);
      setDailyLimit(board.daily_limit ?? 5);
      setActivePersonal(board.active_personal ?? 0);
    } catch (error) {
      const code = error instanceof Error ? error.message : '';
      if (code !== 'NOT_IN_ORG') {
        showToast(language === 'ar' ? 'تعذر تحميل العقود والأهداف.' : 'Could not load contracts and goals.', 'error');
      }
    } finally {
      setLoading(false);
    }
  }, [profile.orgId, language, showToast]);

  useEffect(() => {
    void refresh();
    const onRefresh = () => { void refresh(); };
    window.addEventListener('nova:refresh-game', onRefresh);
    window.addEventListener('focus', onRefresh);
    const poll = window.setInterval(onRefresh, 15000);
    const clock = window.setInterval(() => setNow(Date.now()), 1000);
    return () => {
      window.removeEventListener('nova:refresh-game', onRefresh);
      window.removeEventListener('focus', onRefresh);
      window.clearInterval(poll);
      window.clearInterval(clock);
    };
  }, [refresh]);

  async function runAction(contract: DynamicContractOffer, action: 'accept' | 'deliver' | 'abandon' | 'claim') {
    setBusyId(contract.id);
    try {
      if (action === 'accept') await acceptDynamicContract(contract.id);
      if (action === 'deliver') await deliverDynamicContract(contract.id);
      if (action === 'abandon') await abandonDynamicContract(contract.id);
      if (action === 'claim') await claimDynamicContract(contract.id);
      const messages = {
        accept: language === 'ar' ? 'تم استلام العقد وبدأت المهلة.' : 'Contract accepted. The deadline has started.',
        deliver: language === 'ar' ? 'تم تسليم المواد وبدأت المعالجة.' : 'Materials delivered. Processing has started.',
        abandon: language === 'ar' ? 'تم التخلي عن العقد.' : 'Contract abandoned.',
        claim: language === 'ar' ? 'تم استلام مكافأة العقد.' : 'Contract reward claimed.',
      };
      showToast(messages[action], 'success');
      await refresh();
    } catch (error) {
      const code = error instanceof Error ? error.message : '';
      const messages: Record<string, [string, string]> = {
        DAILY_CONTRACT_LIMIT_REACHED: ['استهلكت فرص العقود الخمس لهذا اليوم.', 'You have used all five contract attempts today.'],
        ACTIVE_CONTRACT_LIMIT: ['لديك 3 عقود شخصية نشطة بالفعل.', 'You already have three active personal contracts.'],
        ORG_ACTIVE_CONTRACT_LIMIT: ['لديك عقد منظمة نشط بالفعل.', 'You already have an active organization contract.'],
        ORG_MEMBERSHIP_TOO_NEW: ['يجب أن تمر 8 ساعات على عضويتك في المنظمة.', 'Organization membership must be at least 8 hours old.'],
        MISSING_INPUTS: ['المواد المطلوبة غير متوفرة في المخزون.', 'Required materials are missing from inventory.'],
        INSUFFICIENT_FUNDS: ['رصيدك لا يكفي لرسوم المعالجة.', 'Your balance cannot cover the processing fee.'],
        CONTRACT_NOT_READY: ['لم تنتهِ المعالجة بعد.', 'Processing is not finished yet.'],
        CONTRACT_EXPIRED: ['انتهت مهلة العقد وتم استبداله بعرض جديد.', 'The contract expired and was replaced with a new offer.'],
        CONTRACT_CANNOT_BE_ABANDONED: ['يمكن التخلي عن العقد قبل التسليم فقط.', 'A contract can only be abandoned before delivery.'],
        CONTRACT_ALREADY_CLAIMED: ['حجز عضو آخر هذا العقد.', 'Another member has reserved this contract.'],
      };
      const message = messages[code]?.[language === 'ar' ? 0 : 1]
        ?? (language === 'ar' ? `تعذرت العملية: ${code || 'خطأ غير معروف'}` : `Action failed: ${code || 'Unknown error'}`);
      showToast(message, 'error');
      await refresh();
    } finally {
      setBusyId(null);
    }
  }

  function renderContract(contract: DynamicContractOffer, organization = false) {
    const item = ITEM_MAP[contract.item_id];
    if (!item) return null;
    const owned = inventoryMap.get(contract.item_id) ?? 0;
    const fee = Math.round(contract.payout * 0.04);
    const isOwnedContract = !organization || contract.claimed_by === profile.uid;
    const isReservedByOther = organization && contract.claimed_by && contract.claimed_by !== profile.uid;
    const countdownTarget = contract.status === 'accepted'
      ? contract.deadline_at
      : contract.status === 'processing'
        ? contract.ready_at
        : contract.status === 'offered' ? contract.offer_expires_at : null;
    const countdownLabel = contract.status === 'accepted'
      ? t.deadline
      : contract.status === 'processing'
        ? t.readyIn
        : t.offerEndsIn;
    const canAccept = contract.status === 'offered' && !isReservedByOther
      && dailyUsed < dailyLimit && (organization || activePersonal < 3);
    const canDeliver = contract.status === 'accepted' && isOwnedContract && owned >= contract.quantity && (wallet?.balance ?? 0) >= fee;
    const isBusy = busyId === contract.id;
    const tierColor: Record<DynamicContractOffer['tier'], string> = {
      common: 'text-slate-300 border-slate-400/25 bg-slate-400/10',
      uncommon: 'text-sky-300 border-sky-400/25 bg-sky-400/10',
      rare: 'text-violet-300 border-violet-400/25 bg-violet-400/10',
      epic: 'text-amber-300 border-amber-400/25 bg-amber-400/10',
    };
    return (
      <article key={contract.id} className="rounded-2xl border border-white/10 bg-[#111A2C] p-4 flex flex-col gap-3 min-w-0">
        <div className="flex items-start justify-between gap-3">
          <div className="flex items-center gap-3 min-w-0">
            <ResourceIcon itemId={contract.item_id} size="md" />
            <div className="min-w-0">
              <h3 className="text-sm font-bold text-[#EAF1FF] truncate">{language === 'ar' ? item.nameAr : item.nameEn}</h3>
              <p className="text-[11px] text-[#8FA1BF]">{t.requiredQuantity}: <b className="text-white font-mono-num">{contract.quantity.toLocaleString()}</b></p>
            </div>
          </div>
          <span className={`shrink-0 rounded-lg border px-2 py-1 text-[10px] font-semibold ${tierColor[contract.tier]}`}>{tierText(contract.tier, t)}</span>
        </div>
        <div className="grid grid-cols-2 gap-2">
          <div className="rounded-xl bg-[#0A1221] p-2.5">
            <p className="text-[10px] text-[#8192AD]">{t.contractReward}</p>
            <p className="text-sm font-bold text-emerald-300 font-mono-num">{contract.payout.toLocaleString()} $</p>
          </div>
          <div className="rounded-xl bg-[#0A1221] p-2.5">
            <p className="text-[10px] text-[#8192AD]">{t.processingTime}</p>
            <p className="text-sm font-semibold text-white font-mono-num">{contract.processing_minutes} min</p>
          </div>
        </div>
        <div className="flex items-center justify-between gap-2 text-[11px]">
          <span className="text-[#8FA1BF]">{t.contractStatus ?? (language === 'ar' ? 'الحالة' : 'Status')}</span>
          <span className="text-[#EAF1FF] font-semibold">{statusText(contract.status, t)}</span>
        </div>
        {countdownTarget && (
          <div className="flex items-center justify-between gap-2 text-[11px]">
            <span className="text-[#8FA1BF]">{countdownLabel}</span>
            <span className="flex items-center gap-1.5 text-[#D7E5FF] font-mono-num"><Timer className="w-3.5 h-3.5" />{remainingLabel(countdownTarget, now)}</span>
          </div>
        )}
        {contract.status === 'processing' && contract.deadline_remaining_secs !== null && (
          <div className="flex items-center justify-between gap-2 text-[10px]">
            <span className="text-[#8192AD]">{t.deadlineFrozen}</span>
            <span className="text-[#9FB1CC] font-mono-num">{secondsLabel(contract.deadline_remaining_secs)}</span>
          </div>
        )}
        {contract.event_premium > 0 && (
          <p className="text-[10px] text-amber-300">{t.contractEventBonus}: +{(contract.event_premium * 100).toFixed(1)}%</p>
        )}
        {contract.status === 'accepted' && (
          <div className="space-y-2">
            <div className="flex justify-between text-[11px]">
              <span className="text-[#8FA1BF]">{t.requiredQuantity}</span>
              <span className={owned >= contract.quantity ? 'text-emerald-300' : 'text-rose-300'}>{owned} / {contract.quantity}</span>
            </div>
            <div className="flex justify-between text-[11px]">
              <span className="text-[#8FA1BF]">{t.processingFee}</span>
              <span className="text-rose-300 font-mono-num">{fee.toLocaleString()} $</span>
            </div>
          </div>
        )}
        {isReservedByOther && <p className="text-[11px] text-amber-300">{t.reservedByMember}</p>}
        <div className="flex flex-wrap gap-2 mt-auto pt-1">
          {contract.status === 'offered' && (
            <button type="button" disabled={!canAccept || isBusy} onClick={() => void runAction(contract, 'accept')}
              className="flex-1 min-h-10 rounded-xl bg-[#2468D8] hover:bg-[#347CF0] text-white text-xs font-bold disabled:opacity-40">
              {isBusy ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : t.acceptContract}
            </button>
          )}
          {contract.status === 'accepted' && isOwnedContract && (
            <>
              <button type="button" disabled={!canDeliver || isBusy} onClick={() => void runAction(contract, 'deliver')}
                className="flex-1 min-h-10 rounded-xl bg-[#2468D8] hover:bg-[#347CF0] text-white text-xs font-bold disabled:opacity-40">
                {isBusy ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : t.deliverContract}
              </button>
              <button type="button" disabled={isBusy} onClick={() => void runAction(contract, 'abandon')}
                className="min-h-10 rounded-xl border border-rose-400/25 px-3 text-rose-300 text-xs font-semibold disabled:opacity-40">{t.abandonContract}</button>
            </>
          )}
          {contract.status === 'accepted' && isReservedByOther && (
            <p className="w-full text-center text-[11px] text-amber-300">{t.reservedByMember}</p>
          )}
          {contract.status === 'processing' && isOwnedContract && (
            <div className="w-full rounded-xl bg-sky-400/10 border border-sky-400/20 px-3 py-2 text-center text-xs text-sky-200 flex items-center justify-center gap-2">
              <Loader2 className="w-4 h-4 animate-spin" />{t.contractProcessing}
            </div>
          )}
          {contract.status === 'processing' && isReservedByOther && (
            <p className="w-full text-center text-[11px] text-amber-300">{t.reservedByMember}</p>
          )}
          {contract.status === 'ready' && isOwnedContract && (
            <button type="button" disabled={isBusy} onClick={() => void runAction(contract, 'claim')}
              className="flex-1 min-h-10 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold disabled:opacity-40">
              {isBusy ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : t.claimContractReward}
            </button>
          )}
          {contract.status === 'ready' && isReservedByOther && (
            <p className="w-full text-center text-[11px] text-amber-300">{t.reservedByMember}</p>
          )}
        </div>
      </article>
    );
  }

  const personal = contracts.map((contract) => renderContract(contract)).filter(Boolean);
  const organization = orgContracts.map((contract) => renderContract(contract, true)).filter(Boolean);


  return (
    <div className="space-y-6">
      <section className="rounded-2xl border border-white/10 bg-gradient-to-br from-[#142644] to-[#101A30] p-4 sm:p-5 space-y-3">
        <div className="flex items-center justify-between gap-3">
          <div>
            <h2 className="text-lg font-bold text-white">{t.dynamicContracts}</h2>
            <p className="text-xs text-[#A9B9D4] mt-1">{t.dailyRemaining}: {Math.max(0, dailyLimit - dailyUsed)} / {dailyLimit} · {t.activeContractLimit}: {activePersonal} / 3</p>
          </div>
          <button type="button" onClick={() => void refresh()} className="min-h-10 min-w-10 rounded-xl bg-white/10 flex items-center justify-center text-white" aria-label={language === 'ar' ? 'تحديث' : 'Refresh'}>
            <RefreshCw className="w-4 h-4" />
          </button>
        </div>
        <div className="h-2 rounded-full bg-black/25 overflow-hidden">
          <div className="h-full rounded-full bg-[#5797FF] transition-all" style={{ width: `${Math.min(100, dailyUsed / Math.max(1, dailyLimit) * 100)}%` }} />
        </div>
      </section>

      {loading && <div className="py-10 text-center text-sm text-[#9BAEC9]"><Loader2 className="w-5 h-5 animate-spin mx-auto mb-2" />{t.loadingContracts}</div>}

      {!loading && (
        <>
          <div className="flex gap-2 rounded-xl border border-white/10 bg-[#0B1425] p-1.5" role="tablist" aria-label={language === 'ar' ? 'أنواع العقود' : 'Contract types'}>
            <button type="button" role="tab" aria-selected={activeContractTab === 'personal'} onClick={() => setActiveContractTab('personal')} className={`flex-1 min-h-10 rounded-lg px-3 text-xs font-bold transition-colors ${activeContractTab === 'personal' ? 'bg-[#2468D8] text-white' : 'text-[#9AAEC9] hover:text-white'}`}>{t.personalContracts}</button>
            {profile.orgId && <button type="button" role="tab" aria-selected={activeContractTab === 'organization'} onClick={() => setActiveContractTab('organization')} className={`flex-1 min-h-10 rounded-lg px-3 text-xs font-bold transition-colors ${activeContractTab === 'organization' ? 'bg-[#2468D8] text-white' : 'text-[#9AAEC9] hover:text-white'}`}>{t.organizationContracts}</button>}
          </div>
          {activeContractTab === 'personal' && (
          <section className="space-y-3">
            <div className="flex items-center justify-between gap-2">
              <h3 className="text-base font-bold text-white flex items-center gap-2"><ShieldCheck className="w-4 h-4 text-sky-300" />{t.personalContracts}</h3>
              <span className="text-[10px] text-[#8192AD]">{contracts.filter((contract) => contract.status === 'offered' && contract.slot_no >= 1 && contract.slot_no <= 6).length} / 6</span>
            </div>
            {personal.length ? <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3">{personal}</div> : <p className="rounded-xl border border-white/10 p-5 text-center text-xs text-[#8192AD]">{t.noContracts}</p>}
          </section>
          )}

          {profile.orgId && activeContractTab === 'organization' && (
            <>
              <section className="space-y-3">
                <h3 className="text-base font-bold text-white flex items-center gap-2"><Building2 className="w-4 h-4 text-amber-300" />{t.organizationContracts}</h3>
                <p className="text-[11px] text-[#8192AD]">{language === 'ar' ? 'اللوحة مشتركة، وأول عضو يستلم العقد يحجزه حتى ينتهي.' : 'Shared board: the first member to accept reserves a contract until it ends.'}</p>
                {organization.length ? <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3">{organization}</div> : <p className="rounded-xl border border-white/10 p-5 text-center text-xs text-[#8192AD]">{t.noContracts}</p>}
              </section>

            </>
          )}
        </>
      )}
    </div>
  );
}
