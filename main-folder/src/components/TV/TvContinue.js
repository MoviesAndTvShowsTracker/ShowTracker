import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { Check, ChevronDown, ChevronRight, List, X } from 'lucide-react';
import api from '../../api/axios';
import { IMAGE_URL } from '../../config/keys';
import useIsMobile from '../../hooks/useIsMobile';
import useAnimatedPresence from '../../hooks/useAnimatedPresence';
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
import StarRating, { starsToPayload } from '../ui/StarRating';
import { clearSessionStats } from '../../utils/statsCache';
import { formatShortDate } from '../../utils/statsFormat';
import { haptic } from '../../utils/haptics';

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
  const [rateChip, setRateChip] = useState(null); // { seasonNumber, episodeNumber, episodeName, saving }
  const [rateChipView, setRateChipView] = useState(null);
  const rateChipPresence = useAnimatedPresence(Boolean(rateChip), 140);

  useEffect(() => {
    if (rateChip) setRateChipView(rateChip);
  }, [rateChip]);

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
        const finished = r.data.tracking?.status === 'completed';
        haptic(finished ? 'success' : 'light');
        handleProgressChange(r.data);
        setEpisodesRefresh((n) => (n ?? 0) + 1);
        setRateChip({
          seasonNumber: nextEp.seasonNumber,
          episodeNumber: nextEp.episodeNumber,
          episodeName: nextEp.episodeName,
          saving: false,
        });
      }
    } finally {
      setMarking(false);
    }
  };

  const rateJustWatched = async (stars) => {
    if (!rateChip) return;
    setRateChip((prev) => (prev ? { ...prev, saving: true } : prev));
    try {
      const r = await api.post('/api/tv/episodes/rate-episode', {
        tvId: tvShowId,
        seasonNumber: rateChip.seasonNumber,
        episodeNumber: rateChip.episodeNumber,
        rating: starsToPayload(stars),
      });
      if (r.data?.success) {
        setWatched((rows) =>
          rows.map((row) =>
            row.seasonNumber === rateChip.seasonNumber &&
            row.episodeNumber === rateChip.episodeNumber
              ? { ...row, rating: r.data.rating ?? null }
              : row
          )
        );
        clearSessionStats();
        setEpisodesRefresh((n) => (n ?? 0) + 1);
      }
    } finally {
      setRateChip(null);
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
      <div className="mx-auto max-w-content px-4 py-10" aria-busy="true" aria-label="Loading show progress">
        <div className="glass-card animate-pulse overflow-hidden">
          <div className="h-32 bg-surface-raised sm:h-40" />
          <div className="flex gap-4 p-4 sm:p-6">
            <div className="h-28 w-[4.5rem] shrink-0 rounded-xl bg-surface-raised" />
            <div className="flex-1 space-y-3">
              <div className="h-6 w-2/3 rounded-lg bg-surface-raised" />
              <div className="h-2 w-full rounded-full bg-surface-raised" />
              <div className="h-4 w-1/2 rounded-lg bg-surface-raised" />
            </div>
          </div>
        </div>
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
                  <div
                    className="progress-track flex-1"
                    role="progressbar"
                    aria-valuenow={pct}
                    aria-valuemin={0}
                    aria-valuemax={100}
                  >
                    <div className="progress-fill" style={{ '--progress': pct / 100 }} />
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
              <div
                key="finished"
                className="celebrate-soft mt-6 rounded-xl border border-link/30 bg-link/10 px-4 py-5 text-center"
              >
                <p className="font-serif text-lg text-ink-bright">You&apos;ve finished this show</p>
              </div>
            ) : caughtUpWithAired && upcomingLabel ? (
              <div
                key="caught-up"
                className="state-enter mt-6 rounded-xl border border-accent/30 bg-accent/10 px-4 py-5"
              >
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
              <div
                key={`next-${nextEp.seasonNumber}-${nextEp.episodeNumber}`}
                className="state-enter mt-6 rounded-xl border border-border bg-surface-raised/40 p-4 sm:p-5"
              >
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
              <div key="pick-season" className="state-enter mt-6">
                <p className="text-sm text-muted">Choose a season to start tracking.</p>
              </div>
            )}

            {rateChipPresence.rendered && rateChipView && (
              <div
                key={`rate-${rateChipView.seasonNumber}-${rateChipView.episodeNumber}`}
                className={`notice-presence mt-4 rounded-xl border border-border/60 bg-surface/60 px-3 py-3 shadow-glass backdrop-blur-md sm:px-4 ${
                  rateChipPresence.exiting ? 'is-exiting' : ''
                }`}
              >
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="text-[10px] font-bold uppercase tracking-[0.14em] text-muted">
                      Rate this episode?
                    </p>
                    <p className="mt-0.5 truncate text-sm text-ink">
                      S{rateChipView.seasonNumber} · E{rateChipView.episodeNumber}
                      {rateChipView.episodeName ? ` — ${rateChipView.episodeName}` : ''}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => setRateChip(null)}
                    className="focus-ring pressable inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-muted hover:bg-surface-raised hover:text-ink-bright cursor-pointer"
                    aria-label="Dismiss rating prompt"
                  >
                    <X className="h-4 w-4" aria-hidden="true" />
                  </button>
                </div>
                <div className="mt-2.5">
                  <StarRating
                    value={0}
                    onChange={rateJustWatched}
                    size="md"
                    allowClear={false}
                    disabled={
                      Boolean(rateChip?.saving) || rateChipPresence.exiting || !rateChip
                    }
                    label={`Rate S${rateChipView.seasonNumber}E${rateChipView.episodeNumber}`}
                  />
                </div>
              </div>
            )}

            <ShowQuickLinks
              tvShowId={tvShowId}
              episodesOpen={episodesOpen}
              onEpisodesClick={handleEpisodesClick}
              isMobile={isMobile}
            />

            {!isMobile && episodesPanel && (
              <div
                className="collapsible-grid"
                style={{ gridTemplateRows: episodesOpen ? '1fr' : '0fr' }}
                aria-hidden={!episodesOpen}
              >
                <div className="min-h-0 overflow-hidden">
                  <div className="mt-4 border-t border-border pt-4">{episodesPanel}</div>
                </div>
              </div>
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
