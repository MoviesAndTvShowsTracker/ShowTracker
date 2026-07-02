import { useCallback, useEffect, useMemo, useState } from 'react';
import { Check, ChevronDown, Star } from 'lucide-react';
import api from '../../api/axios';
import { tmdbFetch } from '../../utils/tmdb';
import {
  buildBatchPayload,
  buildMarkPayload,
  episodeFromTmdb,
  episodeKey,
  fetchShowEpisodeIndex,
  progressPercent,
  watchedSetFromEpisodes,
} from '../../utils/tvProgress';

export default function TvSeasonEpisodesPanel({ tvShowId, tvShow, seasons, initialSeason }) {
  const orderedSeasons = useMemo(
    () =>
      [...(seasons || [])]
        .filter((s) => s.season_number > 0)
        .sort((a, b) => a.season_number - b.season_number),
    [seasons]
  );

  const [selectedSeason, setSelectedSeason] = useState(
    initialSeason || orderedSeasons[0]?.season_number || 1
  );
  const [seasonEpisodes, setSeasonEpisodes] = useState([]);
  const [seasonMeta, setSeasonMeta] = useState(null);
  const [loadingSeason, setLoadingSeason] = useState(false);
  const [watched, setWatched] = useState([]);
  const [track, setTrack] = useState(null);
  const [episodeIndex, setEpisodeIndex] = useState([]);
  const [totalEpisodes, setTotalEpisodes] = useState(0);
  const [toggling, setToggling] = useState(null);
  const [batching, setBatching] = useState(false);

  const showMeta = useMemo(
    () => ({ ...tvShow, totalEpisodes, tvId: tvShowId }),
    [tvShow, totalEpisodes, tvShowId]
  );

  const loadWatched = useCallback(() => {
    api.get(`/api/tv/episodes/${tvShowId}`).then((r) => {
      if (r.data.success) setWatched(r.data.episodes || []);
    });
    api.get(`/api/tv/tracking/show/${tvShowId}`).then((r) => {
      if (r.data.success) setTrack(r.data.tracking);
    });
  }, [tvShowId]);

  useEffect(() => {
    loadWatched();
    fetchShowEpisodeIndex(tvShowId).then(({ episodes, totalEpisodes: total }) => {
      setEpisodeIndex(episodes);
      setTotalEpisodes(total);
    });
  }, [tvShowId, loadWatched]);

  useEffect(() => {
    if (initialSeason && orderedSeasons.some((s) => s.season_number === initialSeason)) {
      setSelectedSeason(initialSeason);
    }
  }, [initialSeason, orderedSeasons]);

  useEffect(() => {
    if (!orderedSeasons.length) return;
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

  const watchedKeys = watchedSetFromEpisodes(watched);
  const nextKey =
    track?.nextSeason && track?.nextEpisode
      ? episodeKey(track.nextSeason, track.nextEpisode)
      : null;

  const seasonEpisodesMeta = useMemo(
    () => seasonEpisodes.map((ep) => episodeFromTmdb(selectedSeason, ep)),
    [seasonEpisodes, selectedSeason]
  );

  const seasonWatchedCount = seasonEpisodesMeta.filter((ep) =>
    watchedKeys.has(episodeKey(ep.seasonNumber, ep.episodeNumber))
  ).length;

  const seasonComplete =
    seasonEpisodesMeta.length > 0 && seasonWatchedCount === seasonEpisodesMeta.length;

  const applyResponse = (r) => {
    if (r.data.success) {
      setWatched(r.data.episodes || []);
      setTrack(r.data.tracking);
    }
  };

  const toggleEpisode = async (episode) => {
    if (!episodeIndex.length) return;
    const key = episodeKey(selectedSeason, episode.episode_number);
    const isWatched = watchedKeys.has(key);
    setToggling(key);

    const epMeta = episodeFromTmdb(selectedSeason, episode);
    try {
      const payload = buildMarkPayload(
        showMeta,
        epMeta,
        episodeIndex,
        watchedKeys,
        !isWatched
      );
      const r = await api.post(isWatched ? '/api/tv/episodes/unmark' : '/api/tv/episodes/mark', payload);
      applyResponse(r);
    } finally {
      setToggling(null);
    }
  };

  const markSeason = async () => {
    const unwatched = seasonEpisodesMeta.filter(
      (ep) => !watchedKeys.has(episodeKey(ep.seasonNumber, ep.episodeNumber))
    );
    if (!unwatched.length) return;
    setBatching(true);
    try {
      const payload = buildBatchPayload(showMeta, unwatched, episodeIndex, watchedKeys, true);
      const r = await api.post('/api/tv/episodes/mark-batch', payload);
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
      const r = await api.post('/api/tv/episodes/unmark-batch', payload);
      applyResponse(r);
    } finally {
      setBatching(false);
    }
  };

  const markAllShow = async () => {
    const unwatched = episodeIndex.filter(
      (ep) => !watchedKeys.has(episodeKey(ep.seasonNumber, ep.episodeNumber))
    );
    if (!unwatched.length) return;
    setBatching(true);
    try {
      const payload = buildBatchPayload(showMeta, unwatched, episodeIndex, watchedKeys, true);
      const r = await api.post('/api/tv/episodes/mark-batch', payload);
      applyResponse(r);
    } finally {
      setBatching(false);
    }
  };

  const airdate = (prop) =>
    new Date(prop).toLocaleDateString('en-US', { day: 'numeric', month: 'short', year: 'numeric' });

  if (!orderedSeasons.length) return null;

  return (
    <section id="episodes" className="mt-8 md:mt-10 scroll-mt-24">
      <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
        <h3 className="section-title">Episodes</h3>
        {track && (
          <span className="text-xs text-muted">
            {track.watchedEpisodeCount || 0}/{track.totalEpisodes || totalEpisodes} episodes logged
          </span>
        )}
      </div>

      <div className="glass-card space-y-4 p-4 sm:p-5">
        <div>
          <label htmlFor="season-select" className="section-title mb-2 block normal-case tracking-wide">
            Season
          </label>
          <div className="relative">
            <select
              id="season-select"
              className="input-field min-h-[48px] appearance-none pr-10"
              value={selectedSeason}
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
            <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-surface-raised">
              <div
                className="h-full rounded-full bg-accent transition-all duration-300"
                style={{
                  width: `${progressPercent(seasonWatchedCount, seasonEpisodesMeta.length)}%`,
                }}
              />
            </div>
            <span className="text-[10px] font-bold tabular-nums text-muted">
              {seasonWatchedCount}/{seasonEpisodesMeta.length || '—'}
            </span>
          </div>
          {!seasonComplete ? (
            <button
              type="button"
              disabled={batching || !seasonEpisodesMeta.length}
              onClick={markSeason}
              className="btn-secondary !min-h-[40px] !px-3 !py-2 !text-xs disabled:opacity-50"
            >
              Mark season
            </button>
          ) : (
            <button
              type="button"
              disabled={batching}
              onClick={unmarkSeason}
              className="btn-ghost !min-h-[40px] border border-border !px-3 !py-2 !text-xs disabled:opacity-50"
            >
              Unmark season
            </button>
          )}
          <button
            type="button"
            disabled={batching}
            onClick={markAllShow}
            className="btn-primary !min-h-[40px] !px-3 !py-2 !text-xs disabled:opacity-50"
          >
            Mark all
          </button>
        </div>

        {loadingSeason ? (
          <div className="space-y-2">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-16 animate-pulse rounded-xl bg-surface-raised" />
            ))}
          </div>
        ) : (
          <div className="space-y-2">
            {seasonEpisodes.map((episode) => {
              const key = episodeKey(selectedSeason, episode.episode_number);
              const isWatched = watchedKeys.has(key);
              const isNext = key === nextKey;

              return (
                <article
                  key={episode.id}
                  className={`flex gap-3 rounded-xl border border-border/60 bg-surface/50 p-3 transition-colors ${
                    isNext ? 'ring-2 ring-accent/40' : ''
                  }`}
                >
                  <button
                    type="button"
                    disabled={toggling === key || batching}
                    onClick={() => toggleEpisode(episode)}
                    aria-label={isWatched ? 'Mark unwatched' : 'Mark watched'}
                    className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-xl border-2 transition-all cursor-pointer disabled:opacity-50 ${
                      isWatched
                        ? 'border-accent bg-accent text-on-accent'
                        : 'border-border bg-surface hover:border-accent/50'
                    }`}
                  >
                    {isWatched && <Check className="h-5 w-5" strokeWidth={3} />}
                  </button>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-semibold leading-snug">
                      <span className="text-accent">{episode.episode_number}.</span> {episode.name}
                      {isNext && (
                        <span className="ml-2 text-[10px] font-bold uppercase tracking-wide text-accent">
                          Up next
                        </span>
                      )}
                    </p>
                    <p className="mt-0.5 flex flex-wrap gap-x-2 text-xs text-muted">
                      {episode.air_date ? airdate(episode.air_date) : '—'}
                      {episode.runtime > 0 && <span>{episode.runtime} min</span>}
                      {episode.vote_average > 0 && (
                        <span className="inline-flex items-center gap-0.5">
                          <Star className="h-3 w-3 fill-accent text-accent" />
                          {Number(episode.vote_average).toFixed(1)}
                        </span>
                      )}
                    </p>
                  </div>
                </article>
              );
            })}
          </div>
        )}
      </div>
    </section>
  );
}
