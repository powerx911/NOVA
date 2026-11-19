import { Atom, Battery, Box, Cable, Cpu, FlaskConical, Gem, Layers, Shield, Sparkles, Wind, type LucideIcon } from 'lucide-react';

const RESOURCE_STYLES: Record<string, { icon: LucideIcon; tone: string }> = {
  copper_wire: { icon: Cable, tone: 'from-orange-400/20 to-amber-500/5 text-orange-300 border-orange-300/20' },
  silicon_ore: { icon: Cpu, tone: 'from-sky-400/20 to-blue-500/5 text-sky-300 border-sky-300/20' },
  energy_cells: { icon: Battery, tone: 'from-yellow-300/20 to-amber-500/5 text-yellow-200 border-yellow-300/20' },
  crude_alloy: { icon: Layers, tone: 'from-slate-300/20 to-slate-500/5 text-slate-200 border-slate-300/20' },
  carbon_fiber: { icon: Wind, tone: 'from-cyan-300/20 to-teal-500/5 text-cyan-200 border-cyan-300/20' },
  rare_minerals: { icon: Gem, tone: 'from-violet-400/20 to-fuchsia-500/5 text-violet-300 border-violet-300/20' },
  titanium_ore: { icon: Shield, tone: 'from-indigo-300/20 to-blue-500/5 text-indigo-200 border-indigo-300/20' },
  polymer_resin: { icon: Box, tone: 'from-emerald-300/20 to-teal-500/5 text-emerald-200 border-emerald-300/20' },
  biotech_gel: { icon: FlaskConical, tone: 'from-lime-300/20 to-green-500/5 text-lime-200 border-lime-300/20' },
  quantum_dust: { icon: Atom, tone: 'from-fuchsia-400/20 to-violet-500/5 text-fuchsia-200 border-fuchsia-300/20' },
};

const SIZE_STYLES = {
  sm: 'h-8 w-8 rounded-lg',
  md: 'h-11 w-11 rounded-xl',
  lg: 'h-14 w-14 rounded-2xl',
};

const ICON_SIZES = { sm: 'h-4 w-4', md: 'h-5 w-5', lg: 'h-6 w-6' };

type ResourceIconProps = {
  itemId: string;
  size?: keyof typeof SIZE_STYLES;
  className?: string;
};

export function ResourceIcon({ itemId, size = 'md', className = '' }: ResourceIconProps) {
  const style = RESOURCE_STYLES[itemId] ?? { icon: Sparkles, tone: 'from-blue-400/20 to-violet-500/5 text-blue-200 border-blue-300/20' };
  const Icon = style.icon;

  return (
    <span
      role="img"
      aria-label={itemId}
      className={`inline-flex shrink-0 items-center justify-center border bg-gradient-to-br shadow-inner ${SIZE_STYLES[size]} ${style.tone} ${className}`}
    >
      <Icon className={ICON_SIZES[size]} strokeWidth={1.8} aria-hidden="true" />
    </span>
  );
}
