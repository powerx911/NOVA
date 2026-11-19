import type { CompanyLog, Language } from '../../types/game';

type CompanyOperationsLogProps = {
  logs: CompanyLog[];
  language: Language;
};

export function CompanyOperationsLog({ logs, language }: CompanyOperationsLogProps) {
  if (logs.length === 0) return null;

  return (
    <div className="bg-[#141821] border border-white/8 rounded-2xl p-5 space-y-3">
      <h3 className="text-sm font-semibold text-[#F4F5F7]">
        {language === 'ar' ? 'سجل عمليات الشركة' : 'Company Operations Log'}
      </h3>
      <div className="space-y-2">
        {logs.slice(0, 20).map((log) => (
          <div
            key={log.id}
            className="flex items-center justify-between text-xs py-2 border-b border-white/6 last:border-0"
          >
            <span className="text-[#9299A6]">{log.details}</span>
            <span className={`font-mono-num font-semibold ${log.amount >= 0 ? 'text-emerald-400' : 'text-[#E04455]'}`}>
              {log.amount >= 0 ? `+${log.amount}` : log.amount}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
