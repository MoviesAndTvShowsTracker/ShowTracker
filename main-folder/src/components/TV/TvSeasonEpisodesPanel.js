import { useCallback, useEffect, useMemo, useState } from 'react';
import { Check, ChevronDown, Star } from 'lucide-react';
import api from '../../api/axios';
import { tmdbFetch } from '../../utils/tmdb';
import useConfirmDialog from '../../hooks/useConfirmDialog';
import { EpisodeRatingControl, starsToPayload } from '../ui/StarRating';
import { clearSessionStats } from '../../utils/statsCache';
import { invalidateUserTvLists } from '../../utils/routeCache';
import { haptic } from '../../utils/haptics';
import {
  episodeUnmarkConfirm,
  markSeasonConfirm,
  markWholeShowConfirm,
  seasonUnmarkConfirm,
} from '../../utils/removeConfirm';
import {
  buildBatchPayload,
  buildMarkPayload,
  deriveShowProgress,
  episodeFromTmdb,
  episodeKey,
  fetchShowEpisodeIndex,
  formatEpisodeReleaseLabel,
  isEpisodeAired,
  progressPercent,
  resolveTrackingSeason,
  watchedSetFromEpisodes,
  watchedMapFromEpisodes,
} from '../../utils/tvProgress';
import { formatShortDate } from '../../utils/statsFormat';

export default function TvSeasonEpisodesPanel({
  tvShowId,
  tvShow,
  seasons,
  initialSeason,
  embedded = false,
  onProgressChange,
  refreshToken,
}) {
  const orderedSeasons = useMemo(
    () =>
      [...(seasons || [])]
        .filter((s) => s.season_number > 0)
        .sort((a, b) => a.season_number - b.season_number),
    [seasons]
  );

  const [selectedSeason, setSelectedSeason] = useState(null);
  const [seasonEpisodes, setSeasonEpisodes] = useState([]);
  const [seasonMeta, setSeasonMeta] = useState(null);
  const [loadingSeason, setLoadingSeason] = useState(false);
  const [watched, setWatched] = useState([]);
  const [track, setTrack] = useState(null);
  const [episodeIndex, setEpisodeIndex] = useState([]);
  const [totalEpisodes, setTotalEpisodes] = useState(0);
  const [airedEpisodeCount, setAiredEpisodeCount] = useState(0);
  const [toggling, setToggling] = useState(null);
  const [batching, setBatching] = useState(false);
  const [seasonDataReady, setSeasonDataReady] = useState(false);
  const [ratingSavingKey, setRatingSavingKey] = useState(null);
  const [rewatchSession, setRewatchSession] = useState(null);
  const [rewatchBusy, setRewatchBusy] = useState(false);
  const [playCounts, setPlayCounts] = useState({});
  const [rewatchPlayTotal, setRewatchPlayTotal] = useState(0);
  const { confirm, confirmDialog } = useConfirmDialog();

  const showMeta = useMemo(
    () => ({ ...tvShow, totalEpisodes, tvId: tvShowId }),
    [tvShow, totalEpisodes, tvShowId]
  );

  const isRewatching = track?.status === 'rewatching';

  const applyDiaryState = useCallback((tracking, episodes, session) => {
    if (tracking !== undefined) setTrack(tracking ?? null);
    if (session !== undefined) setRewatchSession(session ?? null);
    if (episodes !== undefined) setWatched(episodes || []);
  }, []);

  const loadWatched = useCallback(() => {
    Promise.all([
      api.get(`/api/tv/tracking/show/${tvShowId}`),
      api.get(`/api/tv/episodes/${tvShowId}`),
      api.get(`/api/tv/rewatch/${tvShowId}`).catch(() => ({ data: {} })),
    ]).then(([trackRes, epsRes, rewatchRes]) => {
      const tracking =
        rewatchRes.data?.tracking ||
        (trackRes.data.success ? trackRes.data.tracking : null);
      const session = rewatchRes.data?.activeSession || null;
      const rewatching = tracking?.status === 'rewatching';
      const episodes = rewatching
        ? session?.episodes || []
        : epsRes.data.success
          ? epsRes.data.episodes || []
          : [];
      setPlayCounts(rewatchRes.data?.playCounts || {});
      setRewatchPlayTotal(rewatchRes.data?.rewatchPlayTotal || 0);
      applyDiaryState(tracking, episodes, session);
    });
  }, [tvShowId, applyDiaryState]);

  useEffect(() => {
    setSeasonDataReady(false);
    setSelectedSeason(null);

    const trackingReq = api.get(`/api/tv/tracking/show/${tvShowId}`);
    const watchedReq = api.get(`/api/tv/episodes/${tvShowId}`);
    const rewatchReq = api.get(`/api/tv/rewatch/${tvShowId}`).catch(() => ({ data: {} }));
    const indexReq = fetchShowEpisodeIndex(tvShowId).then(
      ({ episodes, totalEpisodes: total, airedEpisodeCount: aired }) => {
        setEpisodeIndex(episodes);
        setTotalEpisodes(total);
        setAiredEpisodeCount(aired);
      }
    );

    Promise.all([trackingReq, watchedReq, rewatchReq, indexReq])
      .then(([trackRes, epsRes, rewatchRes]) => {
        const tracking =
          rewatchRes.data?.tracking ||
          (trackRes.data.success ? trackRes.data.tracking : null);
        const session = rewatchRes.data?.activeSession || null;
        const rewatching = tracking?.status === 'rewatching';
        const episodes = rewatching
          ? session?.episodes || []
          : epsRes.data.success
            ? epsRes.data.episodes || []
            : [];
        setPlayCounts(rewatchRes.data?.playCounts || {});
        setRewatchPlayTotal(rewatchRes.data?.rewatchPlayTotal || 0);
        applyDiaryState(tracking, episodes, session);
      })
      .finally(() => setSeasonDataReady(true));
  }, [tvShowId, applyDiaryState]);

  useEffect(() => {
    if (refreshToken == null) return;
    loadWatched();
  }, [refreshToken, loadWatched]);

  const watchedKeys = watchedSetFromEpisodes(watched);

  const contextSeason = useMemo(() => {
    const season = resolveTrackingSeason(track, episodeIndex, watchedKeys);
    if (season == null || !orderedSeasons.some((s) => s.season_number === season)) return null;
    return season;
  }, [track, episodeIndex, watchedKeys, orderedSeasons]);

  useEffect(() => {
    if (!seasonDataReady) return;
    if (initialSeason && orderedSeasons.some((s) => s.season_number === initialSeason)) {
      setSelectedSeason(initialSeason);
      return;
    }
    if (selectedSeason != null) return;
    if (contextSeason != null) {
      setSelectedSeason(contextSeason);
      return;
    }
    if (orderedSeasons.length) {
      setSelectedSeason(orderedSeasons[0].season_number);
    }
  }, [seasonDataReady, initialSeason, contextSeason, orderedSeasons, selectedSeason]);

  useEffect(() => {
    if (!orderedSeasons.length || selectedSeason == null) return;
    if (!orderedSeasons.some((s) => s.season_number === selectedSeason)) {
      setSelectedSeason(orderedSeasons[0].season_number);
    }
  }, [orderedSeasons, selectedSeason]);

  useEffect(() => {
    if (!selectedSeason) return;
    setLoadingSeason(true);
    tmdbFetch(`tv/${tvShowId}/season/${selectedSeason}`)
      .then((data) => {
        setSeasonMeta(data);
        setSeasonEpisodes(data.episodes || []);
      })
      .catch(() => {
        setSeasonMeta(null);
        setSeasonEpisodes([]);
      })
      .finally(() => setLoadingSeason(false));
  }, [tvShowId, selectedSeason]);

  const watchedByKey = useMemo(() => watchedMapFromEpisodes(watched), [watched]);
  const nextKey =
    track?.nextSeason && track?.nextEpisode
      ? episodeKey(track.nextSeason, track.nextEpisode)
      : null;

  const seasonEpisodesMeta = useMemo(
    () => seasonEpisodes.map((ep) => episodeFromTmdb(selectedSeason, ep)),
    [seasonEpisodes, selectedSeason]
  );

  const seasonAiredMeta = useMemo(
    () => seasonEpisodesMeta.filter((ep) => isEpisodeAired(ep)),
    [seasonEpisodesMeta]
  );

  const seasonAiredWatchedCount = seasonAiredMeta.filter((ep) =>
    watchedKeys.has(episodeKey(ep.seasonNumber, ep.episodeNumber))
  ).length;

  const showProgress = deriveShowProgress(track, episodeIndex, watchedKeys);

  const seasonComplete =
    seasonAiredMeta.length > 0 && seasonAiredWatchedCount === seasonAiredMeta.length;

  const unwatchedAiredAll = useMemo(
    () =>
      episodeIndex.filter(
        (ep) =>
          isEpisodeAired(ep) &&
          !watchedKeys.has(episodeKey(ep.seasonNumber, ep.episodeNumber))
      ),
    [episodeIndex, watchedKeys]
  );

  const unwatchedAiredSeason = useMemo(
    () =>
      seasonAiredMeta.filter(
        (ep) => !watchedKeys.has(episodeKey(ep.seasonNumber, ep.episodeNumber))
      ),
    [seasonAiredMeta, watchedKeys]
  );

  const applyResponse = (r) => {
    if (r.data.success) {
      const session = r.data.session;
      const episodes = r.data.episodes || session?.episodes || [];
      if (r.data.playCounts) setPlayCounts(r.data.playCounts);
      if (r.data.rewatchPlayTotal != null) setRewatchPlayTotal(r.data.rewatchPlayTotal);
      applyDiaryState(r.data.tracking ?? null, episodes, session ?? rewatchSession);
      // Keep Home / Library / Profile / Continue caches honest after any
      // episode mark/unmark/batch — the next visit will be instant *and* fresh.
      invalidateUserTvLists();
      clearSessionStats();
      onProgressChange?.(r.data);
    }
  };

  const refreshPlayState = async () => {
    const [rewatchRes, epsRes] = await Promise.all([
      api.get(`/api/tv/rewatch/${tvShowId}`).catch(() => ({ data: {} })),
      api.get(`/api/tv/episodes/${tvShowId}`),
    ]);
    setPlayCounts(rewatchRes.data?.playCounts || {});
    setRewatchPlayTotal(rewatchRes.data?.rewatchPlayTotal || 0);
    const tracking = rewatchRes.data?.tracking;
    const session = rewatchRes.data?.activeSession || null;
    const rewatching = tracking?.status === 'rewatching';
    const episodes = rewatching
      ? session?.episodes || []
      : epsRes.data.success
        ? epsRes.data.episodes || []
        : [];
    applyDiaryState(tracking ?? track, episodes, session);
  };

  const markBase = isRewatching ? '/api/tv/rewatch' : '/api/tv/episodes';

  const startRewatch = async () => {
    setRewatchBusy(true);
    try {
      const r = await api.post('/api/tv/rewatch/start', {
        tvId: String(tvShowId),
        tvTitle: tvShow?.name,
        tvPosterImage: tvShow?.poster_path,
        totalEpisodes,
        airedEpisodeCount,
        nextSeason: 1,
        nextEpisode: 1,
      });
      if (r.data.success) {
        applyDiaryState(r.data.tracking, r.data.session?.episodes || [], r.data.session);
        invalidateUserTvLists();
        clearSessionStats();
        haptic('success');
        onProgressChange?.(r.data);
      }
    } finally {
      setRewatchBusy(false);
    }
  };

  const cancelRewatch = async () => {
    setRewatchBusy(true);
    try {
      const r = await api.post('/api/tv/rewatch/cancel', { tvId: String(tvShowId) });
      if (r.data.success) {
        const eps = await api.get(`/api/tv/episodes/${tvShowId}`);
        applyDiaryState(
          r.data.tracking,
          eps.data.success ? eps.data.episodes || [] : [],
          null
        );
        invalidateUserTvLists();
        clearSessionStats();
        haptic('light');
        onProgressChange?.(r.data);
      }
    } finally {
      setRewatchBusy(false);
    }
  };

  const watchedInSeasonCount = seasonEpisodesMeta.filter((ep) =>
    watchedKeys.has(episodeKey(ep.seasonNumber, ep.episodeNumber))
  ).length;

  const performEpisodeToggle = async (episode, isUnmark) => {
    if (!episodeIndex.length) return;
    const key = episodeKey(selectedSeason, episode.episode_number);
    setToggling(key);

    const epMeta = episodeFromTmdb(selectedSeason, episode);
    try {
      const payload = buildMarkPayload(
        showMeta,
        epMeta,
        episodeIndex,
        watchedKeys,
        !isUnmark
      );
      const r = await api.post(isUnmark ? `${markBase}/unmark` : `${markBase}/mark`, payload);
      if (r.data?.success && !isUnmark) {
        haptic(
          r.data.completed || r.data.tracking?.status === 'completed' ? 'success' : 'light'
        );
      }
      applyResponse(r);
    } finally {
      setToggling(null);
    }
  };

  const logEpisodeRewatch = async (episode) => {
    const epMeta = episodeFromTmdb(selectedSeason, episode);
    const payload = buildMarkPayload(showMeta, epMeta, episodeIndex, watchedKeys, true);
    const r = await api.post('/api/tv/rewatch/log', payload);
    if (r.data?.success) {
      haptic('success');
      applyResponse(r);
      if (!r.data.playCounts) await refreshPlayState();
    }
  };

  const undoEpisodePlay = async (episode) => {
    const epMeta = episodeFromTmdb(selectedSeason, episode);
    const payload = buildMarkPayload(showMeta, epMeta, episodeIndex, watchedKeys, false);
    if (isRewatching) {
      await performEpisodeToggle(episode, true);
      return;
    }
    const r = await api.post('/api/tv/rewatch/undo-play', payload);
    if (r.data?.success) {
      haptic('light');
      applyResponse(r);
      await refreshPlayState();
    }
  };

  const toggleEpisode = (episode) => {
    const key = episodeKey(selectedSeason, episode.episode_number);
    const isWatched = watchedKeys.has(key);
    const plays = playCounts[key] || (isWatched ? 1 : 0);
    if (isWatched || plays > 0) {
      const name = episode.name ? ` — ${episode.name}` : '';
      confirm({
        title: plays > 1 ? `Watched ${plays} times` : 'Watched',
        body:
          plays > 1
            ? `S${selectedSeason} E${episode.episode_number}${name} is on ${plays} watches. Watch again, or peel off the latest one.`
            : `S${selectedSeason} E${episode.episode_number}${name}. Watch again, or clear this watch.`,
        actions: [
          { label: 'Watch again', primary: true, onClick: () => logEpisodeRewatch(episode) },
          {
            label: plays > 1 ? 'Remove latest watch' : 'Mark as unwatched',
            destructive: true,
            onClick: () => undoEpisodePlay(episode),
          },
        ],
      });
      return;
    }
    performEpisodeToggle(episode, false);
  };

  const markSeason = async () => {
    if (!unwatchedAiredSeason.length) return;
    setBatching(true);
    try {
      const payload = buildBatchPayload(showMeta, unwatchedAiredSeason, episodeIndex, watchedKeys, true);
      const r = await api.post(`${markBase}/mark-batch`, payload);
      if (r.data?.success) {
        haptic(
          r.data.completed || r.data.tracking?.status === 'completed' ? 'success' : 'light'
        );
      }
      applyResponse(r);
    } finally {
      setBatching(false);
    }
  };

  const unmarkSeason = async () => {
    const watchedInSeason = seasonEpisodesMeta.filter((ep) =>
      watchedKeys.has(episodeKey(ep.seasonNumber, ep.episodeNumber))
    );
    if (!watchedInSeason.length) return;
    setBatching(true);
    try {
      const payload = buildBatchPayload(showMeta, watchedInSeason, episodeIndex, watchedKeys, false);
      if (isRewatching) {
        const r = await api.post(`${markBase}/unmark-batch`, payload);
        applyResponse(r);
      } else {
        await api.post('/api/tv/rewatch/undo-play-batch', payload);
        await refreshPlayState();
        invalidateUserTvLists();
        clearSessionStats();
      }
    } finally {
      setBatching(false);
    }
  };

  const rewatchSeason = async () => {
    const watchedInSeason = seasonAiredMeta.filter((ep) =>
      watchedKeys.has(episodeKey(ep.seasonNumber, ep.episodeNumber))
    );
    if (!watchedInSeason.length) return;
    setBatching(true);
    try {
      const payload = buildBatchPayload(showMeta, watchedInSeason, episodeIndex, watchedKeys, true);
      const r = await api.post('/api/tv/rewatch/log-batch', payload);
      if (r.data?.success) {
        haptic('success');
        applyResponse(r);
        if (!r.data.playCounts) await refreshPlayState();
      }
    } finally {
      setBatching(false);
    }
  };

  const openSeasonCompleteMenu = () => {
    confirm({
      title: 'Season watched',
      body: 'Add another watch for every aired episode, or strip watches from this season (latest first).',
      actions: [
        { label: 'Watch season again', primary: true, onClick: rewatchSeason },
        { label: 'Remove season watches', destructive: true, onClick: unmarkSeason },
      ],
    });
  };

  const rateEpisode = async (ep, stars) => {
    const key = episodeKey(ep.seasonNumber, ep.episodeNumber);
    const prev = [...watched];
    const payload = starsToPayload(stars);

    // Optimistic update
    setWatched((rows) =>
      rows.map((row) =>
        row.seasonNumber === ep.seasonNumber && row.episodeNumber === ep.episodeNumber
          ? { ...row, rating: payload || null }
          : row
      )
    );
    setRatingSavingKey(key);
    try {
      const r = await api.post('/api/tv/episodes/rate-episode', {
        tvId: tvShowId,
        seasonNumber: ep.seasonNumber,
        episodeNumber: ep.episodeNumber,
        rating: payload,
      });
      if (r.data?.success) {
        setWatched((rows) =>
          rows.map((row) =>
            row.seasonNumber === ep.seasonNumber && row.episodeNumber === ep.episodeNumber
              ? { ...row, rating: r.data.rating ?? null }
              : row
          )
        );
        clearSessionStats();
      } else {
        setWatched(prev);
      }
    } catch {
      setWatched(prev);
    } finally {
      setRatingSavingKey(null);
    }
  };

  const markAllShow = async () => {
    if (!unwatchedAiredAll.length) return;
    setBatching(true);
    try {
      const payload = buildBatchPayload(showMeta, unwatchedAiredAll, episodeIndex, watchedKeys, true);
      const r = await api.post(`${markBase}/mark-batch`, payload);
      if (r.data?.success) {
        haptic(
          r.data.completed || r.data.tracking?.status === 'completed' ? 'success' : 'medium'
        );
      }
      applyResponse(r);
    } finally {
      setBatching(false);
    }
  };

  const airdate = (prop) =>
    new Date(prop).toLocaleDateString('en-US', { day: 'numeric', month: 'short', year: 'numeric' });

  if (!orderedSeasons.length) return null;

  const markAllButton =
    unwatchedAiredAll.length > 0 && track?.status !== 'completed' ? (
      <button
        type="button"
        disabled={batching}
        onClick={() =>
          confirm({
            ...markWholeShowConfirm(unwatchedAiredAll.length),
            onConfirm: markAllShow,
          })
        }
        className="pressable shrink-0 text-xs font-semibold text-muted transition-colors hover:text-ink disabled:opacity-50"
      >
        {isRewatching ? 'Mark whole rewatch' : 'Mark whole show'}
      </button>
    ) : null;

  const rewatchControls =
    track?.status === 'completed' ? (
      <button
        type="button"
        disabled={rewatchBusy}
        onClick={() =>
          confirm({
            title: 'Start a rewatch?',
            body: 'Your original watch history stays. Episode checks reset for this rewatch only.',
            confirmLabel: 'Start rewatch',
            onConfirm: startRewatch,
          })
        }
        className="pressable shrink-0 text-xs font-semibold text-accent transition-colors hover:text-accent/80 disabled:opacity-50"
      >
        {rewatchBusy ? 'Starting…' : 'Start rewatch'}
      </button>
    ) : isRewatching ? (
      <button
        type="button"
        disabled={rewatchBusy}
        onClick={() =>
          confirm({
            title: 'Cancel rewatch?',
            body: 'Rewatch progress for this run will be cleared. Your first watch stays intact.',
            confirmLabel: 'Cancel rewatch',
            onConfirm: cancelRewatch,
          })
        }
        className="pressable shrink-0 text-xs font-semibold text-danger transition-colors hover:opacity-80 disabled:opacity-50"
      >
        {rewatchBusy ? 'Cancelling…' : `Cancel rewatch${rewatchSession?.sessionNumber ? ` #${rewatchSession.sessionNumber}` : ''}`}
      </button>
    ) : null;

  return (
    <section
      id={embedded ? undefined : 'episodes'}
      className={embedded ? 'mt-0' : 'mt-8 scroll-mt-24 md:mt-10'}
    >
      {!embedded ? (
        <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
          <h3 className="section-title">Episodes</h3>
          <div className="flex flex-wrap items-center gap-3">
            {track && (
              <span className="text-xs text-muted">
                {isRewatching ? (
                  <>
                    Rewatch {watchedKeys.size}/
                    {showProgress.airedTotal || airedEpisodeCount || track.totalEpisodes || totalEpisodes}
                  </>
                ) : (
                  <>
                    {track.watchedEpisodeCount || 0}/
                    {showProgress.airedTotal || airedEpisodeCount || track.totalEpisodes || totalEpisodes}{' '}
                    aired
                    {showProgress.airedTotal < showProgress.totalEpisodes &&
                    showProgress.totalEpisodes > 0
                      ? ` · ${showProgress.totalEpisodes} total`
                      : ''}
                  </>
                )}
              </span>
            )}
            {rewatchControls}
            {markAllButton}
          </div>
        </div>
      ) : (
        <div className="mb-3 flex flex-wrap items-center justify-end gap-3">
          {rewatchControls}
          {unwatchedAiredAll.length > 0 ? markAllButton : null}
        </div>
      )}

      <div className="glass-card space-y-4 p-4 sm:p-5">
        <div>
          <label htmlFor="season-select" className="section-title mb-2 block normal-case tracking-wide">
            Season
          </label>
          <div className="relative">
            <select
              id="season-select"
              className="input-field min-h-[48px] appearance-none pr-10"
              value={selectedSeason ?? orderedSeasons[0]?.season_number ?? 1}
              disabled={selectedSeason == null}
              onChange={(e) => setSelectedSeason(Number(e.target.value))}
            >
              {orderedSeasons.map((s) => (
                <option key={s.id} value={s.season_number}>
                  {s.name || `Season ${s.season_number}`}
                  {s.episode_count ? ` · ${s.episode_count} episodes` : ''}
                </option>
              ))}
            </select>
            <ChevronDown className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
          </div>
        </div>

        {seasonMeta?.overview && (
          <p className="text-sm leading-relaxed text-muted line-clamp-3">{seasonMeta.overview}</p>
        )}

        <div className="flex flex-wrap items-center gap-2">
          <div className="mr-auto flex min-w-[8rem] flex-1 items-center gap-2">
            <div
              className="progress-track flex-1"
              role="progressbar"
              aria-valuenow={progressPercent(
                seasonAiredWatchedCount,
                seasonAiredMeta.length || seasonEpisodesMeta.length
              )}
              aria-valuemin={0}
              aria-valuemax={100}
            >
              <div
                className="progress-fill"
                style={{
                  '--progress':
                    progressPercent(
                      seasonAiredWatchedCount,
                      seasonAiredMeta.length || seasonEpisodesMeta.length
                    ) / 100,
                }}
              />
            </div>
            <span className="text-[10px] font-bold tabular-nums text-muted">
              {seasonAiredWatchedCount}/{seasonAiredMeta.length || seasonEpisodesMeta.length || '—'}
            </span>
          </div>
          {!seasonComplete ? (
            <button
              type="button"
              disabled={batching || !unwatchedAiredSeason.length}
              onClick={() =>
                confirm({
                  ...markSeasonConfirm(selectedSeason, unwatchedAiredSeason.length),
                  onConfirm: markSeason,
                })
              }
              className="btn-secondary !min-h-[40px] !px-3 !py-2 !text-xs disabled:opacity-50"
            >
              Mark season
            </button>
          ) : (
            <button
              type="button"
              disabled={batching}
              onClick={openSeasonCompleteMenu}
              className="btn-ghost !min-h-[40px] border border-border !px-3 !py-2 !text-xs disabled:opacity-50"
            >
              Season watched
            </button>
          )}
        </div>

        {loadingSeason || !seasonDataReady || selectedSeason == null ? (
          <div className="state-enter space-y-2" aria-busy="true" aria-label="Loading episodes">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-16 animate-pulse rounded-xl bg-surface-raised" />
            ))}
          </div>
        ) : (
          <div key={selectedSeason} className="state-enter space-y-2">
            {seasonEpisodes.map((episode) => {
              const key = episodeKey(selectedSeason, episode.episode_number);
              const epMeta = episodeFromTmdb(selectedSeason, episode);
              const aired = isEpisodeAired(epMeta);
              const releaseLabel = !aired ? formatEpisodeReleaseLabel(episode.air_date) : null;
              const isWatched = watchedKeys.has(key);
              const plays = playCounts[key] || (isWatched ? 1 : 0);
              const isNext = aired && key === nextKey;
              const watchedAt = watchedByKey.get(key)?.watchedAt;

              return (
                <article
                  key={episode.id}
                  className={`flex gap-3 rounded-xl border border-border/60 bg-surface/50 p-3 transition-colors ${
                    isNext ? 'ring-2 ring-accent/40' : ''
                  } ${!aired ? 'opacity-75' : ''}`}
                >
                  <button
                    type="button"
                    disabled={!aired || toggling === key || batching}
                    onClick={() => toggleEpisode(episode)}
                    aria-label={isWatched ? 'Episode options' : aired ? 'Mark watched' : 'Not released yet'}
                    className={`pressable relative flex h-11 w-11 shrink-0 items-center justify-center rounded-xl border-2 transition-all duration-200 cursor-pointer disabled:cursor-not-allowed disabled:opacity-50 ${
                      isWatched || plays > 0
                        ? 'border-accent bg-accent text-on-accent'
                        : 'border-border bg-surface hover:border-accent/50'
                    }`}
                    aria-label={
                      plays > 1
                        ? `Watched ${plays} times`
                        : isWatched || plays > 0
                          ? 'Watched once'
                          : aired
                            ? 'Mark watched'
                            : 'Not released yet'
                    }
                  >
                    {plays > 1 ? (
                      <span className="text-xs font-bold tabular-nums leading-none">{plays}×</span>
                    ) : (
                      (isWatched || plays > 0) && <Check className="check-pop h-5 w-5" strokeWidth={3} />
                    )}
                  </button>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-semibold leading-snug">
                      <span className="text-accent">{episode.episode_number}.</span> {episode.name}
                      {isNext && (
                        <span className="ml-2 text-[10px] font-bold uppercase tracking-wide text-accent">
                          Up next
                        </span>
                      )}
                      {releaseLabel && (
                        <span className="ml-2 text-[10px] font-bold uppercase tracking-wide text-muted">
                          {releaseLabel}
                        </span>
                      )}
                    </p>
                    <div className="mt-0.5 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-muted">
                      {episode.air_date && <span>Aired {airdate(episode.air_date)}</span>}
                      {isWatched && watchedAt && (
                        <span className="state-enter font-medium text-accent">
                          Watched {formatShortDate(watchedAt)}
                        </span>
                      )}
                      {episode.runtime > 0 && <span>{episode.runtime} min</span>}
                      {episode.vote_average > 0 && (
                        <span className="inline-flex items-center gap-0.5">
                          <Star className="h-3 w-3 fill-accent text-accent" aria-hidden="true" />
                          {Number(episode.vote_average).toFixed(1)}
                        </span>
                      )}
                      {isWatched && (
                        <EpisodeRatingControl
                          value={watchedByKey.get(key)?.rating}
                          onChange={(stars) => rateEpisode(epMeta, stars)}
                          disabled={ratingSavingKey === key}
                          label={`Rate episode ${episode.episode_number}`}
                        />
                      )}
                    </div>
                  </div>
                </article>
              );
            })}
          </div>
        )}
      </div>

      {confirmDialog}
    </section>
  );
}
