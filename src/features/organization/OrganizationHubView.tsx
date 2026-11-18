import { ArrowUpCircle, Building2, Check, Plus, Shield, UserMinus, Users, Vault, X } from 'lucide-react';
import { useEffect, useState } from 'react';
import { ConfirmDialog } from '../../components/ui/ConfirmDialog';
import { useToast } from '../../components/ui/ToastProvider';
import { ORG_CREATION_COST, ROLE_DEFAULT_PERMISSIONS } from '../../data/catalog';
import { useTranslations, formatOrgRole } from '../../i18n/translations';
import { searchAndSortOrganizations, type OrganizationSort } from '../../lib/organizationDirectory';
import {
  calculateOrgUpgradeCost,
  calculateOrgResearchCost,
  getOrgMemberCapacity,
  ORG_RESEARCH_DEFINITIONS,
  canManageOrgMember,
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
    void getOrgDonationRanking(currentOrg.id).then((ranking) => { if (active) setDonationRanking(ranking); }).catch(() => {
      if (active) setDonationRanking([]);
    });
    return () => { active = false; };
  }, [currentOrg?.id]);

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

      <nav aria-label={language === 'ar' ? 'أقسام المنظمة' : 'Organization sections'} className="flex gap-2 overflow-x-auto rounded-xl border border-white/8 bg-[#141821] p-2 text-xs">
        {[['org-info', language === 'ar' ? 'معلومات المنظمة' : 'Information'], ['org-members', t.members], ['org-research', language === 'ar' ? 'الأبحاث' : 'Research'], ['org-treasury', language === 'ar' ? 'الخزنة' : 'Treasury'], ['org-donations', language === 'ar' ? 'ترتيب التبرعات' : 'Donations']].map(([id, label]) => <a key={id} href={`#${id}`} className="shrink-0 rounded-lg bg-[#0B0D12] px-3 py-2 text-[#D5D9E1] hover:bg-[#252B36]">{label}</a>)}
      </nav>

      <section id="org-research" className="min-w-0 rounded-2xl border border-white/8 bg-[#141821] p-4 sm:p-5 space-y-4">
        <div className="flex items-center justify-between gap-3">
          <div>
            <h2 className="text-base font-bold text-[#F4F5F7]">{language === 'ar' ? 'أبحاث المنظمة' : 'Organization Research'}</h2>
            <p className="mt-1 text-xs text-[#9299A6]">{language === 'ar' ? 'خمسة مسارات بحثية، لكل مسار 10 مستويات وتأثير محدود.' : 'Five research paths, each with 10 levels and balanced effects.'}</p>
          </div>
          <span className="rounded-lg bg-[#0B0D12] px-3 py-1.5 text-xs text-[#E5A0A8]">{language === 'ar' ? '10 مستويات' : '10 levels'}</span>
        </div>
        <div className="grid min-w-0 grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-3">
          {(Object.keys(ORG_RESEARCH_DEFINITIONS) as OrganizationResearchId[]).map((researchId) => {
            const definition = ORG_RESEARCH_DEFINITIONS[researchId];
            const level = currentOrg.research?.[researchId] ?? 0;
            const cost = calculateOrgResearchCost(researchId, level);
            const isMax = level >= 10;
            return (
              <div key={researchId} className="rounded-xl border border-white/8 bg-[#0B0D12] p-4 space-y-3">
                <div className="flex items-center justify-between gap-2">
                  <h3 className="text-sm font-bold text-[#F4F5F7]">{language === 'ar' ? definition.titleAr : definition.titleEn}</h3>
                  <span className="font-mono-num text-xs text-[#E5A0A8]">{level}/10</span>
                </div>
                <p className="min-h-[38px] text-xs leading-relaxed text-[#9299A6]">{language === 'ar' ? definition.effectAr : definition.effectEn}</p>
                <div className="h-1.5 overflow-hidden rounded-full bg-white/8">
                  <div className="h-full rounded-full bg-[#B91C32]" style={{ width: `${level * 10}%` }} />
                </div>
                <button
                  type="button"
                  disabled={!canManageOrg || isMax || busyKey === `research_${researchId}` || currentOrg.treasuryBalance < cost}
                  onClick={() => handleResearchUpgrade(researchId)}
                  className="min-h-[40px] w-full rounded-lg bg-[#1B2230] px-3 text-xs font-semibold text-[#F4F5F7] hover:bg-[#B91C32] disabled:cursor-not-allowed disabled:opacity-40"
                >
                  {isMax
                    ? (language === 'ar' ? 'اكتمل البحث' : 'Research maxed')
                    : busyKey === `research_${researchId}`
                    ? '...'
                    : (language === 'ar' ? `تطوير · $${cost.toLocaleString()}` : `Research · $${cost.toLocaleString()}`)}
                </button>
              </div>
            );
          })}
        </div>
        {!canManageOrg && <p className="text-xs text-[#9299A6]">{language === 'ar' ? 'تطوير الأبحاث متاح للقائد والنائب.' : 'Research upgrades are available to the leader and deputy.'}</p>}
      </section>

      <div className="grid min-w-0 grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-5">
        {/* Shared Treasury Operations & RBAC Matrix */}
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

        {/* Members & RBAC + Join Requests */}
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

          <div id="org-members" className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-3">
            <div className="flex items-center justify-between">
              <h2 className="text-base font-semibold text-[#F4F5F7]">{t.members}</h2>
              <Users className="w-4 h-4 text-[#9299A6]" />
            </div>
            <div className="space-y-2">
              {orgMembers.map((m) => {
                const canChangeRole =
                  canManageRoles &&
                  m.uid !== profile.uid &&
                  m.role !== 'leader' &&
                  (myOrgMember.role === 'leader' || m.role !== 'deputy');
                const canKick =
                  canManageMembers &&
                  m.uid !== profile.uid &&
                  canManageOrgMember(myOrgMember.role, m.role);

                return (
                  <div
                    key={m.uid}
                    className="p-3 rounded-xl bg-[#0B0D12] border border-white/6 flex items-center justify-between gap-3"
                  >
                    <div className="min-w-0">
                      <p className="text-sm font-medium text-[#F4F5F7] truncate">{m.username}</p>
                      <p className="text-xs text-[#9299A6] mt-0.5">
                        {formatOrgRole(m.role, language)}

                      </p>
                    </div>
                    <div className="flex items-center gap-2 shrink-0">
                      {canChangeRole && (
                        <div className="flex flex-col items-end gap-1">
                          <select value={m.role} disabled={busyKey === `role_${m.uid}`} onChange={(e) => handleRoleChange(m.uid, e.target.value as Exclude<OrgRole, 'leader'>)} className="min-h-[38px] px-2.5 rounded-lg bg-[#141821] border border-white/10 text-xs text-[#F4F5F7]">
                            {myOrgMember.role === 'leader' && <option value="deputy">{formatOrgRole('deputy', language)}</option>}
                            <option value="officer">{formatOrgRole('officer', language)}</option>
                            <option value="member">{formatOrgRole('member', language)}</option>
                          </select>
                          <span className="max-w-[190px] text-[10px] text-[#9299A6] text-end">{(ROLE_DEFAULT_PERMISSIONS[m.role] || []).length === 0 ? (language === 'ar' ? 'صلاحيات العضو الأساسية' : 'Basic member access') : (ROLE_DEFAULT_PERMISSIONS[m.role] || []).map((p) => p === 'manage_members' ? (language === 'ar' ? 'إدارة الأعضاء' : 'Members') : p === 'manage_roles' ? (language === 'ar' ? 'إدارة الرتب' : 'Roles') : p === 'manage_treasury' ? (language === 'ar' ? 'الخزينة' : 'Treasury') : (language === 'ar' ? 'إدارة المنظمة' : 'Organization')).join(' · ')}</span>
                        </div>
                      )}
                      {canKick && (
                        <button
                          type="button"
                          disabled={busyKey === `kick_${m.uid}`}
                          onClick={() => setKickTarget({ uid: m.uid, username: m.username })}
                          title={t.kick}
                          aria-label={t.kick}
                          className="min-h-[38px] px-2.5 rounded-lg bg-[#1B2230] hover:bg-[#B91C32]/30 text-[#E04455] text-xs font-semibold flex items-center gap-1"
                        >
                          <UserMinus className="w-3.5 h-3.5" />
                        </button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
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
