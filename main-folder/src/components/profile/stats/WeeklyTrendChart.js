import { useState } from 'react';
import { formatDuration, isoWeekParts } from '../../../utils/statsFormat';

const BAR_MAX_PX = 96;

function scalePx(value, max) {
  if (!value || !max) return 0;
  return Math.max(4, Math.round((value / max) * BAR_MAX_PX));
}

const MODES = [
  { key: 'episodes', label: 'Episodes' },
  { key: 'time', label: 'Time' },
];

export default function WeeklyTrendChart({
  data,
  episodeKey = 'episodes',
  countLabel = 'Episodes',
  emptyMessage = 'No activity in the last 12 weeks yet.',
  weeksToShow = 8,
}) {
  const [mode, setMode] = useState('episodes');

  if (!data?.length) {
    return (
      <p className="rounded-xl bg-surface-raised/50 px-3 py-5 text-center text-xs text-muted">
        {emptyMessage}
      </p>
    );
  }

  const rows = data.slice(-weeksToShow);
  const maxEp = Math.max(...rows.map((w) => w[episodeKey] || 0), 1);
  const maxMin = Math.max(...rows.map((w) => w.minutes || 0), 1);
  const hasAny = rows.some((w) => (w[episodeKey] || 0) > 0 || (w.minutes || 0) > 0);

  if (!hasAny) {
    return (
      <p className="rounded-xl bg-surface-raised/50 px-3 py-5 text-center text-xs text-muted">
        {emptyMessage}
      </p>
    );
  }

  const activeWeeks = rows.filter((w) => (w[episodeKey] || 0) > 0 || (w.minutes || 0) > 0).length;
  const isTime = mode === 'time';
  const max = isTime ? maxMin : maxEp;
  const barColor = isTime ? 'bg-link/80 hover:bg-link' : 'bg-accent hover:bg-accent/90';
  const countWord = countLabel.toLowerCase();

  return (
    <div className="rounded-xl border border-border/40 bg-surface-raised/20 p-3">
      <div className="mb-3 flex items-start justify-between gap-2">
        <div>
          <p className="text-[10px] font-bold uppercase tracking-widest text-muted">Weekly rhythm</p>
          <p className="text-[10px] text-muted-dim">
            {activeWeeks} active · {rows.length} weeks
          </p>
        </div>
        <label className="relative shrink-0">
          <span className="sr-only">Chart metric</span>
          <select
            value={mode}
            onChange={(e) => setMode(e.target.value)}
            className="appearance-none rounded-lg border border-border/60 bg-canvas/80 py-1.5 pl-2.5 pr-7 text-[11px] font-semibold text-ink-bright cursor-pointer focus:border-accent/50 focus:outline-none"
          >
            {MODES.map((m) => (
              <option key={m.key} value={m.key}>
                {m.key === 'episodes' ? countLabel : 'Time'}
              </option>
            ))}
          </select>
          <span
            className="pointer-events-none absolute right-2 top-1/2 -translate-y-1/2 text-[10px] text-muted"
            aria-hidden
          >
            ▾
          </span>
        </label>
      </div>

      <div className="flex items-end justify-between gap-0.5 sm:gap-1" style={{ height: BAR_MAX_PX + 40 }}>
        {rows.map((week) => {
          const ep = week[episodeKey] || 0;
          const mins = week.minutes || 0;
          const value = isTime ? mins : ep;
          const wk = isoWeekParts(week.weekStart);
          const dateHint = new Date(week.weekStart).toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
          });
          const tooltip = isTime
            ? `${wk.full} (${dateHint}): ${formatDuration(mins)}`
            : `${wk.full} (${dateHint}): ${ep} ${countWord}`;

          return (
            <div
              key={week.weekStart}
              className="group flex min-w-0 flex-1 flex-col items-center justify-end gap-1"
              title={tooltip}
            >
              <span className="text-[9px] font-semibold text-muted opacity-0 transition-opacity group-hover:opacity-100 sm:text-[10px]">
                {isTime ? formatDuration(mins) : ep || ''}
              </span>
              <div
                className="flex w-full max-w-[2.25rem] items-end justify-center sm:max-w-[2.75rem]"
                style={{ height: BAR_MAX_PX }}
              >
                <div
                  className={`w-[62%] max-w-[1.75rem] rounded-t-md transition-all ${barColor} ${
                    value ? 'opacity-100' : 'opacity-0'
                  }`}
                  style={{ height: scalePx(value, max) }}
                />
              </div>
              <div className="flex flex-col items-center leading-tight">
                <span className="text-[9px] font-bold text-ink-bright sm:text-[10px]">{wk.label}</span>
              </div>
            </div>
          );
        })}
      </div>

      <p className="mt-2 border-t border-border/30 pt-2 text-center text-[9px] text-muted sm:text-[10px]">
        ISO week · year · left = oldest
      </p>
    </div>
  );
}
