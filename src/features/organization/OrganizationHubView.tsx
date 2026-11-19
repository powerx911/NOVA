import { ArrowUpCircle, Award, Building2, Check, CheckCircle2, Plus, Shield, Trophy, Vault, X } from 'lucide-react';
import { useEffect, useState } from 'react';
import { ConfirmDialog } from '../../components/ui/ConfirmDialog';
import { useToast } from '../../components/ui/ToastProvider';
import { ORG_CREATION_COST } from '../../data/catalog';
import { useTranslations } from '../../i18n/translations';
import { searchAndSortOrganizations, type OrganizationSort } from '../../lib/organizationDirectory';
import { OrganizationMembersPanel } from './OrganizationMembersPanel';
import { OrganizationResearchPanel } from './OrganizationResearchPanel';
import {
  calculateOrgUpgradeCost,
  getOrgMemberCapacity,
  ORG_RESEARCH_DEFINITIONS,
  hasOrgPermission,
  ORG_MAX_LEVEL,
  sanitizePositiveInt,
} from '../../lib/economy';
import {
  createOrganization,
  depositToOrgTreasury,
  handleOrgJoinRequest,
  kickOrgMember,
  leaveOrganization,
  requestJoinOrganization,
  updateOrgMemberRole,
  upgradeOrganization,
  completeOrganizationUpgrade,
  researchOrganization,
  withdrawFromOrgTreasury,
  getOrgDonationRanking,
  getPlayersPresence,
  getOrgWeeklyGoals,
} from '../../services/gameService';
import type {
  Language,
  Organization,
  OrganizationMember,
  OrganizationRequest,
  OrganizationResearchId,
  OrganizationTransaction,
  OrgRole,
  PlayerProfile,
  Wallet,
  OrgWeeklyGoal,
} from '../../types/game';

interface OrganizationHubViewProps {
  profile: PlayerProfile;
  wallet: Wallet | null;
  organizations: Organization[];
  myOrgMember: OrganizationMember | null;
  orgMembers: OrganizationMember[];
  orgRequests: OrganizationRequest[];
  myPendingOrgIds: Set<string>;
  orgTransactions: OrganizationTransaction[];
  language: Language;
}

export function OrganizationHubView({
  profile,
  wallet,
  organizations,
  myOrgMember,
  orgMembers,
  orgRequests,
  myPendingOrgIds,
  orgTransactions,
  language,
}: OrganizationHubViewProps) {
  const t = useTranslations(language);
  const { showToast } = useToast();

  const [orgName, setOrgName] = useState('');
  const [orgTag, setOrgTag] = useState('');
  const [orgDesc, setOrgDesc] = useState('');
  const [orgSearch, setOrgSearch] = useState('');
  const [orgSort, setOrgSort] = useState<OrganizationSort>('reputation');
  const [treasuryAmt, setTreasuryAmt] = useState(100);
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [confirmLeaveOpen, setConfirmLeaveOpen] = useState(false);
  const [kickTarget, setKickTarget] = useState<{ uid: string; username: string } | null>(null);
  const [clockNow, setClockNow] = useState(Date.now());
  const [donationRanking, setDonationRanking] = useState<Array<{ uid: string; username: string; amount: number }>>([]);
  const [activeOrgTab, setActiveOrgTab] = useState<'info' | 'members' | 'research' | 'treasury' | 'goals'>('info');
  const [weeklyGoals, setWeeklyGoals] = useState<OrgWeeklyGoal[]>([]);
  const [memberPresence, setMemberPresence] = useState<Record<string, boolean>>({});

  const currentOrg = myOrgMember
    ? organizations.find((o) => o.id === myOrgMember.orgId) || null
    : null;

  const canManageMembers = hasOrgPermission(myOrgMember, 'manage_members');
  const canManageRoles = hasOrgPermission(myOrgMember, 'manage_roles');
  const canManageTreasury = hasOrgPermission(myOrgMember, 'manage_treasury');
  const canManageOrg = myOrgMember?.role === 'leader' || myOrgMember?.role === 'deputy' || hasOrgPermission(myOrgMember, 'manage_org');

  useEffect(() => {
    const clock = window.setInterval(() => setClockNow(Date.now()), 15_000);
    return () => window.clearInterval(clock);
  }, []);

  useEffect(() => {
    if (!currentOrg?.id) { setWeeklyGoals([]); return; }
    let active = true;
    const refresh = () => { void getOrgWeeklyGoals().then((result) => {
      if (active) setWeeklyGoals(result.goals ?? []);
    }).catch(() => undefined); };
    refresh();
    const timer = window.setInterval(refresh, 30_000);
    window.addEventListener('nova:refresh-game', refresh);
    window.addEventListener('focus', refresh);
    return () => { active = false; window.clearInterval(timer); window.removeEventListener('nova:refresh-game', refresh); window.removeEventListener('focus', refresh); };
  }, [currentOrg?.id]);

  useEffect(() => {
    if (!currentOrg?.upgradeEndsAt) return;
    const finish = async () => {
      try {
        await completeOrganizationUpgrade(currentOrg.id);
      } catch (error) {
        const code = error instanceof Error ? error.message : '';
        if (code !== 'UPGRADE_NOT_READY') showToast(language === 'ar' ? 'تعذر إكمال تطوير المنظمة تلقائياً.' : 'Could not finalize organization upgrade.', 'error');
      }
    };
    const delay = currentOrg.upgradeEndsAt - Date.now();
    if (delay <= 0) { void finish(); return; }
    const timer = window.setTimeout(() => void finish(), delay + 500);
    return () => window.clearTimeout(timer);
  }, [currentOrg?.id, currentOrg?.upgradeEndsAt, language, showToast]);

  useEffect(() => {
    if (!currentOrg?.id) { setDonationRanking([]); return; }
    let active = true;
    const refresh = () => { void getOrgDonationRanking(currentOrg.id).then((ranking) => { if (active) setDonationRanking(ranking); }).catch(() => undefined); };
    refresh();
    const timer = window.setInterval(refresh, 8_000);
    window.addEventListener('nova:refresh-game', refresh);
    window.addEventListener('focus', refresh);
    return () => { active = false; window.clearInterval(timer); window.removeEventListener('nova:refresh-game', refresh); window.removeEventListener('focus', refresh); };
  }, [currentOrg?.id]);

  useEffect(() => {
    const ids = orgMembers.map((member) => member.uid);
    if (!ids.length) { setMemberPresence({}); return; }
    let active = true;
    const refresh = () => { void getPlayersPresence(ids).then((rows) => {
      if (!active) return;
      setMemberPresence(Object.fromEntries(rows.map((row) => [row.uid, row.isOnline])));
    }).catch(() => undefined); };
    refresh();
    const timer = window.setInterval(refresh, 15_000);
    window.addEventListener('focus', refresh);
    return () => { active = false; window.clearInterval(timer); window.removeEventListener('focus', refresh); };
  }, [orgMembers]);

  async function handleCreateOrg(e: React.FormEvent) {
    e.preventDefault();
    setBusyKey('create_org');
    try {
      await createOrganization(profile.uid, profile.username, orgName, orgTag, orgDesc);
      setOrgName('');
      setOrgTag('');
      setOrgDesc('');
      showToast(
        language === 'ar' ? 'تم تأسيس المنظمة بنجاح!' : 'Organization founded!',
        'success'
      );
    } catch (err) {
      const rawMessage = err instanceof Error ? err.message : '';
      let code = rawMessage;
      try {
        const parsed = JSON.parse(rawMessage) as { code?: unknown };
        if (typeof parsed.code === 'string') code = parsed.code;
      } catch {
        // Keep the original application error code.
      }
      const knownMessages: Record<string, string> = {
        INVALID_NAME: language === 'ar' ? 'اسم المنظمة يجب أن يكون بين 3 و40 حرفاً.' : 'Organization name must be 3–40 characters.',
        INVALID_TAG: language === 'ar' ? 'رمز المنظمة يجب أن يكون بين حرفين و6 أحرف.' : 'Organization tag must be 2–6 characters.',
        ALREADY_IN_ORG: language === 'ar' ? 'أنت عضو في منظمة بالفعل.' : 'You are already in an organization.',
        ACCOUNT_NOT_FOUND: language === 'ar' ? 'تعذر العثور على بيانات الحساب.' : 'Account data was not found.',
        INSUFFICIENT_FUNDS: language === 'ar' ? `يتطلب التأسيس ${ORG_CREATION_COST} $.` : `Founding requires ${ORG_CREATION_COST} $.`,
        AUTH_SESSION_MISMATCH: language === 'ar' ? 'جلسة تسجيل الدخول لا تطابق الحساب الحالي. سجّل الخروج ثم ادخل مجدداً.' : 'The signed-in session does not match this account. Sign out and sign in again.',
        EMAIL_NOT_VERIFIED: language === 'ar' ? 'حساب Google غير موثق لدى Firebase، لذلك لا تسمح قواعد الأمان بإنشاء المنظمة.' : 'Firebase does not consider this Google account verified, so security rules block organization creation.',
        'permission-denied': language === 'ar' ? 'رفضت قواعد Firestore حفظ المنظمة (permission-denied).' : 'Firestore rules rejected organization creation (permission-denied).',
        BACKEND_IDENTITY_NOT_READY: language === 'ar' ? 'خدمة إنشاء المنظمة غير جاهزة حالياً. لم يتم خصم أي مبلغ؛ حاول لاحقاً.' : 'Organization service is not ready. No funds were charged; try again later.',
        BACKEND_FIRESTORE_WRITE_DENIED: language === 'ar' ? 'الخادم لا يملك صلاحية إتمام العملية. لم يتم خصم أي مبلغ.' : 'The server is not authorized to complete this operation. No funds were charged.',
        RETRY_OPERATION: language === 'ar' ? 'تعارضت العملية مع تحديث آخر. لم يتم خصم أي مبلغ؛ أعد المحاولة.' : 'The operation conflicted with another update. No funds were charged; retry.',
        ORGANIZATION_CREATE_FAILED: language === 'ar' ? 'تعذر إتمام تأسيس المنظمة على الخادم. لم يتم خصم أي مبلغ.' : 'The server could not complete organization creation. No funds were charged.',
        unavailable: language === 'ar' ? 'خدمة قاعدة البيانات غير متاحة حالياً (unavailable).' : 'Database service is currently unavailable (unavailable).',
      };
      const message = knownMessages[code] || (code && code !== rawMessage
        ? (language === 'ar' ? `فشل تأسيس المنظمة: ${code}` : `Organization creation failed: ${code}`)
        : (language === 'ar' ? 'تعذر تأسيس المنظمة. تحقق من تفاصيل الخطأ.' : 'Organization creation failed. Check the error details.'));
      showToast(message, 'error');
    } finally {
      setBusyKey(null);
    }
  }

  async function handleRequestJoin(orgId: string) {
    setBusyKey(`join_${orgId}`);
    try {
      await requestJoinOrganization(profile.uid, profile.username, orgId);
      showToast(
        language === 'ar' ? 'تم إرسال طلب الانضمام للإدارة.' : 'Join request sent to leadership.',
        'success'
      );
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      showToast(
        code === 'REQUEST_ALREADY_PENDING'
          ? language === 'ar'
            ? 'لديك طلب انضمام قيد المراجعة لهذه المنظمة بالفعل.'
            : 'You already have a pending request for this organization.'
          : code === 'ALREADY_IN_ORG'
          ? language === 'ar'
            ? 'أنت عضو في منظمة أخرى بالفعل.'
            : 'You are already a member of an organization.'
          : language === 'ar'
          ? 'تعذر إرسال الطلب.'
          : 'Could not submit request.',
        'error'
      );
    } finally {
      setBusyKey(null);
    }
  }

  async function handleJoinDecision(
    req: OrganizationRequest,
    decision: 'approved' | 'rejected'
  ) {
    if (!currentOrg) return;
    setBusyKey(`req_${req.id}`);
    try {
      await handleOrgJoinRequest(currentOrg.id, req.id, req.uid, req.username, decision);
      showToast(
        decision === 'approved'
          ? language === 'ar'
            ? `تم قبول ${req.username} في المنظمة.`
            : `${req.username} approved.`
          : language === 'ar'
          ? `تم رفض طلب ${req.username}.`
          : `Request from ${req.username} rejected.`,
        decision === 'approved' ? 'success' : 'info'
      );
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      showToast(
        code === 'REQUEST_ALREADY_HANDLED'
          ? language === 'ar'
            ? 'تمت معالجة هذا الطلب مسبقاً.'
            : 'This request has already been handled.'
          : code === 'ALREADY_ORG_MEMBER'
          ? language === 'ar'
            ? 'اللاعب عضو في هذه المنظمة بالفعل.'
            : 'Player is already a member.'
          : code === 'APPLICANT_IN_OTHER_ORG'
          ? language === 'ar'
            ? 'اللاعب انضم بالفعل إلى منظمة أخرى.'
            : 'Applicant already joined another organization.'
          : code === 'ORG_FULL'
          ? language === 'ar'
            ? 'وصلت المنظمة إلى الحد الأقصى للأعضاء.'
            : 'Organization has reached member capacity.'
          : language === 'ar'
          ? 'تعذر تنفيذ القرار.'
          : 'Could not process request.',
        'error'
      );
    } finally {
      setBusyKey(null);
    }
  }

  async function handleDeposit() {
    if (!currentOrg) return;
    setBusyKey('dep');
    try {
      await depositToOrgTreasury(profile.uid, profile.username, currentOrg.id, treasuryAmt);
      showToast(
        language === 'ar' ? 'تم التبرع لخزينة المنظمة.' : 'Donated to organization treasury.',
        'success'
      );
    } catch {
      showToast(language === 'ar' ? 'الرصيد غير كافٍ.' : 'Insufficient personal funds.', 'error');
    } finally {
      setBusyKey(null);
    }
  }

  async function handleWithdraw() {
    if (!currentOrg) return;
    setBusyKey('wdr');
    try {
      await withdrawFromOrgTreasury(profile.uid, profile.username, currentOrg.id, treasuryAmt);
      showToast(
        language === 'ar' ? 'تم السحب من خزينة المنظمة.' : 'Withdrawn from treasury.',
        'success'
      );
    } catch {
      showToast(
        language === 'ar' ? 'تعذر السحب من الخزينة.' : 'Withdrawal failed or unauthorized.',
        'error'
      );
    } finally {
      setBusyKey(null);
    }
  }

  async function handleRoleChange(targetUid: string, nextRole: Exclude<OrgRole, 'leader'>) {
    if (!currentOrg) return;
    setBusyKey(`role_${targetUid}`);
    try {
      await updateOrgMemberRole(currentOrg.id, targetUid, nextRole);
      showToast(language === 'ar' ? 'تم تحديث الرتبة والصلاحيات.' : 'Member role updated.', 'success');
    } catch {
      showToast(language === 'ar' ? 'ليس لديك صلاحية تعديل الرتب.' : 'Permission denied.', 'error');
    } finally {
      setBusyKey(null);
    }
  }

  async function handleLeave() {
    if (!currentOrg) return;
    setBusyKey('leave');
    try {
      await leaveOrganization(profile.uid, currentOrg.id);
      setConfirmLeaveOpen(false);
      showToast(language === 'ar' ? 'غادرت المنظمة.' : 'Left organization.', 'info');
    } catch {
      showToast(
        language === 'ar'
          ? 'لا يمكن لرئيس المنظمة المغادرة قبل نقل القيادة.'
          : 'Leader cannot leave organization directly.',
        'error'
      );
    } finally {
      setBusyKey(null);
    }
  }

  async function handleUpgradeOrg() {
    if (!currentOrg) return;
    setBusyKey('upgrade_org');
    try {
      const result = await upgradeOrganization(profile.uid, profile.username, currentOrg.id);
      const hours = Math.ceil((result.endsAt - Date.now()) / 3_600_000);
      showToast(language === 'ar' ? `بدأ تطوير المنظمة إلى المستوى ${result.targetLevel}. المدة المتبقية نحو ${hours} ساعة.` : `Organization upgrade to Lv.${result.targetLevel} started. About ${hours} hours remaining.`, 'success');
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      const message = code === 'INSUFFICIENT_TREASURY'
        ? (language === 'ar' ? 'رصيد خزينة المنظمة غير كافٍ للترقية.' : 'Insufficient organization treasury funds.')
        : code === 'MAX_LEVEL' ? t.maxLevelReached
        : code === 'UPGRADE_IN_PROGRESS' ? (language === 'ar' ? 'هناك تطوير جارٍ بالفعل.' : 'An organization upgrade is already in progress.')
        : code === 'UNAUTHORIZED' ? (language === 'ar' ? 'التطوير متاح للقائد والنائب فقط.' : 'Only the leader and deputy can upgrade.')
        : (language === 'ar' ? 'تعذر بدء تطوير المنظمة.' : 'Could not start organization upgrade.');
      showToast(message, 'error');
    } finally { setBusyKey(null); }
  }

  async function handleResearchUpgrade(researchId: OrganizationResearchId) {
    if (!currentOrg) return;
    setBusyKey(`research_${researchId}`);
    try {
      const result = await researchOrganization(currentOrg.id, researchId);
      const definition = ORG_RESEARCH_DEFINITIONS[researchId];
      showToast(language === 'ar' ? `تم تطوير ${definition.titleAr} إلى المستوى ${result.level}.` : `${definition.titleEn} upgraded to level ${result.level}.`, 'success');
    } catch (error) {
      const code = error instanceof Error ? error.message : '';
      const message = code === 'INSUFFICIENT_TREASURY'
        ? (language === 'ar' ? 'رصيد الخزنة غير كافٍ لهذا البحث.' : 'Insufficient organization treasury funds for this research.')
        : code === 'RESEARCH_MAX_LEVEL' ? (language === 'ar' ? 'وصل البحث إلى المستوى الأقصى.' : 'Research is already at maximum level.')
        : code === 'UNAUTHORIZED' ? (language === 'ar' ? 'الأبحاث متاحة للقائد والنائب فقط.' : 'Only the leader and deputy can upgrade research.')
        : (language === 'ar' ? 'تعذر تطوير البحث.' : 'Could not upgrade research.');
      showToast(message, 'error');
    } finally {
      setBusyKey(null);
    }
  }

  async function handleConfirmKick() {
    if (!currentOrg || !kickTarget) return;
    setBusyKey(`kick_${kickTarget.uid}`);
    try {
      await kickOrgMember(profile.uid, currentOrg.id, kickTarget.uid);
      showToast(
        language === 'ar'
          ? `تمت إزالة ${kickTarget.username} من المنظمة.`
          : `Removed ${kickTarget.username} from organization.`,
        'info'
      );
      setKickTarget(null);
    } catch (err) {
      const code = err instanceof Error ? err.message : '';
      showToast(
        code === 'RANK_TOO_HIGH' || code === 'UNAUTHORIZED'
          ? language === 'ar'
            ? 'رتبتك لا تسمح بإزالة هذا العضو.'
            : 'Your rank cannot remove this member.'
          : language === 'ar'
          ? 'تعذر إزالة العضو.'
          : 'Failed to remove member.',
        'error'
      );
    } finally {
      setBusyKey(null);
    }
  }

  const visibleOrganizations = searchAndSortOrganizations(organizations, orgSearch, orgSort);

  if (!myOrgMember || !currentOrg) {
    return (
      <div className="grid w-full min-w-0 grid-cols-1 lg:grid-cols-3 gap-4 sm:gap-5">
        {/* Create Organization */}
        <form
          onSubmit={handleCreateOrg}
          className="min-w-0 w-full bg-[#141821] border border-white/8 rounded-2xl p-4 sm:p-5 space-y-4 h-fit"
        >
          <div className="flex items-center justify-between">
            <h2 className="text-base font-bold text-[#F4F5F7]">{t.createOrg}</h2>
            <Plus className="w-4 h-4 text-[#E04455]" />
          </div>

          <div className="space-y-1.5">
            <label className="text-xs text-[#9299A6]">{t.orgName}</label>
            <input
              type="text"
              value={orgName}
              onChange={(e) => setOrgName(e.target.value)}
              minLength={3}
              maxLength={40}
              required
              className="w-full min-h-[44px] px-3.5 rounded-xl bg-[#0B0D12] border border-white/10 text-sm text-[#F4F5F7] focus:outline-none focus:border-[#E04455]"
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-xs text-[#9299A6]">{t.orgTag}</label>
            <input
              type="text"
              value={orgTag}
              onChange={(e) => setOrgTag(e.target.value.toUpperCase())}
              minLength={2}
              maxLength={6}
              dir="ltr"
              required
              placeholder="NXR"
              className="w-full min-h-[44px] px-3.5 rounded-xl bg-[#0B0D12] border border-white/10 text-sm font-mono-num text-[#F4F5F7] focus:outline-none focus:border-[#E04455]"
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-xs text-[#9299A6]">{t.orgDesc}</label>
            <textarea
              value={orgDesc}
              onChange={(e) => setOrgDesc(e.target.value)}
              maxLength={240}
              rows={3}
              className="w-full p-3 rounded-xl bg-[#0B0D12] border border-white/10 text-sm text-[#F4F5F7] focus:outline-none focus:border-[#E04455]"
            />
          </div>

          <button
            type="submit"
            disabled={busyKey === 'create_org' || (wallet?.balance ?? 0) < ORG_CREATION_COST}
            className="w-full min-h-[44px] px-4 rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-sm font-semibold transition-colors disabled:bg-[#1B2230] disabled:text-[#9299A6]"
          >
            {t.createOrg} ({'$'}{ORG_CREATION_COST.toLocaleString()})
          </button>
        </form>

        {/* Browse Organizations */}
        <div className="min-w-0 lg:col-span-2 space-y-3.5">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-semibold text-[#F4F5F7]">
              {language === 'ar' ? 'المنظمات والتحالفات النشطة' : 'Active Syndicates & Organizations'}
            </h2>
            <Building2 className="w-4 h-4 text-[#9299A6]" />
          </div>

          {organizations.length > 0 && (
            <div className="grid grid-cols-1 sm:grid-cols-[1fr_190px] gap-2.5">
              <input type="search" value={orgSearch} onChange={(e) => setOrgSearch(e.target.value)} placeholder={language === 'ar' ? 'ابحث بالاسم أو الرمز أو القائد...' : 'Search name, tag or leader...'} aria-label={language === 'ar' ? 'البحث عن منظمة' : 'Search organizations'} className="w-full min-h-[44px] px-3.5 rounded-xl bg-[#0B0D12] border border-white/10 text-sm text-[#F4F5F7] focus:outline-none focus:border-[#E04455]" />
              <select value={orgSort} onChange={(e) => setOrgSort(e.target.value as OrganizationSort)} aria-label={language === 'ar' ? 'ترتيب المنظمات' : 'Sort organizations'} className="w-full min-h-[44px] px-3.5 rounded-xl bg-[#0B0D12] border border-white/10 text-sm text-[#F4F5F7] focus:outline-none focus:border-[#E04455]">
                <option value="reputation">{language === 'ar' ? 'الأعلى سمعة' : 'Top reputation'}</option>
                <option value="members">{language === 'ar' ? 'الأكثر أعضاءً' : 'Most members'}</option>
                <option value="level">{language === 'ar' ? 'الأعلى مستوى' : 'Highest level'}</option>
                <option value="treasury">{language === 'ar' ? 'الأغنى خزينةً' : 'Largest treasury'}</option>
              </select>
            </div>
          )}

          {organizations.length === 0 ? (
            <div className="bg-[#141821] border border-white/8 rounded-2xl p-8 text-center">
              <p className="text-sm text-[#9299A6]">
                {language === 'ar'
                  ? 'لا توجد منظمات مؤسسة بعد. كن أول من يؤسس تحالفاً اقتصادياً!'
                  : 'No organizations founded yet. Establish the first economic syndicate!'}
              </p>
            </div>
          ) : (
              visibleOrganizations.length === 0 ? (
                <div className="bg-[#141821] border border-white/8 rounded-2xl p-6 text-center text-sm text-[#9299A6]">{language === 'ar' ? 'لا توجد نتائج مطابقة لبحثك.' : 'No organizations match your search.'}</div>
              ) : visibleOrganizations.map((org) => {
                const isPending = myPendingOrgIds.has(org.id);
                return (
                  <div
                    key={org.id}
                    className="min-w-0 w-full bg-[#141821] border border-white/8 rounded-2xl p-4 sm:p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-4"
                  >
                    <div className="space-y-1">
                      <h3 className="text-base font-bold text-[#F4F5F7]">
                        [{org.tag}] {org.name}
                      </h3>
                      <p className="text-xs text-[#9299A6]">
                        {org.leaderName} · {t.members}:{' '}
                        <span className="font-mono-num text-[#F4F5F7]">{org.memberCount}</span> ·{' '}
                        {t.reputation}:{' '}
                        <span className="font-mono-num text-[#F4F5F7]">{org.reputation}</span>
                      </p>
                      {org.description && (
                        <p className="text-xs text-[#9299A6]/90 pt-1">{org.description}</p>
                      )}
                    </div>

                    <button
                      type="button"
                      disabled={isPending || busyKey === `join_${org.id}`}
                      onClick={() => handleRequestJoin(org.id)}
                      className="w-full sm:w-auto min-h-[42px] px-4 rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-xs font-semibold whitespace-nowrap shrink-0 disabled:bg-[#1B2230] disabled:text-[#9299A6]"
                    >
                      {isPending ? t.requestPending : busyKey === `join_${org.id}` ? '...' : t.joinOrg}
                    </button>
                  </div>
                );
              })
          )}
        </div>
      </div>
    );
  }

  const orgUpgradeCost = Math.round(calculateOrgUpgradeCost(currentOrg.level) * (1 - Math.min(10, currentOrg.research?.finance ?? 0) * 0.005));
  const isOrgMaxLevel = currentOrg.level >= ORG_MAX_LEVEL;
  const upgradeInProgress = Boolean(currentOrg.upgradeEndsAt && currentOrg.upgradeEndsAt > clockNow);
  const memberCapacity = currentOrg.memberCapacity ?? getOrgMemberCapacity(currentOrg.level, currentOrg.research?.expansion ?? 0);
  const upgradeHoursLeft = upgradeInProgress ? Math.ceil((currentOrg.upgradeEndsAt! - clockNow) / 3_600_000) : 0;

  return (
    <div className="w-full min-w-0 space-y-4 sm:space-y-5">
      {/* Segmented organization navigation */}
      <nav aria-label={language === 'ar' ? 'أقسام المنظمة' : 'Organization sections'} className="flex items-center gap-1.5 overflow-x-auto pb-1">
        {([
          ['info', language === 'ar' ? 'معلومات المنظمة' : 'Information'],
          ['members', t.members],
          ['research', language === 'ar' ? 'الأبحاث' : 'Research'],
          ['treasury', language === 'ar' ? 'الخزنة' : 'Treasury'],
          ['goals', language === 'ar' ? 'الأهداف الأسبوعية' : 'Weekly goals'],
        ] as const).map(([id, label]) => (
          <button
            key={id}
            type="button"
            onClick={() => setActiveOrgTab(id)}
            aria-pressed={activeOrgTab === id}
            className={`min-h-[40px] px-4 py-2 rounded-xl text-xs font-semibold whitespace-nowrap shrink-0 transition-colors ${
              activeOrgTab === id
                ? 'bg-[#B91C32] text-white'
                : 'bg-[#141821] text-[#9299A6] border border-white/8 hover:text-[#F4F5F7]'
            }`}
          >
            {label}
          </button>
        ))}
      </nav>

      {activeOrgTab === 'info' && (
        <>
              {/* Organization Header */}
              <div id="org-info" className="min-w-0 w-full bg-[#141821] border border-white/8 rounded-2xl p-4 sm:p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <div className="space-y-1">
                  <p className="text-[10px] font-semibold tracking-wide text-[#E5A0A8]">{language === 'ar' ? 'معلومات المنظمة' : 'Organization information'}</p>
                  <div className="flex items-center gap-2.5">
                    <Shield className="w-5 h-5 text-[#E04455]" />
                    <h1 className="min-w-0 break-words text-lg sm:text-xl font-bold text-[#F4F5F7]">
                      [{currentOrg.tag}] {currentOrg.name}
                    </h1>
                  </div>
                  <p className="text-xs text-[#9299A6]">
                    {t.level} <span className="font-mono-num text-[#F4F5F7]">{currentOrg.level}</span> ·{' '}
                    {t.members}{' '}
                    <span className="font-mono-num text-[#F4F5F7]">{currentOrg.memberCount}/{memberCapacity}</span> ·{' '}
                    {t.reputation}{' '}
                    <span className="font-mono-num text-[#F4F5F7]">{currentOrg.reputation}</span> ·{' '}
                    {language === 'ar' ? 'القائد' : 'Leader'}{' '}
                    <span className="text-[#F4F5F7]">{currentOrg.leaderName}</span>
                  </p>
                </div>
        
                <div className="flex w-full sm:w-auto flex-wrap items-center gap-2 sm:gap-3">
                  <div className="text-end">
                    <p className="text-xs text-[#9299A6]">{t.orgTreasury}</p>
                    <p className="text-lg font-bold font-mono-num text-emerald-400">
                      {'$'}{currentOrg.treasuryBalance.toLocaleString()}
                    </p>
                  </div>
                  {upgradeInProgress && (
                    <p className="w-full text-xs text-amber-300">{language === 'ar' ? `ينتهي تطوير المنظمة خلال نحو ${upgradeHoursLeft} ساعة.` : `Organization upgrade completes in about ${upgradeHoursLeft} hours.`}</p>
                  )}
                  {canManageOrg && (
                    <button
                      type="button"
                      disabled={
                        isOrgMaxLevel ||
                        upgradeInProgress ||
                        busyKey === 'upgrade_org' ||
                        currentOrg.treasuryBalance < orgUpgradeCost
                      }
                      onClick={handleUpgradeOrg}
                      className="min-h-[42px] w-full sm:w-auto justify-center px-3.5 rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-xs font-semibold flex items-center gap-1.5 whitespace-nowrap disabled:bg-[#1B2230] disabled:text-[#9299A6]"
                    >
                      <ArrowUpCircle className="w-4 h-4" />
                      <span>
                        {isOrgMaxLevel
                          ? t.maxLevelReached
                          : upgradeInProgress
                          ? (language === 'ar' ? `جارٍ التطوير · المستوى ${currentOrg.upgradeTargetLevel}` : `Upgrading · Lv.${currentOrg.upgradeTargetLevel}`)
                          : `${t.upgradeOrg} (${orgUpgradeCost.toLocaleString()})`}
                      </span>
                    </button>
                  )}
                  {myOrgMember.role !== 'leader' && (
                    <button
                      type="button"
                      onClick={() => setConfirmLeaveOpen(true)}
                      className="min-h-[40px] px-3.5 rounded-xl bg-[#1B2230] hover:bg-[#232C3E] text-[#E04455] text-xs font-semibold whitespace-nowrap"
                    >
                      {t.leaveOrg}
                    </button>
                  )}
                </div>
              </div>
        </>
      )}

      {activeOrgTab === 'goals' && (
        <section className="rounded-2xl border border-white/10 bg-[#111A2C] p-4 sm:p-5 space-y-4">
          <div className="flex items-center justify-between gap-3">
            <div>
              <h2 className="text-base font-bold text-white flex items-center gap-2"><Trophy className="w-4 h-4 text-amber-300" />{language === 'ar' ? 'أهداف المنظمة الأسبوعية' : 'Weekly organization goals'}</h2>
              <p className="mt-1 text-[11px] text-[#91A4C3]">{language === 'ar' ? 'تتجدد الأهداف كل يوم اثنين عند 00:00 بتوقيت UTC.' : 'Goals reset every Monday at 00:00 UTC.'}</p>
            </div>
            <span className="shrink-0 rounded-lg bg-white/5 px-2.5 py-1.5 text-[11px] font-mono-num text-[#C8D5EA]">
              {(() => {
                const now = new Date(clockNow);
                const day = now.getUTCDay();
                const days = day === 1 ? 7 : (8 - day) % 7;
                const reset = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + days);
                const seconds = Math.max(0, Math.floor((reset - clockNow) / 1000));
                const hours = Math.floor(seconds / 3600);
                const minutes = Math.floor((seconds % 3600) / 60);
                const secs = seconds % 60;
                return `${hours}:${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
              })()}
            </span>
          </div>
          {weeklyGoals.length === 0 ? (
            <p className="rounded-xl border border-white/10 p-5 text-center text-xs text-[#8192AD]">{language === 'ar' ? 'لا توجد أهداف متاحة حاليًا.' : 'No weekly goals available yet.'}</p>
          ) : weeklyGoals.map((goal) => {
            const progress = Math.min(100, goal.current / Math.max(1, goal.target) * 100);
            const titles: Record<OrgWeeklyGoal['type'], [string, string]> = {
              produce_units: ['إنتاج الموارد', 'Produce resources'],
              trade_volume: ['حجم التداول', 'Trading volume'],
              contracts_completed: ['إكمال العقود', 'Complete contracts'],
              treasury_donations: ['دعم خزينة المنظمة', 'Fund the organization treasury'],
              personal_contracts_completed: ['عقود شخصية مكتملة', 'Personal contracts completed'],
              org_contracts_completed: ['عقود المنظمة المكتملة', 'Organization contracts completed'],
              company_revenue: ['تحصيل إيرادات الشركات', 'Collect company revenue'],
              factory_upgrades: ['تطوير المصانع', 'Upgrade factories'],
              company_upgrades: ['تطوير الشركات', 'Upgrade companies'],
              companies_founded: ['تأسيس شركات', 'Found companies'],
              factories_founded: ['إنشاء مصانع', 'Found factories'],
            };
            const descriptions: Record<OrgWeeklyGoal['type'], [string, string]> = {
              produce_units: ['أنتج الموارد في مصانعك. تُحتسب وحدات الإنتاج المكتملة التي تسجلها اللعبة.', 'Produce resources in your factories. Completed production units recorded by the game count.'],
              trade_volume: ['نفّذ صفقات شراء أو بيع في السوق. تُجمع القيمة الفعلية للصفقات المنفذة، وليس قيمة العروض المنشورة.', 'Complete market purchases or sales. The actual value of executed trades counts, not listing prices.'],
              contracts_completed: ['أكمل عقودك الشخصية وعقود المنظمة حتى تستلم مكافآتها. كل عقد يُحتسب مرة واحدة بعد الاستلام.', 'Finish personal and organization contracts and claim their rewards. Each contract counts once after claiming.'],
              treasury_donations: ['حوّل أموالًا من رصيدك إلى خزينة المنظمة عبر زر التبرع. تُحتسب قيمة الإيداع الناجح.', 'Transfer credits from your wallet to the organization treasury using Donate. Successful deposits count.'],
              personal_contracts_completed: ['أكمل العقود الشخصية واستلم مكافآتها. يُحتسب العقد بعد استلام المكافأة فقط.', 'Complete personal contracts and claim their rewards. A contract counts only after its reward is claimed.'],
              org_contracts_completed: ['احجز عقدًا مشتركًا للمنظمة وأكمله واستلم مكافأته. يُحتسب عند الاستلام.', 'Reserve a shared organization contract, complete it, and claim its reward.'],
              company_revenue: ['حصّل الإيرادات المتراكمة من شركاتك. تُحتسب الإيرادات عند تحصيلها فعليًا.', 'Collect accumulated revenue from your companies. Only collected revenue counts.'],
              factory_upgrades: ['ارفع مستوى مصانعك. كل ترقية مستوى ناجحة تُحتسب مرة واحدة.', 'Upgrade your factories. Each successful level upgrade counts once.'],
              company_upgrades: ['ارفع مستوى شركاتك. كل ترقية مستوى ناجحة تُحتسب مرة واحدة.', 'Upgrade your companies. Each successful level upgrade counts once.'],
              companies_founded: ['أسّس شركات جديدة. تُحتسب الشركة عند إنشائها بنجاح.', 'Found new companies. A company counts when it is successfully created.'],
              factories_founded: ['أنشئ مصانع جديدة. يُحتسب المصنع عند تأسيسه بنجاح.', 'Found new factories. A factory counts when it is successfully created.'],
            };
            const difficulty = goal.difficulty === 'easy' ? (language === 'ar' ? 'سهل' : 'Easy') : goal.difficulty === 'medium' ? (language === 'ar' ? 'متوسط' : 'Medium') : (language === 'ar' ? 'صعب' : 'Hard');
            return (
              <article key={goal.id} className="rounded-xl border border-white/8 bg-[#0B1425] p-3.5 space-y-3">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="text-sm font-semibold text-white">{titles[goal.type][language === 'ar' ? 0 : 1]}</p>
                    <p className="mt-1 text-[11px] leading-relaxed text-[#9AAEC9]">{descriptions[goal.type][language === 'ar' ? 0 : 1]}</p>
                    <span className="mt-1 inline-block text-[10px] text-[#91A4C3]">{difficulty}</span>
                  </div>
                  <span className="flex shrink-0 items-center gap-1 text-xs font-semibold text-amber-300"><Award className="w-3.5 h-3.5" />+{goal.rewardReputation}</span>
                </div>
                <div className="flex items-center justify-between text-[11px] text-[#9AAEC9]">
                  <span>{language === 'ar' ? 'التقدم' : 'Progress'}</span>
                  <span className="font-mono-num text-white">{Math.floor(goal.current).toLocaleString()} / {Math.floor(goal.target).toLocaleString()}</span>
                </div>
                <div className="h-2 rounded-full bg-white/8 overflow-hidden"><div className={`h-full rounded-full ${goal.status === 'completed' ? 'bg-emerald-400' : 'bg-sky-400'}`} style={{ width: `${progress}%` }} /></div>
                {goal.status === 'completed' && <p className="flex items-center gap-1 text-[10px] text-emerald-300"><CheckCircle2 className="w-3.5 h-3.5" />{language === 'ar' ? 'اكتمل الهدف وحصلت المنظمة على المكافأة.' : 'Goal completed and the organization received its reward.'}</p>}
              </article>
            );
          })}
        </section>
      )}

      {activeOrgTab === 'research' && (
        <OrganizationResearchPanel
          organization={currentOrg}
          language={language}
          canManageOrg={canManageOrg}
          busyKey={busyKey}
          onResearchUpgrade={(researchId) => void handleResearchUpgrade(researchId)}
        />
      )}

      <div className="grid min-w-0 grid-cols-1 gap-4 sm:gap-5">
        {activeOrgTab === 'treasury' && (
                  <div className="w-full min-w-0 space-y-4 sm:space-y-5">
                    <div id="org-treasury" className="min-w-0 bg-[#141821] border border-white/8 rounded-2xl p-4 sm:p-5 space-y-4">
                      <div className="flex items-center justify-between">
                        <h2 className="text-base font-semibold text-[#F4F5F7]">{language === 'ar' ? 'خزينة المنظمة والتبرعات' : 'Organization treasury & donations'}</h2>
                        <Vault className="w-4 h-4 text-[#E04455]" />
                      </div>
          
                      <div className="flex min-w-0 flex-wrap items-center gap-2.5">
                        <input
                          type="number"
                          min={1}
                          value={treasuryAmt || ''}
                          onChange={(e) => {
                            const v = e.target.value;
                            setTreasuryAmt(v === '' ? 0 : sanitizePositiveInt(v, 1));
                          }}
                          onBlur={() => setTreasuryAmt((v) => sanitizePositiveInt(v, 1))}
                          className="w-full sm:flex-1 min-w-0 min-h-[44px] px-3.5 rounded-xl bg-[#0B0D12] border border-white/10 text-sm font-mono-num text-[#F4F5F7]"
                        />
                        <button
                          type="button"
                          disabled={busyKey === 'dep' || treasuryAmt < 1 || (wallet?.balance ?? 0) < treasuryAmt}
                          onClick={handleDeposit}
                          className="flex-1 sm:flex-none min-w-0 min-h-[44px] px-3 sm:px-4 rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-xs font-semibold whitespace-nowrap disabled:bg-[#1B2230] disabled:text-[#9299A6]"
                        >
                          {language === 'ar' ? 'تبرع للخزنة' : 'Donate to treasury'}
                        </button>
                        {canManageTreasury && (
                          <button
                            type="button"
                            disabled={busyKey === 'wdr' || treasuryAmt < 1 || currentOrg.treasuryBalance < treasuryAmt}
                            onClick={handleWithdraw}
                            className="flex-1 sm:flex-none min-w-0 min-h-[44px] px-3 sm:px-4 rounded-xl bg-[#1B2230] hover:bg-[#232C3E] text-[#F4F5F7] text-xs font-semibold whitespace-nowrap disabled:opacity-50"
                          >
                            {t.withdraw}
                          </button>
                        )}
                      </div>
          
                      <div className="space-y-2 pt-2 border-t border-white/8">
                        {orgTransactions.length === 0 ? (
                          <p className="text-xs text-[#9299A6] py-4 text-center">{t.noActivity}</p>
                        ) : (
                          orgTransactions.slice(0, 8).map((otx) => {
                            const isInflow = otx.type === 'deposit';
                            const typeLabel =
                              otx.type === 'upgrade'
                                ? t.upgradeOrg
                                : otx.type === 'deposit'
                                ? t.deposit
                                : t.withdraw;
                            return (
                              <div
                                key={otx.id}
                                className="flex items-center justify-between text-xs py-2 border-b border-white/6 last:border-0"
                              >
                                <span className="text-[#9299A6]">
                                  {otx.username} · {typeLabel}
                                </span>
                                <span
                                  className={`font-mono-num font-semibold ${
                                    isInflow ? 'text-emerald-400' : 'text-[#E04455]'
                                  }`}
                                >
                                  {isInflow ? '+' : '-'}
                                  {'$'}{otx.amount.toLocaleString()}
                                </span>
                              </div>
                            );
                          })
                        )}
                      </div>
                    </div>
          
                    {/* Donation leaderboard */}
                    <div id="org-donations" className="min-w-0 bg-[#141821] border border-white/8 rounded-2xl p-4 sm:p-5 space-y-3">
                      <h2 className="text-sm font-semibold text-[#F4F5F7]">{language === 'ar' ? 'ترتيب التبرعات' : 'Donation leaderboard'}</h2>
                      {donationRanking.length === 0 ? <p className="py-4 text-center text-xs text-[#9299A6]">{language === 'ar' ? 'لا توجد تبرعات صافية حتى الآن.' : 'No net donations yet.'}</p> : donationRanking.map((entry, index) => (
                        <div key={entry.uid} className="flex items-center justify-between rounded-xl border border-white/6 bg-[#0B0D12] px-3 py-2.5"><span className="flex items-center gap-3 min-w-0"><span className="w-6 text-center text-xs font-bold text-amber-200">#{index + 1}</span><span className="truncate text-sm text-[#F4F5F7]">{entry.username}</span></span><span className="text-xs font-semibold font-mono-num text-emerald-400">${entry.amount.toLocaleString()}</span></div>
                      ))}
                    </div>
                  </div>
          
        )}
        {activeOrgTab === 'members' && (
                  <div className="space-y-5">
                    {canManageMembers && orgRequests.length > 0 && (
                      <div className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-3">
                        <h2 className="text-base font-semibold text-[#F4F5F7]">{t.joinRequests}</h2>
                        <div className="space-y-2">
                          {orgRequests.map((req) => (
                            <div
                              key={req.id}
                              className="p-3 rounded-xl bg-[#0B0D12] border border-white/6 flex items-center justify-between gap-3"
                            >
                              <span className="text-sm font-medium text-[#F4F5F7]">{req.username}</span>
                              <div className="flex items-center gap-2">
                                <button
                                  type="button"
                                  disabled={busyKey === `req_${req.id}`}
                                  onClick={() => handleJoinDecision(req, 'approved')}
                                  className="min-h-[38px] px-3 rounded-lg bg-[#B91C32] hover:bg-[#E04455] text-white text-xs font-semibold flex items-center gap-1 disabled:opacity-50"
                                >
                                  <Check className="w-3.5 h-3.5" />
                                  <span>{t.approve}</span>
                                </button>
                                <button
                                  type="button"
                                  disabled={busyKey === `req_${req.id}`}
                                  onClick={() => handleJoinDecision(req, 'rejected')}
                                  className="min-h-[38px] px-3 rounded-lg bg-[#1B2230] hover:bg-[#232C3E] text-[#9299A6] text-xs font-semibold flex items-center gap-1 disabled:opacity-50"
                                >
                                  <X className="w-3.5 h-3.5" />
                                  <span>{t.reject}</span>
                                </button>
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
          
                    <OrganizationMembersPanel
                      members={orgMembers}
                      memberPresence={memberPresence}
                      profileUid={profile.uid}
                      myOrgRole={myOrgMember.role}
                      canManageRoles={canManageRoles}
                      canManageMembers={canManageMembers}
                      busyKey={busyKey}
                      language={language}
                      membersLabel={t.members}
                      kickLabel={t.kick}
                      onRoleChange={handleRoleChange}
                      onKick={(member) => setKickTarget({ uid: member.uid, username: member.username })}
                    />
                  </div>
        )}
      </div>

      <ConfirmDialog
        open={confirmLeaveOpen}
        title={t.leaveOrg}
        description={
          language === 'ar'
            ? 'هل تريد مغادرة المنظمة الحالية؟ ستفقد رتبتك الحالية.'
            : 'Leave your current organization? You will lose your current rank.'
        }
        confirmLabel={t.confirmBtn}
        cancelLabel={t.cancelBtn}
        busy={busyKey === 'leave'}
        onConfirm={handleLeave}
        onCancel={() => setConfirmLeaveOpen(false)}
      />

      <ConfirmDialog
        open={kickTarget !== null}
        title={t.kick}
        description={
          kickTarget
            ? language === 'ar'
              ? `هل تريد إزالة العضو ${kickTarget.username} من المنظمة؟`
              : `Remove ${kickTarget.username} from the organization?`
            : ''
        }
        confirmLabel={t.confirmBtn}
        cancelLabel={t.cancelBtn}
        busy={kickTarget !== null && busyKey === `kick_${kickTarget.uid}`}
        onConfirm={handleConfirmKick}
        onCancel={() => setKickTarget(null)}
      />
    </div>
  );
}
