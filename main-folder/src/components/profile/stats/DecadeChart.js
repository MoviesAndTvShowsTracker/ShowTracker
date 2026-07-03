import { formatDuration } from '../../../utils/statsFormat';

/** Sqrt scale so 1 vs 275 films still shows visible smaller bars */
function barWidth(count, maxCount) {
  if (!count || !maxCount) return 0;
  return Math.max(8, Math.round((Math.sqrt(count) / Math.sqrt(maxCount)) * 100));
}

export default function DecadeChart({ decades }) {
  if (!decades?.length) {
    return (
      <div className="rounded-xl border border-border/40 bg-surface-raised/20 px-3 py-6 text-center">
        <p className="text-xs text-muted">Release years appear once films have TMDB data.</p>
      </div>
    );
  }

  const sorted = [...decades].sort((a, b) => parseInt(a.decade, 10) - parseInt(b.decade, 10));
  const maxCount = Math.max(...sorted.map((d) => d.count), 1);
  const top = sorted.reduce((best, d) => (d.count > (best?.count || 0) ? d : best), null);

  return (
    <div className="rounded-xl border border-border/40 bg-surface-raised/20 p-3">
      <div className="mb-3 flex items-baseline justify-between gap-2">
        <div>
          <p className="text-sm font-semibold text-ink-bright">Films by decade</p>
          {top && (
            <p className="text-[10px] text-muted">
              Peak: {top.decade} · {top.count} films
            </p>
          )}
        </div>
      </div>

      <ul className="space-y-1.5">
        {sorted.map((d) => {
          const w = barWidth(d.count, maxCount);
          const isTop = d.decade === top?.decade;
          return (
            <li
              key={d.decade}
              className="grid grid-cols-[2.75rem_1fr_auto] items-center gap-2 sm:grid-cols-[3rem_1fr_auto]"
              title={`${d.count} films · ${formatDuration(d.minutes)} watched`}
            >
              <span
                className={`text-[10px] font-bold sm:text-[11px] ${
                  isTop ? 'text-accent' : 'text-muted'
                }`}
              >
                {d.decade}
              </span>
              <div className="h-2 overflow-hidden rounded-full bg-surface-raised sm:h-2.5">
                <div
                  className={`h-full rounded-full transition-all ${
                    isTop ? 'bg-link' : 'bg-link/65'
                  }`}
                  style={{ width: `${w}%` }}
                />
              </div>
              <span className="min-w-[1.75rem] text-right text-[10px] font-semibold text-ink-bright sm:text-[11px]">
                {d.count}
              </span>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
