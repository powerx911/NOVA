import type { Organization, OrganizationResearchId, Language } from '../../types/game';
import { calculateOrgResearchCost, ORG_RESEARCH_DEFINITIONS } from '../../lib/economy';

interface OrganizationResearchPanelProps {
  organization: Organization;
  language: Language;
  canManageOrg: boolean;
  busyKey: string | null;
  onResearchUpgrade: (researchId: OrganizationResearchId) => void;
}

export function OrganizationResearchPanel({
  organization, language, canManageOrg, busyKey, onResearchUpgrade,
}: OrganizationResearchPanelProps) {
  return (
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
          const level = organization.research?.[researchId] ?? 0;
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
                disabled={!canManageOrg || isMax || busyKey === `research_${researchId}` || organization.treasuryBalance < cost}
                onClick={() => onResearchUpgrade(researchId)}
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
  );
}
