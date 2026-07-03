export default function GenreBreakdown({ title, subtitle, items, compact = false }) {
  if (!items?.length) {
    return (
      <div className="rounded-xl border border-border/40 bg-surface-raised/20 px-3 py-6 text-center">
        <p className="text-xs text-muted">Not enough data yet.</p>
      </div>
    );
  }

  const maxPct = Math.max(...items.map((g) => g.pct), 1);
  const gap = compact ? 'space-y-1.5' : 'space-y-2';

  return (
    <div className="h-full rounded-xl border border-border/40 bg-surface-raised/20 p-3">
      <div className="mb-2.5">
        <p className="text-sm font-semibold leading-tight text-ink-bright">{title}</p>
        {subtitle && <p className="text-[10px] text-muted">{subtitle}</p>}
      </div>
      <div className={gap}>
        {items.map((genre) => (
          <div key={genre.name} className="grid grid-cols-[1fr_auto] items-center gap-x-2 gap-y-0.5">
            <span className="truncate text-[11px] font-medium text-ink sm:text-xs">{genre.name}</span>
            <span className="shrink-0 text-[10px] font-bold text-accent">{genre.pct}%</span>
            <div className="col-span-2 h-1.5 overflow-hidden rounded-full bg-surface-raised">
              <div
                className="h-full rounded-full bg-gradient-to-r from-accent/60 to-accent"
                style={{ width: `${Math.max(4, (genre.pct / maxPct) * 100)}%` }}
              />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
