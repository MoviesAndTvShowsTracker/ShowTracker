import { useCallback, useEffect, useState } from 'react';
import { Link, Navigate, useParams } from 'react-router-dom';
import { Tv } from 'lucide-react';
import api from '../../api/axios';
import {
  TV_LIBRARY_TABS,
  TV_LIBRARY_TAB_ORDER,
  tvLibraryPath,
} from '../../config/tvLibrary';
import {
  buildMarkPayload,
  fetchShowEpisodeIndex,
  watchedSetFromEpisodes,
} from '../../utils/tvProgress';
import PageTitle from '../../utils/PageTitle';
import BackNav from '../ui/BackNav';
import TvLibraryTile from './TvLibraryTile';

export default function TvLibraryPage() {
  const { tab: tabParam } = useParams();
  const tab = TV_LIBRARY_TABS[tabParam] ? tabParam : 'watching';
  const config = TV_LIBRARY_TABS[tab];

  const [tracks, setTracks] = useState([]);
  const [counts, setCounts] = useState({ watching: 0, paused: 0, completed: 0 });
  const [staleAfterDays, setStaleAfterDays] = useState(90);
  const [loading, setLoading] = useState(true);
  const [markingId, setMarkingId] = useState(null);
  const [resumingId, setResumingId] = useState(null);

  const load = useCallback(() => {
    setLoading(true);
    api
      .get(`/api/tv/tracking/library/${tab}`)
      .then((r) => {
        if (r.data.success) {
          setTracks(r.data.tracks || []);
          setCounts(r.data.counts || { watching: 0, paused: 0, completed: 0 });
          setStaleAfterDays(r.data.staleAfterDays || 90);
        }
      })
      .catch(() => setTracks([]))
      .finally(() => setLoading(false));
  }, [tab]);

  useEffect(() => {
    if (tabParam && !TV_LIBRARY_TABS[tabParam]) return;
    load();
    window.scrollTo(0, 0);
  }, [tabParam, tab, load]);

  if (tabParam && !TV_LIBRARY_TABS[tabParam]) {
    return <Navigate to={tvLibraryPath('watching')} replace />;
  }

  const markNext = async (track) => {
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
      load();
    } finally {
      setMarkingId(null);
    }
  };

  const resumeShow = async (track) => {
    setResumingId(track.tvId);
    try {
      await api.post('/api/tv/tracking/resume', { tvId: track.tvId });
      load();
    } finally {
      setResumingId(null);
    }
  };

  const countForTab = (key) => {
    if (key === 'watching') return counts.watching;
    if (key === 'stopped') return counts.paused;
    return counts.completed;
  };

  return (
    <>
      <PageTitle title={`TV library — ${config.title}`} />

      <div className="mx-auto max-w-content px-4 py-6 sm:px-6 md:py-10">
        <BackNav to="/home" label="Back to home" className="mb-4" />

        <header className="mb-6 md:mb-8">
          <p className="text-xs font-bold uppercase tracking-[0.15em] text-accent">Your shows</p>
          <h1 className="page-title mt-2">TV library</h1>
          <p className="mt-2 max-w-xl text-sm text-muted">{config.description}</p>
          {tab === 'stopped' && (
            <p className="mt-2 text-xs text-muted">
              Shows with no activity for {staleAfterDays} days move here automatically. Caught-up and
              finished shows are not moved.
            </p>
          )}
        </header>

        <nav
          className="mb-6 flex gap-1 overflow-x-auto rounded-xl border border-border bg-surface/60 p-1"
          aria-label="Library tabs"
        >
          {TV_LIBRARY_TAB_ORDER.map((key) => {
            const t = TV_LIBRARY_TABS[key];
            const active = key === tab;
            const count = countForTab(key);
            return (
              <Link
                key={key}
                to={tvLibraryPath(key)}
                replace
                className={`flex min-h-[44px] shrink-0 items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium transition-colors cursor-pointer ${
                  active
                    ? 'bg-accent text-on-accent shadow-sm'
                    : 'text-muted hover:text-ink-bright'
                }`}
                aria-current={active ? 'page' : undefined}
              >
                {t.title}
                <span
                  className={`rounded-full px-2 py-0.5 text-[10px] font-bold ${
                    active ? 'bg-canvas/20 text-on-accent' : 'bg-surface-raised text-muted'
                  }`}
                >
                  {count}
                </span>
              </Link>
            );
          })}
        </nav>

        {loading ? (
          <div className="poster-grid">
            {[1, 2, 3, 4, 5, 6, 7, 8].map((i) => (
              <div key={i} className="aspect-[2/3] animate-pulse rounded-xl bg-surface-raised" />
            ))}
          </div>
        ) : tracks.length === 0 ? (
          <div className="glass-card p-8 text-center sm:p-10">
            <Tv className="mx-auto h-8 w-8 text-accent/70" />
            <p className="mt-3 font-serif text-lg text-ink-bright">No shows here</p>
            <p className="mt-2 text-sm text-muted">{config.empty}</p>
            {tab === 'watching' && (
              <Link to="/tv" className="btn-primary mt-5 inline-flex">
                Browse TV
              </Link>
            )}
            {tab === 'stopped' && counts.watching > 0 && (
              <Link to={tvLibraryPath('watching')} className="btn-secondary mt-5 inline-flex">
                View watching list
              </Link>
            )}
          </div>
        ) : (
          <>
            <p className="mb-4 text-xs text-muted">
              {tracks.length} {tracks.length === 1 ? 'show' : 'shows'}
              {tab === 'watching' && ' · tap check to log next episode'}
            </p>
            <div className="poster-grid">
              {tracks.map((track) => (
                <TvLibraryTile
                  key={track.tvId}
                  track={track}
                  tab={tab}
                  onMark={tab === 'watching' ? markNext : undefined}
                  onResume={tab === 'stopped' ? resumeShow : undefined}
                  marking={markingId === track.tvId}
                  resuming={resumingId === track.tvId}
                />
              ))}
            </div>
          </>
        )}
      </div>
    </>
  );
}
