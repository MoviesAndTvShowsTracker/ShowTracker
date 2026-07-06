import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { Check, ChevronDown, ChevronRight, List } from 'lucide-react';
import api from '../../api/axios';
import { IMAGE_URL } from '../../config/keys';
import useIsMobile from '../../hooks/useIsMobile';
import {
  buildMarkPayload,
  deriveShowProgress,
  fetchShowEpisodeIndex,
  resolveTrackingSeason,
  watchedSetFromEpisodes,
} from '../../utils/tvProgress';
import PageTitle from '../../utils/PageTitle';
import BackNav from '../ui/BackNav';
import Dialog from '../ui/Dialog';
import TvSeasonEpisodesPanel from './TvSeasonEpisodesPanel';
import TvTrackingStatusAction from './TvTrackingStatusAction';
import { formatShortDate } from '../../utils/statsFormat';

const menuRowClass =
  'flex min-h-[48px] w-full items-center gap-3 px-4 py-3 text-sm font-medium text-ink transition-colors hover:bg-surface-raised/50 active:bg-surface-raised/70';

function ShowQuickLinks({ tvShowId, episodesOpen, onEpisodesClick, isMobile }) {
  return (
    <div className="mt-5 overflow-hidden rounded-xl border border-border">
      <Link to={`/tv/${tvShowId}`} className={`${menuRowClass} border-b border-border`}>
        <ChevronRight className="h-4 w-4 shrink-0 text-muted" aria-hidden />
        <span className="flex-1">Show details</span>
      </Link>
      <button
        type="button"
        onClick={onEpisodesClick}
        aria-haspopup={isMobile ? 'dialog' : undefined}
        aria-expanded={episodesOpen}
        className={`${menuRowClass}${episodesOpen ? ' bg-surface-raised/60' : ''}`}
      >
        <List className="h-4 w-4 shrink-0 text-muted" aria-hidden />
        <span className="flex-1 text-left">Episodes</span>
        {isMobile ? (
          <ChevronRight className="h-4 w-4 shrink-0 text-muted/50" aria-hidden />
        ) : (
          <ChevronDown
            className={`h-4 w-4 shrink-0 text-muted/50 transition-transform duration-300 ${
              episodesOpen ? 'rotate-180' : ''
            }`}
            aria-hidden
          />
        )}
      </button>
    </div>
  );
}

export default function TvContinue() {
  const { Id: tvShowId } = useParams();
  const navigate = useNavigate();
  const isMobile = useIsMobile();
  const [track, setTrack] = useState(null);
  const [showMeta, setShowMeta] = useState(null);
  const [episodeIndex, setEpisodeIndex] = useState([]);
  const [watched, setWatched] = useState([]);
  const [loading, setLoading] = useState(true);
  const [marking, setMarking] = useState(false);
  const [episodesOpen, setEpisodesOpen] = useState(false);
  const [episodesEverOpened, setEpisodesEverOpened] = useState(false);
  const [episodesRefresh, setEpisodesRefresh] = useState(null);

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
    setEpisodesOpen(false);
    setEpisodesEverOpened(false);
    window.scrollTo(0, 0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tvShowId]);

  const handleProgressChange = (data) => {
    setWatched(data.episodes || []);
    const nextTrack = data.tracking ?? null;
    setTrack(nextTrack);
    if (!nextTrack && !(data.episodes || []).length) {
      navigate(`/tv/${tvShowId}`, { replace: true });
    }
  };

  const handleTrackingStatusChange = (data) => {
    if (data && 'tracking' in data) setTrack(data.tracking ?? null);
  };

  const watchedKeys = watchedSetFromEpisodes(watched);
  const progress = deriveShowProgress(track, episodeIndex, watchedKeys);
  const nextEp =
    track?.nextSeason && track?.nextEpisode
      ? episodeIndex.find(
          (e) => e.seasonNumber === track.nextSeason && e.episodeNumber === track.nextEpisode
        )
      : progress.nextAired;

  const { pct, caughtUpWithAired, upcomingLabel, nextUnaired, isComplete } = progress;
  const episodesSeason = resolveTrackingSeason(track, episodeIndex, watchedKeys) ?? 1;

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
        handleProgressChange(r.data);
        setEpisodesRefresh((n) => (n ?? 0) + 1);
      }
    } finally {
      setMarking(false);
    }
  };

  const handleEpisodesClick = () => {
    if (isMobile) {
      setEpisodesEverOpened(true);
      setEpisodesOpen(true);
    } else {
      setEpisodesOpen((open) => !open);
    }
  };

  const episodesPanel = showMeta ? (
    <TvSeasonEpisodesPanel
      embedded
      tvShowId={tvShowId}
      tvShow={showMeta}
      seasons={showMeta.seasons || []}
      initialSeason={episodesSeason}
      refreshToken={episodesRefresh}
      onProgressChange={handleProgressChange}
    />
  ) : null;

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
        <BackNav to="/home" label="Back to home" className="mb-4" />

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
                  {track?.watchedEpisodeCount || 0} of {progress.airedTotal || track?.totalEpisodes || '—'}{' '}
                  aired episodes
                  {progress.airedTotal < progress.totalEpisodes && progress.totalEpisodes > 0
                    ? ` (${progress.totalEpisodes} total)`
                    : ''}
                </p>
              </div>
            </div>

            <TvTrackingStatusAction
              tvId={tvShowId}
              track={track}
              navigateOnStop
              onStatusChange={handleTrackingStatusChange}
            />

            {isComplete ? (
              <div className="mt-6 rounded-xl border border-link/30 bg-link/10 px-4 py-5 text-center">
                <p className="font-serif text-lg text-ink-bright">You&apos;ve finished this show</p>
              </div>
            ) : caughtUpWithAired && upcomingLabel ? (
              <div className="mt-6 rounded-xl border border-accent/30 bg-accent/10 px-4 py-5">
                <p className="text-[10px] font-bold uppercase tracking-widest text-accent">Caught up</p>
                <p className="mt-2 font-serif text-lg text-ink-bright">
                  You&apos;re up to date on all aired episodes
                </p>
                {nextUnaired && (
                  <p className="mt-2 text-sm text-muted">
                    S{nextUnaired.seasonNumber} · E{nextUnaired.episodeNumber}
                    {nextUnaired.episodeName ? ` — ${nextUnaired.episodeName}` : ''} releases{' '}
                    <span className="font-medium text-ink">{upcomingLabel}</span>
                  </p>
                )}
              </div>
            ) : nextEp ? (
              <div className="mt-6 rounded-xl border border-border bg-surface-raised/40 p-4 sm:p-5">
                <p className="text-[10px] font-bold uppercase tracking-widest text-accent">Up next</p>
                <h2 className="mt-2 font-serif text-lg text-ink-bright sm:text-xl">
                  S{nextEp.seasonNumber} · E{nextEp.episodeNumber}
                </h2>
                <p className="mt-1 text-sm text-muted">{nextEp.episodeName}</p>
                {(nextEp.airDate || nextEp.runtimeMinutes > 0) && (
                  <p className="mt-1 text-xs text-muted">
                    {[
                      nextEp.airDate && `Aired ${formatShortDate(nextEp.airDate)}`,
                      nextEp.runtimeMinutes > 0 && `${nextEp.runtimeMinutes} min`,
                    ]
                      .filter(Boolean)
                      .join(' · ')}
                  </p>
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
              </div>
            )}

            <ShowQuickLinks
              tvShowId={tvShowId}
              episodesOpen={episodesOpen}
              onEpisodesClick={handleEpisodesClick}
              isMobile={isMobile}
            />

            {episodesOpen && !isMobile && episodesPanel && (
              <div className="mt-4 border-t border-border pt-4">{episodesPanel}</div>
            )}
          </div>
        </div>
      </div>

      {isMobile && episodesEverOpened && showMeta && (
        <Dialog
          open={episodesOpen}
          onClose={() => setEpisodesOpen(false)}
          title="Episodes"
          sheet
          wide
          bodyClassName="px-3 py-3 pb-[max(1rem,env(safe-area-inset-bottom))]"
        >
          {episodesPanel}
        </Dialog>
      )}
    </>
  );
}
