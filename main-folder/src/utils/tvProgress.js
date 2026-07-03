import { tmdbFetch } from './tmdb';

export function episodeKey(seasonNumber, episodeNumber) {
  return `${seasonNumber}-${episodeNumber}`;
}

export function parseEpisodeKey(key) {
  const [s, e] = key.split('-').map(Number);
  return { seasonNumber: s, episodeNumber: e };
}

export function parseAirDate(airDate) {
  if (!airDate) return null;
  const d = new Date(`${airDate}T12:00:00`);
  return Number.isNaN(d.getTime()) ? null : d;
}

/** Episode is available to watch (aired today or earlier). */
export function isEpisodeAired(ep, now = new Date()) {
  const d = parseAirDate(ep.airDate);
  if (!d) return true;
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const airDay = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  return airDay <= today;
}

export function getAiredEpisodes(episodes, now = new Date()) {
  return episodes.filter((ep) => isEpisodeAired(ep, now));
}

export function countAiredEpisodes(episodes, now = new Date()) {
  return getAiredEpisodes(episodes, now).length;
}

/** Build ordered episode list (skips season 0 specials). */
export async function fetchShowEpisodeIndex(tvId) {
  const show = await tmdbFetch(`tv/${tvId}`);
  const seasons = (show.seasons || []).filter((s) => s.season_number > 0);
  const totalEpisodes = seasons.reduce((sum, s) => sum + (s.episode_count || 0), 0);

  const seasonDetails = await Promise.all(
    seasons.map((s) =>
      tmdbFetch(`tv/${tvId}/season/${s.season_number}`).catch(() => ({ episodes: [] }))
    )
  );

  const episodes = [];
  seasonDetails.forEach((detail, i) => {
    const seasonNum = seasons[i].season_number;
    (detail.episodes || []).forEach((ep) => {
      episodes.push({
        seasonNumber: seasonNum,
        episodeNumber: ep.episode_number,
        tmdbEpisodeId: String(ep.id),
        episodeName: ep.name,
        runtimeMinutes: ep.runtime || 0,
        airDate: ep.air_date || null,
      });
    });
  });

  episodes.sort((a, b) =>
    a.seasonNumber !== b.seasonNumber
      ? a.seasonNumber - b.seasonNumber
      : a.episodeNumber - b.episodeNumber
  );

  const airedEpisodeCount = countAiredEpisodes(episodes);

  return { show, episodes, totalEpisodes, airedEpisodeCount };
}

export function watchedSetFromEpisodes(episodes) {
  return new Set(episodes.map((ep) => episodeKey(ep.seasonNumber, ep.episodeNumber)));
}

export function findNextEpisode(episodeIndex, watchedKeys, now = new Date()) {
  return episodeIndex.find(
    (ep) =>
      isEpisodeAired(ep, now) &&
      !watchedKeys.has(episodeKey(ep.seasonNumber, ep.episodeNumber))
  );
}

export function findNextUnairedEpisode(episodeIndex, now = new Date()) {
  return episodeIndex.find((ep) => !isEpisodeAired(ep, now) && ep.airDate);
}

export function formatEpisodeReleaseLabel(airDate, now = new Date()) {
  const d = parseAirDate(airDate);
  if (!d) return null;
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const airDay = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const diffDays = Math.round((airDay - today) / 86400000);
  if (diffDays <= 0) return null;
  if (diffDays === 1) return 'Tomorrow';
  if (diffDays < 14) return `in ${diffDays} days`;
  const weeks = Math.round(diffDays / 7);
  if (diffDays < 60) return `in ${weeks} week${weeks === 1 ? '' : 's'}`;
  return airDay.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

export function progressPercent(watchedCount, totalEpisodes) {
  if (!totalEpisodes) return 0;
  return Math.min(100, Math.round((watchedCount / totalEpisodes) * 100));
}

/** Progress vs aired episodes only; handles catch-up and upcoming releases. */
export function deriveShowProgress(track, episodeIndex, watchedKeys = null, now = new Date()) {
  const watchedCount = watchedKeys?.size ?? track?.watchedEpisodeCount ?? 0;
  const airedTotal = countAiredEpisodes(episodeIndex, now);
  const totalEpisodes = episodeIndex.length || track?.totalEpisodes || 0;
  const progressTotal = airedTotal || track?.airedEpisodeCount || track?.totalEpisodes || 0;
  const pct = progressPercent(watchedCount, progressTotal);
  const keys =
    watchedKeys ||
    (track?.watchedEpisodeCount
      ? null
      : new Set());

  const nextAired = keys ? findNextEpisode(episodeIndex, keys, now) : null;
  const caughtUpWithAired = airedTotal > 0 && watchedCount >= airedTotal;
  const nextUnaired = caughtUpWithAired ? findNextUnairedEpisode(episodeIndex, now) : null;
  const upcomingLabel =
    caughtUpWithAired && nextUnaired ? formatEpisodeReleaseLabel(nextUnaired.airDate, now) : null;
  const fullyComplete =
    totalEpisodes > 0 && watchedCount >= totalEpisodes && watchedCount >= airedTotal;

  return {
    airedTotal,
    totalEpisodes,
    pct,
    caughtUpWithAired,
    fullyComplete,
    nextAired,
    nextUnaired,
    upcomingLabel,
    isComplete: fullyComplete || (caughtUpWithAired && !nextUnaired),
  };
}

export function buildBatchPayload(showMeta, episodesToMark, episodeIndex, watchedKeys, marking = true) {
  const keys = new Set(watchedKeys);
  episodesToMark.forEach((ep) => {
    const key = episodeKey(ep.seasonNumber, ep.episodeNumber);
    if (marking) keys.add(key);
    else keys.delete(key);
  });
  const next = findNextEpisode(episodeIndex, keys);
  const airedEpisodeCount = countAiredEpisodes(episodeIndex);

  return {
    tvId: String(showMeta.id || showMeta.tvId),
    tvTitle: showMeta.name || showMeta.tvTitle,
    tvPosterImage: showMeta.poster_path || showMeta.tvPosterImage,
    tvBackdropImage: showMeta.backdrop_path || showMeta.tvBackdropImage,
    totalEpisodes: showMeta.totalEpisodes ?? showMeta.number_of_episodes,
    airedEpisodeCount,
    episodes: episodesToMark.map((ep) => ({
      seasonNumber: ep.seasonNumber,
      episodeNumber: ep.episodeNumber,
      tmdbEpisodeId: ep.tmdbEpisodeId,
      episodeName: ep.episodeName,
      runtimeMinutes: ep.runtimeMinutes || 0,
    })),
    nextSeason: next?.seasonNumber ?? null,
    nextEpisode: next?.episodeNumber ?? null,
    nextEpisodeName: next?.episodeName ?? null,
  };
}

export function episodeFromTmdb(seasonNumber, ep) {
  return {
    seasonNumber,
    episodeNumber: ep.episode_number,
    tmdbEpisodeId: String(ep.id),
    episodeName: ep.name,
    runtimeMinutes: ep.runtime || 0,
    airDate: ep.air_date || null,
  };
}

export function buildMarkPayload(showMeta, episode, episodeIndex, watchedKeys, afterMark = true) {
  const keys = new Set(watchedKeys);
  if (afterMark) {
    keys.add(episodeKey(episode.seasonNumber, episode.episodeNumber));
  } else {
    keys.delete(episodeKey(episode.seasonNumber, episode.episodeNumber));
  }
  const next = findNextEpisode(episodeIndex, keys);
  const airedEpisodeCount = countAiredEpisodes(episodeIndex);

  return {
    tvId: String(showMeta.id || showMeta.tvId),
    tvTitle: showMeta.name || showMeta.tvTitle,
    tvPosterImage: showMeta.poster_path || showMeta.tvPosterImage,
    tvBackdropImage: showMeta.backdrop_path || showMeta.tvBackdropImage,
    totalEpisodes: showMeta.totalEpisodes ?? showMeta.number_of_episodes,
    airedEpisodeCount,
    seasonNumber: episode.seasonNumber,
    episodeNumber: episode.episodeNumber,
    tmdbEpisodeId: episode.tmdbEpisodeId,
    episodeName: episode.episodeName,
    runtimeMinutes: episode.runtimeMinutes || 0,
    nextSeason: next?.seasonNumber ?? null,
    nextEpisode: next?.episodeNumber ?? null,
    nextEpisodeName: next?.episodeName ?? null,
  };
}
