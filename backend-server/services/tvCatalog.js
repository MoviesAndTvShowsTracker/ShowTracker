const tmdb = require('../lib/tmdb');

/**
 * A show's real episode list, from TMDB. The server uses it to decide the next episode,
 * totals and completion, so no client ever has to guess (e.g. "season + 1, episode 1").
 */

function regularSeasons(show) {
  return (show?.seasons || [])
    .filter((s) => s.season_number > 0 && s.episode_count > 0)
    .map((s) => ({ season: s.season_number, count: s.episode_count }))
    .sort((a, b) => a.season - b.season);
}

/** Episodes counted up to TMDB's last aired episode (specials excluded). */
function airedCount(seasons, lastAired) {
  if (!lastAired || !(lastAired.season_number > 0)) return 0;
  let count = 0;
  for (const s of seasons) {
    if (s.season < lastAired.season_number) count += s.count;
    else if (s.season === lastAired.season_number) count += Math.min(lastAired.episode_number, s.count);
  }
  return count;
}

/** { seasons, total, aired } or null when TMDB can't be reached. */
async function loadCatalog(tvId, deps = tmdb) {
  const show = await deps.getTvShow(tvId);
  if (!show) return null;
  const seasons = regularSeasons(show);
  if (!seasons.length) return null;
  const total = seasons.reduce((sum, s) => sum + s.count, 0);
  const aired = airedCount(seasons, show.last_episode_to_air);
  return { seasons, total, aired: aired || total };
}

function sortedEpisodes(seasonData) {
  return (seasonData?.episodes || [])
    .filter((e) => Number.isInteger(e.episode_number))
    .sort((a, b) => a.episode_number - b.episode_number);
}

/** True when TMDB lists this episode. A missing season list falls back to the season's count. */
async function episodeExists(tvId, catalog, season, episode, deps = tmdb) {
  const entry = catalog.seasons.find((s) => s.season === Number(season));
  if (!entry) return false;
  const data = await deps.getTvSeason(tvId, entry.season);
  if (!data) return Number(episode) >= 1 && Number(episode) <= entry.count;
  return sortedEpisodes(data).some((e) => e.episode_number === Number(episode));
}

/**
 * The episode after (season, episode), or null when that was the last one TMDB lists.
 * Pass no position to get the show's first episode.
 */
async function episodeAfter(tvId, catalog, position, deps = tmdb) {
  const fromSeason = position ? Number(position.season) : 0;
  const fromEpisode = position ? Number(position.episode) : 0;
  for (const s of catalog.seasons) {
    if (s.season < fromSeason) continue;
    const sameSeason = s.season === fromSeason;
    const data = await deps.getTvSeason(tvId, s.season);
    if (data) {
      const hit = sortedEpisodes(data).find((e) => !sameSeason || e.episode_number > fromEpisode);
      if (hit) return { season: s.season, episode: hit.episode_number, name: hit.name || null };
      continue;
    }
    // Season list unavailable: trust TMDB's episode count for that season.
    if (!sameSeason) return { season: s.season, episode: 1, name: null };
    if (fromEpisode < s.count) return { season: s.season, episode: fromEpisode + 1, name: null };
  }
  return null;
}

/**
 * Next episode and totals for a show given the furthest episode watched.
 * Null when TMDB is unavailable, so callers keep what they had.
 */
async function resolveProgress(tvId, furthest, deps = tmdb) {
  const catalog = await loadCatalog(tvId, deps);
  if (!catalog) return null;
  const next = await episodeAfter(tvId, catalog, furthest, deps);
  return {
    totalEpisodes: catalog.total,
    airedEpisodeCount: catalog.aired,
    nextSeason: next ? next.season : null,
    nextEpisode: next ? next.episode : null,
    nextEpisodeName: next ? next.name : null,
  };
}

/**
 * Status after a sync (not used during rewatches).
 * With TMDB's catalog: finished when nothing comes after the furthest episode watched and
 * nothing is still to air (raw counts can include specials, so they aren't trusted).
 * Without it: finished when the count reaches the stored total.
 */
function decideStatus({ status, count, total, aired, hasNext, resolved }) {
  const finished = resolved
    ? !hasNext && total > 0 && aired >= total
    : total > 0 && count >= total;
  if (finished) return 'completed';
  if (status === 'completed' || status === 'paused') return 'watching';
  return status;
}

module.exports = {
  airedCount,
  decideStatus,
  episodeAfter,
  episodeExists,
  loadCatalog,
  regularSeasons,
  resolveProgress,
};
