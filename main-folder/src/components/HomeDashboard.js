import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Tv } from 'lucide-react';
import api from '../api/axios';
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
import usePullToRefresh from '../hooks/usePullToRefresh';
import PageTitle from '../utils/PageTitle';
import { displayName } from '../utils/displayUser';
import ContinueWatchingTile from './TV/ContinueWatchingTile';
import TvTimeWelcomeBanner, {
  dismissTvTimePrompt,
  shouldShowTvTimeBanner,
} from './home/TvTimeWelcomeBanner';
import WeeklyRecapCard from './home/WeeklyRecapCard';
import PwaInstallBanner from './home/PwaInstallBanner';
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

const SKELETON_TILE = 'h-[132px] w-[88px] shrink-0 animate-pulse rounded-xl bg-surface-raised sm:w-[100px]';

export default function HomeDashboard() {
  const { user } = useAuth();
  const [tracks, setTracks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [markingId, setMarkingId] = useState(null);
  const [movieWatchlist, setMovieWatchlist] = useState([]);
  const [tvWatchlist, setTvWatchlist] = useState([]);
  const [watchlistsLoading, setWatchlistsLoading] = useState(true);
  const [recap, setRecap] = useState(null);
  const [recapLoading, setRecapLoading] = useState(true);
  const [showTvTimeBanner, setShowTvTimeBanner] = useState(false);

  const refreshAll = useCallback(async () => {
    setLoading(true);
    setWatchlistsLoading(true);
    setRecapLoading(true);
    try {
      const [
        continueRes,
        movies,
        tv,
        recapRes,
        watchedMovies,
        watchedTv,
        favoriteMovies,
        favoriteTv,
      ] = await Promise.all([
        api.get('/api/tv/tracking/continue').catch(() => ({ data: { success: false } })),
        api.post('/api/watchlist/getMovieWatchlist', {}).catch(() => ({ data: { success: false } })),
        api.post('/api/tv/watchlist/getTvWatchlist', {}).catch(() => ({ data: { success: false } })),
        api.get('/api/stats/week-recap').catch(() => ({ data: { success: false } })),
        api.post('/api/watch/getWatchMovie', {}).catch(() => ({ data: { success: false } })),
        api.post('/api/tv/watch/getWatchTv', {}).catch(() => ({ data: { success: false } })),
        api.post('/api/favorite/getFavoriteMovie', {}).catch(() => ({ data: { success: false } })),
        api.post('/api/tv/favorite/getFavoriteMovie', {}).catch(() => ({ data: { success: false } })),
      ]);

      const nextTracks = continueRes.data.success ? continueRes.data.tracks || [] : [];
      const nextMovieWatchlist = movies.data.success ? movies.data.watchlist || [] : [];
      const nextTvWatchlist = tv.data.success ? tv.data.watchlist || [] : [];
      const nextWatchedMovies = watchedMovies.data.success ? watchedMovies.data.watch || [] : [];
      const nextWatchedTv = watchedTv.data.success ? watchedTv.data.watch || [] : [];
      const nextFavoriteMovies = favoriteMovies.data.success ? favoriteMovies.data.favorites || [] : [];
      const nextFavoriteTv = favoriteTv.data.success ? favoriteTv.data.favorites || [] : [];

      setTracks(nextTracks);
      setMovieWatchlist(nextMovieWatchlist);
      setTvWatchlist(nextTvWatchlist);
      setRecap(recapRes.data.success ? recapRes.data.recap : null);
      setShowTvTimeBanner(
        shouldShowTvTimeBanner({
          userId: user?.id,
          tracks: nextTracks,
          movieWatchlist: nextMovieWatchlist,
          tvWatchlist: nextTvWatchlist,
          watchedMovies: nextWatchedMovies,
          watchedTv: nextWatchedTv,
          favoriteMovies: nextFavoriteMovies,
          favoriteTv: nextFavoriteTv,
        })
      );
      clearSessionStats();
    } finally {
      setLoading(false);
      setWatchlistsLoading(false);
      setRecapLoading(false);
    }
  }, [user?.id]);

  const { indicator: pullIndicator } = usePullToRefresh(refreshAll);

  useEffect(() => {
    refreshAll();
  }, [refreshAll]);

  const dismissTvTime = () => {
    dismissTvTimePrompt(user?.id);
    setShowTvTimeBanner(false);
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

      await api.post('/api/tv/episodes/mark', payload);
      await refreshAll();
    } finally {
      setMarkingId(null);
    }
  };

  const greeting = user ? `Hey, ${displayName(user)}` : 'Welcome back';

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
        <WeeklyRecapCard recap={recap} loading={recapLoading} />
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
            <div className="poster-rail">
              {[1, 2, 3, 4].map((i) => (
                <div
                  key={i}
                  className="h-[168px] w-[108px] shrink-0 animate-pulse rounded-xl bg-surface-raised sm:w-[120px]"
                />
              ))}
            </div>
          ) : tracks.length > 0 ? (
            <div className="poster-rail">
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
            <div className="glass-card p-6 text-center sm:p-8">
              <Tv className="mx-auto h-8 w-8 text-accent/70" />
              <p className="mt-3 font-serif text-lg text-ink-bright">Nothing in progress yet</p>
              <p className="mt-2 text-sm text-muted">
                Open a TV show and mark an episode watched — tracking starts automatically.
              </p>
              <Link to="/tv" className="btn-primary mt-5 inline-flex">
                Browse TV
              </Link>
            </div>
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
