const TvEpisodeWatch = require('../models/tvEpisodeWatch');
const Watch = require('../models/watch');
const { getCachedUserStats } = require('./statsCache');
const { filmRuntimeMinutes } = require('./mediaMeta');

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

async function buildWeekRecap(userId) {
  const cached = await getCachedUserStats(userId);
  if (cached?.stats?.activity) {
    const { activity, films } = cached.stats;
    return {
      episodesThisWeek: activity.episodesThisWeek || 0,
      filmsThisWeek: films?.thisWeek || 0,
      tvMinsThisWeek: activity.tvMinsThisWeek || 0,
      filmMinsThisWeek: films?.filmMinsThisWeek || 0,
      streak: activity.streak || 0,
      cached: true,
    };
  }

  const weekStart = daysAgo(7);
  const [weekEpisodes, weekFilms, allEpisodes] = await Promise.all([
    TvEpisodeWatch.find({ userFrom: userId, watchedAt: { $gte: weekStart } }),
    Watch.find({ userFrom: userId, watchedAt: { $gte: weekStart } }),
    TvEpisodeWatch.find({ userFrom: userId }).select('watchedAt'),
  ]);

  return {
    episodesThisWeek: weekEpisodes.length,
    filmsThisWeek: weekFilms.length,
    tvMinsThisWeek: weekEpisodes.reduce((s, ep) => s + (ep.runtimeMinutes || 0), 0),
    filmMinsThisWeek: weekFilms.reduce((s, f) => s + filmRuntimeMinutes(f), 0),
    streak: computeStreak(allEpisodes),
    cached: false,
  };
}

module.exports = { buildWeekRecap };
