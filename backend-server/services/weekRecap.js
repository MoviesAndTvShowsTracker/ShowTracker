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

  // Prefer dashboard cache when it was built for the same timezone contract.
  // Never reuse the dashboard year insight here — Lobby’s card is “this week.”
  if (cached?.stats?.activity && cached.stats.timeZone === timeZone) {
    const { activity, films, week } = cached.stats;
    const episodesThisWeek = week?.episodeCount ?? activity.episodesThisWeek ?? 0;
    const filmsThisWeek = week?.filmCount ?? films?.thisWeek ?? 0;
    const tvMinsThisWeek = week?.tvMins ?? activity.tvMinsThisWeek ?? 0;
    const filmMinsThisWeek = week?.filmMins ?? films?.filmMinsThisWeek ?? 0;
    const totalMinsThisWeek = week?.totalMins ?? activity.totalMinsThisWeek ?? 0;
    const streak = activity.streak || 0;
    return {
      episodesThisWeek,
      filmsThisWeek,
      tvMinsThisWeek,
      filmMinsThisWeek,
      totalMinsThisWeek,
      streak,
      insight: buildWeekInsight({
        filmsThisWeek,
        episodesThisWeek,
        totalMinsThisWeek,
        streak,
      }),
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

  // Unique titles for the week card; every play date feeds the streak.
  const films = dedupeFilms(weekFilms);
  const allFilmKeys = allFilms
    .filter((f) => f.watchedAt)
    .map((f) => dateKeyInZone(f.watchedAt, timeZone));
  const daySet = new Set([
    ...allEpisodes.filter((ep) => ep.watchedAt).map((ep) => dateKeyInZone(ep.watchedAt, timeZone)),
    ...allFilmKeys,
  ]);

  const episodesThisWeek = weekEpisodes.length;
  const filmsThisWeek = films.length;
  const tvMinsThisWeek = weekEpisodes.reduce((s, ep) => s + (ep.runtimeMinutes || 0), 0);
  const filmMinsThisWeek = weekFilms.reduce((s, f) => s + filmRuntimeMinutes(f), 0);
  const totalMinsThisWeek = tvMinsThisWeek + filmMinsThisWeek;
  const streak = computeStreakFromDaySet(daySet, bounds.todayKey);

  return {
    episodesThisWeek,
    filmsThisWeek,
    tvMinsThisWeek,
    filmMinsThisWeek,
    totalMinsThisWeek,
    streak,
    insight: buildWeekInsight({
      filmsThisWeek,
      episodesThisWeek,
      totalMinsThisWeek,
      streak,
    }),
    weekStart: bounds.weekStart,
    timeZone,
    cached: false,
  };
}

function buildWeekInsight({ filmsThisWeek, episodesThisWeek, totalMinsThisWeek, streak }) {
  if (!filmsThisWeek && !episodesThisWeek && !totalMinsThisWeek) {
    return {
      kind: 'empty',
      text: 'Mark a film or episode and this week fills in.',
    };
  }

  const bits = [];
  if (filmsThisWeek > 0) {
    bits.push(`${filmsThisWeek} film${filmsThisWeek === 1 ? '' : 's'}`);
  }
  if (episodesThisWeek > 0) {
    bits.push(`${episodesThisWeek} episode${episodesThisWeek === 1 ? '' : 's'}`);
  }

  if (bits.length === 2) {
    return { kind: 'mix', text: `${bits[0]} and ${bits[1]} this week.` };
  }
  if (filmsThisWeek > 0) {
    return { kind: 'films', text: `${bits[0]} logged this week.` };
  }
  if (episodesThisWeek > 0) {
    return {
      kind: 'episodes',
      text:
        streak > 1
          ? `${bits[0]} this week — streak still warm.`
          : `${bits[0]} this week. No films yet.`,
    };
  }
  return { kind: 'time', text: 'Time is on the clock — keep going.' };
}

module.exports = { buildWeekRecap, buildWeekInsight };
