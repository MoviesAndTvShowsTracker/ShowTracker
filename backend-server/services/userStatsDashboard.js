const TvEpisodeWatch = require('../models/tvEpisodeWatch');
const TvShowTracking = require('../models/tvShowTracking');
const Watch = require('../models/watch');
const User = require('../models/user');
const { isCaughtUpWaiting } = require('./tvTrackingMaintenance');
const {
  applyFilmRuntimeBackfill,
  filmRuntimeMinutes,
  buildTasteProfile,
} = require('./mediaMeta');
const { getMovieMetaBatch } = require('../lib/tmdb');

const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

function startOfDay(d) {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
}

function dateKey(d) {
  return startOfDay(d).toISOString().slice(0, 10);
}

function daysAgo(n) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return startOfDay(d);
}

function countSince(episodes, since) {
  return episodes.filter((ep) => ep.watchedAt && new Date(ep.watchedAt) >= since).length;
}

function groupByDay(episodes) {
  const map = {};
  for (const ep of episodes) {
    if (!ep.watchedAt) continue;
    const k = dateKey(ep.watchedAt);
    if (!map[k]) map[k] = { episodes: 0, minutes: 0 };
    map[k].episodes += 1;
    map[k].minutes += ep.runtimeMinutes || 0;
  }
  return map;
}

function groupFilmsByDay(films) {
  const map = {};
  for (const f of films) {
    if (!f.watchedAt) continue;
    const k = dateKey(f.watchedAt);
    if (!map[k]) map[k] = { count: 0, minutes: 0 };
    map[k].count += 1;
    map[k].minutes += filmRuntimeMinutes(f);
  }
  return map;
}

function sumSinceDayMap(dayMap, since, field) {
  let total = 0;
  for (const [day, bucket] of Object.entries(dayMap)) {
    if (new Date(day) >= since) total += bucket[field] || 0;
  }
  return total;
}

function computeStreak(episodes) {
  if (!episodes.length) return 0;
  const daySet = new Set(episodes.filter((ep) => ep.watchedAt).map((ep) => dateKey(ep.watchedAt)));
  let streak = 0;
  const cursor = startOfDay(new Date());
  if (!daySet.has(dateKey(cursor))) {
    cursor.setDate(cursor.getDate() - 1);
  }
  while (daySet.has(dateKey(cursor))) {
    streak += 1;
    cursor.setDate(cursor.getDate() - 1);
  }
  return streak;
}

function busiestDayOfWeek(episodes) {
  const counts = [0, 0, 0, 0, 0, 0, 0];
  for (const ep of episodes) {
    if (!ep.watchedAt) continue;
    counts[new Date(ep.watchedAt).getDay()] += 1;
  }
  const max = Math.max(...counts);
  if (max === 0) return null;
  return { day: DAY_NAMES[counts.indexOf(max)], count: max };
}

function biggestBinge(byDay) {
  let best = null;
  for (const [date, bucket] of Object.entries(byDay)) {
    const count = bucket.episodes || 0;
    if (!best || count > best.count) best = { date, count };
  }
  return best;
}

function computeBacklog(tracks) {
  let backlog = 0;
  for (const t of tracks) {
    if (t.status !== 'watching') continue;
    const aired = t.airedEpisodeCount || 0;
    const watched = t.watchedEpisodeCount || 0;
    if (aired > watched) backlog += aired - watched;
  }
  return backlog;
}

function weeklyTrendFromDayMap(dayMap, weeks = 12) {
  const result = [];
  for (let w = weeks - 1; w >= 0; w -= 1) {
    let episodes = 0;
    let minutes = 0;
    const weekEnd = daysAgo(w * 7);
    const weekStart = daysAgo(w * 7 + 6);
    for (let d = new Date(weekStart); d <= weekEnd; d.setDate(d.getDate() + 1)) {
      const bucket = dayMap[dateKey(d)];
      if (!bucket) continue;
      episodes += bucket.episodes ?? bucket.count ?? 0;
      minutes += bucket.minutes || 0;
    }
    result.push({ weekStart: dateKey(weekStart), episodes, minutes });
  }
  return result;
}

function filmExtremes(films) {
  const withRuntime = films
    .map((f) => ({
      movieId: f.movieId,
      movieTitle: f.movieTitle,
      minutes: filmRuntimeMinutes(f),
    }))
    .filter((f) => f.minutes > 0);

  if (!withRuntime.length) return { longest: null, shortest: null };

  const sorted = [...withRuntime].sort((a, b) => a.minutes - b.minutes);
  return {
    longest: sorted[sorted.length - 1],
    shortest: sorted[0],
  };
}

function computeMilestones({ episodeCount, totalMins, completedShows }) {
  const reached = [];
  const epTargets = [100, 500, 1000, 2500, 5000];
  for (const t of epTargets) {
    if (episodeCount >= t) reached.push({ key: `ep-${t}`, label: `${t.toLocaleString()} episodes logged` });
  }
  const hours = totalMins / 60;
  for (const t of [24, 100, 500, 1000]) {
    if (hours >= t) reached.push({ key: `hr-${t}`, label: `${t} hours of screen time` });
  }
  if (completedShows >= 1) {
    reached.push({ key: 'first-finish', label: 'Finished your first series' });
  }
  if (completedShows >= 10) {
    reached.push({ key: 'ten-finish', label: '10 series completed' });
  }
  return reached.slice(-8);
}

async function buildUserStatsDashboard(userId) {
  let [episodes, tracks, films, user] = await Promise.all([
    TvEpisodeWatch.find({ userFrom: userId }).lean(),
    TvShowTracking.find({ userFrom: userId }).lean(),
    Watch.find({ userFrom: userId }).sort({ watchedAt: -1 }).lean(),
    User.findById(userId).lean(),
  ]);

  const missingRuntimeIds = films.filter((f) => !filmRuntimeMinutes(f)).map((f) => f.movieId);
  const { map: filmMetaMap, fetchesRemaining: filmMetaPending } = await getMovieMetaBatch(
    films.map((f) => f.movieId),
    { priorityIds: missingRuntimeIds, maxFetches: 30 }
  );
  const backfilled = await applyFilmRuntimeBackfill(films, filmMetaMap, 30);

  const trackingMap = new Map(tracks.map((t) => [t.tvId, t]));
  const byDay = groupByDay(episodes);
  const filmsByDay = groupFilmsByDay(films);
  const tvMins = episodes.reduce((s, ep) => s + (ep.runtimeMinutes || 0), 0);
  const filmMins = films.reduce((s, f) => s + filmRuntimeMinutes(f), 0);
  const now = new Date();
  const weekStart = daysAgo(7);
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const yearStart = new Date(now.getFullYear(), 0, 1);
  const { longest: longestFilm, shortest: shortestFilm } = filmExtremes(films);

  const library = {
    watching: tracks.filter((t) => t.status === 'watching').length,
    stopped: tracks.filter((t) => t.status === 'paused').length,
    finished: tracks.filter((t) => t.status === 'completed').length,
  };

  const lastWatchedAt = episodes.reduce((max, ep) => {
    if (!ep.watchedAt) return max;
    const t = new Date(ep.watchedAt);
    return !max || t > max ? t : max;
  }, null);

  const totalMins = tvMins + filmMins;
  const tvShowCount = new Set(episodes.map((e) => e.tvId)).size;
  const filmsWithRuntime = films.filter((f) => filmRuntimeMinutes(f) > 0).length;

  const taste = await buildTasteProfile(films, episodes, filmMetaMap, {
    filmFetchesRemaining: filmMetaPending,
  });

  return {
    memberSince: user?.createdAt || null,
    overview: {
      filmCount: films.length,
      tvShowCount,
      episodeCount: episodes.length,
      filmMins,
      tvMins,
      totalMins,
      filmShare: totalMins > 0 ? Math.round((filmMins / totalMins) * 100) : 0,
      tvShare: totalMins > 0 ? Math.round((tvMins / totalMins) * 100) : 0,
    },
    library: {
      ...library,
      caughtUp: tracks.filter((t) => isCaughtUpWaiting(t)).length,
      backlog: computeBacklog(tracks),
      totalTracked: tracks.length,
    },
    activity: {
      episodesThisWeek: countSince(episodes, weekStart),
      episodesThisMonth: countSince(episodes, monthStart),
      episodesThisYear: countSince(episodes, yearStart),
      tvMinsThisWeek: sumSinceDayMap(byDay, weekStart, 'minutes'),
      tvMinsThisMonth: sumSinceDayMap(byDay, monthStart, 'minutes'),
      streak: computeStreak(episodes),
      busiestDay: busiestDayOfWeek(episodes),
      lastWatchedAt,
      weeklyTrend: weeklyTrendFromDayMap(byDay, 12),
    },
    films: {
      count: films.length,
      filmMins,
      withRuntime: filmsWithRuntime,
      runtimeBackfilled: backfilled,
      thisWeek: films.filter((f) => f.watchedAt && new Date(f.watchedAt) >= weekStart).length,
      thisMonth: films.filter((f) => f.watchedAt && new Date(f.watchedAt) >= monthStart).length,
      thisYear: films.filter((f) => f.watchedAt && new Date(f.watchedAt) >= yearStart).length,
      filmMinsThisWeek: sumSinceDayMap(filmsByDay, weekStart, 'minutes'),
      filmMinsThisMonth: sumSinceDayMap(filmsByDay, monthStart, 'minutes'),
      filmMinsThisYear: sumSinceDayMap(filmsByDay, yearStart, 'minutes'),
      avgRuntime: filmsWithRuntime ? Math.round(filmMins / filmsWithRuntime) : 0,
      longest: longestFilm,
      shortest: shortestFilm,
      weeklyTrend: weeklyTrendFromDayMap(filmsByDay, 12),
      shareOfScreenTime: tvMins + filmMins > 0 ? Math.round((filmMins / (tvMins + filmMins)) * 100) : 0,
    },
    funFacts: {
      biggestBinge: biggestBinge(byDay),
      avgEpisodeMins: episodes.length ? Math.round(tvMins / episodes.length) : 0,
    },
    milestones: computeMilestones({
      episodeCount: episodes.length,
      totalMins,
      completedShows: library.finished,
    }),
    taste,
    metaPending: Boolean(taste?.partial),
  };
}

module.exports = { buildUserStatsDashboard };
