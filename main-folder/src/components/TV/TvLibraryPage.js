import { useLayoutEffect, useState } from 'react';
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
import useCachedResource, {
  CACHE_KEYS,
  invalidateUserTvLists,
} from '../../utils/routeCache';
import PageTitle from '../../utils/PageTitle';
import { haptic } from '../../utils/haptics';
import { confirmScrollRestore } from '../ScrollRestoration';
import BackNav from '../ui/BackNav';
import EmptyState from '../ui/EmptyState';
import TvLibraryTile from './TvLibraryTile';

const EMPTY_LIBRARY = {
  tracks: [],
  counts: { watching: 0, paused: 0, completed: 0 },
  staleAfterDays: 90,
};

async function fetchTvLibraryTab(tab) {
  const r = await api.get(`/api/tv/tracking/library/${tab}`);
  if (!r.data.success) return EMPTY_LIBRARY;
  return {
    tracks: r.data.tracks || [],
    counts: r.data.counts || EMPTY_LIBRARY.counts,
    staleAfterDays: r.data.staleAfterDays || 90,
  };
}

export default function TvLibraryPage() {
  const { tab: tabParam } = useParams();
  const tab = TV_LIBRARY_TABS[tabParam] ? tabParam : 'watching';
  const config = TV_LIBRARY_TABS[tab];
  const invalidTab = tabParam && !TV_LIBRARY_TABS[tabParam];

  const {
    data,
    loading,
    fromCache,
    refresh,
  } = useCachedResource(
    invalidTab ? null : CACHE_KEYS.tvLibrary(tab),
    () => fetchTvLibraryTab(tab),
    { ttl: 30_000, enabled: !invalidTab }
  );

  const { tracks, counts, staleAfterDays } = data || EMPTY_LIBRARY;

  const [markingId, setMarkingId] = useState(null);
  const [resumingId, setResumingId] = useState(null);

  useLayoutEffect(() => {
    if (!loading) confirmScrollRestore();
  }, [loading, tracks.length]);

  if (invalidTab) {
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

      const r = await api.post('/api/tv/episodes/mark', payload);
      if (r.data?.success) {
        haptic(r.data.tracking?.status === 'completed' ? 'success' : 'light');
      }
      invalidateUserTvLists();
      await refresh();
    } finally {
      setMarkingId(null);
    }
  };

  const resumeShow = async (track) => {
    setResumingId(track.tvId);
    try {
      await api.post('/api/tv/tracking/resume', { tvId: track.tvId });
      invalidateUserTvLists();
      await refresh();
    } finally {
      setResumingId(null);
    }
  };

  const countForTab = (key) => {
    if (key === 'watching') return counts.watching;
    if (key === 'stopped') return counts.paused;
    return counts.completed;
  };

  const showSkeleton = loading && !fromCache && tracks.length === 0;

  return (
    <>
      <PageTitle title={`TV library — ${config.title}`} />

      <div className="mx-auto max-w-content px-4 py-6 sm:px-6 md:py-10">
        <BackNav to="/home" label="Back to home" className="mb-4" />

        <header className="mb-6 md:mb-8">
          <p className="section-title text-accent">Your shows</p>
          <h1 className="page-title mt-2">TV library</h1>
          <p className="mt-2 max-w-xl text-sm text-muted">{config.description}</p>
          {tab === 'stopped' && (
            <p className="mt-2 text-sm text-muted">
              Shows with no activity for {staleAfterDays} days move here automatically. Caught-up and
              finished shows are not moved.
            </p>
          )}
        </header>

        <nav className="seg-tabs mb-6 overflow-x-auto" aria-label="Library tabs">
          {TV_LIBRARY_TAB_ORDER.map((key) => {
            const t = TV_LIBRARY_TABS[key];
            const active = key === tab;
            const count = countForTab(key);
            return (
              <Link
                key={key}
                to={tvLibraryPath(key)}
                replace
                className={`seg-tab shrink-0 gap-2 px-4 ${active ? 'seg-tab--active' : ''}`}
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

        {showSkeleton ? (
          <div
            key={`${tab}-loading`}
            className="state-enter poster-grid"
            aria-busy="true"
            aria-label="Loading TV library"
          >
            {[1, 2, 3, 4, 5, 6, 7, 8].map((i) => (
              <div key={i} className="aspect-[2/3] animate-pulse rounded-xl bg-surface-raised" />
            ))}
          </div>
        ) : tracks.length === 0 ? (
          <EmptyState
            key={`${tab}-empty`}
            icon={Tv}
            title="No shows here"
            description={config.empty}
            className="sm:p-10"
          >
            {tab === 'watching' && (
              <Link to="/tv" className="btn-primary">
                Browse TV
              </Link>
            )}
            {tab === 'stopped' && counts.watching > 0 && (
              <Link to={tvLibraryPath('watching')} className="btn-secondary">
                View watching list
              </Link>
            )}
          </EmptyState>
        ) : (
          <div key={`${tab}-grid`} className="state-enter">
            <p className="mb-4 text-sm text-muted">
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
          </div>
        )}
      </div>
    </>
  );
}
