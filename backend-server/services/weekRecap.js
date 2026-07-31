const TvEpisodeWatch = require('../models/tvEpisodeWatch');
const Watch = require('../models/watch');
const { getCachedUserStats } = require('./statsCache');
const { filmRuntimeMinutes } = require('./mediaMeta');
const {
  resolveTimeZone,
  periodBounds,
  dateKeyInZone,
  computeStreakFromDaySet,
} = require('./statsCalendar');
const { dedupeFilms } = require('./filmDedupe');

async function buildWeekRecap(userId, options = {}) {
  const timeZone = resolveTimeZone(options.timeZone);
  const cached = await getCachedUserStats(userId);

  // Prefer dashboard cache when it was built for the same timezone contract
  if (cached?.stats?.activity && cached.stats.timeZone === timeZone) {
    const { activity, films, week, insight } = cached.stats;
    return {
      episodesThisWeek: week?.episodeCount ?? activity.episodesThisWeek ?? 0,
      filmsThisWeek: week?.filmCount ?? films?.thisWeek ?? 0,
      tvMinsThisWeek: week?.tvMins ?? activity.tvMinsThisWeek ?? 0,
      filmMinsThisWeek: week?.filmMins ?? films?.filmMinsThisWeek ?? 0,
      totalMinsThisWeek: week?.totalMins ?? activity.totalMinsThisWeek ?? 0,
      streak: activity.streak || 0,
      insight: insight || null,
      weekStart: cached.stats.weekStart || null,
      timeZone,
      cached: true,
    };
  }

  const bounds = periodBounds(timeZone);
  const [weekEpisodes, weekFilms, allEpisodes, allFilms] = await Promise.all([
    TvEpisodeWatch.find({
      userFrom: userId,
      watchedAt: { $gte: bounds.weekStartDate },
    }).lean(),
    Watch.find({
      userFrom: userId,
      watchedAt: { $gte: bounds.weekStartDate },
    }).lean(),
    TvEpisodeWatch.find({ userFrom: userId }).select('watchedAt').lean(),
    Watch.find({ userFrom: userId }).select('watchedAt movieId').lean(),
  ]);

  const films = dedupeFilms(weekFilms);
  const allFilmKeys = dedupeFilms(allFilms)
    .filter((f) => f.watchedAt)
    .map((f) => dateKeyInZone(f.watchedAt, timeZone));
  const daySet = new Set([
    ...allEpisodes.filter((ep) => ep.watchedAt).map((ep) => dateKeyInZone(ep.watchedAt, timeZone)),
    ...allFilmKeys,
  ]);

  return {
    episodesThisWeek: weekEpisodes.length,
    filmsThisWeek: films.length,
    tvMinsThisWeek: weekEpisodes.reduce((s, ep) => s + (ep.runtimeMinutes || 0), 0),
    filmMinsThisWeek: films.reduce((s, f) => s + filmRuntimeMinutes(f), 0),
    totalMinsThisWeek:
      weekEpisodes.reduce((s, ep) => s + (ep.runtimeMinutes || 0), 0) +
      films.reduce((s, f) => s + filmRuntimeMinutes(f), 0),
    streak: computeStreakFromDaySet(daySet, bounds.todayKey),
    weekStart: bounds.weekStart,
    timeZone,
    cached: false,
  };
}

module.exports = { buildWeekRecap };
