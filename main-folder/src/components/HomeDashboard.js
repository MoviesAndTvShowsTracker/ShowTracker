import { useCallback, useLayoutEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Tv } from 'lucide-react';
import api from '../api/axios';
import { fetchTvWatchlist } from '../api/tvWatchlist';
import { clearSessionStats } from '../utils/statsCache';
import { useAuth } from '../context/AuthContext';
import { IMAGE_URL } from '../config/keys';
import { profileListPath } from '../config/profileLists';
import { tvLibraryPath } from '../config/tvLibrary';
import {
  buildMarkPayload,
  fetchShowEpisodeIndex,
  watchedSetFromEpisodes,
} from '../utils/tvProgress';
import useCachedResource, {
  CACHE_KEYS,
  invalidateUserTvLists,
} from '../utils/routeCache';
import usePullToRefresh from '../hooks/usePullToRefresh';
import PageTitle from '../utils/PageTitle';
import { displayName } from '../utils/displayUser';
import { haptic } from '../utils/haptics';
import { confirmScrollRestore } from './ScrollRestoration';
import ContinueWatchingTile from './TV/ContinueWatchingTile';
import TvTimeWelcomeBanner, {
  dismissTvTimePrompt,
  shouldShowTvTimeBanner,
} from './home/TvTimeWelcomeBanner';
import WeeklyRecapCard from './home/WeeklyRecapCard';
import PwaInstallBanner from './home/PwaInstallBanner';
import EmptyState from './ui/EmptyState';
import PosterRail from './ui/PosterRail';
import PosterTile from './ui/PosterTile';

const emptyFilm = (
  <>
    Nothing queued.{' '}
    <Link to="/movies" className="text-link hover:text-ink-bright cursor-pointer">
      Browse films
    </Link>
  </>
);

const emptyTv = (
  <>
    Nothing queued.{' '}
    <Link to="/tv" className="text-link hover:text-ink-bright cursor-pointer">
      Browse TV
    </Link>
  </>
);

const SKELETON_TILE =
  'h-[132px] w-[88px] shrink-0 animate-pulse rounded-xl bg-surface-raised sm:w-[100px]';

const EMPTY_DASHBOARD = {
  tracks: [],
  movieWatchlist: [],
  tvWatchlist: [],
  recap: null,
  watchedMovies: [],
  watchedTv: [],
  favoriteMovies: [],
  favoriteTv: [],
};

/** One call site for every home-screen fetch so cache hits are atomic. */
async function fetchDashboardSnapshot() {
  const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
  const [
    continueRes,
    movies,
    tvWatchlistItems,
    recapRes,
    watchedMovies,
    watchedTv,
    favoriteMovies,
    favoriteTv,
  ] = await Promise.all([
    api.get('/api/tv/tracking/continue').catch(() => ({ data: { success: false } })),
    api.post('/api/watchlist/getMovieWatchlist', {}).catch(() => ({ data: { success: false } })),
    fetchTvWatchlist().catch(() => []),
    api
      .get(`/api/stats/week-recap?tz=${encodeURIComponent(tz)}`)
      .catch(() => ({ data: { success: false } })),
    api.post('/api/watch/getWatchMovie', {}).catch(() => ({ data: { success: false } })),
    api.post('/api/tv/watch/getWatchTv', {}).catch(() => ({ data: { success: false } })),
    api.post('/api/favorite/getFavoriteMovie', {}).catch(() => ({ data: { success: false } })),
    api.post('/api/tv/favorite/getFavoriteMovie', {}).catch(() => ({ data: { success: false } })),
  ]);

  return {
    tracks: continueRes.data.success ? continueRes.data.tracks || [] : [],
    movieWatchlist: movies.data.success ? movies.data.watchlist || [] : [],
    tvWatchlist: tvWatchlistItems,
    recap: recapRes.data.success ? recapRes.data.recap : null,
    watchedMovies: watchedMovies.data.success ? watchedMovies.data.watch || [] : [],
    watchedTv: watchedTv.data.success ? watchedTv.data.watch || [] : [],
    favoriteMovies: favoriteMovies.data.success ? favoriteMovies.data.favorites || [] : [],
    favoriteTv: favoriteTv.data.success ? favoriteTv.data.favorites || [] : [],
  };
}

export default function HomeDashboard() {
  const { user } = useAuth();
  const {
    data,
    loading: initialLoading,
    fromCache,
    refresh,
  } = useCachedResource(user?.id ? CACHE_KEYS.home : null, fetchDashboardSnapshot, {
    ttl: 30_000,
    enabled: Boolean(user?.id),
  });

  const snapshot = data || EMPTY_DASHBOARD;
  const {
    tracks,
    movieWatchlist,
    tvWatchlist,
    recap,
    watchedMovies,
    watchedTv,
    favoriteMovies,
    favoriteTv,
  } = snapshot;

  const [markingId, setMarkingId] = useState(null);
  const [dismissedTvTime, setDismissedTvTime] = useState(false);

  const refreshAll = useCallback(async () => {
    try {
      await refresh();
    } finally {
      clearSessionStats();
    }
  }, [refresh]);

  const { indicator: pullIndicator } = usePullToRefresh(refreshAll);

  // Confirm scroll restore the moment cached content paints — the browser
  // reserves list height before the images load, so Back lands exactly where
  // the user left.
  useLayoutEffect(() => {
    if (!initialLoading) confirmScrollRestore();
  }, [initialLoading, tracks.length, movieWatchlist.length, tvWatchlist.length]);

  const dismissTvTime = () => {
    dismissTvTimePrompt(user?.id);
    setDismissedTvTime(true);
  };

  const markNextFromHome = async (track) => {
    if (!track.nextSeason || !track.nextEpisode) return;
    setMarkingId(track.tvId);
    try {
      const { show, episodes, totalEpisodes } = await fetchShowEpisodeIndex(track.tvId);
      const ep = episodes.find(
        (e) => e.seasonNumber === track.nextSeason && e.episodeNumber === track.nextEpisode
      );
      if (!ep) return;

      const watchedRes = await api.get(`/api/tv/episodes/${track.tvId}`);
      const watched = watchedRes.data.success ? watchedRes.data.episodes : [];
      const keys = watchedSetFromEpisodes(watched);

      const payload = buildMarkPayload(
        { ...show, totalEpisodes, tvId: track.tvId },
        ep,
        episodes,
        keys,
        true
      );

      const r = await api.post('/api/tv/episodes/mark', payload);
      if (r.data?.success) {
        haptic(r.data.tracking?.status === 'completed' ? 'success' : 'light');
      }
      invalidateUserTvLists();
      clearSessionStats();
      await refresh();
    } finally {
      setMarkingId(null);
    }
  };

  const greeting = user ? `Hey, ${displayName(user)}` : 'Welcome back';

  // Only block the whole page with skeletons on the very first visit of
  // the session; later visits are instant via cache.
  const loading = initialLoading && !fromCache;
  const watchlistsLoading = loading;

  const showTvTimeBanner =
    !dismissedTvTime &&
    shouldShowTvTimeBanner({
      userId: user?.id,
      tracks,
      movieWatchlist,
      tvWatchlist,
      watchedMovies,
      watchedTv,
      favoriteMovies,
      favoriteTv,
    });

  return (
    <>
      <PageTitle title="Home" />

      <div className="mx-auto max-w-content px-4 py-6 sm:px-6 md:py-10">
        {pullIndicator}

        <header className="mb-8">
          <p className="text-xs font-bold uppercase tracking-[0.15em] text-accent">Your diary</p>
          <h1 className="page-title mt-2">{greeting}</h1>
          <p className="mt-2 text-sm text-muted">Pick up where you left off.</p>
        </header>

        <PwaInstallBanner />
        <WeeklyRecapCard recap={recap} loading={loading} />
        <TvTimeWelcomeBanner visible={showTvTimeBanner} onDismiss={dismissTvTime} />

        <section aria-label="Continue watching" className="mb-10 md:mb-12">
          <div className="mb-4 flex items-end justify-between gap-3">
            <div className="min-w-0">
              <h2 className="section-title">Continue watching</h2>
              <p className="mt-1 min-h-5 text-sm text-muted">
                {!loading && tracks.length > 0
                  ? `${tracks.length} in progress · tap poster to resume, check to log episode`
                  : '\u00a0'}
              </p>
            </div>
            <Link
              to={tvLibraryPath('watching')}
              className="shrink-0 text-xs font-semibold text-link hover:text-ink-bright cursor-pointer"
            >
              View library
            </Link>
          </div>

          {loading ? (
            <div key="continue-loading" className="state-enter poster-rail">
              {[1, 2, 3, 4].map((i) => (
                <div
                  key={i}
                  className="h-[168px] w-[108px] shrink-0 animate-pulse rounded-xl bg-surface-raised sm:w-[120px]"
                />
              ))}
            </div>
          ) : tracks.length > 0 ? (
            <div key="continue-rail" className="state-enter poster-rail">
              {tracks.map((track) => (
                <ContinueWatchingTile
                  key={track.tvId}
                  track={track}
                  onMark={markNextFromHome}
                  marking={markingId === track.tvId}
                />
              ))}
            </div>
          ) : (
            <EmptyState
              icon={Tv}
              title="Nothing in progress yet"
              description="Open a TV show and mark an episode watched — tracking starts automatically."
            >
              <Link to="/tv" className="btn-primary">
                Browse TV
              </Link>
            </EmptyState>
          )}
        </section>

        <div className="space-y-10 md:space-y-12">
          <PosterRail
            title="Film watchlist"
            actionTo={profileListPath('film-watchlist')}
            actionLabel="View all"
            empty={watchlistsLoading ? null : emptyFilm}
          >
            {watchlistsLoading
              ? [1, 2, 3, 4].map((i) => <div key={i} className={SKELETON_TILE} />)
              : movieWatchlist.map((m) => (
                  <PosterTile
                    key={m.movieId}
                    to={`/movies/${m.movieId}`}
                    poster={m.moviePosterImage}
                    title={m.movieTitle}
                    imageUrlPrefix={`${IMAGE_URL}w342`}
                    size="sm"
                  />
                ))}
          </PosterRail>

          <PosterRail
            title="TV watchlist"
            actionTo={profileListPath('tv-watchlist')}
            actionLabel="View all"
            empty={watchlistsLoading ? null : emptyTv}
          >
            {watchlistsLoading
              ? [1, 2, 3, 4].map((i) => <div key={`tv-${i}`} className={SKELETON_TILE} />)
              : tvWatchlist.map((s) => (
                  <PosterTile
                    key={s.tvId}
                    to={`/tv/${s.tvId}`}
                    poster={s.tvPosterImage}
                    title={s.tvTitle}
                    imageUrlPrefix={`${IMAGE_URL}w342`}
                    size="sm"
                  />
                ))}
          </PosterRail>
        </div>
      </div>
    </>
  );
}
