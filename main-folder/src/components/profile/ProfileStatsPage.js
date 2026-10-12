import { Link } from 'react-router-dom';
import { Clapperboard, RefreshCw, Star } from 'lucide-react';
import {
  formatCount,
  formatDelta,
  formatDuration,
  formatMemberSince,
} from '../../utils/statsFormat';
import PageTitle from '../../utils/PageTitle';
import BackNav from '../ui/BackNav';
import useDashboardStats from '../../hooks/useDashboardStats';
import RhythmExplorer from './stats/RhythmExplorer';
import GenreBreakdown from './stats/GenreBreakdown';
import DecadeChart from './stats/DecadeChart';
import { RuntimeCoverageNote, TimeSplitBar } from './stats/StatsPrimitives';
import { buildQuirkTickets, screenDaysLine, storyInsight } from './stats/statsStory';

function QuirkTicket({ ticket }) {
  return (
    <article className="stats-quirk shrink-0 snap-start rounded-2xl border border-border/50 bg-surface/70 p-4 sm:min-w-0 sm:snap-none">
      <p className="text-[10px] font-bold uppercase tracking-[0.14em] text-accent">{ticket.kicker}</p>
      <p className="tnum mt-2 font-serif text-2xl leading-none text-ink-bright sm:text-[1.85rem]">
        {ticket.headline}
      </p>
      <p className="mt-2 text-sm leading-snug text-ink">{ticket.line}</p>
      {ticket.meta && <p className="mt-2 text-[11px] text-muted">{ticket.meta}</p>}
    </article>
  );
}

function RatingSummaryCard({ label, count, average }) {
  const hasData = (count || 0) > 0 && average > 0;
  return (
    <article className="rounded-2xl border border-border/50 bg-surface/70 p-4">
      <p className="text-[10px] font-bold uppercase tracking-[0.14em] text-muted">{label}</p>
      {hasData ? (
        <>
          <p className="tnum mt-2 inline-flex items-center gap-1.5 font-serif text-2xl leading-none text-ink-bright">
            <Star className="h-4 w-4 fill-accent text-accent" aria-hidden="true" />
            {average.toFixed(1)}
          </p>
          <p className="mt-1.5 text-xs text-muted">
            avg · {formatCount(count)} rated
          </p>
        </>
      ) : (
        <>
          <p className="tnum mt-2 font-serif text-2xl leading-none text-ink-bright">
            {formatCount(count || 0)}
          </p>
          <p className="mt-1.5 text-xs text-muted">rated</p>
        </>
      )}
    </article>
  );
}

function SpotlightLink({ to, kicker, title, meta, tone = 'accent' }) {
  if (!title) return null;
  const toneClass = tone === 'link' ? 'text-link' : 'text-accent';
  const hoverClass = tone === 'link' ? 'hover:border-link/40' : 'hover:border-accent/40';
  return (
    <Link
      to={to}
      className={`focus-ring pressable block rounded-2xl border border-border/50 bg-surface-raised/30 p-4 transition-colors cursor-pointer ${hoverClass}`}
    >
      <p className="text-[10px] font-bold uppercase tracking-[0.14em] text-muted">{kicker}</p>
      <p className="mt-2 line-clamp-2 font-serif text-xl leading-snug text-ink-bright">{title}</p>
      {meta && <p className={`mt-2 text-xs font-semibold ${toneClass}`}>{meta}</p>}
    </Link>
  );
}

export default function ProfileStatsPage() {
  const { stats, loading, refreshing, error, fromCache, refresh } = useDashboardStats();

  const o = stats?.overview;
  const year = stats?.year;
  const lib = stats?.library;
  const act = stats?.activity;
  const films = stats?.films;
  const taste = stats?.taste;
  const quality = stats?.quality;
  const facts = stats?.funFacts;
  const ratings = stats?.ratings;
  const hasRatings =
    (ratings?.films?.count || 0) > 0 ||
    (ratings?.shows?.count || 0) > 0 ||
    (ratings?.episodeCount || 0) > 0;

  const previousYearTotal = stats?.previousYear?.totalMins;
  const delta = formatDelta(year?.totalMins, previousYearTotal);
  const lastYearLabel = stats?.yearStart ? Number(stats.yearStart.slice(0, 4)) - 1 : null;
  const quirks = buildQuirkTickets(stats);
  const daysLine = screenDaysLine(o?.totalMins);

  const hasTaste =
    taste?.available &&
    (taste.tv?.genreByEpisodes?.length > 0 ||
      taste.films?.genreByCount?.length > 0 ||
      taste.films?.decades?.length > 0);

  const isEmpty = !o?.episodeCount && !o?.filmCount && !(lib?.totalTracked > 0);

  return (
    <>
      <PageTitle title="Your stats" />

      <div className="mx-auto max-w-content px-4 py-6 sm:px-6 md:py-10">
        <div className="mb-5 flex items-center justify-between gap-3">
          <BackNav to="/profile" label="Back to profile" />
          {stats && (
            <button
              type="button"
              disabled={refreshing}
              onClick={refresh}
              className="focus-ring inline-flex min-h-[44px] items-center gap-1.5 rounded-lg px-2 text-xs font-semibold text-link hover:text-ink-bright disabled:opacity-50 cursor-pointer"
            >
              <RefreshCw className={`h-3.5 w-3.5 ${refreshing ? 'animate-spin' : ''}`} />
              Refresh
            </button>
          )}
        </div>

        {loading && !stats ? (
          <div className="space-y-4">
            <div className="glass-card p-6 text-center">
              <p className="text-sm font-medium text-ink-bright">Crunching your stats…</p>
              <p className="mt-1.5 text-sm text-muted">First load can take a moment.</p>
            </div>
            <div className="h-48 animate-pulse rounded-2xl bg-surface-raised" />
            <div className="h-28 animate-pulse rounded-2xl bg-surface-raised" />
          </div>
        ) : error && !stats ? (
          <div className="glass-card p-8 text-center">
            <p className="text-sm text-muted">{error}</p>
            <button type="button" onClick={refresh} className="btn-primary mt-4">
              Try again
            </button>
          </div>
        ) : isEmpty ? (
          <div className="glass-card p-8 text-center">
            <Clapperboard className="mx-auto h-8 w-8 text-accent/70" />
            <p className="mt-3 font-serif text-lg text-ink-bright">Your stats start with one log</p>
            <p className="mt-1.5 text-sm text-muted">
              Mark an episode or a film watched and this page fills in.
            </p>
            <Link to="/tv" className="btn-primary mt-5 inline-flex">
              Browse TV
            </Link>
          </div>
        ) : (
          <div className="stats-diary space-y-8 sm:space-y-10">
            {/* Hero — one composition: story + time */}
            <section className="animate-soft-rise relative overflow-hidden rounded-3xl border border-border/60 bg-surface/85 shadow-glass opacity-0">
              <div
                className="pointer-events-none absolute -right-16 -top-20 h-56 w-56 rounded-full opacity-40 blur-3xl"
                style={{ background: 'var(--bg-glow-1)' }}
                aria-hidden
              />
              <div
                className="pointer-events-none absolute -bottom-24 -left-10 h-48 w-48 rounded-full opacity-30 blur-3xl"
                style={{ background: 'var(--bg-glow-2)' }}
                aria-hidden
              />

              <div className="relative border-b border-border/50 px-5 py-5 sm:px-7 sm:py-6">
                <div className="flex flex-wrap items-end justify-between gap-3">
                  <div>
                    <p className="section-title text-accent">Your diary</p>
                    <h1 className="page-title mt-1.5">Stats</h1>
                  </div>
                  <p className="text-xs text-muted">
                    {stats?.memberSince && <>Member since {formatMemberSince(stats.memberSince)}</>}
                    {fromCache && stats && !refreshing && (
                      <span className="text-muted-dim"> · Saved snapshot</span>
                    )}
                  </p>
                </div>
                <blockquote className="mt-5 max-w-3xl font-serif text-xl leading-snug text-ink-bright sm:text-2xl md:text-[1.7rem] md:leading-snug">
                  {storyInsight(stats)}
                </blockquote>
              </div>

              <div className="relative grid gap-6 p-5 sm:p-7 lg:grid-cols-[minmax(0,1.35fr)_minmax(0,1fr)] lg:gap-10">
                <div className="min-w-0">
                  <p className="section-title">Estimated watch time</p>
                  <p className="tnum mt-2 font-serif text-[3rem] leading-[0.95] tracking-tight text-ink-bright sm:text-6xl">
                    {formatDuration(o?.totalMins)}
                  </p>
                  {daysLine && <p className="mt-2 text-sm text-muted">{daysLine}</p>}
                  <p className="mt-3 text-sm text-ink">
                    {[
                      o?.filmCount ? `${formatCount(o.filmCount)} films` : null,
                      o?.episodeCount ? `${formatCount(o.episodeCount)} episodes` : null,
                      o?.tvShowCount ? `${formatCount(o.tvShowCount)} shows` : null,
                    ]
                      .filter(Boolean)
                      .join(' · ')}
                  </p>
                  <div className="mt-5 max-w-md">
                    <TimeSplitBar
                      filmShare={o?.filmShare}
                      tvShare={o?.tvShare}
                      filmMins={o?.filmMins}
                      tvMins={o?.tvMins}
                    />
                  </div>
                </div>

                <div className="flex min-w-0 flex-col justify-between gap-5 rounded-2xl border border-border/50 bg-canvas/40 p-4 sm:p-5">
                  <div>
                    <p className="section-title">This year so far</p>
                    <p className="tnum mt-2 font-serif text-4xl leading-none text-ink-bright">
                      {formatDuration(year?.totalMins)}
                    </p>
                    <p className="mt-2 text-sm text-muted">
                      {formatCount(year?.filmCount)} films · {formatCount(year?.episodeCount)}{' '}
                      episodes
                    </p>
                  </div>
                  <div className="flex flex-wrap items-center gap-2">
                    {delta && lastYearLabel && (
                      <span
                        className={`inline-flex items-center rounded-full px-2.5 py-1 text-[11px] font-semibold ${
                          delta.direction === 'down'
                            ? 'bg-surface-raised/80 text-muted'
                            : 'bg-accent/12 text-accent'
                        }`}
                      >
                        {delta.text} vs {lastYearLabel}
                      </span>
                    )}
                    {act?.activeDaysThisYear > 0 && (
                      <span className="inline-flex items-center rounded-full bg-link/10 px-2.5 py-1 text-[11px] font-semibold text-link">
                        {formatCount(act.activeDaysThisYear)} days logged
                      </span>
                    )}
                  </div>
                </div>
              </div>

              {quality?.filmRuntimeMissing > 0 && (
                <div className="relative px-5 pb-5 sm:px-7">
                  <RuntimeCoverageNote quality={quality} films={films} />
                </div>
              )}
            </section>

            {/* Quirks — the memorable, weird bits */}
            {quirks.length > 0 && (
              <section className="animate-soft-rise space-y-3 opacity-0 [animation-delay:60ms]">
                <div className="flex items-end justify-between gap-3">
                  <h2 className="rule-label section-title">From the margins</h2>
                  <p className="hidden text-xs text-muted sm:block">The odd details worth keeping</p>
                </div>
                <div className="stats-quirk-rail -mx-4 flex gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-2 sm:overflow-visible sm:px-0 lg:grid-cols-4">
                  {quirks.map((ticket) => (
                    <QuirkTicket key={ticket.key} ticket={ticket} />
                  ))}
                </div>
              </section>
            )}

            {/* Rhythm — interactive, fits any width */}
            <section className="animate-soft-rise opacity-0 [animation-delay:120ms]">
              <RhythmExplorer
                months={act?.monthlyTrend}
                days={act?.dailyActivity}
                streak={act?.streak}
              />
            </section>

            {/* Spotlight — titles that define the diary */}
            {(facts?.mostWatchedShow?.tvTitle || films?.longest || films?.shortest) && (
              <section className="animate-soft-rise space-y-3 opacity-0 [animation-delay:160ms]">
                <h2 className="rule-label section-title">On the marquee</h2>
                <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                  {facts?.mostWatchedShow?.tvTitle && (
                    <div className="sm:col-span-2 lg:col-span-1">
                      <SpotlightLink
                        to={`/tv/${facts.mostWatchedShow.tvId}`}
                        kicker="Most watched show"
                        title={facts.mostWatchedShow.tvTitle}
                        meta={`${formatCount(facts.mostWatchedShow.episodeCount)} episodes${
                          facts.mostWatchedShow.minutes
                            ? ` · ${formatDuration(facts.mostWatchedShow.minutes)}`
                            : ''
                        }`}
                      />
                    </div>
                  )}
                  <SpotlightLink
                    to={`/movies/${films?.longest?.movieId}`}
                    kicker="Longest film"
                    title={films?.longest?.movieTitle}
                    meta={formatDuration(films?.longest?.minutes)}
                    tone="link"
                  />
                  <SpotlightLink
                    to={`/movies/${films?.shortest?.movieId}`}
                    kicker="Shortest film"
                    title={films?.shortest?.movieTitle}
                    meta={formatDuration(films?.shortest?.minutes)}
                    tone="link"
                  />
                </div>
              </section>
            )}

            {/* Ratings — only when the user has started rating */}
            {hasRatings && (
              <section className="animate-soft-rise space-y-3 opacity-0 [animation-delay:180ms]">
                <div className="flex flex-wrap items-end justify-between gap-2">
                  <h2 className="rule-label section-title">Your ratings</h2>
                  {(ratings?.episodeCount || 0) > 0 && (
                    <p className="text-xs text-muted">
                      {formatCount(ratings.episodeCount)} episode
                      {ratings.episodeCount === 1 ? '' : 's'} rated
                    </p>
                  )}
                </div>
                <div className="grid gap-3 sm:grid-cols-2">
                  {(ratings?.films?.count || 0) > 0 && (
                    <RatingSummaryCard
                      label="Films"
                      count={ratings.films.count}
                      average={ratings.films.average}
                    />
                  )}
                  {(ratings?.shows?.count || 0) > 0 && (
                    <RatingSummaryCard
                      label="Shows"
                      count={ratings.shows.count}
                      average={ratings.shows.average}
                    />
                  )}
                </div>
                <div className="grid gap-3 sm:grid-cols-2">
                  {ratings?.films?.top?.movieId && (
                    <SpotlightLink
                      to={`/movies/${ratings.films.top.movieId}`}
                      kicker="Top-rated film"
                      title={ratings.films.top.movieTitle}
                      meta={`${ratings.films.top.rating.toFixed(1)} stars`}
                    />
                  )}
                  {ratings?.shows?.top?.tvId && (
                    <SpotlightLink
                      to={`/tv/${ratings.shows.top.tvId}`}
                      kicker="Top-rated show"
                      title={ratings.shows.top.tvTitle}
                      meta={`${ratings.shows.top.rating.toFixed(1)} stars`}
                      tone="link"
                    />
                  )}
                </div>
              </section>
            )}

            {/* Taste — compact, not a wall of charts */}
            {hasTaste && (
              <section className="animate-soft-rise space-y-3 opacity-0 [animation-delay:200ms]">
                <h2 className="rule-label section-title">Taste</h2>
                <div className="grid gap-3 lg:grid-cols-2">
                  <GenreBreakdown
                    compact
                    title="TV genres"
                    subtitle="By episodes logged"
                    items={(taste.tv?.genreByEpisodes || []).slice(0, 5)}
                  />
                  <GenreBreakdown
                    compact
                    title="Film genres"
                    subtitle="By title count"
                    items={(taste.films?.genreByCount || []).slice(0, 5)}
                  />
                </div>
                {taste.films?.decades?.length > 0 && (
                  <DecadeChart decades={taste.films.decades} />
                )}
                {stats?.metaPending && (
                  <p className="text-[11px] text-muted-dim">
                    More taste data fills in each time you refresh after logging.
                  </p>
                )}
              </section>
            )}
          </div>
        )}
      </div>
    </>
  );
}
