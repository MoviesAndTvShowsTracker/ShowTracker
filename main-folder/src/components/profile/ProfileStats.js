import { useMemo } from 'react';
import { Clapperboard, Clock, Layers, Timer, Tv } from 'lucide-react';

function formatDuration(totalMins) {
  if (!totalMins || totalMins <= 0) return '—';
  const rounded = Math.round(totalMins);
  if (rounded < 60) return `${rounded}m`;
  const h = Math.floor(rounded / 60);
  const m = rounded % 60;
  if (h >= 24) {
    const d = Math.floor(h / 24);
    const rh = h % 24;
    return rh > 0 ? `${d}d ${rh}h` : `${d}d`;
  }
  return m > 0 ? `${h}h ${m}m` : `${h}h`;
}

function formatCount(n) {
  if (n >= 1000) return `${(n / 1000).toFixed(1).replace(/\.0$/, '')}k`;
  return String(n);
}

function StatCard({ icon: Icon, label, value, detail, loading, className = '' }) {
  return (
    <div
      className={`flex min-h-[5.5rem] flex-col justify-between rounded-xl border border-border/50 bg-surface-raised/40 p-3 sm:min-h-[6.25rem] sm:p-4 ${className}`}
    >
      <div className="flex items-start justify-between gap-2">
        <span className="text-[10px] font-bold uppercase leading-tight tracking-widest text-muted">
          {label}
        </span>
        <span className="inline-flex shrink-0 rounded-lg bg-accent/10 p-1 text-accent">
          <Icon className="h-3.5 w-3.5" aria-hidden="true" />
        </span>
      </div>
      <div>
        {loading ? (
          <div className="mt-1 h-7 w-12 animate-pulse rounded-md bg-border/60 sm:h-8" />
        ) : (
          <p className="font-serif text-2xl leading-none text-ink-bright sm:text-3xl">{value}</p>
        )}
        {detail && <p className="mt-1 line-clamp-2 text-[10px] leading-snug text-muted sm:text-[11px]">{detail}</p>}
      </div>
    </div>
  );
}

export default function ProfileStats({
  filmCount,
  tvCount,
  episodeCount,
  filmMins,
  tvMins,
  tvStatsLoading,
}) {
  const filmDetail = useMemo(() => {
    if (!filmCount) return 'Mark films watched';
    return `${filmCount} film${filmCount !== 1 ? 's' : ''} logged`;
  }, [filmCount]);

  const tvDetail = useMemo(() => {
    if (!tvCount) return 'Favorite shows to add';
    if (episodeCount > 0) return `~${formatCount(episodeCount)} episodes`;
    return `${tvCount} show${tvCount !== 1 ? 's' : ''} in diary`;
  }, [tvCount, episodeCount]);

  const episodeDetail = useMemo(() => {
    if (tvStatsLoading) return 'Calculating…';
    if (!tvCount) return 'From your TV shows';
    return 'Across favorited shows';
  }, [tvStatsLoading, tvCount]);

  const filmTimeDetail = useMemo(() => {
    if (!filmCount) return 'Favorite or mark watched';
    if (filmMins > 0) return 'From watched films';
    return 'Runtime not available';
  }, [filmCount, filmMins]);

  const tvTimeDetail = useMemo(() => {
    if (tvStatsLoading) return 'Calculating…';
    if (!tvCount) return 'Favorite a show to track';
    if (tvMins > 0) return `~${formatCount(episodeCount)} episodes`;
    return 'Episode data loading';
  }, [tvStatsLoading, tvCount, tvMins, episodeCount]);

  return (
    <section aria-label="Your stats" className="glass-card overflow-hidden !p-0">
      <div className="border-b border-border/60 px-4 py-3 sm:px-5">
        <h2 className="section-title">Your stats</h2>
      </div>
      <div className="grid grid-cols-2 gap-2 p-3 sm:gap-3 sm:p-4 md:grid-cols-3 lg:grid-cols-5">
        <StatCard icon={Clapperboard} label="Films" value={filmCount || '0'} detail={filmDetail} />
        <StatCard icon={Tv} label="TV shows" value={tvCount || '0'} detail={tvDetail} />
        <StatCard
          icon={Clock}
          label="Film time"
          value={formatDuration(filmMins)}
          detail={filmTimeDetail}
        />
        <StatCard
          icon={Timer}
          label="TV time"
          value={formatDuration(tvMins)}
          detail={tvTimeDetail}
          loading={tvStatsLoading && tvCount > 0}
        />
        <StatCard
          icon={Layers}
          label="Episodes"
          value={episodeCount > 0 ? formatCount(episodeCount) : '—'}
          detail={episodeDetail}
          loading={tvStatsLoading && tvCount > 0}
          className="col-span-2 md:col-span-1"
        />
      </div>
    </section>
  );
}
