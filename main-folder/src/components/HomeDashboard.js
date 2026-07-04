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
import TvTimeWelcomeBanner from './home/TvTimeWelcomeBanner';
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

export default function HomeDashboard() {
  const { user } = useAuth();
  const [tracks, setTracks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [markingId, setMarkingId] = useState(null);
  const [movieWatchlist, setMovieWatchlist] = useState([]);
  const [tvWatchlist, setTvWatchlist] = useState([]);
  const [watchlistsLoading, setWatchlistsLoading] = useState(true);
  const [refreshKey, setRefreshKey] = useState(0);

  const refreshAll = useCallback(async () => {
    setLoading(true);
    setWatchlistsLoading(true);
    try {
      const [continueRes, movies, tv] = await Promise.all([
        api.get('/api/tv/tracking/continue').catch(() => ({ data: { success: false } })),
        api.post('/api/watchlist/getMovieWatchlist', {}).catch(() => ({ data: { success: false } })),
        api.post('/api/tv/watchlist/getTvWatchlist', {}).catch(() => ({ data: { success: false } })),
      ]);
      if (continueRes.data.success) setTracks(continueRes.data.tracks || []);
      else setTracks([]);
      if (movies.data.success) setMovieWatchlist(movies.data.watchlist || []);
      if (tv.data.success) setTvWatchlist(tv.data.watchlist || []);
      clearSessionStats();
      setRefreshKey((k) => k + 1);
    } finally {
      setLoading(false);
      setWatchlistsLoading(false);
    }
  }, []);

  const { indicator: pullIndicator } = usePullToRefresh(refreshAll);

  useEffect(() => {
    refreshAll();
  }, [refreshAll]);

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
        <WeeklyRecapCard refreshKey={refreshKey} />

        <TvTimeWelcomeBanner />

        <section aria-label="Continue watching" className="mb-10 md:mb-12">
          <div className="mb-4 flex items-end justify-between gap-3">
            <div>
              <h2 className="section-title">Continue watching</h2>
              {!loading && tracks.length > 0 && (
                <p className="mt-1 text-xs text-muted">
                  {tracks.length} in progress · tap poster to resume, check to log episode
                </p>
              )}
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
                  className="h-[180px] w-[108px] shrink-0 animate-pulse rounded-xl bg-surface-raised sm:w-[120px]"
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
            actionTo={movieWatchlist.length ? profileListPath('film-watchlist') : undefined}
            actionLabel="View all"
            empty={watchlistsLoading ? null : emptyFilm}
          >
            {watchlistsLoading
              ? [1, 2, 3, 4].map((i) => (
                  <div
                    key={i}
                    className="h-[132px] w-[88px] shrink-0 animate-pulse rounded-xl bg-surface-raised sm:w-[100px]"
                  />
                ))
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
            actionTo={tvWatchlist.length ? profileListPath('tv-watchlist') : undefined}
            actionLabel="View all"
            empty={watchlistsLoading ? null : emptyTv}
          >
            {watchlistsLoading
              ? [1, 2, 3, 4].map((i) => (
                  <div
                    key={`tv-${i}`}
                    className="h-[132px] w-[88px] shrink-0 animate-pulse rounded-xl bg-surface-raised sm:w-[100px]"
                  />
                ))
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
