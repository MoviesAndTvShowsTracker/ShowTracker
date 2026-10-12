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
const {
  dateKeyInZone,
  periodBounds,
  isOnOrAfterKey,
  computeStreakFromDaySet,
  longestStreakFromDaySet,
  trailingMonthKeys,
  busiestWeekdayFromDayKeys,
  calendarWeeklyTrend,
  weekdayOfKey,
  addDaysToKey,
  resolveTimeZone,
} = require('./statsCalendar');
const { dedupeFilms } = require('./filmDedupe');

function buildCombinedDayMap(episodes, films, timeZone) {
  const map = {};
  for (const ep of episodes) {
    if (!ep.watchedAt) continue;
    const k = dateKeyInZone(ep.watchedAt, timeZone);
    if (!map[k]) map[k] = { episodes: 0, films: 0, tvMinutes: 0, filmMinutes: 0 };
    map[k].episodes += 1;
    map[k].tvMinutes += ep.runtimeMinutes || 0;
  }
  for (const f of films) {
    if (!f.watchedAt) continue;
    const k = dateKeyInZone(f.watchedAt, timeZone);
    if (!map[k]) map[k] = { episodes: 0, films: 0, tvMinutes: 0, filmMinutes: 0 };
    map[k].films += 1;
    map[k].filmMinutes += filmRuntimeMinutes(f);
  }
  return map;
}

function sumFieldSince(dayMap, boundKey, field) {
  let total = 0;
  for (const [day, bucket] of Object.entries(dayMap)) {
    if (isOnOrAfterKey(day, boundKey)) total += bucket[field] || 0;
  }
  return total;
}

function countItemsSince(items, boundDate, getAt = (x) => x.watchedAt) {
  return items.filter((item) => {
    const at = getAt(item);
    return at && new Date(at) >= boundDate;
  }).length;
}

function biggestBinge(dayMap) {
  let best = null;
  for (const [date, bucket] of Object.entries(dayMap)) {
    const count = (bucket.episodes || 0) + (bucket.films || 0);
    const minutes = (bucket.tvMinutes || 0) + (bucket.filmMinutes || 0);
    if (!best || count > best.count || (count === best.count && minutes > best.minutes)) {
      best = {
        date,
        count,
        episodes: bucket.episodes || 0,
        films: bucket.films || 0,
        minutes,
      };
    }
  }
  return best;
}

/** Active days inside the heatmap window, oldest first. */
function dailyActivityWindow(dayMap, todayKey, days = 371) {
  const from = addDaysToKey(todayKey, -(days - 1));
  return Object.entries(dayMap)
    .filter(([key]) => key >= from && key <= todayKey)
    .sort((a, b) => (a[0] < b[0] ? -1 : 1))
    .map(([date, bucket]) => ({
      date,
      episodes: bucket.episodes || 0,
      films: bucket.films || 0,
      minutes: (bucket.tvMinutes || 0) + (bucket.filmMinutes || 0),
    }));
}

function monthlyTrend(dayMap, timeZone, now) {
  const keys = trailingMonthKeys(timeZone, 12, now);
  const totals = new Map(keys.map((k) => [k, { episodes: 0, films: 0, minutes: 0 }]));

  for (const [day, bucket] of Object.entries(dayMap)) {
    const monthKey = day.slice(0, 7);
    const entry = totals.get(monthKey);
    if (!entry) continue;
    entry.episodes += bucket.episodes || 0;
    entry.films += bucket.films || 0;
    entry.minutes += (bucket.tvMinutes || 0) + (bucket.filmMinutes || 0);
  }

  return keys.map((month) => ({ month, ...totals.get(month) }));
}

function totalsForYear(dayMap, year) {
  const prefix = `${year}-`;
  let episodes = 0;
  let films = 0;
  let minutes = 0;
  for (const [day, bucket] of Object.entries(dayMap)) {
    if (!day.startsWith(prefix)) continue;
    episodes += bucket.episodes || 0;
    films += bucket.films || 0;
    minutes += (bucket.tvMinutes || 0) + (bucket.filmMinutes || 0);
  }
  return { episodeCount: episodes, filmCount: films, totalMins: minutes };
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

/** Average + top-rated across any item list with a `rating` field (1..10). */
function ratingSummary(items, keyFn) {
  const rated = items.filter((it) => Number.isFinite(it.rating) && it.rating > 0);
  if (!rated.length) {
    return { count: 0, average: 0, top: null };
  }
  const sum = rated.reduce((acc, it) => acc + it.rating, 0);
  const average = Math.round((sum / rated.length) * 10) / 10 / 2; // stored 1..10 -> 0.5..5 average
  const top = [...rated].sort((a, b) => (b.rating || 0) - (a.rating || 0))[0];
  return {
    count: rated.length,
    average,
    top: top ? { ...keyFn(top), rating: top.rating / 2 } : null,
  };
}

function mostWatchedShow(episodes, tracks) {
  if (!episodes.length) return null;
  const counts = new Map();
  const mins = new Map();
  for (const ep of episodes) {
    counts.set(ep.tvId, (counts.get(ep.tvId) || 0) + 1);
    mins.set(ep.tvId, (mins.get(ep.tvId) || 0) + (ep.runtimeMinutes || 0));
  }
  let topId = null;
  let topCount = 0;
  for (const [tvId, count] of counts.entries()) {
    if (count > topCount) {
      topId = tvId;
      topCount = count;
    }
  }
  if (!topId) return null;
  const track = tracks.find((t) => String(t.tvId) === String(topId));
  return {
    tvId: topId,
    tvTitle: track?.tvTitle || null,
    tvPosterImage: track?.tvPosterImage || null,
    episodeCount: topCount,
    minutes: mins.get(topId) || 0,
  };
}

function computeMilestones({ episodeCount, filmCount, totalMins, completedShows }) {
  const reached = [];
  const epTargets = [100, 500, 1000, 2500, 5000];
  for (const t of epTargets) {
    if (episodeCount >= t) {
      reached.push({ key: `ep-${t}`, label: `${t.toLocaleString()} episodes logged` });
    }
  }
  const filmTargets = [25, 50, 100, 250, 500];
  for (const t of filmTargets) {
    if (filmCount >= t) {
      reached.push({ key: `film-${t}`, label: `${t} films logged` });
    }
  }
  const hours = totalMins / 60;
  for (const t of [24, 100, 500, 1000]) {
    if (hours >= t) {
      reached.push({ key: `hr-${t}`, label: `${t} hours estimated watch time` });
    }
  }
  if (completedShows >= 1) {
    reached.push({ key: 'first-finish', label: 'Finished your first series' });
  }
  if (completedShows >= 10) {
    reached.push({ key: 'ten-finish', label: '10 series completed' });
  }
  return reached.slice(-8);
}

function pct(part, whole) {
  if (!whole) return 0;
  return Math.round((part / whole) * 100);
}

function buildInsight({ overview, activity, year, taste, funFacts, mostWatched }) {
  if (activity.streak > 1) {
    return {
      kind: 'streak',
      text: `${activity.streak}-day watching streak — keep it going.`,
    };
  }
  if (year.totalMins > 0 || year.episodeCount > 0 || year.filmCount > 0) {
    const parts = [];
    if (year.filmCount) parts.push(`${year.filmCount} film${year.filmCount === 1 ? '' : 's'}`);
    if (year.episodeCount) {
      parts.push(`${year.episodeCount} episode${year.episodeCount === 1 ? '' : 's'}`);
    }
    if (parts.length) {
      return {
        kind: 'year',
        text: `This year you’ve logged ${parts.join(' and ')}.`,
      };
    }
  }
  if (mostWatched?.tvTitle && mostWatched.episodeCount > 1) {
    return {
      kind: 'show',
      text: `${mostWatched.tvTitle} leads your diary at ${mostWatched.episodeCount} episodes.`,
    };
  }
  const topGenre =
    taste?.tv?.genreByEpisodes?.[0]?.name || taste?.films?.genreByCount?.[0]?.name;
  if (topGenre) {
    return {
      kind: 'genre',
      text: `${topGenre} shows up most in what you’ve logged.`,
    };
  }
  if (funFacts?.biggestBinge?.count > 1) {
    return {
      kind: 'binge',
      text: `Biggest day so far: ${funFacts.biggestBinge.count} titles logged.`,
    };
  }
  if (overview.totalMins > 0) {
    return {
      kind: 'total',
      text: 'Your diary is filling in — open Stats for the full story.',
    };
  }
  return {
    kind: 'empty',
    text: 'Log a film or episode to start your viewing story.',
  };
}

/** Bump when the payload shape changes so cached snapshots rebuild. */
const STATS_SCHEMA_VERSION = 3;

async function buildUserStatsDashboard(userId, options = {}) {
  const timeZone = resolveTimeZone(options.timeZone);
  const now = options.now ? new Date(options.now) : new Date();
  const bounds = periodBounds(timeZone, now);

  let [episodes, tracks, rawFilms, user] = await Promise.all([
    TvEpisodeWatch.find({ userFrom: userId }).lean(),
    TvShowTracking.find({ userFrom: userId }).lean(),
    Watch.find({ userFrom: userId }).sort({ watchedAt: -1 }).lean(),
    User.findById(userId).lean(),
  ]);

  const films = dedupeFilms(rawFilms);
  const filmDuplicatesRemoved = rawFilms.length - films.length;

  const missingRuntimeIds = films.filter((f) => !filmRuntimeMinutes(f)).map((f) => f.movieId);
  const { map: filmMetaMap, fetchesRemaining: filmMetaPending } = await getMovieMetaBatch(
    films.map((f) => f.movieId),
    { priorityIds: missingRuntimeIds, maxFetches: 30 }
  );
  const backfilled = await applyFilmRuntimeBackfill(films, filmMetaMap, 30);

  const dayMap = buildCombinedDayMap(episodes, films, timeZone);
  const tvMins = episodes.reduce((s, ep) => s + (ep.runtimeMinutes || 0), 0);
  const filmMins = films.reduce((s, f) => s + filmRuntimeMinutes(f), 0);
  const filmsWithRuntime = films.filter((f) => filmRuntimeMinutes(f) > 0).length;
  const filmsMissingRuntime = films.length - filmsWithRuntime;
  const epsWithRuntime = episodes.filter((ep) => (ep.runtimeMinutes || 0) > 0).length;
  const epsMissingRuntime = episodes.length - epsWithRuntime;

  const { longest: longestFilm, shortest: shortestFilm } = filmExtremes(films);

  const filmRatingStats = ratingSummary(films, (f) => ({
    movieId: f.movieId,
    movieTitle: f.movieTitle,
  }));
  const showRatingStats = ratingSummary(tracks, (t) => ({
    tvId: t.tvId,
    tvTitle: t.tvTitle,
  }));
  const episodeRatingCount = episodes.filter(
    (e) => Number.isFinite(e.rating) && e.rating > 0
  ).length;

  const library = {
    watching: tracks.filter((t) => t.status === 'watching').length,
    stopped: tracks.filter((t) => t.status === 'paused').length,
    finished: tracks.filter((t) => t.status === 'completed').length,
  };

  const lastEpisodeAt = episodes.reduce((max, ep) => {
    if (!ep.watchedAt) return max;
    const t = new Date(ep.watchedAt);
    return !max || t > max ? t : max;
  }, null);
  const lastFilmAt = films.reduce((max, f) => {
    if (!f.watchedAt) return max;
    const t = new Date(f.watchedAt);
    return !max || t > max ? t : max;
  }, null);
  const lastWatchedAt =
    lastEpisodeAt && lastFilmAt
      ? lastEpisodeAt > lastFilmAt
        ? lastEpisodeAt
        : lastFilmAt
      : lastEpisodeAt || lastFilmAt;

  const totalMins = tvMins + filmMins;
  const tvShowCount = new Set(episodes.map((e) => e.tvId)).size;

  const daySet = new Set(Object.keys(dayMap));
  const streak = computeStreakFromDaySet(daySet, bounds.todayKey);
  const longestStreak = longestStreakFromDaySet(daySet);
  const sortedDays = [...daySet].sort();
  const firstLoggedOn = sortedDays[0] || null;

  const weekdayBuckets = Object.entries(dayMap).map(([key, bucket]) => ({
    key,
    count: (bucket.episodes || 0) + (bucket.films || 0),
    weekday: weekdayOfKey(key, timeZone),
  }));
  const busiestDay = busiestWeekdayFromDayKeys(weekdayBuckets);

  const taste = await buildTasteProfile(films, episodes, filmMetaMap, {
    filmFetchesRemaining: filmMetaPending,
  });

  const mostWatched = mostWatchedShow(episodes, tracks);
  const binge = biggestBinge(dayMap);

  const year = {
    filmCount: countItemsSince(films, bounds.yearStartDate),
    episodeCount: countItemsSince(episodes, bounds.yearStartDate),
    filmMins: sumFieldSince(dayMap, bounds.yearStart, 'filmMinutes'),
    tvMins: sumFieldSince(dayMap, bounds.yearStart, 'tvMinutes'),
  };
  year.totalMins = year.filmMins + year.tvMins;

  const week = {
    filmCount: countItemsSince(films, bounds.weekStartDate),
    episodeCount: countItemsSince(episodes, bounds.weekStartDate),
    filmMins: sumFieldSince(dayMap, bounds.weekStart, 'filmMinutes'),
    tvMins: sumFieldSince(dayMap, bounds.weekStart, 'tvMinutes'),
  };
  week.totalMins = week.filmMins + week.tvMins;

  const month = {
    filmCount: countItemsSince(films, bounds.monthStartDate),
    episodeCount: countItemsSince(episodes, bounds.monthStartDate),
    filmMins: sumFieldSince(dayMap, bounds.monthStart, 'filmMinutes'),
    tvMins: sumFieldSince(dayMap, bounds.monthStart, 'tvMinutes'),
  };
  month.totalMins = month.filmMins + month.tvMins;

  const weeklyTrend = calendarWeeklyTrend(dayMap, timeZone, 12, now);
  const months = monthlyTrend(dayMap, timeZone, now);
  const currentYear = Number(bounds.yearStart.slice(0, 4));
  const previousYear = totalsForYear(dayMap, currentYear - 1);
  const busiestMonth = months.reduce(
    (best, m) => {
      const count = m.episodes + m.films;
      return !best || count > best.count ? { month: m.month, count, minutes: m.minutes } : best;
    },
    null
  );

  const overview = {
    filmCount: films.length,
    tvShowCount,
    episodeCount: episodes.length,
    filmMins,
    tvMins,
    totalMins,
    filmShare: pct(filmMins, totalMins),
    tvShare: pct(tvMins, totalMins),
  };

  const activity = {
    // Calendar week (Monday–Sunday) in the user's timezone
    episodesThisWeek: week.episodeCount,
    filmsThisWeek: week.filmCount,
    tvMinsThisWeek: week.tvMins,
    filmMinsThisWeek: week.filmMins,
    totalMinsThisWeek: week.totalMins,
    episodesThisMonth: month.episodeCount,
    filmsThisMonth: month.filmCount,
    tvMinsThisMonth: month.tvMins,
    filmMinsThisMonth: month.filmMins,
    totalMinsThisMonth: month.totalMins,
    episodesThisYear: year.episodeCount,
    filmsThisYear: year.filmCount,
    tvMinsThisYear: year.tvMins,
    filmMinsThisYear: year.filmMins,
    totalMinsThisYear: year.totalMins,
    streak,
    longestStreak,
    busiestDay,
    busiestMonth,
    lastWatchedAt,
    firstLoggedOn,
    activeDays: daySet.size,
    activeDaysThisYear: sortedDays.filter((d) => d >= bounds.yearStart).length,
    weeklyTrend,
    monthlyTrend: months,
    dailyActivity: dailyActivityWindow(dayMap, bounds.todayKey),
  };

  const quality = {
    filmRuntimeKnown: filmsWithRuntime,
    filmRuntimeMissing: filmsMissingRuntime,
    filmRuntimeCoverage: pct(filmsWithRuntime, films.length),
    episodeRuntimeKnown: epsWithRuntime,
    episodeRuntimeMissing: epsMissingRuntime,
    episodeRuntimeCoverage: pct(epsWithRuntime, episodes.length),
    filmDuplicatesRemoved,
    runtimeBackfilled: backfilled,
    estimated: true,
  };

  const funFacts = {
    biggestBinge: binge,
    avgEpisodeMins:
      epsWithRuntime > 0
        ? Math.round(
            episodes.reduce((s, ep) => s + (ep.runtimeMinutes || 0), 0) / epsWithRuntime
          )
        : 0,
    mostWatchedShow: mostWatched,
    avgPerActiveDay: daySet.size
      ? Math.round(((episodes.length + films.length) / daySet.size) * 10) / 10
      : 0,
    avgMinsPerActiveDay: daySet.size ? Math.round(totalMins / daySet.size) : 0,
  };

  const insight = buildInsight({
    overview,
    activity,
    year,
    taste,
    funFacts,
    mostWatched,
  });

  return {
    schemaVersion: STATS_SCHEMA_VERSION,
    memberSince: user?.createdAt || null,
    timeZone,
    weekStart: bounds.weekStart,
    yearStart: bounds.yearStart,
    insight,
    overview,
    year,
    week,
    month,
    quality,
    library: {
      ...library,
      caughtUp: tracks.filter((t) => isCaughtUpWaiting(t)).length,
      backlog: computeBacklog(tracks),
      totalTracked: tracks.length,
      completionRate: pct(library.finished, tracks.length),
    },
    activity,
    films: {
      count: films.length,
      filmMins,
      withRuntime: filmsWithRuntime,
      missingRuntime: filmsMissingRuntime,
      runtimeBackfilled: backfilled,
      thisWeek: week.filmCount,
      thisMonth: month.filmCount,
      thisYear: year.filmCount,
      filmMinsThisWeek: week.filmMins,
      filmMinsThisMonth: month.filmMins,
      filmMinsThisYear: year.filmMins,
      avgRuntime: filmsWithRuntime ? Math.round(filmMins / filmsWithRuntime) : 0,
      longest: longestFilm,
      shortest: shortestFilm,
      weeklyTrend: weeklyTrend.map((w) => ({
        weekStart: w.weekStart,
        weekEnd: w.weekEnd,
        episodes: w.films,
        minutes: w.filmMinutes,
      })),
      shareOfScreenTime: pct(filmMins, totalMins),
    },
    previousYear,
    funFacts,
    ratings: {
      films: filmRatingStats,
      shows: showRatingStats,
      episodeCount: episodeRatingCount,
    },
    milestones: computeMilestones({
      episodeCount: episodes.length,
      filmCount: films.length,
      totalMins,
      completedShows: library.finished,
    }),
    taste,
    metaPending: Boolean(taste?.partial),
  };
}

module.exports = { buildUserStatsDashboard, STATS_SCHEMA_VERSION };
