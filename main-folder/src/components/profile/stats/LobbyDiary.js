import { formatCount, formatDuration, formatShortDate } from '../../../utils/statsFormat';

function hourLabel(hour) {
  const h = ((hour % 24) + 24) % 24;
  if (h === 0) return '12a';
  if (h === 12) return '12p';
  return h < 12 ? `${h}a` : `${h - 12}p`;
}

export function HouseLightsDial({ rhythm }) {
  if (!rhythm?.byHour?.length) return null;
  const hours = rhythm.byHour;
  const maxMins = Math.max(...hours.map((h) => h.mins || 0), 1);
  const peak = rhythm.peakHour ?? 0;

  return (
    <section className="rounded-3xl border border-border/50 bg-surface/70 p-5">
      <p className="text-[10px] font-bold uppercase tracking-[0.14em] text-link">House lights</p>
      <h2 className="mt-2 font-serif text-2xl leading-snug text-ink-bright">
        {rhythm.caption || 'Your lobby hours'}
      </h2>
      <div className="relative mx-auto mt-6 h-56 w-56">
        <div className="absolute inset-0 rounded-full border border-border/60" />
        {hours.map((bucket, hour) => {
          const mins = bucket.mins || 0;
          const tv = bucket.tvMins || 0;
          const intensity = mins / maxMins;
          const len = 18 + intensity * 52;
          const angle = (hour / 24) * 360 - 90;
          const isPeak = hour === peak && mins > 0;
          const filmHeavy = tv < mins - tv;
          return (
            <div
              key={hour}
              className="absolute left-1/2 top-1/2 origin-bottom"
              style={{
                width: isPeak ? 7 : 5,
                height: len,
                marginLeft: isPeak ? -3.5 : -2.5,
                marginTop: -len,
                transform: `rotate(${angle}deg) translateY(-70px)`,
                opacity: mins > 0 ? 1 : 0.12,
                borderRadius: 999,
                background: filmHeavy
                  ? 'color-mix(in srgb, rgb(var(--ink)) 40%, transparent)'
                  : 'rgb(var(--ink))',
              }}
              title={`${hourLabel(hour)} · ${formatDuration(mins)}`}
            />
          );
        })}
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <p className="tnum font-serif text-2xl text-ink-bright">{hourLabel(peak)}</p>
          <p className="text-[10px] font-bold uppercase tracking-[0.12em] text-muted">peak</p>
        </div>
      </div>
      <div className="mt-4 flex flex-wrap gap-4 text-xs text-muted">
        <span>TV-heavy hours denser</span>
        <span>Film-heavy hours softer</span>
      </div>
    </section>
  );
}

export function LobbyTypePlaque({ lobby }) {
  if (!lobby?.label) return null;
  return (
    <section className="rounded-3xl bg-link/10 p-5">
      <p className="text-[10px] font-bold uppercase tracking-[0.14em] text-link">Lobby type</p>
      <h2 className="mt-2 font-serif text-2xl text-ink-bright">{lobby.label}</h2>
      <p className="mt-2 text-sm text-muted">{lobby.blurb}</p>
      <div className="mt-3 flex flex-wrap gap-2">
        {lobby.finishLabel && (
          <span className="rounded-full bg-surface/80 px-3 py-1 text-xs font-semibold text-link">
            {lobby.finishLabel}
          </span>
        )}
        {lobby.mediaLabel && (
          <span className="rounded-full bg-surface/80 px-3 py-1 text-xs font-semibold text-link">
            {lobby.mediaLabel}
          </span>
        )}
        {lobby.rewatchRate > 0 && (
          <span className="rounded-full bg-surface/80 px-3 py-1 text-xs font-semibold text-link">
            {lobby.rewatchRate}% rewatch
          </span>
        )}
      </div>
    </section>
  );
}

export function SeasonArcs({ arcs }) {
  if (!arcs?.length) return null;
  return (
    <section>
      <h2 className="font-serif text-2xl text-ink-bright">On a loop</h2>
      <p className="mt-1 text-sm text-muted">First watches and rewatch passes as parallel ribbons.</p>
      <div className="mt-4 space-y-3">
        {arcs.map((arc) => {
          const densest = Math.max(...(arc.passes || []).map((p) => p.episodes || 0), 1);
          return (
            <article
              key={arc.tvId || arc.tvTitle}
              className="flex gap-3 rounded-2xl border border-border/50 bg-surface/70 p-3"
            >
              {arc.tvPosterImage && (
                <img
                  src={`https://image.tmdb.org/t/p/w185${arc.tvPosterImage}`}
                  alt=""
                  className="h-[72px] w-12 shrink-0 rounded-lg object-cover"
                />
              )}
              <div className="min-w-0 flex-1">
                <p className="font-semibold text-ink-bright">{arc.tvTitle}</p>
                <p className="text-xs text-link">
                  {arc.passCount || 1} passes · {formatDuration(arc.totalMins || 0)}
                </p>
                <div className="mt-2 space-y-1.5">
                  {(arc.passes || []).map((pass, index) => (
                    <div key={`${pass.label}-${index}`} className="flex items-center gap-2">
                      <div className="h-2 flex-1 overflow-hidden rounded-full bg-border/40">
                        <div
                          className="h-full rounded-full bg-link"
                          style={{
                            width: `${Math.max(12, ((pass.episodes || 0) / densest) * 100)}%`,
                            opacity: index === 0 ? 0.55 : 1,
                          }}
                        />
                      </div>
                      <span className="shrink-0 text-[11px] font-semibold text-muted">
                        {pass.label}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            </article>
          );
        })}
      </div>
    </section>
  );
}

export function BiggestNight({ night }) {
  if (!night || (night.count || 0) < 2) return null;
  return (
    <section>
      <h2 className="font-serif text-2xl text-ink-bright">Biggest night</h2>
      <p className="mt-1 text-sm text-muted">
        {night.date ? formatShortDate(night.date) : ''} · {formatCount(night.count)} titles ·{' '}
        {formatDuration(night.minutes || 0)}
      </p>
      <div className="mt-4 flex gap-2 overflow-x-auto pb-1">
        {(night.items || []).map((item) => (
          <div key={`${item.kind}-${item.id}-${item.watchedAt}`} className="w-[72px] shrink-0">
            <div className="overflow-hidden rounded-lg bg-surface-raised">
              {item.stillOrPoster ? (
                <img
                  src={`https://image.tmdb.org/t/p/w185${item.stillOrPoster}`}
                  alt=""
                  className={`w-full object-cover ${item.kind === 'film' ? 'h-[108px]' : 'h-[72px]'}`}
                />
              ) : (
                <div className={`w-full bg-border/40 ${item.kind === 'film' ? 'h-[108px]' : 'h-[72px]'}`} />
              )}
            </div>
            <p className="mt-1 line-clamp-2 text-[11px] font-semibold leading-snug text-ink">
              {item.title}
            </p>
          </div>
        ))}
      </div>
    </section>
  );
}

export function Shelves({ library }) {
  if (!library) return null;
  const cells = [
    ['Watching', library.watching || 0],
    ['Caught up', library.caughtUp || 0],
    ['Backlog eps', library.backlog || 0],
    ['Finished', library.finished || 0],
  ];
  return (
    <section>
      <h2 className="font-serif text-2xl text-ink-bright">The shelves</h2>
      <div className="mt-4 grid grid-cols-2 gap-3">
        {cells.map(([label, value]) => (
          <article key={label} className="rounded-2xl border border-border/50 bg-surface/70 p-4">
            <p className="text-[10px] font-bold uppercase tracking-[0.12em] text-muted">{label}</p>
            <p className="tnum mt-2 font-serif text-2xl text-ink-bright">{formatCount(value)}</p>
          </article>
        ))}
      </div>
      {library.completionRate != null && (
        <p className="mt-3 text-xs text-muted">{library.completionRate}% of tracked shows finished</p>
      )}
    </section>
  );
}

export function HotTakes({ takes }) {
  if (!takes?.length) return null;
  return (
    <section>
      <h2 className="font-serif text-2xl text-ink-bright">Hot takes</h2>
      <p className="mt-1 text-sm text-muted">Where your stars split from the room.</p>
      <ul className="mt-4 space-y-2">
        {takes.map((take) => {
          const loved = (take.delta || 0) > 0;
          return (
            <li
              key={`${take.kind}-${take.id}`}
              className="flex items-center gap-3 rounded-2xl border border-border/50 bg-surface/70 p-3"
            >
              {take.poster && (
                <img
                  src={`https://image.tmdb.org/t/p/w185${take.poster}`}
                  alt=""
                  className="h-14 w-10 shrink-0 rounded-md object-cover"
                />
              )}
              <div className="min-w-0 flex-1">
                <p className="truncate font-semibold text-ink-bright">{take.title}</p>
                <p className="text-xs text-muted">
                  You {take.userRating?.toFixed?.(1) ?? take.userRating} · room{' '}
                  {take.communityRating?.toFixed?.(1) ?? take.communityRating}
                </p>
              </div>
              <p className="shrink-0 text-xs font-semibold text-link">
                {loved ? 'You loved it more' : 'You were cooler'}
              </p>
            </li>
          );
        })}
      </ul>
    </section>
  );
}

export function QuietTaste({ taste }) {
  const tv = taste?.tv?.genreByEpisodes?.slice(0, 5) || [];
  const films = (taste?.films?.genreByTime || taste?.films?.genreByCount || []).slice(0, 5);
  if (!tv.length && !films.length) return null;
  const rows = [
    ['TV', tv],
    ['Films', films],
  ].filter(([, list]) => list.length);
  return (
    <section>
      <h2 className="font-serif text-2xl text-ink-bright">Taste</h2>
      <div className="mt-4 space-y-4">
        {rows.map(([label, list]) => (
          <div key={label}>
            <p className="text-[10px] font-bold uppercase tracking-[0.12em] text-muted">{label}</p>
            <ul className="mt-2 space-y-1.5">
              {list.map((g) => (
                <li key={g.name} className="flex items-center gap-3 text-sm">
                  <span className="w-28 shrink-0 truncate text-ink">{g.name}</span>
                  <span className="h-1.5 flex-1 overflow-hidden rounded-full bg-border/40">
                    <span
                      className="block h-full rounded-full bg-link/70"
                      style={{ width: `${Math.max(8, g.pct || 0)}%` }}
                    />
                  </span>
                  <span className="tnum w-8 text-right text-xs text-muted">{g.pct || 0}%</span>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    </section>
  );
}

export function Ledger({ overview, previousYear }) {
  if (!overview) return null;
  const parts = [];
  if (overview.filmCount) parts.push(`${formatCount(overview.filmCount)} films`);
  if (overview.tvShowCount) parts.push(`${formatCount(overview.tvShowCount)} shows`);
  if (overview.episodeCount) parts.push(`${formatCount(overview.episodeCount)} episodes`);
  if (overview.episodeRewatchPlays) {
    parts.push(`${formatCount(overview.episodeRewatchPlays)} rewatches`);
  }
  return (
    <section className="rounded-3xl border border-border/50 bg-surface/70 p-5">
      <p className="text-[10px] font-bold uppercase tracking-[0.14em] text-muted">Ledger</p>
      <p className="tnum mt-2 font-serif text-3xl text-ink-bright">
        {formatDuration(overview.totalMins || 0)}
      </p>
      <p className="mt-2 text-sm text-muted">{parts.join(' · ') || 'Nothing logged yet'}</p>
      {previousYear?.totalMins > 0 && (
        <p className="mt-2 text-xs font-semibold text-link">
          Prior calendar year: {formatDuration(previousYear.totalMins)}
        </p>
      )}
    </section>
  );
}
