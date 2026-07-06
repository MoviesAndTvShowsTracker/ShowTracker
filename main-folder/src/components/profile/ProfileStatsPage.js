import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  Award,
  Clapperboard,
  Clock,
  Film,
  Flame,
  Layers,
  PauseCircle,
  PlayCircle,
  RefreshCw,
  Star,
  Timer,
  TrendingUp,
  Tv,
} from 'lucide-react';
import api from '../../api/axios';
import { tvLibraryPath } from '../../config/tvLibrary';
import {
  formatCount,
  formatDuration,
  formatMemberSince,
  formatShortDate,
} from '../../utils/statsFormat';
import { readSessionStats, writeSessionStats } from '../../utils/statsCache';
import PageTitle from '../../utils/PageTitle';
import BackNav from '../ui/BackNav';
import WeeklyTrendChart from './stats/WeeklyTrendChart';
import GenreBreakdown from './stats/GenreBreakdown';
import DecadeChart from './stats/DecadeChart';

function Section({ title, description, children, action }) {
  return (
    <section className="glass-card overflow-hidden !p-0">
      <div className="flex items-start justify-between gap-3 border-b border-border/60 px-3 py-3 sm:px-5 sm:py-4">
        <div className="min-w-0">
          <h2 className="section-title text-base sm:text-lg">{title}</h2>
          {description && (
            <p className="mt-1 text-xs text-muted sm:text-sm">{description}</p>
          )}
        </div>
        {action}
      </div>
      <div className="space-y-3 p-3 sm:space-y-4 sm:p-5">{children}</div>
    </section>
  );
}

/** Letterboxd-style dense stat cell — works in 3-up grids on mobile */
function StatCell({ label, value, sub, icon: Icon }) {
  return (
    <div className="rounded-lg border border-border/45 bg-surface-raised/30 px-2 py-2 text-center sm:rounded-xl sm:px-2.5 sm:py-2.5">
      {Icon && (
        <Icon className="mx-auto mb-0.5 h-3 w-3 text-accent/80 sm:mb-1 sm:h-3.5 sm:w-3.5" aria-hidden />
      )}
      <p className="text-[10px] font-bold uppercase tracking-wider text-muted sm:text-[11px]">
        {label}
      </p>
      <p className="mt-0.5 font-serif text-base leading-none text-ink-bright sm:text-lg">{value}</p>
      {sub && (
        <p className="mt-0.5 line-clamp-1 text-[10px] leading-snug text-muted-dim sm:line-clamp-2 sm:text-xs">
          {sub}
        </p>
      )}
    </div>
  );
}

function StatStrip({ items, className = 'grid-cols-2 sm:grid-cols-3 lg:grid-cols-6' }) {
  return (
    <div className={`grid gap-1.5 sm:gap-2 ${className}`}>
      {items.map((item) => (
        <StatCell key={item.label} {...item} />
      ))}
    </div>
  );
}

function TimeSplitBar({ filmShare, tvShare, filmMins, tvMins }) {
  if (!filmShare && !tvShare) {
    return <p className="text-xs text-muted sm:text-sm">Log episodes or films to see your split.</p>;
  }
  return (
    <div className="rounded-xl border border-border/30 bg-canvas/40 p-3 sm:p-4">
      <p className="text-[9px] font-bold uppercase tracking-widest text-muted">Film vs TV</p>
      <div className="mt-2 flex h-2.5 overflow-hidden rounded-full bg-surface-raised sm:mt-3 sm:h-3">
        {filmShare > 0 && <div className="bg-link/80" style={{ width: `${filmShare}%` }} />}
        {tvShare > 0 && <div className="bg-accent" style={{ width: `${tvShare}%` }} />}
      </div>
      <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-[11px] text-muted sm:text-xs">
        <span className="flex items-center gap-1.5">
          <span className="h-2 w-2 rounded-full bg-link/80" />
          Films {filmShare}% · {formatDuration(filmMins)}
        </span>
        <span className="flex items-center gap-1.5">
          <span className="h-2 w-2 rounded-full bg-accent" />
          TV {tvShare}% · {formatDuration(tvMins)}
        </span>
      </div>
    </div>
  );
}

function FilmHighlight({ film, label }) {
  if (!film) return null;
  return (
    <Link
      to={`/movies/${film.movieId}`}
      className="block rounded-xl border border-border/40 bg-surface-raised/25 p-3 transition-colors hover:border-link/40 cursor-pointer sm:p-4"
    >
      <p className="text-[9px] font-bold uppercase tracking-widest text-muted">{label}</p>
      <p className="mt-1.5 line-clamp-2 font-serif text-base leading-snug text-ink-bright sm:text-lg">
        {film.movieTitle}
      </p>
      <p className="mt-0.5 text-xs font-medium text-link sm:text-sm">{formatDuration(film.minutes)}</p>
    </Link>
  );
}

export default function ProfileStatsPage() {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState('');
  const [fromCache, setFromCache] = useState(false);

  const loadStats = useCallback((force = false) => {
    const controller = new AbortController();
    const url = force ? '/api/stats/dashboard?refresh=1' : '/api/stats/dashboard';
    let hasLocalData = false;

    if (!force) {
      const session = readSessionStats();
      if (session?.stats) {
        hasLocalData = true;
        setStats(session.stats);
        setFromCache(true);
        setLoading(false);
      } else {
        setLoading(true);
      }
    } else {
      setRefreshing(true);
    }

    api
      .get(url, { signal: controller.signal, timeout: 90000 })
      .then((r) => {
        if (r.data.success) {
          setStats(r.data.stats);
          writeSessionStats(r.data.stats, r.data.builtAt);
          setFromCache(Boolean(r.data.cached));
          setError('');
        } else if (!hasLocalData) {
          setError('Could not load stats.');
        }
      })
      .catch((err) => {
        if (err.code === 'ERR_CANCELED') return;
        if (!hasLocalData) {
          setError(
            err.code === 'ECONNABORTED'
              ? 'Stats took too long — tap refresh to try again.'
              : 'Could not load stats.'
          );
        }
      })
      .finally(() => {
        setLoading(false);
        setRefreshing(false);
      });

    return () => controller.abort();
  }, []);

  useEffect(() => {
    const cleanup = loadStats(false);
    return cleanup;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const o = stats?.overview;
  const lib = stats?.library;
  const act = stats?.activity;
  const films = stats?.films;
  const taste = stats?.taste;

  const tvActivityCells = [
    {
      label: 'This week',
      value: formatCount(act?.episodesThisWeek),
      sub: formatDuration(act?.tvMinsThisWeek),
      icon: TrendingUp,
    },
    {
      label: 'Month',
      value: formatCount(act?.episodesThisMonth),
      sub: formatDuration(act?.tvMinsThisMonth),
    },
    {
      label: 'Year',
      value: formatCount(act?.episodesThisYear),
      sub: 'episodes',
    },
    {
      label: 'TV time',
      value: formatDuration(o?.tvMins),
      sub: 'all time',
      icon: Clock,
    },
    {
      label: 'Last',
      value: act?.lastWatchedAt ? formatShortDate(act.lastWatchedAt).split(',')[0] : '—',
      sub: 'watched',
    },
    ...(act?.busiestDay
      ? [
          {
            label: 'Top day',
            value: act.busiestDay.day.slice(0, 3),
            sub: `${formatCount(act.busiestDay.count)} eps`,
          },
        ]
      : []),
  ];

  const libraryCells = [
    { label: 'Watching', value: formatCount(lib?.watching), icon: PlayCircle },
    { label: 'Stopped', value: formatCount(lib?.stopped), icon: PauseCircle },
    { label: 'Finished', value: formatCount(lib?.finished), icon: Award },
    { label: 'Backlog', value: formatCount(lib?.backlog), icon: Layers },
    { label: 'Caught up', value: formatCount(lib?.caughtUp), icon: Timer },
  ];

  return (
    <>
      <PageTitle title="Your stats" />

      <div className="mx-auto max-w-content px-3 py-5 sm:px-6 sm:py-8 md:py-10">
        <div className="mb-4 flex items-center justify-between gap-3">
          <BackNav to="/profile" label="Back to profile" />
          {stats && (
            <button
              type="button"
              disabled={refreshing}
              onClick={() => loadStats(true)}
              className="inline-flex min-h-[44px] items-center gap-1.5 rounded-lg px-2 text-xs font-semibold text-link hover:text-ink-bright disabled:opacity-50 cursor-pointer"
            >
              <RefreshCw className={`h-3.5 w-3.5 ${refreshing ? 'animate-spin' : ''}`} />
              Refresh
            </button>
          )}
        </div>

        <header className="mb-6 sm:mb-8">
          <p className="text-xs font-bold uppercase tracking-[0.15em] text-accent">Your diary</p>
          <h1 className="page-title mt-1.5 text-2xl sm:mt-2 sm:text-3xl">Stats</h1>
          <div className="mt-1.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-muted">
            {stats?.memberSince && <span>Member since {formatMemberSince(stats.memberSince)}</span>}
            {fromCache && stats && !refreshing && (
              <span className="text-muted-dim">· Saved snapshot</span>
            )}
          </div>
        </header>

        {loading && !stats ? (
          <div className="space-y-4">
            <div className="glass-card p-6 text-center">
              <p className="text-sm font-medium text-ink-bright">Crunching your stats…</p>
              <p className="mt-1.5 text-sm text-muted">First load can take a moment.</p>
            </div>
            <div className="h-36 animate-pulse rounded-2xl bg-surface-raised" />
          </div>
        ) : error && !stats ? (
          <div className="glass-card p-8 text-center">
            <p className="text-sm text-muted">{error}</p>
            <button type="button" onClick={() => loadStats(true)} className="btn-primary mt-4">
              Try again
            </button>
          </div>
        ) : (
          <div className="space-y-4 sm:space-y-6">
            <section className="glass-card overflow-hidden bg-gradient-to-br from-accent/10 via-surface to-surface p-4 sm:p-6">
              <div className="lg:grid lg:grid-cols-2 lg:gap-6 lg:items-end">
                <div>
                  <p className="text-[9px] font-bold uppercase tracking-widest text-accent sm:text-[10px]">
                    Total screen time
                  </p>
                  <p className="mt-2 font-serif text-3xl text-ink-bright sm:text-4xl lg:text-5xl">
                    {formatDuration(o?.totalMins)}
                  </p>
                  <div className="mt-4 grid grid-cols-4 gap-1.5 sm:gap-2">
                    <StatCell label="Eps" value={formatCount(o?.episodeCount)} />
                    <StatCell label="Shows" value={formatCount(o?.tvShowCount)} />
                    <StatCell label="Films" value={formatCount(o?.filmCount)} />
                    <StatCell
                      label="Streak"
                      value={act?.streak ? `${act.streak}d` : '—'}
                      sub={act?.streak ? 'days' : undefined}
                    />
                  </div>
                </div>
                <TimeSplitBar
                  filmShare={o?.filmShare}
                  tvShare={o?.tvShare}
                  filmMins={o?.filmMins}
                  tvMins={o?.tvMins}
                />
              </div>
            </section>

            <Section
              title="TV"
              description="Activity & library"
              action={
                <Link
                  to={tvLibraryPath('watching')}
                  className="shrink-0 text-xs font-semibold text-link hover:text-ink-bright cursor-pointer"
                >
                  Library
                </Link>
              }
            >
              <StatStrip items={tvActivityCells} className="grid-cols-2 sm:grid-cols-3 lg:grid-cols-6" />
              <div className="grid gap-3 lg:grid-cols-2 lg:items-start">
                <WeeklyTrendChart data={act?.weeklyTrend} weeksToShow={8} />
                <div className="space-y-2">
                  <p className="text-[10px] font-bold uppercase tracking-widest text-muted">Library</p>
                  <StatStrip items={libraryCells} className="grid-cols-2 sm:grid-cols-3 lg:grid-cols-5" />
                </div>
              </div>
            </Section>

            <Section title="Films">
              {films?.count > 0 && films?.withRuntime < films?.count && (
                <p className="-mt-1 rounded-lg border border-border/40 bg-surface-raised/30 px-3 py-2 text-[11px] text-muted">
                  Runtime for {films.withRuntime}/{films.count} films
                  {films.runtimeBackfilled > 0 ? ` · ${films.runtimeBackfilled} updated` : ''}
                </p>
              )}
              <StatStrip
                className="grid-cols-2 sm:grid-cols-3 lg:grid-cols-6"
                items={[
                  { label: 'Total', value: formatCount(films?.count), icon: Film },
                  {
                    label: 'Time',
                    value: formatDuration(films?.filmMins),
                    sub: `${films?.shareOfScreenTime || 0}% split`,
                    icon: Clock,
                  },
                  {
                    label: 'Year',
                    value: formatCount(films?.thisYear),
                    sub: formatDuration(films?.filmMinsThisYear),
                  },
                  {
                    label: 'Month',
                    value: formatCount(films?.thisMonth),
                    sub: formatDuration(films?.filmMinsThisMonth),
                  },
                  {
                    label: 'Week',
                    value: formatCount(films?.thisWeek),
                    sub: formatDuration(films?.filmMinsThisWeek),
                  },
                  {
                    label: 'Avg',
                    value: films?.avgRuntime ? formatDuration(films.avgRuntime) : '—',
                    sub: 'per film',
                  },
                ]}
              />
              <div className="grid gap-3 lg:grid-cols-2">
                <WeeklyTrendChart
                  data={films?.weeklyTrend}
                  countLabel="Films"
                  weeksToShow={8}
                  emptyMessage="No films in the last 8 weeks."
                />
                {(films?.longest || films?.shortest) && (
                  <div className="grid grid-cols-2 gap-2">
                    <FilmHighlight film={films.longest} label="Longest" />
                    <FilmHighlight film={films.shortest} label="Shortest" />
                  </div>
                )}
              </div>
            </Section>

            {taste?.available &&
              (taste.tv?.genreByEpisodes?.length > 0 ||
                taste.films?.genreByCount?.length > 0 ||
                taste.films?.decades?.length > 0) && (
                <Section title="Your taste" description="Genres & eras">
                  {stats?.metaPending && (
                    <p className="-mt-1 rounded-lg border border-border/40 bg-surface-raised/30 px-3 py-2 text-[11px] text-muted">
                      More taste data fills in when you refresh after logging activity.
                    </p>
                  )}
                  {(taste.tv?.avgRating > 0 || taste.films?.avgRating > 0) && (
                    <div className="grid grid-cols-2 gap-1.5 lg:max-w-md">
                      {taste.tv?.avgRating > 0 && (
                        <StatCell
                          label="TV score"
                          value={`${taste.tv.avgRating}`}
                          sub="/ 10 TMDB"
                          icon={Star}
                        />
                      )}
                      {taste.films?.avgRating > 0 && (
                        <StatCell
                          label="Film score"
                          value={`${taste.films.avgRating}`}
                          sub="/ 10 TMDB"
                          icon={Star}
                        />
                      )}
                    </div>
                  )}
                  <div className="grid gap-3 lg:grid-cols-2">
                    <GenreBreakdown
                      compact
                      title="TV genres"
                      subtitle="By episodes"
                      items={taste.tv?.genreByEpisodes}
                    />
                    <GenreBreakdown
                      compact
                      title="Film genres"
                      subtitle="By count"
                      items={taste.films?.genreByCount}
                    />
                    <GenreBreakdown
                      compact
                      title="Film genres"
                      subtitle="By watch time"
                      items={taste.films?.genreByTime}
                    />
                    <DecadeChart decades={taste.films?.decades} />
                  </div>
                </Section>
              )}

            {(stats?.funFacts?.biggestBinge || stats?.milestones?.length > 0) && (
              <Section title="Highlights">
                <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                  {stats.funFacts?.biggestBinge?.count > 1 && (
                    <p className="flex items-start gap-2 rounded-lg border border-border/40 bg-surface-raised/25 px-3 py-2 text-[11px] text-muted sm:text-xs">
                      <Flame className="mt-0.5 h-3.5 w-3.5 shrink-0 text-accent" />
                      <span>
                        Biggest binge:{' '}
                        <span className="font-medium text-ink">
                          {stats.funFacts.biggestBinge.count} eps ·{' '}
                          {formatShortDate(stats.funFacts.biggestBinge.date)}
                        </span>
                      </span>
                    </p>
                  )}
                  {stats.funFacts?.avgEpisodeMins > 0 && (
                    <p className="flex items-start gap-2 rounded-lg border border-border/40 bg-surface-raised/25 px-3 py-2 text-[11px] text-muted sm:text-xs">
                      <Tv className="mt-0.5 h-3.5 w-3.5 shrink-0 text-accent" />
                      Avg episode:{' '}
                      <span className="font-medium text-ink">{stats.funFacts.avgEpisodeMins} min</span>
                    </p>
                  )}
                </div>
                {stats.milestones?.length > 0 && (
                  <div className="grid grid-cols-2 gap-1.5 sm:grid-cols-3 lg:grid-cols-4">
                    {stats.milestones.map((m) => (
                      <span
                        key={m.key}
                        className="inline-flex items-center gap-1.5 rounded-lg border border-accent/30 bg-accent/10 px-2.5 py-1.5 text-[10px] font-medium leading-snug text-accent sm:text-[11px]"
                      >
                        <Award className="h-3 w-3 shrink-0" />
                        {m.label}
                      </span>
                    ))}
                  </div>
                )}
              </Section>
            )}

            {!o?.episodeCount && !o?.filmCount && (
              <div className="glass-card p-8 text-center">
                <Clapperboard className="mx-auto h-8 w-8 text-accent/70" />
                <p className="mt-3 font-serif text-lg text-ink-bright">Stats appear as you log</p>
                <Link to="/tv" className="btn-primary mt-4 inline-flex">
                  Browse TV
                </Link>
              </div>
            )}
          </div>
        )}
      </div>
    </>
  );
}
