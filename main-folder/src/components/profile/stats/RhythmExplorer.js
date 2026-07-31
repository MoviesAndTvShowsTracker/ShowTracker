import { useEffect, useMemo, useState } from 'react';
import {
  addDays,
  formatCount,
  formatDayLabel,
  formatDuration,
  formatMonthLabel,
  todayKey,
} from '../../../utils/statsFormat';

const TRACK_PX = 88;
const DAY_COUNT = 30;
const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

function barHeight(value, max) {
  if (!value || !max) return 3;
  return Math.max(6, Math.round((Math.sqrt(value) / Math.sqrt(max)) * TRACK_PX));
}

function monthBars(months) {
  return (months || []).map((m) => ({
    key: m.month,
    label: formatMonthLabel(m.month).slice(0, 1),
    title: formatMonthLabel(m.month, true),
    minutes: m.minutes || 0,
    films: m.films || 0,
    episodes: m.episodes || 0,
    count: (m.films || 0) + (m.episodes || 0),
  }));
}

function dayBars(days) {
  const byDate = new Map((days || []).map((d) => [d.date, d]));
  const end = todayKey();
  return Array.from({ length: DAY_COUNT }, (_, i) => {
    const key = addDays(end, -(DAY_COUNT - 1 - i));
    const entry = byDate.get(key);
    const films = entry?.films || 0;
    const episodes = entry?.episodes || 0;
    return {
      key,
      label: i === 0 || i === DAY_COUNT - 1 || key.endsWith('-01') ? String(Number(key.slice(-2))) : '',
      title: formatDayLabel(key),
      minutes: entry?.minutes || 0,
      films,
      episodes,
      count: films + episodes,
    };
  });
}

function weekdayBars(days) {
  const buckets = WEEKDAYS.map((name) => ({
    key: name,
    label: name.slice(0, 1),
    title: `${name}s`,
    minutes: 0,
    films: 0,
    episodes: 0,
    count: 0,
  }));

  for (const entry of days || []) {
    if (!entry?.date) continue;
    const [y, m, d] = entry.date.split('-').map(Number);
    // JS: 0=Sun … convert to Mon-first index
    const jsDay = new Date(y, m - 1, d).getDay();
    const idx = (jsDay + 6) % 7;
    const films = entry.films || 0;
    const episodes = entry.episodes || 0;
    buckets[idx].films += films;
    buckets[idx].episodes += episodes;
    buckets[idx].count += films + episodes;
    buckets[idx].minutes += entry.minutes || 0;
  }

  return buckets;
}

function pickDefault(bars) {
  let best = null;
  for (const bar of bars) {
    if (!best || bar.count > best.count || (bar.count === best.count && bar.minutes > best.minutes)) {
      best = bar;
    }
  }
  if (best?.count) return best.key;
  return bars[bars.length - 1]?.key || null;
}

function DetailCard({ bar, mode }) {
  if (!bar) {
    return (
      <div className="rounded-xl border border-border/40 bg-surface-raised/30 px-4 py-3">
        <p className="text-sm text-muted">Tap a bar to inspect that stretch of your diary.</p>
      </div>
    );
  }

  const empty = !bar.count && !bar.minutes;
  return (
    <div className="rounded-xl border border-border/50 bg-canvas/50 px-4 py-3.5">
      <p className="text-[10px] font-bold uppercase tracking-[0.14em] text-accent">
        {mode === 'months' ? 'Month' : mode === 'weekdays' ? 'Weekday' : 'Day'}
      </p>
      <p className="mt-1.5 font-serif text-lg leading-snug text-ink-bright">{bar.title}</p>
      {empty ? (
        <p className="mt-1.5 text-sm text-muted">Nothing logged here.</p>
      ) : (
        <>
          <p className="mt-1.5 text-sm text-ink">
            <span className="tnum font-semibold text-ink-bright">{formatDuration(bar.minutes)}</span>
            {' · '}
            {formatCount(bar.count)} logged
          </p>
          <p className="mt-1 text-xs text-muted">
            {[
              bar.films ? `${formatCount(bar.films)} film${bar.films === 1 ? '' : 's'}` : null,
              bar.episodes
                ? `${formatCount(bar.episodes)} episode${bar.episodes === 1 ? '' : 's'}`
                : null,
            ]
              .filter(Boolean)
              .join(' · ')}
          </p>
        </>
      )}
    </div>
  );
}

const MODES = [
  { id: 'months', label: 'Months' },
  { id: 'days', label: '30 days' },
  { id: 'weekdays', label: 'Weekdays' },
];

/** Interactive rhythm chart that always fits its container — no horizontal overflow. */
export default function RhythmExplorer({ months, days, streak }) {
  const [mode, setMode] = useState('months');
  const [selectedKey, setSelectedKey] = useState(null);

  const bars = useMemo(() => {
    if (mode === 'days') return dayBars(days);
    if (mode === 'weekdays') return weekdayBars(days);
    return monthBars(months);
  }, [mode, months, days]);

  const max = Math.max(...bars.map((b) => b.minutes || b.count || 0), 1);
  const peakKey = pickDefault(bars);

  useEffect(() => {
    setSelectedKey(peakKey);
  }, [peakKey]);

  const selected = bars.find((b) => b.key === selectedKey) || null;

  return (
    <div className="glass-card overflow-hidden p-4 sm:p-5">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div>
          <p className="text-sm font-semibold text-ink-bright">Rhythm</p>
          <p className="mt-0.5 text-xs text-muted">Tap a bar to dig in</p>
        </div>
        {streak > 0 && (
          <p className="text-xs font-semibold text-accent">{streak}-day streak</p>
        )}
      </div>

      <div className="seg-tabs mb-4" role="tablist" aria-label="Rhythm range">
        {MODES.map((m) => (
          <button
            key={m.id}
            type="button"
            role="tab"
            aria-selected={mode === m.id}
            onClick={() => setMode(m.id)}
            className={`seg-tab ${mode === m.id ? 'seg-tab--active' : ''}`}
          >
            {m.label}
          </button>
        ))}
      </div>

      <div
        className="flex min-w-0 items-end gap-1 sm:gap-1.5"
        style={{ height: TRACK_PX + 28 }}
        role="listbox"
        aria-label={
          mode === 'months' ? 'Monthly activity' : mode === 'days' ? 'Daily activity' : 'Weekday activity'
        }
      >
        {bars.map((bar) => {
          const value = bar.minutes || bar.count;
          const height = barHeight(value, max);
          const isSelected = bar.key === selectedKey;
          const isPeak = bar.key === peakKey && value > 0;

          return (
            <button
              key={bar.key}
              type="button"
              role="option"
              aria-selected={isSelected}
              aria-label={`${bar.title}: ${bar.count} logged, ${formatDuration(bar.minutes)}`}
              onClick={() => setSelectedKey(bar.key)}
              className="group flex min-w-0 flex-1 flex-col items-center justify-end gap-1.5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent cursor-pointer"
            >
              <span
                className={`w-full rounded-t-[4px] transition-[background-color,transform] duration-150 ease-out ${
                  value
                    ? isSelected
                      ? 'bg-accent'
                      : isPeak
                        ? 'bg-accent/70 group-hover:bg-accent'
                        : 'bg-accent/40 group-hover:bg-accent/65'
                    : 'bg-border/70'
                } ${isSelected ? 'scale-y-105' : 'group-active:scale-y-95'}`}
                style={{ height, transformOrigin: 'bottom' }}
              />
              <span
                className={`h-3 text-[9px] font-bold uppercase tracking-wide ${
                  isSelected ? 'text-accent' : 'text-muted-dim'
                }`}
              >
                {bar.label}
              </span>
            </button>
          );
        })}
      </div>

      <div className="mt-4">
        <DetailCard bar={selected} mode={mode} />
      </div>
    </div>
  );
}
