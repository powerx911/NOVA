import {
  AlertTriangle,
  CheckCircle2,
  ClipboardCopy,
  Database,
  Lock,
  RefreshCw,
  Server,
  ShieldAlert,
  ShieldCheck,
  Terminal,
  XCircle,
  MinusCircle,
} from 'lucide-react';
import { useCallback, useEffect, useState } from 'react';
import { useToast } from '../../components/ui/ToastProvider';
import { useTranslations } from '../../i18n/translations';
import {
  getSanitizedErrorHistory,
  type DiagnosticReport,
  type DiagnosticStatus,
} from '../../lib/diagnosticsSanitizer';
import {
  generateDiagnosticReport,
  verifyDiagnosticsOwnerAccess,
  type ClientSnapshotContext,
  type OwnerAuthorizationStatus,
} from '../../services/diagnosticsService';
import type { Language } from '../../types/game';

interface DiagnosticsViewProps {
  language: Language;
  snapshotContext: ClientSnapshotContext;
}

function StatusBadge({ status, language }: { status: DiagnosticStatus; language: Language }) {
  const t = useTranslations(language);

  const config: Record<
    DiagnosticStatus,
    { label: string; colorClass: string; Icon: typeof CheckCircle2 }
  > = {
    healthy: {
      label: t.diagStatusHealthy,
      colorClass: 'text-emerald-400',
      Icon: CheckCircle2,
    },
    warning: {
      label: t.diagStatusWarning,
      colorClass: 'text-amber-400',
      Icon: AlertTriangle,
    },
    error: {
      label: t.diagStatusError,
      colorClass: 'text-[#E04455]',
      Icon: XCircle,
    },
    unavailable: {
      label: t.diagStatusUnavailable,
      colorClass: 'text-[#9299A6]',
      Icon: MinusCircle,
    },
  };

  const { label, colorClass, Icon } = config[status];
  return (
    <span className={`inline-flex items-center gap-1.5 text-xs font-semibold ${colorClass}`}>
      <Icon className="w-3.5 h-3.5 shrink-0" />
      <span className="whitespace-nowrap">{label}</span>
    </span>
  );
}

export function DiagnosticsView({ language, snapshotContext }: DiagnosticsViewProps) {
  const t = useTranslations(language);
  const { showToast } = useToast();

  const [checkingAuth, setCheckingAuth] = useState(true);
  const [ownerStatus, setOwnerStatus] = useState<OwnerAuthorizationStatus | null>(null);
  const [running, setRunning] = useState(false);
  const [report, setReport] = useState<DiagnosticReport | null>(null);
  const [jsonText, setJsonText] = useState<string>('');
  const [showRawJson, setShowRawJson] = useState(false);

  const checkAccess = useCallback(async () => {
    setCheckingAuth(true);
    try {
      const status = await verifyDiagnosticsOwnerAccess();
      setOwnerStatus(status);
    } finally {
      setCheckingAuth(false);
    }
  }, []);

  useEffect(() => {
    checkAccess();
  }, [checkAccess]);

  async function handleGenerateReport() {
    if (!ownerStatus?.authorized) return;
    setRunning(true);
    try {
      const generated = await generateDiagnosticReport(ownerStatus, snapshotContext);
      setReport(generated);
      setJsonText(JSON.stringify(generated, null, 2));
      showToast(
        language === 'ar' ? 'تم توليد تقرير التشخيص بنجاح.' : 'Diagnostic report generated.',
        'success'
      );
    } catch (err) {
      showToast(
        err instanceof Error
          ? err.message
          : language === 'ar'
          ? 'تعذر توليد التقرير.'
          : 'Failed to generate report.',
        'error'
      );
    } finally {
      setRunning(false);
    }
  }

  async function handleCopyJson() {
    if (!jsonText) return;
    try {
      await navigator.clipboard.writeText(jsonText);
      showToast(t.diagCopiedSuccess, 'success');
    } catch {
      setShowRawJson(true);
      showToast(t.diagCopyFailed, 'info');
    }
  }

  const sessionErrors = report?.recentSanitizedErrors ?? getSanitizedErrorHistory();

  if (checkingAuth) {
    return (
      <div className="bg-[#141821] border border-white/8 rounded-2xl p-6 space-y-3">
        <div className="h-5 w-48 bg-[#1B2230] rounded animate-pulse" />
        <div className="h-4 w-72 bg-[#1B2230] rounded animate-pulse" />
        <div className="h-24 w-full bg-[#0B0D12] rounded-xl animate-pulse" />
      </div>
    );
  }

  if (!ownerStatus?.authorized) {
    return (
      <div className="bg-[#141821] border border-[#B91C32]/35 rounded-2xl p-6 space-y-4">
        <div className="flex items-start gap-3">
          <div className="w-10 h-10 rounded-xl bg-[#B91C32]/15 border border-[#B91C32]/35 flex items-center justify-center shrink-0">
            <Lock className="w-5 h-5 text-[#E04455]" />
          </div>
          <div className="space-y-1">
            <h2 className="text-base font-bold text-[#F4F5F7]">{t.diagUnauthorizedTitle}</h2>
            <p className="text-xs text-[#9299A6] leading-relaxed">{t.diagUnauthorizedBody}</p>
          </div>
        </div>

        <div className="bg-[#0B0D12] border border-white/6 rounded-xl p-4 space-y-2 text-xs text-[#9299A6]">
          <div className="flex items-center justify-between">
            <span>{language === 'ar' ? 'المعرّف المقنّع' : 'Masked UID'}</span>
            <span className="font-mono-num text-[#F4F5F7]">{ownerStatus?.maskedUid ?? 'anonymous'}</span>
          </div>
          <div className="flex items-center justify-between">
            <span>{language === 'ar' ? 'التحقق من البريد' : 'Email Verified'}</span>
            <span className="font-mono-num text-[#F4F5F7]">
              {ownerStatus?.emailVerified ? 'true' : 'false'}
            </span>
          </div>
          <div className="flex items-center justify-between gap-4">
            <span>{language === 'ar' ? 'الحالة' : 'Status'}</span>
            <StatusBadge status="error" language={language} />
          </div>
          <p className="pt-2 border-t border-white/6 text-[11px] text-[#9299A6]">
            {ownerStatus?.reason}
          </p>
        </div>

        <button
          type="button"
          onClick={checkAccess}
          className="min-h-[44px] px-4 rounded-xl bg-[#1B2230] hover:bg-[#232C3E] text-[#F4F5F7] text-xs font-semibold inline-flex items-center gap-2 whitespace-nowrap shrink-0 transition-colors"
        >
          <RefreshCw className="w-4 h-4" />
          <span>{t.diagCheckAccess}</span>
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-5">
      {/* Header & Action Controls */}
      <div className="bg-[#141821] border border-white/8 rounded-2xl p-5 flex flex-col lg:flex-row lg:items-center justify-between gap-4">
        <div className="space-y-1">
          <h1 className="text-base font-bold text-[#F4F5F7]">{t.diagTitle}</h1>
          <p className="text-xs text-[#9299A6] leading-relaxed">{t.diagSubtitle}</p>
          <p className="text-[11px] text-[#9299A6] font-mono-num pt-1">
            {ownerStatus.maskedUid} · {ownerStatus.verifiedBy}
            {report ? ` · ${report.generatedAt}` : ''}
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2.5 shrink-0">
          <button
            type="button"
            disabled={running}
            onClick={handleGenerateReport}
            className="min-h-[44px] px-4 rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-xs font-semibold inline-flex items-center justify-center gap-2 whitespace-nowrap shrink-0 transition-colors disabled:opacity-60"
          >
            <RefreshCw className={`w-4 h-4 ${running ? 'animate-spin' : ''}`} />
            <span>{running ? t.diagGenerating : t.diagGenerateBtn}</span>
          </button>

          <button
            type="button"
            disabled={!jsonText}
            onClick={handleCopyJson}
            className="min-h-[44px] px-4 rounded-xl bg-[#1B2230] hover:bg-[#232C3E] text-[#F4F5F7] text-xs font-semibold inline-flex items-center justify-center gap-2 whitespace-nowrap shrink-0 transition-colors disabled:opacity-45"
          >
            <ClipboardCopy className="w-4 h-4 text-[#E04455]" />
            <span>{t.diagCopyJsonBtn}</span>
          </button>
        </div>
      </div>

      {!report ? (
        <div className="bg-[#141821] border border-white/8 rounded-2xl p-6 text-center space-y-2">
          <Terminal className="w-6 h-6 text-[#E04455] mx-auto" />
          <p className="text-sm font-semibold text-[#F4F5F7]">
            {language === 'ar'
              ? 'اضغط "توليد تقرير التشخيص" لبدء الفحص القرائي المنقّح.'
              : 'Press "Generate Diagnostic Report" to execute read-only checks.'}
          </p>
          <p className="text-xs text-[#9299A6]">
            {language === 'ar'
              ? 'جميع المخرجات خالية من البيانات الشخصية والرموز السرية.'
              : 'All outputs are stripped of PII, tokens, and credentials.'}
          </p>
        </div>
      ) : (
        <div className="space-y-5">
          {/* Section 1: Firebase Health */}
          <section className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-4">
            <div className="flex items-center justify-between gap-2">
              <div className="flex items-center gap-2">
                <Server className="w-4 h-4 text-[#E04455]" />
                <h2 className="text-sm font-bold text-[#F4F5F7]">{t.diagSectionFirebase}</h2>
              </div>
              <StatusBadge status={report.firebaseHealth.overallStatus} language={language} />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
              <div className="bg-[#0B0D12] border border-white/6 rounded-xl p-4 space-y-1.5">
                <div className="flex items-center justify-between gap-2">
                  <span className="text-xs font-semibold text-[#F4F5F7]">Cloud Firestore</span>
                  <StatusBadge status={report.firebaseHealth.firestore.status} language={language} />
                </div>
                <p className="text-xs text-[#9299A6] font-mono-num">
                  {report.firebaseHealth.firestore.latencyMs !== null
                    ? `${report.firebaseHealth.firestore.latencyMs} ms`
                    : '—'}
                </p>
                <p className="text-[11px] text-[#9299A6] leading-relaxed">
                  {report.firebaseHealth.firestore.message}
                </p>
              </div>

              <div className="bg-[#0B0D12] border border-white/6 rounded-xl p-4 space-y-1.5">
                <div className="flex items-center justify-between gap-2">
                  <span className="text-xs font-semibold text-[#F4F5F7]">Authentication</span>
                  <StatusBadge
                    status={report.firebaseHealth.authentication.status}
                    language={language}
                  />
                </div>
                <p className="text-xs text-[#9299A6] font-mono-num">
                  {report.firebaseHealth.authentication.provider} ·{' '}
                  {report.firebaseHealth.authentication.ownerVerifiedBy}
                </p>
                <p className="text-[11px] text-[#9299A6] leading-relaxed">
                  {report.firebaseHealth.authentication.message}
                </p>
              </div>

              <div className="bg-[#0B0D12] border border-white/6 rounded-xl p-4 space-y-1.5">
                <div className="flex items-center justify-between gap-2">
                  <span className="text-xs font-semibold text-[#F4F5F7]">Cloud Functions Gen 2</span>
                  <StatusBadge
                    status={report.firebaseHealth.backendFunctions.status}
                    language={language}
                  />
                </div>
                <p className="text-xs text-[#9299A6] font-mono-num">
                  {report.firebaseHealth.backendFunctions.functionName} ·{' '}
                  {report.firebaseHealth.backendFunctions.runtime}
                </p>
                <p className="text-[11px] text-[#9299A6] leading-relaxed">
                  {report.firebaseHealth.backendFunctions.message}
                </p>
              </div>
            </div>
          </section>

          {/* Section 2: Game Systems */}
          <section className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-4">
            <h2 className="text-sm font-bold text-[#F4F5F7]">{t.diagSectionSystems}</h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
              {report.gameSystems.map((sys) => (
                <div
                  key={sys.key}
                  className="bg-[#0B0D12] border border-white/6 rounded-xl p-4 space-y-2.5"
                >
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-xs font-bold text-[#F4F5F7]">
                      {language === 'ar' ? sys.labelAr : sys.labelEn}
                    </span>
                    <StatusBadge status={sys.status} language={language} />
                  </div>
                  <div className="space-y-1 border-t border-white/6 pt-2">
                    {Object.entries(sys.metrics).map(([k, v]) => (
                      <div key={k} className="flex items-center justify-between gap-2 text-[11px]">
                        <span className="text-[#9299A6] truncate">{k}</span>
                        <span className="font-mono-num text-[#F4F5F7]">
                          {v === null ? '—' : String(v)}
                        </span>
                      </div>
                    ))}
                  </div>
                  {sys.issues.length > 0 && (
                    <p className="text-[11px] text-amber-400 leading-relaxed">
                      {sys.issues.join(' · ')}
                    </p>
                  )}
                </div>
              ))}
            </div>
          </section>

          {/* Section 3: Database Health */}
          <section className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-4">
            <div className="flex items-center justify-between gap-2">
              <div className="flex items-center gap-2">
                <Database className="w-4 h-4 text-[#E04455]" />
                <h2 className="text-sm font-bold text-[#F4F5F7]">{t.diagSectionDatabase}</h2>
              </div>
              <span className="text-xs font-mono-num text-[#9299A6]">
                {report.databaseCollections.length} collections
              </span>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-start border-collapse">
                <thead>
                  <tr className="border-b border-white/8 text-[11px] text-[#9299A6]">
                    <th className="py-2 pe-3 font-medium text-start">Collection</th>
                    <th className="py-2 px-3 font-medium text-start">Category</th>
                    <th className="py-2 px-3 font-medium text-end">Count</th>
                    <th className="py-2 px-3 font-medium text-start">Status</th>
                    <th className="py-2 ps-3 font-medium text-start">Note</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-white/6 text-xs">
                  {report.databaseCollections.map((col) => (
                    <tr key={col.name} className="hover:bg-white/[0.02]">
                      <td className="py-2.5 pe-3 font-mono-num text-[#F4F5F7] whitespace-nowrap">
                        {col.name}
                      </td>
                      <td className="py-2.5 px-3 text-[#9299A6] whitespace-nowrap">
                        {col.category}
                        {col.piiRestricted ? ' · PII' : ''}
                      </td>
                      <td className="py-2.5 px-3 font-mono-num text-[#F4F5F7] text-end whitespace-nowrap">
                        {col.count === null ? '—' : col.count.toLocaleString()}
                      </td>
                      <td className="py-2.5 px-3 whitespace-nowrap">
                        <StatusBadge status={col.status} language={language} />
                      </td>
                      <td className="py-2.5 ps-3 text-[11px] text-[#9299A6] min-w-[200px]">
                        {col.note}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          {/* Section 4: Security Audit */}
          <section className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-4">
            <div className="flex items-center justify-between gap-2">
              <div className="flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-[#E04455]" />
                <h2 className="text-sm font-bold text-[#F4F5F7]">{t.diagSectionSecurity}</h2>
              </div>
              <StatusBadge status={report.securityChecks.overallStatus} language={language} />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
              {report.securityChecks.checks.map((chk) => (
                <div
                  key={chk.id}
                  className="bg-[#0B0D12] border border-white/6 rounded-xl p-4 space-y-1.5"
                >
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-xs font-semibold text-[#F4F5F7]">{chk.label}</span>
                    <StatusBadge status={chk.status} language={language} />
                  </div>
                  <p className="text-[11px] text-[#9299A6] leading-relaxed">{chk.detail}</p>
                </div>
              ))}
            </div>

            {report.securityChecks.collectionsNeedingReview.length > 0 && (
              <div className="bg-[#0B0D12] border border-white/6 rounded-xl p-4 space-y-2">
                <p className="text-xs font-semibold text-[#F4F5F7]">
                  {language === 'ar'
                    ? 'مجموعات موصى بمراجعتها دورياً'
                    : 'Collections Flagged for Periodic Review'}
                </p>
                {report.securityChecks.collectionsNeedingReview.map((item) => (
                  <p key={item.collection} className="text-[11px] text-[#9299A6]">
                    <span className="font-mono-num text-[#F4F5F7]">{item.collection}</span> ·{' '}
                    {item.reason}
                  </p>
                ))}
              </div>
            )}
          </section>

          {/* Section 5: Sanitized Error Monitor */}
          <section className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-3">
            <div className="flex items-center justify-between gap-2">
              <div className="flex items-center gap-2">
                <ShieldAlert className="w-4 h-4 text-[#E04455]" />
                <h2 className="text-sm font-bold text-[#F4F5F7]">{t.diagSectionErrors}</h2>
              </div>
              <span className="text-xs font-mono-num text-[#9299A6]">
                {sessionErrors.length}
              </span>
            </div>

            {sessionErrors.length === 0 ? (
              <p className="text-xs text-[#9299A6] py-3">{t.diagNoErrors}</p>
            ) : (
              <div className="space-y-2">
                {sessionErrors.slice(0, 10).map((err) => (
                  <div
                    key={err.id}
                    className="bg-[#0B0D12] border border-white/6 rounded-xl p-3 space-y-1"
                  >
                    <div className="flex flex-wrap items-center justify-between gap-2 text-[11px]">
                      <span className="font-mono-num text-[#F4F5F7]">
                        {err.category} · {err.severity} · {err.source}
                      </span>
                      <span className="font-mono-num text-[#9299A6]">{err.timestamp}</span>
                    </div>
                    <p className="text-xs text-[#9299A6] break-words">{err.message}</p>
                  </div>
                ))}
              </div>
            )}
          </section>

          {/* Unified JSON Preview */}
          <section className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-3">
            <div className="flex items-center justify-between gap-2">
              <h2 className="text-sm font-bold text-[#F4F5F7]">{t.diagJsonPreview}</h2>
              <button
                type="button"
                onClick={() => setShowRawJson((v) => !v)}
                className="min-h-[36px] px-3 rounded-lg bg-[#0B0D12] border border-white/8 text-xs font-semibold text-[#F4F5F7] whitespace-nowrap shrink-0"
              >
                {showRawJson
                  ? language === 'ar'
                    ? 'إخفاء JSON'
                    : 'Hide JSON'
                  : language === 'ar'
                  ? 'عرض JSON'
                  : 'Show JSON'}
              </button>
            </div>
            {showRawJson && (
              <pre
                dir="ltr"
                className="bg-[#0B0D12] border border-white/8 rounded-xl p-4 text-[11px] font-mono-num text-[#F4F5F7] overflow-x-auto max-h-96"
              >
                {jsonText}
              </pre>
            )}
          </section>
        </div>
      )}
    </div>
  );
}
