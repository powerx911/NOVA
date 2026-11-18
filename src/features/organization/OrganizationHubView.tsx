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
          
                  {/* Members & RBAC + Join Requests */}
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
