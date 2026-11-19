import { UserMinus, Users } from 'lucide-react';
import { formatOrgRole } from '../../i18n/translations';
import { canManageOrgMember } from '../../lib/economy';
import { ROLE_DEFAULT_PERMISSIONS } from '../../data/catalog';
import type { Language, OrganizationMember, OrgRole } from '../../types/game';

interface OrganizationMembersPanelProps {
  members: OrganizationMember[];
  memberPresence: Record<string, boolean>;
  profileUid: string;
  myOrgRole: OrgRole;
  canManageRoles: boolean;
  canManageMembers: boolean;
  busyKey: string | null;
  language: Language;
  membersLabel: string;
  kickLabel: string;
  onRoleChange: (uid: string, role: Exclude<OrgRole, 'leader'>) => void;
  onKick: (member: OrganizationMember) => void;
}

export function OrganizationMembersPanel({
  members, memberPresence, profileUid, myOrgRole, canManageRoles, canManageMembers,
  busyKey, language, membersLabel, kickLabel, onRoleChange, onKick,
}: OrganizationMembersPanelProps) {
  const roleOrder = { leader: 0, deputy: 1, officer: 2, member: 3 } as const;
  return (
    <div id="org-members" className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-3">
      <div className="flex items-center justify-between">
        <h2 className="text-base font-semibold text-[#F4F5F7]">{membersLabel}</h2>
        <Users className="w-4 h-4 text-[#9299A6]" />
      </div>
      <div className="space-y-2">
        {[...members].sort((a, b) => Number(Boolean(memberPresence[b.uid])) - Number(Boolean(memberPresence[a.uid])) || roleOrder[a.role] - roleOrder[b.role]).map((member) => {
          const canChangeRole = canManageRoles && member.uid !== profileUid && member.role !== 'leader' && (myOrgRole === 'leader' || member.role !== 'deputy');
          const canKick = canManageMembers && member.uid !== profileUid && canManageOrgMember(myOrgRole, member.role);
          return (
            <div key={member.uid} className="p-3 rounded-xl bg-[#0B0D12] border border-white/6 flex items-center justify-between gap-3">
              <div className="min-w-0">
                <p className="text-sm font-medium text-[#F4F5F7] truncate">{member.username}</p>
                <p className="text-xs text-[#9299A6] mt-0.5">
                  {formatOrgRole(member.role, language)}
                  <span className={`mt-1 inline-flex items-center gap-1.5 ${memberPresence[member.uid] ? 'text-emerald-400' : 'text-[#77808F]'}`}><span className={`h-1.5 w-1.5 rounded-full ${memberPresence[member.uid] ? 'bg-emerald-400' : 'bg-[#77808F]'}`} />{memberPresence[member.uid] ? (language === 'ar' ? 'متصل الآن' : 'Online now') : (language === 'ar' ? 'غير متصل' : 'Offline')}</span>
                </p>
              </div>
              <div className="flex items-center gap-2 shrink-0">
                {canChangeRole && (
                  <div className="flex flex-col items-end gap-1">
                    <select value={member.role} disabled={busyKey === `role_${member.uid}`} onChange={(e) => onRoleChange(member.uid, e.target.value as Exclude<OrgRole, 'leader'>)} className="min-h-[38px] px-2.5 rounded-lg bg-[#141821] border border-white/10 text-xs text-[#F4F5F7]">
                      {myOrgRole === 'leader' && <option value="deputy">{formatOrgRole('deputy', language)}</option>}
                      <option value="officer">{formatOrgRole('officer', language)}</option>
                      <option value="member">{formatOrgRole('member', language)}</option>
                    </select>
                    <span className="max-w-[190px] text-[10px] text-[#9299A6] text-end">{(ROLE_DEFAULT_PERMISSIONS[member.role] || []).length === 0 ? (language === 'ar' ? 'صلاحيات العضو الأساسية' : 'Basic member access') : (ROLE_DEFAULT_PERMISSIONS[member.role] || []).map((permission) => permission === 'manage_members' ? (language === 'ar' ? 'إدارة الأعضاء' : 'Members') : permission === 'manage_roles' ? (language === 'ar' ? 'إدارة الرتب' : 'Roles') : permission === 'manage_treasury' ? (language === 'ar' ? 'الخزينة' : 'Treasury') : (language === 'ar' ? 'إدارة المنظمة' : 'Organization')).join(' · ')}</span>
                  </div>
                )}
                {canKick && (
                  <button type="button" disabled={busyKey === `kick_${member.uid}`} onClick={() => onKick(member)} title={kickLabel} aria-label={kickLabel} className="min-h-[38px] px-2.5 rounded-lg bg-[#1B2230] hover:bg-[#B91C32]/30 text-[#E04455] text-xs font-semibold flex items-center gap-1">
                    <UserMinus className="w-3.5 h-3.5" />
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
