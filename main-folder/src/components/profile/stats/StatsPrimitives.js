import { formatCount, formatDuration } from '../../../utils/statsFormat';

/** Compact metric used on Profile teaser and Stats story cards. */
export function StatFact({ label, value, detail, loading = false, className = '' }) {
  return (
    <div className={`min-w-0 ${className}`}>
      <p className="text-[10px] font-bold uppercase tracking-widest text-muted">{label}</p>
      {loading ? (
        <div className="mt-1.5 h-7 w-16 animate-pulse rounded-md bg-border/60" />
      ) : (
        <p className="tnum mt-1.5 font-serif text-2xl leading-none text-ink-bright sm:text-[1.75rem]">
          {value}
        </p>
      )}
      {detail ? <p className="mt-1 text-[11px] leading-snug text-muted">{detail}</p> : null}
    </div>
  );
}

export function TimeSplitBar({ filmShare, tvShare, filmMins, tvMins }) {
  if (!filmShare && !tvShare) {
    return <p className="text-xs text-muted sm:text-sm">Log episodes or films to see your split.</p>;
  }
  return (
    <div>
      <p className="text-[10px] font-bold uppercase tracking-widest text-muted">Film vs TV</p>
      <div className="mt-2 flex h-2.5 overflow-hidden rounded-full bg-surface-raised sm:h-3">
        {filmShare > 0 && <div className="bg-link/80" style={{ width: `${filmShare}%` }} />}
        {tvShare > 0 && <div className="bg-accent" style={{ width: `${tvShare}%` }} />}
      </div>
      <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-[11px] text-muted sm:text-xs">
        <span className="flex items-center gap-1.5">
          <span className="h-2 w-2 rounded-full bg-link/80" aria-hidden />
          Films {filmShare}% · {formatDuration(filmMins)}
        </span>
        <span className="flex items-center gap-1.5">
          <span className="h-2 w-2 rounded-full bg-accent" aria-hidden />
          TV {tvShare}% · {formatDuration(tvMins)}
        </span>
      </div>
    </div>
  );
}

export function RuntimeCoverageNote({ quality, films }) {
  if (!quality && !films) return null;
  const known = quality?.filmRuntimeKnown ?? films?.withRuntime;
  const total = films?.count;
  const missing = quality?.filmRuntimeMissing ?? films?.missingRuntime;
  if (!total || !missing) return null;
  return (
    <p className="rounded-lg border border-border/40 bg-surface-raised/30 px-3 py-2 text-[11px] text-muted">
      Estimated watch time uses runtime for {known}/{total} films
      {quality?.runtimeBackfilled > 0 ? ` · ${quality.runtimeBackfilled} updated` : ''}.
    </p>
  );
}

export { storyInsight as insightFallback } from './statsStory';
