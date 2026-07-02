import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { Check, ChevronRight, List } from 'lucide-react';
import api from '../../api/axios';
import { IMAGE_URL } from '../../config/keys';
import {
  buildMarkPayload,
  fetchShowEpisodeIndex,
  progressPercent,
  watchedSetFromEpisodes,
} from '../../utils/tvProgress';
import PageTitle from '../../utils/PageTitle';
import BackNav from '../ui/BackNav';

export default function TvContinue() {
  const { Id: tvShowId } = useParams();
  const [track, setTrack] = useState(null);
  const [showMeta, setShowMeta] = useState(null);
  const [episodeIndex, setEpisodeIndex] = useState([]);
  const [watched, setWatched] = useState([]);
  const [loading, setLoading] = useState(true);
  const [marking, setMarking] = useState(false);

  const load = () => {
    setLoading(true);
    Promise.all([
      api.get(`/api/tv/tracking/show/${tvShowId}`),
      api.get(`/api/tv/episodes/${tvShowId}`),
      fetchShowEpisodeIndex(tvShowId),
    ])
      .then(([trackRes, epRes, index]) => {
        if (trackRes.data.success) setTrack(trackRes.data.tracking);
        if (epRes.data.success) setWatched(epRes.data.episodes || []);
        setShowMeta(index.show);
        setEpisodeIndex(index.episodes);
      })
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    load();
    window.scrollTo(0, 0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tvShowId]);

  const watchedKeys = watchedSetFromEpisodes(watched);
  const nextEp =
    track?.nextSeason && track?.nextEpisode
      ? episodeIndex.find(
          (e) => e.seasonNumber === track.nextSeason && e.episodeNumber === track.nextEpisode
        )
      : null;

  const pct = progressPercent(track?.watchedEpisodeCount || 0, track?.totalEpisodes || 0);
  const isComplete = track?.status === 'completed' || pct >= 100;

  const markNext = async () => {
    if (!nextEp || !showMeta) return;
    setMarking(true);
    try {
      const payload = buildMarkPayload(
        { ...showMeta, totalEpisodes: track?.totalEpisodes },
        nextEp,
        episodeIndex,
        watchedKeys,
        true
      );
      const r = await api.post('/api/tv/episodes/mark', payload);
      if (r.data.success) {
        setTrack(r.data.tracking);
        setWatched(r.data.episodes || []);
      }
    } finally {
      setMarking(false);
    }
  };

  if (loading) {
    return (
      <div className="mx-auto max-w-content px-4 py-10">
        <div className="h-48 animate-pulse rounded-2xl bg-surface-raised" />
      </div>
    );
  }

  return (
    <>
      <PageTitle title={showMeta?.name ? `Continue — ${showMeta.name}` : 'Continue watching'} />

      <div className="mx-auto max-w-content px-4 py-5 sm:px-6 md:py-8">
        <BackNav fallback="/home" label="Back to home" className="mb-4" />

        <div className="glass-card overflow-hidden">
          {showMeta?.backdrop_path && (
            <div
              className="h-32 bg-cover bg-center sm:h-40"
              style={{
                backgroundImage: `linear-gradient(to top, rgb(var(--surface)), transparent), url(${IMAGE_URL}w780${showMeta.backdrop_path})`,
              }}
            />
          )}
          <div className="p-4 sm:p-6">
            <div className="flex gap-3 sm:gap-4">
              {showMeta?.poster_path && (
                <img
                  src={`${IMAGE_URL}w342${showMeta.poster_path}`}
                  alt=""
                  className="h-28 w-[4.5rem] shrink-0 rounded-xl object-cover shadow-poster"
                />
              )}
              <div className="min-w-0 flex-1">
                <h1 className="font-serif text-xl text-ink-bright sm:text-2xl">{showMeta?.name}</h1>
                <div className="mt-2 flex items-center gap-2">
                  <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-surface-raised">
                    <div className="h-full rounded-full bg-accent" style={{ width: `${pct}%` }} />
                  </div>
                  <span className="text-xs font-bold text-muted">{pct}%</span>
                </div>
                <p className="mt-1 text-xs text-muted">
                  {track?.watchedEpisodeCount || 0} of {track?.totalEpisodes || '—'} episodes
                </p>
              </div>
            </div>

            {isComplete ? (
              <div className="mt-6 rounded-xl border border-accent/30 bg-accent/10 px-4 py-5 text-center">
                <p className="font-serif text-lg text-ink-bright">You&apos;ve finished this show</p>
                <Link to={`/tv/${tvShowId}`} className="btn-secondary mt-4 inline-flex">
                  View show page
                </Link>
              </div>
            ) : nextEp ? (
              <div className="mt-6 rounded-xl border border-border bg-surface-raised/40 p-4 sm:p-5">
                <p className="text-[10px] font-bold uppercase tracking-widest text-accent">Up next</p>
                <h2 className="mt-2 font-serif text-lg text-ink-bright sm:text-xl">
                  S{nextEp.seasonNumber} · E{nextEp.episodeNumber}
                </h2>
                <p className="mt-1 text-sm text-muted">{nextEp.episodeName}</p>
                {nextEp.runtimeMinutes > 0 && (
                  <p className="mt-1 text-xs text-muted">{nextEp.runtimeMinutes} min</p>
                )}
                <button
                  type="button"
                  disabled={marking}
                  onClick={markNext}
                  className="btn-primary mt-5 w-full gap-2 disabled:opacity-50 sm:w-auto"
                >
                  <Check className="h-4 w-4" />
                  {marking ? 'Saving…' : 'Mark watched'}
                </button>
              </div>
            ) : (
              <div className="mt-6">
                <p className="text-sm text-muted">Choose a season to start tracking.</p>
                <Link to={`/tv/${tvShowId}`} className="btn-primary mt-4 inline-flex">
                  View seasons
                </Link>
              </div>
            )}

            <div className="mt-6 flex flex-col gap-2 sm:flex-row">
              <Link
                to={`/tv/${tvShowId}`}
                className="btn-secondary flex min-h-[44px] flex-1 items-center justify-center gap-2"
              >
                <ChevronRight className="h-4 w-4" />
                Show details
              </Link>
              {nextEp && (
                <Link
                  to={`/tv/${tvShowId}/${nextEp.seasonNumber}/episodes`}
                  className="btn-ghost flex min-h-[44px] flex-1 items-center justify-center gap-2 border border-border"
                >
                  <List className="h-4 w-4" />
                  All episodes
                </Link>
              )}
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
