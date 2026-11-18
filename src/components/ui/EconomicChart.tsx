interface SeriesPoint {
  label: string;
  value: number;
}

interface EconomicChartProps {
  data: SeriesPoint[];
  height?: number;
  unit?: string;
}

export function EconomicChart({ data, height = 110, unit = '' }: EconomicChartProps) {
  if (!data.length) return null;

  const maxVal = Math.max(...data.map((d) => d.value), 1);
  const minVal = Math.min(...data.map((d) => d.value), 0);
  const span = Math.max(maxVal - minVal, 1);

  const width = 320;
  const padX = 8;
  const padY = 12;
  const chartH = height - padY * 2;
  const chartW = width - padX * 2;

  const points = data.map((d, i) => {
    const x = padX + (data.length === 1 ? chartW / 2 : (i / (data.length - 1)) * chartW);
    const y = padY + chartH - ((d.value - minVal) / span) * chartH;
    return { x, y, ...d };
  });

  const linePath = points
    .map((p, idx) => `${idx === 0 ? 'M' : 'L'} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`)
    .join(' ');

  const areaPath = `${linePath} L ${points[points.length - 1].x.toFixed(1)} ${height} L ${points[0].x.toFixed(1)} ${height} Z`;

  return (
    <div className="w-full">
      <svg
        viewBox={`0 0 ${width} ${height}`}
        className="w-full overflow-visible"
        role="img"
        aria-label="Economic Trend Chart"
      >
        <defs>
          <linearGradient id="nexoraChartGrad" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#B91C32" stopOpacity="0.32" />
            <stop offset="100%" stopColor="#B91C32" stopOpacity="0" />
          </linearGradient>
        </defs>
        <line
          x1={padX}
          y1={height - padY}
          x2={width - padX}
          y2={height - padY}
          stroke="rgba(244,245,247,0.08)"
          strokeWidth="1"
        />
        <path d={areaPath} fill="url(#nexoraChartGrad)" />
        <path
          d={linePath}
          fill="none"
          stroke="#E04455"
          strokeWidth="2.2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        {points.map((p) => (
          <circle key={p.label} cx={p.x} cy={p.y} r="3" fill="#0B0D12" stroke="#E04455" strokeWidth="2" />
        ))}
      </svg>
      <div className="flex items-center justify-between gap-2 mt-2 text-[11px] text-[#9299A6]">
        {data.map((d) => (
          <div key={d.label} className="flex flex-col items-center min-w-0">
            <span className="truncate max-w-[60px]">{d.label}</span>
            <span className="font-mono-num text-[#F4F5F7] font-medium">
              {d.value.toLocaleString()}
              {unit ? ` ${unit}` : ''}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
