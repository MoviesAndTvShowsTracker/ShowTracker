import { tmdbFetch } from './tmdb';

export function episodeKey(seasonNumber, episodeNumber) {
  return `${seasonNumber}-${episodeNumber}`;
}

export function parseEpisodeKey(key) {
  const [s, e] = key.split('-').map(Number);
  return { seasonNumber: s, episodeNumber: e };
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
      });
    });
  });

  episodes.sort((a, b) =>
    a.seasonNumber !== b.seasonNumber
      ? a.seasonNumber - b.seasonNumber
      : a.episodeNumber - b.episodeNumber
  );

  return { show, episodes, totalEpisodes };
}

export function watchedSetFromEpisodes(episodes) {
  return new Set(episodes.map((ep) => episodeKey(ep.seasonNumber, ep.episodeNumber)));
}

export function findNextEpisode(episodeIndex, watchedKeys) {
  return episodeIndex.find(
    (ep) => !watchedKeys.has(episodeKey(ep.seasonNumber, ep.episodeNumber))
  );
}

export function progressPercent(watchedCount, totalEpisodes) {
  if (!totalEpisodes) return 0;
  return Math.min(100, Math.round((watchedCount / totalEpisodes) * 100));
}

export function buildBatchPayload(showMeta, episodesToMark, episodeIndex, watchedKeys, marking = true) {
  const keys = new Set(watchedKeys);
  episodesToMark.forEach((ep) => {
    const key = episodeKey(ep.seasonNumber, ep.episodeNumber);
    if (marking) keys.add(key);
    else keys.delete(key);
  });
  const next = findNextEpisode(episodeIndex, keys);

  return {
    tvId: String(showMeta.id || showMeta.tvId),
    tvTitle: showMeta.name || showMeta.tvTitle,
    tvPosterImage: showMeta.poster_path || showMeta.tvPosterImage,
    tvBackdropImage: showMeta.backdrop_path || showMeta.tvBackdropImage,
    totalEpisodes: showMeta.totalEpisodes ?? showMeta.number_of_episodes,
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

  return {
    tvId: String(showMeta.id || showMeta.tvId),
    tvTitle: showMeta.name || showMeta.tvTitle,
    tvPosterImage: showMeta.poster_path || showMeta.tvPosterImage,
    tvBackdropImage: showMeta.backdrop_path || showMeta.tvBackdropImage,
    totalEpisodes: showMeta.totalEpisodes ?? showMeta.number_of_episodes,
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
