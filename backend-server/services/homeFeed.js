const TvShowTracking = require('../models/tvShowTracking');
const MovieWatchlist = require('../models/moviewatchlist');
const { getTvSeason } = require('../lib/tmdb');
const { autoPauseStaleTracks } = require('./tvTrackingMaintenance');
const { getQueuedTvWatchlist } = require('./tvWatchlistService');
const { buildActivity } = require('./diaryActivity');
const { buildWeekRecap } = require('./weekRecap');

const AIRING_DAYS = 7;
const RETURNING_DAYS = 30;

// Pure date helpers on 'YYYY-MM-DD' strings.

function dayKey(date, timeZone) {
  return new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(date);
}

function addDays(key, n) {
  const [y, m, d] = key.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d + n)).toISOString().slice(0, 10);
}

function inWindow(airDate, todayKey, days) {
  return typeof airDate === 'string' && airDate.length >= 10
    && airDate >= todayKey && airDate <= addDays(todayKey, days);
}

function agendaEpisode(track, ep, season, kind) {
  return {
    tvId: Number(track.tvId),
    title: track.tvTitle || track.tvName || 'Show',
    posterPath: track.tvPosterImage || track.tvPost || null,
    season: ep.season_number ?? season,
    episode: ep.episode_number,
    episodeName: ep.name || null,
    airDate: ep.air_date.slice(0, 10),
    kind,
  };
}

function upcomingFromSeason(track, seasonJson, todayKey, windowDays = AIRING_DAYS) {
  const season = track.nextSeason || 1;
  return (seasonJson?.episodes || [])
    .filter((ep) => inWindow(ep.air_date, todayKey, windowDays))
    .map((ep) => agendaEpisode(track, ep, season, 'airing'));
}

function firstReturnFromSeason(track, seasonJson, todayKey, windowDays = RETURNING_DAYS) {
  const first = (seasonJson?.episodes || []).find((ep) => (ep.air_date || '').length >= 10);
  if (!first || !inWindow(first.air_date, todayKey, windowDays)) return null;
  return agendaEpisode(track, first, seasonJson.season_number, 'returning');
}

function nextAirDateFor(track, agenda) {
  const hit = agenda.find((e) => e.kind === 'airing'
    && String(e.tvId) === String(track.tvId)
    && e.season === track.nextSeason
    && e.episode === track.nextEpisode);
  return hit ? hit.airDate : null;
}

function mergeAgenda(airing, returning) {
  const airingIds = new Set(airing.map((e) => e.tvId));
  const seen = new Set();
  return [...airing, ...returning.filter((e) => !airingIds.has(e.tvId))]
    .filter((e) => {
      const k = `${e.tvId}-${e.airDate}`;
      if (seen.has(k)) return false;
      seen.add(k);
      return true;
    })
    .sort((a, b) => a.airDate.localeCompare(b.airDate));
}

async function returningFor(track, todayKey) {
  const base = (track.lastSeason || track.nextSeason || 1) + 1;
  for (const season of [base, base + 1]) {
    const hit = firstReturnFromSeason(track, await getTvSeason(track.tvId, season), todayKey);
    if (hit) return hit;
  }
  return null;
}

/** Everything the iOS Home tab shows, in one response. */
async function buildHomeFeed(userId, { timeZone }) {
  await autoPauseStaleTracks(userId);
  const todayKey = dayKey(new Date(), timeZone);

  const [watching, paused, finished, films, tv, recent, recap] = await Promise.all([
    TvShowTracking.find({
      userFrom: userId,
      status: { $in: ['watching', 'rewatching'] },
      watchedEpisodeCount: { $gt: 0 },
    }).sort({ lastWatchedAt: -1, updatedAt: -1 }).limit(24).lean(),
    TvShowTracking.find({ userFrom: userId, status: 'paused' }).sort({ lastWatchedAt: -1, updatedAt: -1 }).lean(),
    TvShowTracking.find({ userFrom: userId, status: 'completed' }).sort({ lastWatchedAt: -1, updatedAt: -1 }).lean(),
    MovieWatchlist.find({ userFrom: userId }).sort({ updatedAt: -1, createdAt: -1, _id: -1 }).lean(),
    getQueuedTvWatchlist(userId),
    buildActivity(userId, 10),
    buildWeekRecap(userId, { timeZone }).catch(() => null),
  ]);

  const [airingLists, returning] = await Promise.all([
    Promise.all([...watching, ...paused].slice(0, 16).map(async (t) =>
      upcomingFromSeason(t, await getTvSeason(t.tvId, t.nextSeason || 1), todayKey))),
    Promise.all([...paused, ...finished].slice(0, 12).map((t) => returningFor(t, todayKey))),
  ]);

  const thisWeek = mergeAgenda(airingLists.flat(), returning.filter(Boolean));

  return {
    upNext: watching.map((track) => ({ track, nextAirDate: nextAirDateFor(track, thisWeek) })),
    pausedCount: paused.length,
    thisWeek,
    recent,
    recap,
    watchlist: { films, tv },
  };
}

module.exports = {
  dayKey,
  addDays,
  upcomingFromSeason,
  firstReturnFromSeason,
  nextAirDateFor,
  mergeAgenda,
  buildHomeFeed,
};
