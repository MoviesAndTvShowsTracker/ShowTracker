import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Tv } from 'lucide-react';
import api from '../api/axios';
import { useAuth } from '../context/AuthContext';
import { IMAGE_URL } from '../config/keys';
import { tmdbFetch, withPoster } from '../utils/tmdb';
import {
  buildMarkPayload,
  fetchShowEpisodeIndex,
  watchedSetFromEpisodes,
} from '../utils/tvProgress';
import PageTitle from '../utils/PageTitle';
import ContinueWatchingCard from './TV/ContinueWatchingCard';
import PosterRail from './ui/PosterRail';
import PosterTile from './ui/PosterTile';

export default function HomeDashboard() {
  const { user } = useAuth();
  const [tracks, setTracks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [markingId, setMarkingId] = useState(null);
  const [trendingTv, setTrendingTv] = useState([]);

  const loadTracks = useCallback(() => {
    setLoading(true);
    api
      .get('/api/tv/tracking/continue')
      .then((r) => {
        if (r.data.success) setTracks(r.data.tracks || []);
      })
      .catch(() => setTracks([]))
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    loadTracks();
    tmdbFetch('trending/tv/week').then((d) => setTrendingTv(withPoster(d.results).slice(0, 12)));
  }, [loadTracks]);

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
      loadTracks();
    } finally {
      setMarkingId(null);
    }
  };

  const greeting = user?.username ? `Hey, ${user.username}` : 'Welcome back';

  return (
    <>
      <PageTitle title="Home" />

      <div className="mx-auto max-w-content px-4 py-6 sm:px-6 md:py-10">
        <header className="mb-8">
          <p className="text-xs font-bold uppercase tracking-[0.15em] text-accent">Your diary</p>
          <h1 className="page-title mt-2">{greeting}</h1>
          <p className="mt-2 text-sm text-muted">Pick up where you left off.</p>
        </header>

        <section aria-label="Continue watching" className="mb-10 md:mb-12">
          <h2 className="section-title mb-4">Continue watching</h2>

          {loading ? (
            <div className="space-y-3">
              {[1, 2].map((i) => (
                <div key={i} className="h-32 animate-pulse rounded-2xl bg-surface-raised" />
              ))}
            </div>
          ) : tracks.length > 0 ? (
            <div className="space-y-3">
              {tracks.map((track) => (
                <ContinueWatchingCard
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

        <PosterRail title="Trending TV" actionTo="/tv" actionLabel="All TV">
          {trendingTv.map((s) => (
            <PosterTile
              key={s.id}
              to={`/tv/${s.id}`}
              poster={s.poster_path}
              title={s.name}
              imageUrlPrefix={`${IMAGE_URL}w342`}
              size="sm"
            />
          ))}
        </PosterRail>
      </div>
    </>
  );
}
