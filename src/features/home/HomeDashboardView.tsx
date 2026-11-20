import { ArrowDownLeft, ArrowUpRight, Award, CalendarCheck, Flame, TrendingUp } from 'lucide-react';
import { useState } from 'react';
import { EconomicChart } from '../../components/ui/EconomicChart';
import { ResourceIcon } from '../../components/ui/ResourceIcon';
import { getMissionPeriodKey } from '../../lib/missionPeriods';
import { useToast } from '../../components/ui/ToastProvider';
import { AVATARS, CATALOG_ITEMS, ITEM_MAP, MISSIONS } from '../../data/catalog';
import { useTranslations, formatTxType } from '../../i18n/translations';
import {
  calculateDailyStipend,
  calculateDynamicItemPrice,
  calculateLevelProgress,
  calculateMarketTaxRate,
  getActiveWorldEvents,
  getMissionProgress,
  getReputationTier,
  timestampToMs,
} from '../../lib/economy';
import { claimDailyStipend, claimMissionReward } from '../../services/gameService';
import type {
  Language,
  MainTab,
  MarketListing,
  PlayerMissionClaim,
  PlayerProfile,
  TransactionRecord,
  Wallet,
  WorldEvent,
} from '../../types/game';

interface HomeDashboardViewProps {
  profile: PlayerProfile;
  wallet: Wallet | null;
  transactions: TransactionRecord[];
  claimedMissions: PlayerMissionClaim[];
  claimedDailyToday: boolean;
  notifications: import('../../types/game').GameNotification[];
  worldEvents: WorldEvent[];
  marketListings: MarketListing[];
  language: Language;
  onNavigate: (tab: MainTab) => void;
  onOpenMissions: () => void;
}

export function HomeDashboardView({
  profile,
  wallet,
  transactions,
  claimedMissions,
  claimedDailyToday,
  notifications,
  worldEvents,
  marketListings,
  language,
  onNavigate,
  onOpenMissions,
}: HomeDashboardViewProps) {
  const t = useTranslations(language);
  const { showToast } = useToast();
  const [busyId, setBusyId] = useState<string | null>(null);

  const xpProg = calculateLevelProgress(profile.xp);
  const avatar = AVATARS.find((a) => a.id === profile.avatarId) || AVATARS[0];
  const dailyStipendAlert = notifications.some((notification) => !notification.read && notification.eventKey?.startsWith('daily-stipend-ready:'));
  const dailyAmount = calculateDailyStipend(profile.level, profile.skills.finance || 0);
  const activeEvents = getActiveWorldEvents(worldEvents);
  const taxRate = calculateMarketTaxRate(profile.skills.trade || 0, activeEvents);
  const repTier = getReputationTier(profile.reputation);

  const claimedSet = new Set(claimedMissions.filter((m) => (m.periodKey ?? 'lifetime') === getMissionPeriodKey(m.missionId)).map((m) => m.missionId));
  const getProgress = (mission: (typeof MISSIONS)[number]) => mission.id === 'daily_active_trader'
    ? (profile.dailyTradesCount ?? 0)
    : getMissionProgress(mission.metric, profile);

  // Compute dynamic market index across 5 benchmark commodities
  const chartData = CATALOG_ITEMS.slice(0, 5).map((item) => {
    const supply = marketListings
      .filter((l) => l.itemId === item.id && l.status === 'active')
      .reduce((acc, l) => acc + l.remainingQty, 0);
    return {
      label: language === 'ar' ? item.nameAr.split(' ')[0] : item.nameEn.split(' ')[0],
      value: calculateDynamicItemPrice(item.id, supply, activeEvents),
    };
  });

  async function handleDailyClaim() {
    setBusyId('daily');
    try {
      const credited = await claimDailyStipend(profile.uid);
      showToast(
        language === 'ar'
          ? `تم استلام +${credited} $ و40 XP.`
          : `Claimed +${credited} $ and 40 XP.`,
        'success'
      );
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      showToast(
        code === 'ALREADY_CLAIMED_TODAY'
          ? language === 'ar'
            ? 'لقد استلمت العائد اليومي بالفعل.'
            : 'Daily stipend already claimed today.'
          : language === 'ar'
          ? 'تعذر تنفيذ العملية.'
          : 'Action failed.',
        'error'
      );
    } finally {
      setBusyId(null);
    }
  }

  async function handleClaimMission(missionId: string) {
    setBusyId(missionId);
    try {
      await claimMissionReward(profile.uid, missionId);
      showToast(
        language === 'ar' ? 'تمت إضافة مكافأة المهمة إلى رصيدك.' : 'Mission reward credited.',
        'success'
      );
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      showToast(
        code === 'MISSION_ALREADY_CLAIMED'
          ? language === 'ar'
            ? 'تم استلام مكافأة هذه المهمة بالفعل.'
            : 'Mission reward already claimed.'
          : code === 'MISSION_NOT_COMPLETE'
          ? language === 'ar'
            ? 'لم تكتمل شروط المهمة بعد.'
            : 'Mission requirements not met yet.'
          : language === 'ar'
          ? 'تعذر استلام المكافأة.'
          : 'Could not claim reward.',
        'error'
      );
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="space-y-6">
      {/* Top Executive Identity & Core Stats */}
      <section className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="lg:col-span-2 bg-[#141821] border border-white/8 rounded-2xl p-5 flex flex-col justify-between gap-5">
          <div className="flex items-center justify-between gap-4">
            <div className="flex items-center gap-3.5 min-w-0">
              <img
                src={avatar.src}
                alt={profile.username}
                referrerPolicy="no-referrer"
                className="w-14 h-14 rounded-xl object-cover border border-white/10 shrink-0"
              />
              <div className="min-w-0">
                <h1 className="text-lg font-bold text-[#F4F5F7] truncate">{profile.username}</h1>
                <p className="text-xs text-[#9299A6] mt-0.5">
                  {profile.title} · {t.level} {profile.level}
                </p>
              </div>
            </div>

            <div className="text-end shrink-0">
              <p className="text-xs text-[#9299A6]">{t.balance}</p>
              <p className="text-xl font-bold font-mono-num text-[#F4F5F7]">
                {'$'}{(wallet?.balance ?? 0).toLocaleString()}
              </p>
            </div>
          </div>

          {/* XP Bar */}
          <div className="space-y-1.5">
            <div className="flex items-center justify-between text-xs">
              <span className="text-[#9299A6]">
                {t.xp}: <span className="font-mono-num text-[#F4F5F7]">{xpProg.currentLevelXp} / {xpProg.nextLevelXp}</span>
              </span>
              <span className="font-mono-num text-[#63A5FF] font-medium">
                {xpProg.progressPercent}%
              </span>
            </div>
            <div className="h-2 rounded-full bg-[#0B0D12] overflow-hidden border border-white/6">
              <div
                className="h-full bg-[#397BFF] rounded-full transition-all duration-300"
                style={{ width: `${xpProg.progressPercent}%` }}
              />
            </div>
          </div>

          {/* 3 Metric Summary Row */}
          <div className="grid grid-cols-3 gap-3 pt-3 border-t border-white/8">
            <div>
              <p className="text-xs text-[#9299A6]">{t.reputation}</p>
              <p className="text-base font-semibold font-mono-num text-[#F4F5F7] mt-0.5">
                {profile.reputation.toLocaleString()}
              </p>
              <p className="text-[11px] text-[#63A5FF] truncate mt-0.5">
                {language === 'ar' ? repTier.titleAr : repTier.titleEn}
              </p>
            </div>
            <div>
              <p className="text-xs text-[#9299A6]">{t.influence}</p>
              <p className="text-base font-semibold font-mono-num text-[#F4F5F7] mt-0.5">
                {profile.influence.toLocaleString()}
              </p>
            </div>
            <div>
              <p className="text-xs text-[#9299A6]">{t.skillPoints}</p>
              <p className="text-base font-semibold font-mono-num text-[#63A5FF] mt-0.5">
                {profile.skillPoints}
              </p>
            </div>
          </div>
        </div>

        {/* Daily Interactive Stipend & Quick Actions */}
        <div className="bg-[#141821] border border-white/8 rounded-2xl p-5 flex flex-col justify-between gap-4">
          <div className="space-y-1.5">
            <div className="flex items-center justify-between">
              <h2 className="text-base font-semibold text-[#F4F5F7] flex items-center gap-2">{t.dailyOperation}{(!claimedDailyToday || dailyStipendAlert) && <span className="inline-flex h-2.5 w-2.5 rounded-full bg-red-500" aria-label={language === 'ar' ? 'مكافأة جاهزة' : 'Reward ready'} />}</h2>
              <CalendarCheck className="w-4 h-4 text-[#63A5FF]" />
            </div>
            <p className="text-xs text-[#9299A6] leading-relaxed">
              {language === 'ar'
                ? 'عائد التشغيل اليومي يزداد مع مستواك ومهارة التحليل المالي.'
                : 'Daily operating stipend scales with your Level and Financial Analysis skill.'}
            </p>
          </div>

          <div className="bg-[#0B0D12] border border-white/6 rounded-xl p-3.5 flex items-center justify-between">
            <span className="text-xs text-[#9299A6]">{language === 'ar' ? 'المكافأة' : 'Payout'}</span>
            <span className="text-base font-bold font-mono-num text-[#F4F5F7]">
              +{'$'}{dailyAmount.toLocaleString()}
            </span>
          </div>

          <button
            type="button"
            disabled={claimedDailyToday || busyId === 'daily'}
            onClick={handleDailyClaim}
            className="w-full min-h-[44px] px-4 py-2.5 rounded-xl bg-[#397BFF] hover:bg-[#2F6DE0] text-white text-sm font-semibold transition-colors disabled:bg-[#1B2230] disabled:text-[#9299A6]"
          >
            {claimedDailyToday ? t.dailyClaimed : busyId === 'daily' ? '...' : t.dailyClaimBtn}
          </button>
        </div>
      </section>

      {/* Economic Index Chart & Active World Events */}
      <section className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-base font-semibold text-[#F4F5F7]">{t.economicIndicators}</h2>
              <p className="text-xs text-[#9299A6] mt-0.5">
                {t.marketTax}: <span className="font-mono-num text-[#F4F5F7]">{(taxRate * 100).toFixed(1)}%</span>
              </p>
            </div>
            <button
              type="button"
              onClick={() => onNavigate('market')}
              className="text-xs font-medium text-[#63A5FF] hover:underline whitespace-nowrap"
            >
              {t.navMarket}
            </button>
          </div>
          <EconomicChart data={chartData} />
        </div>

        <div className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-3.5">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-semibold text-[#F4F5F7]">{t.worldEvents}</h2>
            <Flame className="w-4 h-4 text-[#63A5FF]" />
          </div>
          {activeEvents.length === 0 ? (
            <p className="text-sm text-[#9299A6] py-6 text-center">
              {language === 'ar' ? 'السوق في حالة استقرار قياسي.' : 'Markets are operating under baseline conditions.'}
            </p>
          ) : (
            <div className="space-y-3">
              {activeEvents.map((evt) => {
                const endsMs = timestampToMs(evt.endsAt, 0);
                const hoursLeft =
                  endsMs > Date.now() ? Math.max(1, Math.ceil((endsMs - Date.now()) / 3_600_000)) : null;
                const targetItem = evt.targetItemId ? ITEM_MAP[evt.targetItemId] : null;
                const revMult = evt.revenueMultiplier ?? 1;

                return (
                  <div
                    key={evt.id}
                    className="p-3.5 rounded-xl bg-[#0B0D12] border border-white/6 space-y-1.5"
                  >
                    <div className="flex items-center justify-between gap-2">
                      <p className="text-sm font-medium text-[#F4F5F7]">
                        {language === 'ar' ? evt.titleAr : evt.titleEn}
                      </p>
                      <span className="text-xs font-mono-num text-[#63A5FF] shrink-0">
                        {evt.priceMultiplier !== 1
                          ? `×${evt.priceMultiplier.toFixed(2)}`
                          : `${evt.taxDelta > 0 ? '+' : ''}${(evt.taxDelta * 100).toFixed(0)}% ${t.marketTax}`}
                      </span>
                    </div>
                    <p className="text-xs text-[#9299A6] leading-relaxed">
                      {language === 'ar' ? evt.descriptionAr : evt.descriptionEn}
                    </p>
                    <div className="flex flex-wrap items-center gap-3 text-[11px] text-[#9299A6] pt-0.5">
                      {targetItem && (
                        <span className="inline-flex items-center gap-1.5">
                          <ResourceIcon itemId={evt.targetItemId!} size="sm" />
                          {language === 'ar' ? targetItem.nameAr : targetItem.nameEn}
                        </span>
                      )}
                      {Math.abs(revMult - 1) > 0.001 && (
                        <span className={revMult >= 1 ? 'text-emerald-400 font-mono-num' : 'text-amber-300 font-mono-num'}>
                          {language === 'ar' ? 'عائد القطاعات' : 'Sector'}: ×{revMult.toFixed(2)}
                        </span>
                      )}
                      {hoursLeft !== null && (
                        <span className="font-mono-num">
                          {language === 'ar' ? `${hoursLeft} س متبقية` : `${hoursLeft}h left`}
                        </span>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </section>

      {/* Active Missions & Recent Activity */}
      <section className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-3.5">
          <div className="flex items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <Award className="w-4 h-4 text-[#63A5FF]" />
              <h2 className="text-base font-semibold text-[#F4F5F7]">{language === 'ar' ? 'المهام اليومية' : 'Daily Missions'}</h2>
            </div>
            <button
              type="button"
              onClick={onOpenMissions}
              className="text-xs font-medium text-[#63A5FF] hover:underline whitespace-nowrap"
            >
              {t.allMissions}
            </button>
          </div>
          <div className="space-y-2.5">
            {[...MISSIONS]
              .filter((mission) => mission.category === 'daily')
              .sort((a, b) => {
                const aClaimed = claimedSet.has(a.id) ? 1 : 0;
                const bClaimed = claimedSet.has(b.id) ? 1 : 0;
                if (aClaimed !== bClaimed) return aClaimed - bClaimed;
                const aReady = getProgress(a) >= a.targetCount ? 0 : 1;
                const bReady = getProgress(b) >= b.targetCount ? 0 : 1;
                return aReady - bReady;
              })
              .slice(0, 4)
              .map((m) => {
                const isClaimed = claimedSet.has(m.id);
                const val = getProgress(m);
                const pct = Math.min(100, Math.round((Math.min(val, m.targetCount) / m.targetCount) * 100));
                const ready = val >= m.targetCount && !isClaimed;

                return (
                  <div
                    key={m.id}
                    className="p-3.5 rounded-xl bg-[#0B0D12] border border-white/6 space-y-2"
                  >
                    <div className="flex items-center justify-between gap-3">
                      <div className="min-w-0">
                        <p className="text-sm font-medium text-[#F4F5F7] truncate">
                          {language === 'ar' ? m.titleAr : m.titleEn}
                        </p>
                        <div className="flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-[#9299A6] mt-0.5" dir="ltr">
                          <span className="font-mono-num whitespace-nowrap">{Math.min(val, m.targetCount)}/{m.targetCount}</span>
                          <span className="text-[#667080]">•</span>
                          <span className="inline-flex items-center gap-1 whitespace-nowrap font-mono-num text-[#F4F5F7]">${m.rewardCredits.toLocaleString()}</span>
                          <span className="text-[#667080]">•</span>
                          <span className="inline-flex items-center gap-1 whitespace-nowrap font-mono-num text-[#F4F5F7]">+{m.rewardXp} XP</span>
                          <span className="text-[#667080]">•</span>
                          <span className="inline-flex items-center gap-1 whitespace-nowrap"><span className="font-mono-num">+{m.rewardReputation}</span><span dir={language === 'ar' ? 'rtl' : 'ltr'}>{t.reputation}</span></span>
                        </div>
                      </div>
                      <button
                        type="button"
                        disabled={!ready || busyId === m.id}
                        onClick={() => handleClaimMission(m.id)}
                        className={`min-h-[40px] px-3.5 rounded-xl text-xs font-semibold whitespace-nowrap shrink-0 transition-colors ${
                          isClaimed
                            ? 'bg-[#1B2230] text-[#9299A6]'
                            : ready
                            ? 'bg-[#397BFF] hover:bg-[#2F6DE0] text-white'
                            : 'bg-[#1B2230] text-[#9299A6]/70'
                        }`}
                      >
                        {isClaimed ? t.claimed : ready ? t.claimReward : t.inProgress}
                      </button>
                    </div>
                    <div className="h-1.5 rounded-full bg-[#141821] overflow-hidden">
                      <div
                        className={`h-full rounded-full transition-all duration-300 ${
                          isClaimed || ready ? 'bg-emerald-500' : 'bg-[#397BFF]'
                        }`}
                        style={{ width: `${pct}%` }}
                      />
                    </div>
                  </div>
                );
              })}
          </div>
        </div>

        {/* Recent Ledger Activity */}
        <div className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-3.5">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-semibold text-[#F4F5F7]">{t.recentActivity}</h2>
            <TrendingUp className="w-4 h-4 text-[#9299A6]" />
          </div>
          {transactions.length === 0 ? (
            <p className="text-sm text-[#9299A6] py-8 text-center">{t.noActivity}</p>
          ) : (
            <div className="space-y-2">
              {transactions.slice(0, 6).map((tx) => {
                const isCredit = tx.toUid === profile.uid;
                return (
                  <div
                    key={tx.id}
                    className="p-3 rounded-xl bg-[#0B0D12] border border-white/6 flex items-center justify-between gap-3"
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="w-8 h-8 rounded-lg bg-[#1B2230] flex items-center justify-center shrink-0">
                        {isCredit ? (
                          <ArrowDownLeft className="w-4 h-4 text-emerald-400" />
                        ) : (
                          <ArrowUpRight className="w-4 h-4 text-[#63A5FF]" />
                        )}
                      </div>
                      <div className="min-w-0">
                        <p className="text-xs font-medium text-[#F4F5F7] truncate">
                          {tx.description}
                        </p>
                        <p className="text-[11px] text-[#9299A6] mt-0.5">{formatTxType(tx.type, language)}</p>
                      </div>
                    </div>
                    <span
                      className={`text-sm font-mono-num font-semibold shrink-0 ${
                        isCredit ? 'text-emerald-400' : 'text-[#F4F5F7]'
                      }`}
                    >
                      {isCredit ? `+$${tx.netAmount.toLocaleString()}` : `-$${tx.amount.toLocaleString()}`}
                    </span>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </section>
    </div>
  );
}
