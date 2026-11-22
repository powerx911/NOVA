import { Activity, Award, Clock3, Globe, Lightbulb, LogOut, Medal, MessageSquareWarning, RefreshCw, ShieldCheck, Sliders, Trash2, Trophy, Volume2, Zap } from 'lucide-react';
import { lazy, Suspense, useCallback, useEffect, useState } from 'react';
import { EmailAuthProvider, reauthenticateWithCredential, reauthenticateWithPopup } from 'firebase/auth';
import { auth, googleAuthProvider } from '../../lib/firebase';
import { nexoraApi } from '../../lib/nexoraApi';
import { SupportTicketsPanel } from './SupportTicketsPanel';
import { useToast } from '../../components/ui/ToastProvider';
import { ACHIEVEMENTS, AVATARS, MISSIONS, SKILL_DEFINITIONS } from '../../data/catalog';
import { formatMissionCategory, useTranslations } from '../../i18n/translations';
import { getMissionPeriodKey } from '../../lib/missionPeriods';
import {
  getAchievementProgress,
  getMissionProgress,
  getNextReputationTier,
  getReputationTier,
} from '../../lib/economy';
import {
  verifyDiagnosticsOwnerAccess,
  type ClientSnapshotContext,
} from '../../services/diagnosticsService';
import {
  claimMissionReward,
  claimAchievementReward,
  fetchLeaderboards,
  updatePlayerAvatar,
  updatePlayerSettings,
  upgradeSkill,
  resetSkills,
  refreshPlayerAchievements,
  deletePlayerAccount,
} from '../../services/gameService';
import type {
  Company,
  Language,
  Organization,
  PlayerMissionClaim,
  PlayerProfile,
  ProfileSubTab,
  SkillKey,
  UserPrivate,
  Wallet,
} from '../../types/game';

const DiagnosticsView = lazy(() =>
  import('../diagnostics/DiagnosticsView').then((m) => ({ default: m.DiagnosticsView }))
);

interface ProfileHubViewProps {
  profile: PlayerProfile;
  wallet: Wallet | null;
  userPrivate: UserPrivate | null;
  claimedMissions: PlayerMissionClaim[];
  unlockedAchievements: Set<string>;
  claimedAchievements: Set<string>;
  notifications: import('../../types/game').GameNotification[];
  diagnosticsContext: ClientSnapshotContext;
  language: Language;
  onLanguageChange: (lang: Language) => void;
  onLogout: () => Promise<void>;
  initialSubTab?: ProfileSubTab;
}

export function ProfileHubView({
  profile,
  wallet,
  userPrivate,
  claimedMissions,
  unlockedAchievements,
  claimedAchievements,
  notifications,
  diagnosticsContext,
  language,
  onLanguageChange,
  onLogout,
  initialSubTab = 'overview',
}: ProfileHubViewProps) {
  const t = useTranslations(language);
  const { showToast } = useToast();

  const [subTab, setSubTab] = useState<ProfileSubTab>('overview');
  const [nowMs, setNowMs] = useState(() => Date.now());
  const [isOwnerAuthorized, setIsOwnerAuthorized] = useState(false);
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [lbTab, setLbTab] = useState<'players' | 'companies' | 'orgs'>('players');
  const [leaderboards, setLeaderboards] = useState<{
    players: PlayerProfile[];
    companies: Company[];
    organizations: Organization[];
  }>({ players: [], companies: [], organizations: [] });
  const [lbLoading, setLbLoading] = useState(false);
  const [lbError, setLbError] = useState(false);
  const [deleteConfirmOpen, setDeleteConfirmOpen] = useState(false);
  const [resetSkillsConfirmOpen, setResetSkillsConfirmOpen] = useState(false);
  const [deletePassword, setDeletePassword] = useState('');
  const [deleteBusy, setDeleteBusy] = useState(false);
  const [feedbackText, setFeedbackText] = useState('');
  const [feedbackImages, setFeedbackImages] = useState<File[]>([]);
  const [feedbackBusy, setFeedbackBusy] = useState(false);
  const [feedbackFormType, setFeedbackFormType] = useState<'issue' | 'suggestion' | null>(null);
  const [musicVolume, setMusicVolume] = useState(() => {
    try { const stored = window.localStorage.getItem('nexora-music-volume'); return stored === null ? 22 : Math.round(Math.max(0, Math.min(1, Number(stored))) * 100); } catch { return 22; }
  });
  const [buttonSoundEnabled, setButtonSoundEnabled] = useState(() => {
    try { return window.localStorage.getItem('nexora-button-sound') !== 'off'; } catch { return true; }
  });

  useEffect(() => {
    setSubTab(initialSubTab);
  }, [initialSubTab]);

  useEffect(() => {
    const timer = window.setInterval(() => setNowMs(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, []);

  useEffect(() => {
    if (subTab === 'achievements') {
      void refreshPlayerAchievements().catch(() => undefined);
    }
  }, [subTab, profile.uid]);

  const claimedSet = new Set(claimedMissions.filter((m) => (m.periodKey ?? 'lifetime') === getMissionPeriodKey(m.missionId)).map((m) => m.missionId));
  const getProgress = (mission: (typeof MISSIONS)[number]) => getMissionProgress(mission.metric, profile);
  const avatar = AVATARS.find((a) => a.id === profile.avatarId) || AVATARS[0];

  useEffect(() => {
    verifyDiagnosticsOwnerAccess()
      .then((res) => setIsOwnerAuthorized(res.authorized))
      .catch(() => setIsOwnerAuthorized(false));
  }, [profile.uid]);

  const loadLeaderboards = useCallback(() => {
    setLbLoading(true);
    setLbError(false);
    fetchLeaderboards()
      .then((res) => setLeaderboards(res))
      .catch(() => setLbError(true))
      .finally(() => setLbLoading(false));
  }, []);

  useEffect(() => {
    if (subTab !== 'rankings') return;
    loadLeaderboards();
  }, [subTab, loadLeaderboards]);

  async function handleAvatarChange(avatarId: string) {
    if (profile.avatarId === avatarId) return;
    setBusyKey(`av_${avatarId}`);
    try {
      await updatePlayerAvatar(profile.uid, avatarId);
      showToast(language === 'ar' ? 'تم تحديث الصورة الشخصية.' : 'Avatar updated.', 'success');
    } catch {
      showToast(
        language === 'ar' ? 'تعذر تحديث الصورة الشخصية.' : 'Could not update avatar.',
        'error'
      );
    } finally {
      setBusyKey(null);
    }
  }

  async function handleUpgradeSkill(key: SkillKey) {
    setBusyKey(`sk_${key}`);
    try {
      await upgradeSkill(profile.uid, key);
      showToast(language === 'ar' ? 'تم تطوير المهارة بنجاح.' : 'Skill upgraded.', 'success');
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      showToast(
        code === 'SKILL_MAXED'
          ? language === 'ar'
            ? 'وصلت هذه المهارة إلى الحد الأقصى.'
            : 'This skill is already at maximum level.'
          : code === 'NO_SKILL_POINTS'
          ? language === 'ar'
            ? 'لا توجد نقاط مهارة متاحة.'
            : 'No skill points available.'
          : language === 'ar'
          ? 'تعذر تطوير المهارة.'
          : 'Could not upgrade skill.',
        'error'
      );
    } finally {
      setBusyKey(null);
    }
  }

  async function handleResetSkills() {
    setBusyKey('reset_skills');
    try {
      await resetSkills(profile.uid);
      setResetSkillsConfirmOpen(false);
      showToast(language === 'ar' ? 'تمت إعادة تعيين المهارات وإرجاع النقاط.' : 'Skills reset and points refunded.', 'success');
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      showToast(code === 'INSUFFICIENT_FUNDS'
        ? (language === 'ar' ? 'تحتاج إلى 2,500 لإعادة تعيين المهارات.' : 'You need 2,500 credits to reset skills.')
        : code === 'NO_SKILLS_TO_RESET'
        ? (language === 'ar' ? 'لا توجد مهارات مطوّرة لإعادة تعيينها.' : 'There are no upgraded skills to reset.')
        : (language === 'ar' ? 'تعذر إعادة تعيين المهارات.' : 'Could not reset skills.'), 'error');
    } finally {
      setBusyKey(null);
    }
  }

  async function handleClaimAchievement(achievementId: string) {
    setBusyKey(`ach_${achievementId}`);
    try {
      await claimAchievementReward(profile.uid, achievementId);
      showToast(language === 'ar' ? 'تم استلام مكافأة الإنجاز.' : 'Achievement reward claimed.', 'success');
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      showToast(code === 'ACHIEVEMENT_ALREADY_CLAIMED'
        ? (language === 'ar' ? 'تم استلام هذه المكافأة بالفعل.' : 'This reward was already claimed.')
        : code === 'ACHIEVEMENT_NOT_UNLOCKED'
          ? (language === 'ar' ? 'الإنجاز لم يكتمل بعد.' : 'Achievement is not unlocked yet.')
          : (language === 'ar' ? 'تعذر استلام مكافأة الإنجاز.' : 'Could not claim achievement reward.'), 'error');
    } finally {
      setBusyKey(null);
    }
  }

  async function handleClaimMission(missionId: string) {
    setBusyKey(`mis_${missionId}`);
    try {
      await claimMissionReward(profile.uid, missionId);
      showToast(language === 'ar' ? 'تم استلام المكافأة.' : 'Reward claimed.', 'success');
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      showToast(
        code === 'MISSION_ALREADY_CLAIMED'
          ? language === 'ar'
            ? 'تم استلام مكافأة هذه المهمة بالفعل.'
            : 'Mission reward already claimed.'
          : code === 'MISSION_NOT_COMPLETE'
          ? language === 'ar'
            ? 'المهمة لم تكتمل بعد.'
            : 'Mission requirements not yet met.'
          : language === 'ar'
          ? 'تعذر استلام المكافأة.'
          : 'Could not claim reward.',
        'error'
      );
    } finally {
      setBusyKey(null);
    }
  }

  async function handleLanguageToggle(nextLang: Language) {
    onLanguageChange(nextLang);
    try {
      await updatePlayerSettings(
        profile.uid,
        nextLang,
        userPrivate?.notificationsEnabled ?? true
      );
    } catch {
      // Persisted locally as fallback
    }
  }



  async function handleDeleteAccount() {
    const user = auth.currentUser;
    if (!user) return;
    const providers = user.providerData.map((provider) => provider.providerId);
    if (!user.isAnonymous && providers.includes('password') && !deletePassword) {
      showToast(language === 'ar' ? 'أدخل كلمة المرور لتأكيد هويتك.' : 'Enter your password to confirm your identity.', 'error');
      return;
    }
    setDeleteBusy(true);
    try {
      if (user.isAnonymous) {
        // A newly-created anonymous session is already the active identity.
      } else if (providers.includes('password') && user.email) {
        await reauthenticateWithCredential(user, EmailAuthProvider.credential(user.email, deletePassword));
      } else if (providers.includes('google.com')) {
        await reauthenticateWithPopup(user, googleAuthProvider);
      } else {
        throw new Error('REAUTHENTICATION_REQUIRED');
      }
      await deletePlayerAccount();
      setDeleteConfirmOpen(false);
      showToast(language === 'ar' ? 'تم حذف الحساب وبيانات اللعب.' : 'Your account and game data have been deleted.', 'success');
      await onLogout();
    } catch (error) {
      const code = error instanceof Error ? error.message : '';
      const message = code === 'LEADER_MUST_TRANSFER'
        ? (language === 'ar' ? 'انقل قيادة منظمتك أولاً قبل حذف الحساب.' : 'Transfer your organization leadership before deleting this account.')
        : code === 'ACCOUNT_HAS_ACTIVE_AUCTION_BID'
        ? (language === 'ar' ? 'لديك مزايدة نشطة. انتظر انتهاء المزاد ثم أعد حذف الحساب.' : 'You have an active auction bid. Wait for the auction to finish, then retry.')
        : code === 'REAUTHENTICATION_REQUIRED' || code.includes('auth/requires-recent-login')
        ? (language === 'ar' ? 'سجّل الدخول من جديد ثم أعد محاولة الحذف.' : 'Sign in again, then retry account deletion.')
        : (language === 'ar' ? 'تعذر حذف الحساب بالكامل. إذا تمت إزالة بيانات اللعب، يمكنك إعادة المحاولة لإكمال حذف تسجيل الدخول.' : 'Account deletion is pending. If game data was already removed, retry to finish deleting the sign-in account.');
      showToast(message, 'error');
    } finally {
      setDeleteBusy(false);
    }
  }

  async function handleFeedbackSubmit(type: 'issue' | 'suggestion') {
    const message = feedbackText.trim();
    if (message.length < 10 || message.length > 3000) {
      showToast(language === 'ar' ? 'اكتب وصفاً من 10 إلى 3000 حرف.' : 'Enter 10–3000 characters.', 'error');
      return;
    }
    setFeedbackBusy(true);
    try {
      const images = await Promise.all(feedbackImages.slice(0, 3).map((file) => new Promise<string>((resolve, reject) => { const reader = new FileReader(); reader.onload = () => resolve(String(reader.result)); reader.onerror = () => reject(new Error('ATTACHMENT_READ_FAILED')); reader.readAsDataURL(file); })));
      await nexoraApi<{ id: string; createdAt: string }>('submit_game_feedback', { type, message, images });
      setFeedbackText(''); setFeedbackImages([]); setFeedbackFormType(null);
      showToast(language === 'ar' ? 'تم إرسال رسالتك بنجاح. شكراً لمساعدتنا في تحسين NOVA.' : 'Your message was sent. Thank you for helping improve NOVA.', 'success');
    } catch {
      showToast(language === 'ar' ? 'تعذر إرسال الرسالة حالياً. حاول لاحقاً.' : 'Could not send your message right now. Try again later.', 'error');
    } finally {
      setFeedbackBusy(false);
    }
  }

  function handleMusicVolumeChange(rawValue: string) {
    const next = Math.max(0, Math.min(100, Number(rawValue) || 0));
    setMusicVolume(next);
    try { window.localStorage.setItem('nexora-music-volume', String(next / 100)); } catch { /* Keep the preference for this session. */ }
    window.dispatchEvent(new CustomEvent('nexora-music-volume-change', { detail: next / 100 }));
  }

  function handleButtonSoundToggle() {
    const next = !buttonSoundEnabled;
    setButtonSoundEnabled(next);
    try { window.localStorage.setItem('nexora-button-sound', next ? 'on' : 'off'); } catch { /* Keep the preference for this session. */ }
  }

  async function handleNotifToggle() {
    const nextVal = !(userPrivate?.notificationsEnabled ?? true);
    try {
      await updatePlayerSettings(profile.uid, language, nextVal);
      showToast(
        language === 'ar' ? 'تم تحديث إعدادات الإشعارات.' : 'Notification preferences saved.',
        'success'
      );
    } catch {
      showToast(language === 'ar' ? 'تعذر الحفظ.' : 'Save failed.', 'error');
    }
  }

  const subTabs: { id: ProfileSubTab; label: string }[] = [
    { id: 'overview', label: t.subOverview },
    { id: 'skills', label: t.subSkills },
    { id: 'missions', label: t.subMissions },
    { id: 'achievements', label: t.achievementsTitle },
    { id: 'rankings', label: t.subRankings },
    { id: 'settings', label: t.subSettings },
    ...(isOwnerAuthorized ? [{ id: 'diagnostics' as const, label: t.subDiagnostics }] : []),
  ];

  return (
    <div className="space-y-5">
      <div className="flex items-center gap-1.5 overflow-x-auto pb-1">
        {subTabs.map((tab) => (
          <button
            key={tab.id}
            type="button"
            onClick={() => setSubTab(tab.id)}
            className={`min-h-[40px] px-4 py-2 rounded-xl text-xs font-semibold whitespace-nowrap shrink-0 transition-colors ${
              subTab === tab.id
                ? 'bg-[#B91C32] text-white'
                : 'bg-[#141821] text-[#9299A6] border border-white/8 hover:text-[#F4F5F7]'
            }`}
          >
            {tab.label}{tab.id === 'missions' && notifications.some((n) => n.eventKey?.startsWith('mission-ready:') || (!n.read && (n.title === 'مكافأة مهمة جاهزة' || n.title === 'Mission reward ready'))) && <span className="ms-1 inline-flex h-2 w-2 rounded-full bg-red-500" />}{tab.id === 'achievements' && [...unlockedAchievements].some((id) => !claimedAchievements.has(id)) && <span className="ms-1 inline-flex h-2 w-2 rounded-full bg-red-500" />}
          </button>
        ))}
      </div>

      {/* 1. OVERVIEW */}
      {subTab === 'overview' && (
        <div className="space-y-5">
          <div className="bg-[#141821] border border-white/8 rounded-2xl p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="flex items-center gap-4">
              <img
                src={avatar.src}
                alt={profile.username}
                referrerPolicy="no-referrer"
                className="w-16 h-16 rounded-2xl object-cover border border-white/10"
              />
              <div>
                <h1 className="text-lg font-bold text-[#F4F5F7]">{profile.username}</h1>
                <p className="text-xs text-[#9299A6] mt-0.5">
                  {profile.title} · {t.level} {profile.level} · {profile.xp.toLocaleString()} XP
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2">
              {AVATARS.map((av) => (
                <button
                  key={av.id}
                  type="button"
                  disabled={busyKey === `av_${av.id}`}
                  onClick={() => handleAvatarChange(av.id)}
                  className={`w-10 h-10 rounded-xl overflow-hidden border transition-colors disabled:opacity-50 ${
                    profile.avatarId === av.id ? 'border-[#E04455]' : 'border-white/10 opacity-70 hover:opacity-100'
                  }`}
                >
                  <img
                    src={av.src}
                    alt={language === 'ar' ? av.labelAr : av.labelEn}
                    referrerPolicy="no-referrer"
                    className="w-full h-full object-cover"
                  />
                </button>
              ))}
            </div>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            {[
              { label: language === 'ar' ? 'الصفقات' : 'Trades', val: profile.stats.tradesCount },
              { label: language === 'ar' ? 'الإنتاج' : 'Produced', val: profile.stats.totalProduced },
              { label: t.subCompanies, val: profile.stats.companiesOwned },
              { label: t.subMissions, val: profile.stats.missionsCompleted },
            ].map((s) => (
              <div key={s.label} className="bg-[#141821] border border-white/8 rounded-2xl p-4">
                <p className="text-xs text-[#9299A6]">{s.label}</p>
                <p className="text-lg font-bold font-mono-num text-[#F4F5F7] mt-1">{s.val}</p>
              </div>
            ))}
          </div>

          <div className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-3">
            {(() => {
              const repTier = getReputationTier(profile.reputation);
              const nextTier = getNextReputationTier(profile.reputation);
              const baseMin = repTier.minReputation;
              const nextMin = nextTier ? nextTier.minReputation : Math.max(profile.reputation, 700);
              const pct = nextTier
                ? Math.min(
                    100,
                    Math.max(0, Math.round(((profile.reputation - baseMin) / (nextMin - baseMin)) * 100))
                  )
                : 100;

              return (
                <>
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <div>
                      <h2 className="text-base font-semibold text-[#F4F5F7]">
                        {t.reputationTier}:{' '}
                        <span className="text-[#E04455]">
                          {language === 'ar' ? repTier.titleAr : repTier.titleEn}
                        </span>
                      </h2>
                      <p className="text-xs text-[#9299A6] mt-0.5">{t.repInfluenceSources}</p>
                    </div>
                    <span className="text-xs font-mono-num text-[#F4F5F7]">
                      {nextTier
                        ? `${t.nextTier}: ${language === 'ar' ? nextTier.titleAr : nextTier.titleEn} (${profile.reputation}/${nextTier.minReputation})`
                        : t.maxTierReached}
                    </span>
                  </div>

                  <div className="h-2 rounded-full bg-[#0B0D12] overflow-hidden border border-white/6">
                    <div
                      className="h-full bg-[#B91C32] rounded-full transition-all duration-300"
                      style={{ width: `${pct}%` }}
                    />
                  </div>

                  <div className="flex flex-wrap items-center gap-4 text-xs text-[#9299A6]">
                    <span>
                      {t.contractBonus}:{' '}
                      <span className="font-mono-num text-emerald-400">
                        +{(repTier.contractBonusRate * 100).toFixed(0)}%
                      </span>
                    </span>
                    <span>
                      {t.companyYieldBonus}:{' '}
                      <span className="font-mono-num text-emerald-400">
                        +{(repTier.companyYieldBonusRate * 100).toFixed(0)}%
                      </span>
                    </span>
                    <span>
                      {t.influence}:{' '}
                      <span className="font-mono-num text-[#F4F5F7]">
                        {profile.influence.toLocaleString()}
                      </span>
                    </span>
                  </div>
                </>
              );
            })()}
          </div>

        </div>
      )}

      {/* 2. SKILLS TREE */}
      {subTab === 'skills' && (
        <div className="space-y-4">
          <div className="bg-[#141821] border border-white/8 rounded-2xl p-4 flex items-center justify-between gap-3">
            <span className="text-sm font-medium text-[#F4F5F7]">{t.skillPoints}</span>
            <div className="flex items-center gap-3">
              <span className="text-lg font-bold font-mono-num text-[#E04455]">{profile.skillPoints}</span>
              <button type="button" aria-label={language === 'ar' ? 'إعادة تعيين المهارات' : 'Reset skills'} title={language === 'ar' ? 'إعادة تعيين المهارات' : 'Reset skills'} onClick={() => setResetSkillsConfirmOpen(true)} disabled={busyKey === 'reset_skills'} className="inline-flex h-9 w-9 items-center justify-center rounded-lg border border-white/10 bg-[#1B2230] text-[#F4F5F7] hover:bg-[#2A3548] disabled:opacity-50"><RefreshCw className="h-4 w-4" /></button>
            </div>
          </div>
          {resetSkillsConfirmOpen && <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/70 p-4"><section role="dialog" aria-modal="true" className="w-full max-w-sm rounded-2xl border border-white/10 bg-[#141821] p-5 space-y-4"><h3 className="text-base font-bold text-white">{language === 'ar' ? 'تأكيد إعادة تعيين المهارات' : 'Confirm skill reset'}</h3><p className="text-sm leading-6 text-[#B8C0CE]">{language === 'ar' ? 'التكلفة: 2,500. ستعود جميع نقاط المهارات التي أنفقتها إلى رصيدك.' : 'Cost: 2,500 credits. All spent skill points will be refunded.'}</p><div className="flex gap-2"><button type="button" onClick={() => setResetSkillsConfirmOpen(false)} disabled={busyKey === 'reset_skills'} className="flex-1 min-h-[42px] rounded-xl border border-white/10 text-sm text-[#D7DCE5]">{language === 'ar' ? 'إلغاء' : 'Cancel'}</button><button type="button" onClick={() => void handleResetSkills()} disabled={busyKey === 'reset_skills'} className="flex-1 min-h-[42px] rounded-xl bg-[#B91C32] text-sm font-semibold text-white disabled:opacity-50">{busyKey === 'reset_skills' ? '...' : (language === 'ar' ? 'تأكيد · 2,500' : 'Confirm · 2,500')}</button></div></section></div>}

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {SKILL_DEFINITIONS.map((sk) => {
              const cur = profile.skills[sk.key] || 0;
              const maxed = cur >= sk.maxLevel;
              return (
                <div
                  key={sk.key}
                  className="bg-[#141821] border border-white/8 rounded-2xl p-5 flex flex-col justify-between gap-4"
                >
                  <div>
                    <div className="flex items-center justify-between">
                      <h3 className="text-base font-bold text-[#F4F5F7]">
                        {language === 'ar' ? sk.nameAr : sk.nameEn}
                      </h3>
                      <span className="font-mono-num text-sm font-semibold text-[#E04455]">
                        {cur} / {sk.maxLevel}
                      </span>
                    </div>
                    <p className="text-xs text-[#9299A6] mt-1.5 leading-relaxed">
                      {language === 'ar' ? sk.effectAr : sk.effectEn}
                    </p>
                  </div>

                  <div className="h-1.5 rounded-full bg-[#0B0D12] overflow-hidden">
                    <div
                      className="h-full bg-[#B91C32] rounded-full"
                      style={{ width: `${(cur / sk.maxLevel) * 100}%` }}
                    />
                  </div>

                  <button
                    type="button"
                    disabled={maxed || profile.skillPoints < 1 || busyKey === `sk_${sk.key}`}
                    onClick={() => handleUpgradeSkill(sk.key)}
                    className="w-full min-h-[42px] px-4 rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-xs font-semibold flex items-center justify-center gap-1.5 transition-colors disabled:bg-[#1B2230] disabled:text-[#9299A6]"
                  >
                    <Zap className="w-3.5 h-3.5" />
                    <span>{maxed ? 'MAX' : t.upgradeSkill}</span>
                  </button>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* 3. MISSIONS */}
      {subTab === 'missions' && (
        <div className="space-y-6">
          {(['daily', 'weekly', 'seasonal', 'tutorial'] as const).map((category) => {
            const missions = MISSIONS.filter((mission) =>
              mission.category === category && !(category === 'tutorial' && claimedSet.has(mission.id))
            );
            if (!missions.length) return null;
            const nextDaily = new Date(nowMs);
            const dailyReset = Date.UTC(nextDaily.getUTCFullYear(), nextDaily.getUTCMonth(), nextDaily.getUTCDate() + 1);
            const weekday = new Date(nowMs).getUTCDay();
            const daysToMonday = (8 - weekday) % 7 || 7;
            const weeklyReset = Date.UTC(nextDaily.getUTCFullYear(), nextDaily.getUTCMonth(), nextDaily.getUTCDate() + daysToMonday);
            const nextQuarterMonth = (Math.floor(nextDaily.getUTCMonth() / 3) + 1) * 3;
            const seasonalReset = Date.UTC(nextDaily.getUTCFullYear(), nextQuarterMonth, 1);
            const resetAt = category === 'daily' ? dailyReset : category === 'weekly' ? weeklyReset : seasonalReset;
            const remaining = Math.max(0, resetAt - nowMs);
            const seconds = Math.floor(remaining / 1000);
            const days = Math.floor(seconds / 86400);
            const hours = Math.floor((seconds % 86400) / 3600);
            const minutes = Math.floor((seconds % 3600) / 60);
            const secs = seconds % 60;
            const countdownParts = [
              ...(days ? [{ value: String(days), label: language === 'ar' ? 'يوم' : 'DAY' }] : []),
              { value: String(hours).padStart(2, '0'), label: language === 'ar' ? 'ساعة' : 'HR' },
              { value: String(minutes).padStart(2, '0'), label: language === 'ar' ? 'دقيقة' : 'MIN' },
              { value: String(secs).padStart(2, '0'), label: language === 'ar' ? 'ثانية' : 'SEC' },
            ];
            const heading = category === 'daily' ? (language === 'ar' ? 'المهام اليومية' : 'Daily Missions')
              : category === 'weekly' ? (language === 'ar' ? 'المهام الأسبوعية' : 'Weekly Missions')
              : category === 'seasonal' ? (language === 'ar' ? 'المهام الموسمية' : 'Seasonal Missions')
              : (language === 'ar' ? 'المهام التعليمية' : 'Tutorial Missions');
            return (
              <section key={category} className="space-y-3">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <h2 className="text-base font-bold text-[#F4F5F7]">{heading}</h2>
                  {(category === 'daily' || category === 'weekly' || category === 'seasonal') && (
                    <div className="flex items-center gap-2.5 rounded-2xl border border-[#397BFF]/20 bg-gradient-to-br from-[#142039] via-[#101827] to-[#0B0D12] px-3 py-2 shadow-[0_8px_28px_rgba(57,123,255,0.08)]">
                      <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-xl border border-[#397BFF]/25 bg-[#397BFF]/10">
                        <Clock3 className="h-4 w-4 text-[#79B2FF]" />
                      </div>
                      <div className="min-w-0">
                        <span className="mb-1 block text-[9px] font-bold tracking-[0.12em] text-[#8FA9CC]">{language === 'ar' ? 'التجديد خلال' : 'NEXT RESET'}</span>
                        <div className="flex items-center gap-1" dir="ltr">
                          {countdownParts.map((part, index) => (
                            <div key={part.label} className="flex items-center gap-1">
                              {index > 0 && <span className="text-[11px] font-bold text-[#5275A5]">:</span>}
                              <div className="min-w-[34px] rounded-lg border border-white/[0.07] bg-white/[0.045] px-1.5 py-1 text-center">
                                <div className="font-mono-num text-[13px] font-bold leading-none text-[#F4F7FF]">{part.value}</div>
                                <div className="mt-1 text-[8px] font-semibold leading-none text-[#8294B0]">{part.label}</div>
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    </div>
                  )}
                </div>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {missions.map((m) => {
                    const isClaimed = claimedSet.has(m.id);
                    const val = getProgress(m);
                    const pct = Math.min(100, Math.round((Math.min(val, m.targetCount) / m.targetCount) * 100));
                    const ready = val >= m.targetCount && !isClaimed;
                    return (
                      <div key={m.id} className="bg-[#141821] border border-white/8 rounded-2xl p-5 flex flex-col justify-between gap-4">
                        <div className="space-y-1.5">
                          <div className="flex items-center justify-between gap-2">
                            <h3 className="text-base font-bold text-[#F4F5F7] flex items-center gap-2">{language === 'ar' ? m.titleAr : m.titleEn}{ready && <span className="inline-flex h-2.5 w-2.5 rounded-full bg-red-500 shrink-0" aria-label={language === 'ar' ? 'المكافأة جاهزة' : 'Reward ready'} />}</h3>
                            <Award className="w-4 h-4 text-[#E04455] shrink-0" />
                          </div>
                          <p className="text-xs text-[#9299A6]">{formatMissionCategory(m.category, language)} · <span className="font-mono-num">{Math.min(val, m.targetCount)}/{m.targetCount}</span></p>
                          <p className="text-xs text-[#9299A6] pt-0.5 leading-relaxed">{language === 'ar' ? m.descriptionAr : m.descriptionEn}</p>
                          <div className="h-1.5 rounded-full bg-[#0B0D12] overflow-hidden">
                            <div className={`h-full rounded-full transition-all duration-300 ${isClaimed || ready ? 'bg-emerald-500' : 'bg-[#B91C32]'}`} style={{ width: `${pct}%` }} />
                          </div>
                        </div>
                        <div className="flex items-center justify-between gap-3 pt-2 border-t border-white/6">
                          <div className="flex flex-wrap items-center gap-x-2 gap-y-1 text-xs font-semibold text-[#F4F5F7]" dir="ltr">
                            <span className="inline-flex items-center whitespace-nowrap font-mono-num">${m.rewardCredits.toLocaleString()}</span>
                            <span className="text-[#667080]">•</span>
                            <span className="inline-flex items-center whitespace-nowrap font-mono-num">+{m.rewardXp} XP</span>
                            <span className="text-[#667080]">•</span>
                            <span className="inline-flex items-center gap-1 whitespace-nowrap"><span className="font-mono-num">+{m.rewardReputation}</span><span dir={language === 'ar' ? 'rtl' : 'ltr'}>{t.reputation}</span></span>
                          </div>
                          <button type="button" disabled={!ready || busyKey === `mis_${m.id}`} onClick={() => handleClaimMission(m.id)} className="min-h-[40px] px-4 rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-xs font-semibold disabled:bg-[#1B2230] disabled:text-[#9299A6]">
                            {isClaimed ? t.claimed : ready ? t.claimReward : t.inProgress}
                          </button>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </section>
            );
          })}
        </div>
      )}

      {/* 4. MEDAL ACHIEVEMENTS */}
      {subTab === 'achievements' && (
        <div className="space-y-5">
          <div className="flex items-center gap-2">
            <Trophy className="w-5 h-5 text-amber-300" />
            <h2 className="text-base font-bold text-[#F4F5F7]">{t.achievementsTitle}</h2>
          </div>
          {([
            { id: 'whale', titleAr: 'الحوت', titleEn: 'The Whale' },
            { id: 'market', titleAr: 'قطب السوق', titleEn: 'Market Magnate' },
            { id: 'industry', titleAr: 'مهندس الصناعة', titleEn: 'Industrial Architect' },
            { id: 'enterprise', titleAr: 'إمبراطورية الأعمال', titleEn: 'Business Empire' },
          ] as const).map((group) => (
            <section key={group.id} className="rounded-2xl border border-white/8 bg-[#141821] p-4 space-y-3">
              <h3 className="text-sm font-bold text-[#F4F5F7]">{language === 'ar' ? group.titleAr : group.titleEn}</h3>
              <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-3">
                {ACHIEVEMENTS.filter((achievement) => achievement.group === group.id).map((ach) => {
                  const unlocked = unlockedAchievements.has(ach.id);
                  const claimed = claimedAchievements.has(ach.id);
                  const val = getAchievementProgress(ach.metric, { ...profile, totalSpent: wallet?.totalSpent ?? 0 });
                  const pct = Math.min(100, Math.round((Math.min(val, ach.threshold) / ach.threshold) * 100));
                  const medalColor = ach.tier === 'platinum' ? 'text-cyan-200 border-cyan-300/40 bg-cyan-300/10' : ach.tier === 'gold' ? 'text-amber-300 border-amber-300/40 bg-amber-300/10' : ach.tier === 'silver' ? 'text-slate-200 border-slate-300/40 bg-slate-300/10' : 'text-orange-300 border-orange-400/40 bg-orange-500/10';
                  const roman = ['I', 'II', 'III', 'IV'][ach.tierLevel - 1];
                  return (
                    <article key={ach.id} className={`rounded-xl border p-3.5 space-y-3 ${unlocked ? 'bg-[#1B2230] border-emerald-400/30' : 'bg-[#0B0D12] border-white/8'}`}>
                      <div className="flex items-center gap-3">
                        <div className={`w-12 h-12 shrink-0 rounded-2xl border flex flex-col items-center justify-center ${unlocked ? medalColor : 'text-[#77808F] border-white/10 bg-[#141821]'}`}>
                          <Medal className="w-6 h-6" />
                          <span className="text-[9px] font-black leading-none">{roman}</span>
                        </div>
                        <div className="min-w-0 flex-1">
                          {unlocked && !claimed && <span className="mb-1 inline-flex h-2.5 w-2.5 rounded-full bg-red-500" aria-label={language === 'ar' ? 'المكافأة جاهزة' : 'Reward ready'} />}
                          <div className={`text-xs font-semibold ${unlocked ? 'text-emerald-300' : 'text-[#77808F]'}`}>{unlocked ? (language === 'ar' ? 'مكتملة' : 'Earned') : (language === 'ar' ? 'قيد التقدم' : 'In progress')}</div>
                        </div>
                      </div>
                      <p className="text-xs leading-relaxed text-[#9299A6]">{language === 'ar' ? ach.descriptionAr : ach.descriptionEn}</p>
                      <div className="flex items-center justify-between gap-2 text-xs">
                        <span className="font-mono-num text-[#C2C8D2]">{Math.min(val, ach.threshold).toLocaleString()} / {ach.threshold.toLocaleString()}</span>
                        <span className="font-mono-num text-emerald-300">+${(ach.rewardCredits ?? 0).toLocaleString()}</span>
                      </div>
                      <div className="h-1.5 rounded-full bg-[#141821] overflow-hidden"><div className={`h-full rounded-full ${unlocked ? 'bg-emerald-500' : 'bg-[#B91C32]'}`} style={{ width: `${pct}%` }} /></div>
                      {unlocked && !claimed && <button type="button" disabled={busyKey === `ach_${ach.id}`} onClick={() => void handleClaimAchievement(ach.id)} className="w-full min-h-[38px] rounded-lg bg-[#B91C32] hover:bg-[#E04455] text-white text-xs font-bold disabled:opacity-50">{busyKey === `ach_${ach.id}` ? '...' : (language === 'ar' ? 'استلام المكافأة' : 'Claim reward')}</button>}
                      {claimed && <p className="text-[11px] font-semibold text-emerald-300">{language === 'ar' ? 'تم استلام المكافأة' : 'Reward claimed'}</p>}
                    </article>
                  );
                })}
              </div>
            </section>
          ))}
        </div>
      )}

      {/* 4. RANKINGS */}
      {subTab === 'rankings' && (
        <div className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-4">
          <div className="flex items-center gap-1.5">
            {[
              { id: 'players' as const, label: t.leaderboardWealth },
              { id: 'companies' as const, label: t.leaderboardCompanies },
              { id: 'orgs' as const, label: t.leaderboardOrgs },
            ].map((item) => (
              <button
                key={item.id}
                type="button"
                onClick={() => setLbTab(item.id)}
                className={`px-3.5 py-2 rounded-xl text-xs font-semibold transition-colors ${
                  lbTab === item.id
                    ? 'bg-[#B91C32] text-white'
                    : 'bg-[#0B0D12] text-[#9299A6] hover:text-[#F4F5F7]'
                }`}
              >
                {item.label}
              </button>
            ))}
          </div>

          {lbLoading ? (
            <p className="text-sm text-[#9299A6] py-8 text-center">{t.loading}</p>
          ) : lbError ? (
            <div className="py-8 text-center space-y-3">
              <p className="text-sm text-[#E04455]">{t.leaderboardError}</p>
              <button
                type="button"
                onClick={loadLeaderboards}
                className="min-h-[40px] px-4 rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-xs font-semibold"
              >
                {t.errorRetry}
              </button>
            </div>
          ) : lbTab === 'players' ? (
            leaderboards.players.length === 0 ? (
              <p className="text-sm text-[#9299A6] py-8 text-center">{t.noActivity}</p>
            ) : (
              <div className="space-y-2">
                {leaderboards.players.map((p, idx) => (
                  <div
                    key={p.uid}
                    className="p-3.5 rounded-xl bg-[#0B0D12] border border-white/6 flex items-center justify-between gap-3"
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      <span className="w-6 text-center font-mono-num text-xs font-bold text-[#E04455]">
                        #{idx + 1}
                      </span>
                      <span className="text-sm font-medium text-[#F4F5F7] truncate">
                        {p.username}
                      </span>
                    </div>
                    <span className="text-xs font-mono-num text-[#9299A6]">
                      Lv.{p.level} · {p.influence} {t.influence}
                    </span>
                  </div>
                ))}
              </div>
            )
          ) : lbTab === 'companies' ? (
            leaderboards.companies.length === 0 ? (
              <p className="text-sm text-[#9299A6] py-8 text-center">{t.noActivity}</p>
            ) : (
              <div className="space-y-2">
                {leaderboards.companies.map((c, idx) => (
                  <div
                    key={c.id}
                    className="p-3.5 rounded-xl bg-[#0B0D12] border border-white/6 flex items-center justify-between gap-3"
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      <span className="w-6 text-center font-mono-num text-xs font-bold text-[#E04455]">
                        #{idx + 1}
                      </span>
                      <span className="text-sm font-medium text-[#F4F5F7] truncate">{c.name}</span>
                    </div>
                    <span className="text-xs font-mono-num text-emerald-400">
                      {'$'}{c.totalRevenue.toLocaleString()}
                    </span>
                  </div>
                ))}
              </div>
            )
          ) : leaderboards.organizations.length === 0 ? (
            <p className="text-sm text-[#9299A6] py-8 text-center">{t.noActivity}</p>
          ) : (
            <div className="space-y-2">
              {leaderboards.organizations.map((o, idx) => (
                <div
                  key={o.id}
                  className="p-3.5 rounded-xl bg-[#0B0D12] border border-white/6 flex items-center justify-between gap-3"
                >
                  <div className="flex items-center gap-3 min-w-0">
                    <span className="w-6 text-center font-mono-num text-xs font-bold text-[#E04455]">
                      #{idx + 1}
                    </span>
                    <span className="text-sm font-medium text-[#F4F5F7] truncate">
                      [{o.tag}] {o.name}
                    </span>
                  </div>
                  <span className="text-xs font-mono-num text-[#F4F5F7]">
                    {o.reputation} {t.reputation}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* 5. SETTINGS */}
      {subTab === 'settings' && (
        <div className="max-w-lg bg-[#141821] border border-white/8 rounded-2xl p-6 space-y-5">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-bold text-[#F4F5F7]">{t.subSettings}</h2>
            <Sliders className="w-4 h-4 text-[#9299A6]" />
          </div>

          <div className="flex items-center justify-between py-2 border-b border-white/8">
            <div className="flex items-center gap-2.5">
              <Globe className="w-4 h-4 text-[#E04455]" />
              <span className="text-sm text-[#F4F5F7]">{t.languageSetting}</span>
            </div>
            <div className="flex items-center gap-1.5">
              <button
                type="button"
                onClick={() => handleLanguageToggle('ar')}
                className={`px-3 py-1.5 rounded-lg text-xs font-semibold ${
                  language === 'ar'
                    ? 'bg-[#B91C32] text-white'
                    : 'bg-[#0B0D12] text-[#9299A6]'
                }`}
              >
                العربية
              </button>
              <button
                type="button"
                onClick={() => handleLanguageToggle('en')}
                className={`px-3 py-1.5 rounded-lg text-xs font-semibold ${
                  language === 'en'
                    ? 'bg-[#B91C32] text-white'
                    : 'bg-[#0B0D12] text-[#9299A6]'
                }`}
              >
                English
              </button>
            </div>
          </div>

          <div className="flex items-center justify-between py-2 border-b border-white/8">
            <div className="flex items-center gap-2.5">
              <ShieldCheck className="w-4 h-4 text-[#E04455]" />
              <span className="text-sm text-[#F4F5F7]">{t.notificationsSetting}</span>
            </div>
            <button
              type="button"
              onClick={handleNotifToggle}
              className={`min-h-[36px] px-4 rounded-lg text-xs font-semibold ${
                userPrivate?.notificationsEnabled ?? true
                  ? 'bg-[#B91C32] text-white'
                  : 'bg-[#0B0D12] text-[#9299A6]'
              }`}
            >
              {(userPrivate?.notificationsEnabled ?? true)
                ? language === 'ar'
                  ? 'مفعل'
                  : 'Enabled'
                : language === 'ar'
                ? 'معطل'
                : 'Muted'}
            </button>
          </div>



          <div className="flex items-center justify-between py-2 border-b border-white/8">
            <div className="flex items-center gap-2.5">
              <Volume2 className="w-4 h-4 text-[#E04455]" />
              <span className="text-sm text-[#F4F5F7]">{language === 'ar' ? 'صوت النقر' : 'Button click sound'}</span>
            </div>
            <button
              type="button"
              onClick={handleButtonSoundToggle}
              aria-pressed={buttonSoundEnabled}
              className={`min-h-[36px] px-4 rounded-lg text-xs font-semibold ${buttonSoundEnabled ? 'bg-[#B91C32] text-white' : 'bg-[#0B0D12] text-[#9299A6]'}`}
            >
              {buttonSoundEnabled ? (language === 'ar' ? 'مفعل' : 'On') : (language === 'ar' ? 'معطل' : 'Off')}
            </button>
          </div>

          <div className="space-y-3 py-2 border-b border-white/8">
            <div className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-2.5">
                <Volume2 className="w-4 h-4 text-[#E04455]" />
                <span className="text-sm text-[#F4F5F7]">{language === 'ar' ? 'مستوى الموسيقى' : 'Music volume'}</span>
              </div>
              <span className="text-xs font-mono-num text-[#9299A6]">{musicVolume}%</span>
            </div>
            <input
              type="range"
              min="0"
              max="100"
              step="1"
              value={musicVolume}
              onChange={(event) => handleMusicVolumeChange(event.target.value)}
              aria-label={language === 'ar' ? 'مستوى صوت الموسيقى' : 'Music volume'}
              className="w-full accent-[#E04455]"
            />
            <p className="text-[11px] text-[#9299A6]">
              {language === 'ar' ? 'الموسيقى: Purrple Cat · مرخصة وفق CC BY 4.0.' : 'Music: Purrple Cat · Licensed under CC BY 4.0.'}
              {' '}<a href="https://creativecommons.org/licenses/by/4.0/" rel="noreferrer" target="_blank" className="text-[#E5A0A8] underline">CC BY 4.0</a>
            </p>
          </div>

          <SupportTicketsPanel language={language} />

          <section className="space-y-3 border-b border-white/8 pb-4">
            <div className="flex items-center gap-2.5">
              <MessageSquareWarning className="w-4 h-4 text-[#E04455]" />
              <h3 className="text-sm font-semibold text-[#F4F5F7]">{language === 'ar' ? 'التواصل مع الإدارة' : 'Contact administration'}</h3>
            </div>
            {!feedbackFormType ? <div className="grid grid-cols-2 gap-2">
              <button type="button" onClick={() => setFeedbackFormType('issue')} className="min-h-[42px] rounded-xl bg-[#1B2230] px-3 text-xs font-semibold text-[#F4F5F7]">{language === 'ar' ? 'إبلاغ عن مشكلة' : 'Report an issue'}</button>
              <button type="button" onClick={() => setFeedbackFormType('suggestion')} className="min-h-[42px] rounded-xl bg-[#B91C32] px-3 text-xs font-semibold text-white">{language === 'ar' ? 'تقديم اقتراح' : 'Send a suggestion'}</button>
            </div> : <>
              <p className="text-xs text-[#AAB1BE]">{feedbackFormType === 'issue' ? (language === 'ar' ? 'إبلاغ عن مشكلة' : 'Report an issue') : (language === 'ar' ? 'تقديم اقتراح' : 'Send a suggestion')}</p>
              <textarea value={feedbackText} onChange={(event) => setFeedbackText(event.target.value.slice(0, 3000))} rows={4} maxLength={3000} placeholder={language === 'ar' ? 'اكتب التفاصيل هنا (10 أحرف على الأقل)...' : 'Describe it here (at least 10 characters)...'} className="w-full resize-y rounded-xl border border-white/10 bg-[#0B0D12] p-3 text-sm text-[#F4F5F7] placeholder:text-[#9299A6]/60 focus:outline-none focus:border-[#E04455]" />
              <label className="inline-flex cursor-pointer items-center justify-center rounded-lg border border-white/15 bg-[#141821] px-4 py-2 text-xs text-white">{language === 'ar' ? 'إرفاق صور' : 'Attach images'}<input type="file" accept="image/png,image/jpeg,image/webp" multiple onChange={(event) => setFeedbackImages(Array.from(event.target.files || []).slice(0, 3))} className="hidden" /></label>
              {feedbackImages.length > 0 && <span className="ms-2 text-[11px] text-[#AAB1BE]">{language === 'ar' ? `تم إرفاق ${feedbackImages.length} صور` : `${feedbackImages.length} images attached`}</span>}
              <div className="flex gap-2">
                <button type="button" disabled={feedbackBusy || feedbackText.trim().length < 10} onClick={() => handleFeedbackSubmit(feedbackFormType)} className="flex-1 min-h-[42px] rounded-xl bg-[#B91C32] px-3 text-xs font-semibold text-white disabled:opacity-40">{language === 'ar' ? 'إرسال' : 'Send'}</button>
                <button type="button" onClick={() => {setFeedbackFormType(null);setFeedbackText('');setFeedbackImages([]);}} className="min-h-[42px] rounded-xl bg-[#252B36] px-4 text-xs text-white">{language === 'ar' ? 'إلغاء' : 'Cancel'}</button>
              </div>
            </>}
          </section>

          <div className="flex items-center justify-between gap-3 border-b border-white/8 py-3">
            <div className="flex items-center gap-2.5">
              <Trash2 className="h-4 w-4 text-[#E04455]" />
              <div>
                <p className="text-sm font-semibold text-[#F4F5F7]">{language === 'ar' ? 'حذف الحساب' : 'Delete account'}</p>
                <p className="text-[11px] text-[#9299A6]">{language === 'ar' ? 'حذف نهائي لبيانات اللعب والحساب.' : 'Permanently delete your game data and account.'}</p>
              </div>
            </div>
            <button type="button" onClick={() => setDeleteConfirmOpen(true)} className="min-h-[38px] rounded-lg border border-[#B91C32]/50 px-3 text-xs font-semibold text-[#F1A0A8] hover:bg-[#B91C32]/10">
              {language === 'ar' ? 'حذف' : 'Delete'}
            </button>
          </div>

          {deleteConfirmOpen && (
            <div className="fixed inset-0 z-[70] flex items-end justify-center bg-black/75 p-0 backdrop-blur-sm sm:items-center sm:p-4" role="dialog" aria-modal="true">
              <div className="w-full max-w-md space-y-4 rounded-t-3xl border border-white/10 bg-[#141821] p-6 sm:rounded-2xl">
                <h3 className="text-lg font-bold text-[#F4F5F7]">{language === 'ar' ? 'تأكيد حذف الحساب نهائياً' : 'Confirm permanent account deletion'}</h3>
                <p className="text-sm leading-relaxed text-[#9299A6]">{language === 'ar' ? 'سيتم حذف حساب الدخول وملف اللاعب والمحفظة والشركات وسجلات اللعب المرتبطة به. لا يمكن التراجع عن هذه العملية.' : 'Your sign-in account, player profile, wallet, companies and associated game records will be deleted. This cannot be undone.'}</p>
                {!auth.currentUser?.isAnonymous && auth.currentUser?.providerData.some((provider) => provider.providerId === 'password') && (
                  <input type="password" value={deletePassword} onChange={(event) => setDeletePassword(event.target.value)} autoComplete="current-password" placeholder={language === 'ar' ? 'كلمة المرور لتأكيد الهوية' : 'Password to confirm identity'} className="min-h-[44px] w-full rounded-xl border border-white/10 bg-[#0B0D12] px-3 text-sm text-[#F4F5F7]" />
                )}
                <div className="flex gap-3">
                  <button type="button" disabled={deleteBusy} onClick={() => { setDeleteConfirmOpen(false); setDeletePassword(''); }} className="min-h-[44px] flex-1 rounded-xl bg-[#1B2230] text-sm font-semibold text-[#F4F5F7] disabled:opacity-50">{language === 'ar' ? 'إلغاء' : 'Cancel'}</button>
                  <button type="button" disabled={deleteBusy} onClick={handleDeleteAccount} className="min-h-[44px] flex-1 rounded-xl bg-[#B91C32] text-sm font-semibold text-white disabled:opacity-50">{deleteBusy ? '...' : (language === 'ar' ? 'حذف نهائي' : 'Delete permanently')}</button>
                </div>
              </div>
            </div>
          )}

          {isOwnerAuthorized && (
            <div className="pt-2 border-t border-white/8 flex items-center justify-between gap-3">
              <div className="flex items-center gap-2.5">
                <Activity className="w-4 h-4 text-[#E04455]" />
                <span className="text-sm text-[#F4F5F7]">{t.subDiagnostics}</span>
              </div>
              <button
                type="button"
                onClick={() => setSubTab('diagnostics')}
                className="min-h-[40px] px-4 rounded-xl bg-[#0B0D12] border border-white/8 hover:border-[#B91C32]/50 text-xs font-semibold text-[#F4F5F7] whitespace-nowrap shrink-0 transition-colors"
              >
                {t.diagTitle}
              </button>
            </div>
          )}

          <button
            type="button"
            onClick={onLogout}
            className="w-full min-h-[44px] px-4 rounded-xl bg-[#1B2230] hover:bg-[#232C3E] text-[#E04455] text-sm font-semibold flex items-center justify-center gap-2 transition-colors"
          >
            <LogOut className="w-4 h-4" />
            <span>{t.signOut}</span>
          </button>
        </div>
      )}

      {/* 6. DIAGNOSTICS (Owner-Gated, Lazy-Loaded) */}
      {subTab === 'diagnostics' && isOwnerAuthorized && (
        <Suspense
          fallback={
            <div className="bg-[#141821] border border-white/8 rounded-2xl p-8 text-center text-sm text-[#9299A6]">
              {t.loading}
            </div>
          }
        >
          <DiagnosticsView language={language} snapshotContext={diagnosticsContext} />
        </Suspense>
      )}
    </div>
  );
}
