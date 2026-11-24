/**
 * Range-scoped stats (week / month / year / all) for the iOS Stats page.
 * Everything is computed in memory from rows the dashboard already loaded,
 * so the client switches ranges instantly from one cached payload.
 */

const { addDaysToKey } = require('./statsCalendar');
const { filmRuntimeMinutes, buildTasteProfileFromMaps } = require('./mediaMeta');
const { dedupeFilms } = require('./filmDedupe');
const { buildHourRhythm, buildBiggestNight, buildHotTakes, attachEpisodePosters } = require('./lobbyDiaryStats');

const MONTH_LABELS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const WEEKDAY_LABELS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/** One cached formatter per call — Intl construction dominates cost on large diaries. */
function makeStamper(timeZone) {
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    hourCycle: 'h23',
  });
  return (value) => {
    if (!value) return null;
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return null;
    const parts = {};
    for (const p of fmt.formatToParts(date)) parts[p.type] = p.value;
    return { key: `${parts.year}-${parts.month}-${parts.day}`, hour: Number(parts.hour) % 24 };
  };
}

function keyToUtc(key) {
  const [y, m, d] = key.split('-').map(Number);
  return Date.UTC(y, m - 1, d);
}

function diffDays(fromKey, toKey) {
  return Math.round((keyToUtc(toKey) - keyToUtc(fromKey)) / 86400000);
}

function daysInMonth(year, month) {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

function pad(n) {
  return String(n).padStart(2, '0');
}

/** Same elapsed span in the prior period, so mid-week compares fairly. */
function rangeWindows(bounds) {
  const today = bounds.todayKey;
  const [ty, tm, td] = today.split('-').map(Number);

  const weekElapsed = diffDays(bounds.weekStart, today);
  const prevWeekStart = addDaysToKey(bounds.weekStart, -7);

  const prevMonthYear = tm === 1 ? ty - 1 : ty;
  const prevMonth = tm === 1 ? 12 : tm - 1;
  const prevMonthStart = `${prevMonthYear}-${pad(prevMonth)}-01`;
  const prevMonthEnd = `${prevMonthYear}-${pad(prevMonth)}-${pad(Math.min(td, daysInMonth(prevMonthYear, prevMonth)))}`;

  const yearElapsed = diffDays(bounds.yearStart, today);
  const prevYearStart = `${ty - 1}-01-01`;

  return {
    week: {
      start: bounds.weekStart,
      previous: { start: prevWeekStart, end: addDaysToKey(prevWeekStart, weekElapsed) },
    },
    month: {
      start: bounds.monthStart,
      previous: { start: prevMonthStart, end: prevMonthEnd },
    },
    year: {
      start: bounds.yearStart,
      previous: { start: prevYearStart, end: addDaysToKey(prevYearStart, yearElapsed) },
    },
    all: { start: null, previous: null },
  };
}

function emptyBucket(key, label, future = false) {
  return { key, label, tvMins: 0, filmMins: 0, plays: 0, future };
}

function trendBuckets(rangeKey, bounds, firstKey) {
  const today = bounds.todayKey;
  const [ty, tm] = today.split('-').map(Number);

  if (rangeKey === 'week') {
    return {
      unit: 'day',
      buckets: WEEKDAY_LABELS.map((label, i) => {
        const key = addDaysToKey(bounds.weekStart, i);
        return emptyBucket(key, label, key > today);
      }),
      bucketOf: (dayKey) => dayKey,
    };
  }
  if (rangeKey === 'month') {
    const total = daysInMonth(ty, tm);
    return {
      unit: 'day',
      buckets: Array.from({ length: total }, (_, i) => {
        const key = `${ty}-${pad(tm)}-${pad(i + 1)}`;
        return emptyBucket(key, String(i + 1), key > today);
      }),
      bucketOf: (dayKey) => dayKey,
    };
  }
  if (rangeKey === 'year') {
    return {
      unit: 'month',
      buckets: MONTH_LABELS.map((label, i) => emptyBucket(`${ty}-${pad(i + 1)}`, label, i + 1 > tm)),
      bucketOf: (dayKey) => dayKey.slice(0, 7),
    };
  }
  const firstYear = firstKey ? Number(firstKey.slice(0, 4)) : ty;
  if (ty - firstYear >= 1) {
    return {
      unit: 'year',
      buckets: Array.from({ length: ty - firstYear + 1 }, (_, i) => {
        const y = String(firstYear + i);
        return emptyBucket(y, `’${y.slice(2)}`);
      }),
      bucketOf: (dayKey) => dayKey.slice(0, 4),
    };
  }
  return {
    unit: 'month',
    buckets: MONTH_LABELS.map((label, i) => emptyBucket(`${ty}-${pad(i + 1)}`, label, i + 1 > tm)),
    bucketOf: (dayKey) => dayKey.slice(0, 7),
  };
}

function inWindow(key, start, end) {
  if (!key) return false;
  if (start && key < start) return false;
  if (end && key > end) return false;
  return true;
}

function topShows(episodeRows, trackById, limit = 5) {
  const byShow = new Map();
  for (const { row } of episodeRows) {
    const id = String(row.tvId);
    const cur = byShow.get(id) || { plays: 0, mins: 0 };
    cur.plays += 1;
    cur.mins += row.runtimeMinutes || 0;
    byShow.set(id, cur);
  }
  return [...byShow.entries()]
    .sort((a, b) => b[1].plays - a[1].plays || b[1].mins - a[1].mins)
    .slice(0, limit)
    .map(([tvId, v]) => {
      const track = trackById.get(tvId);
      return {
        tvId,
        tvTitle: track?.tvTitle || null,
        tvPosterImage: track?.tvPosterImage || null,
        plays: v.plays,
        mins: v.mins,
      };
    });
}

function recentFilms(filmRows, limit = 12) {
  return [...filmRows]
    .sort((a, b) => new Date(b.row.watchedAt) - new Date(a.row.watchedAt))
    .slice(0, limit)
    .map(({ row }) => ({
      movieId: String(row.movieId),
      title: row.movieTitle || null,
      poster: row.moviePosterImage || null,
      watchedAt: row.watchedAt || null,
      rating: Number.isFinite(Number(row.rating)) && Number(row.rating) > 0 ? Number(row.rating) / 2 : null,
    }));
}

function trimTaste(profile) {
  if (!profile?.available) return null;
  return {
    tv: { genreByEpisodes: (profile.tv?.genreByEpisodes || []).slice(0, 6) },
    films: { genreByCount: (profile.films?.genreByCount || []).slice(0, 6) },
  };
}

function buildRange(rangeKey, window, ctx) {
  const { epRows, filmRows, bounds, trackById, filmMetaMap, tvMetaMap, timeZone, firstKey } = ctx;
  const end = bounds.todayKey;

  const eps = epRows.filter((r) => inWindow(r.stamp.key, window.start, end));
  const films = filmRows.filter((r) => inWindow(r.stamp.key, window.start, end));

  const tvMins = eps.reduce((s, r) => s + (r.row.runtimeMinutes || 0), 0);
  const filmMins = films.reduce((s, r) => s + filmRuntimeMinutes(r.row), 0);
  const days = new Set([...eps, ...films].map((r) => r.stamp.key));
  const uniqueFilms = dedupeFilms(films.map((r) => r.row));

  const totals = {
    totalMins: tvMins + filmMins,
    tvMins,
    filmMins,
    episodeCount: eps.filter((r) => !r.rewatch).length,
    episodePlays: eps.length,
    rewatchPlays: eps.filter((r) => r.rewatch).length,
    filmCount: uniqueFilms.length,
    filmPlays: films.length,
    showCount: new Set(eps.map((r) => String(r.row.tvId))).size,
    activeDays: days.size,
  };

  let previous = null;
  if (window.previous) {
    const { start, end: prevEnd } = window.previous;
    const pEps = epRows.filter((r) => inWindow(r.stamp.key, start, prevEnd));
    const pFilms = filmRows.filter((r) => inWindow(r.stamp.key, start, prevEnd));
    previous = {
      start,
      end: prevEnd,
      totalMins:
        pEps.reduce((s, r) => s + (r.row.runtimeMinutes || 0), 0) +
        pFilms.reduce((s, r) => s + filmRuntimeMinutes(r.row), 0),
      plays: pEps.length + pFilms.length,
    };
  }

  const trend = trendBuckets(rangeKey, bounds, firstKey);
  const bucketIndex = new Map(trend.buckets.map((b, i) => [b.key, i]));
  const dayMap = {};
  for (const r of eps) {
    const i = bucketIndex.get(trend.bucketOf(r.stamp.key));
    if (i !== undefined) {
      trend.buckets[i].tvMins += r.row.runtimeMinutes || 0;
      trend.buckets[i].plays += 1;
    }
    const d = (dayMap[r.stamp.key] ||= { episodes: 0, films: 0, tvMinutes: 0, filmMinutes: 0 });
    d.episodes += 1;
    d.tvMinutes += r.row.runtimeMinutes || 0;
  }
  for (const r of films) {
    const mins = filmRuntimeMinutes(r.row);
    const i = bucketIndex.get(trend.bucketOf(r.stamp.key));
    if (i !== undefined) {
      trend.buckets[i].filmMins += mins;
      trend.buckets[i].plays += 1;
    }
    const d = (dayMap[r.stamp.key] ||= { episodes: 0, films: 0, tvMinutes: 0, filmMinutes: 0 });
    d.films += 1;
    d.filmMinutes += mins;
  }

  const stampOf = new Map([...eps, ...films].map((r) => [r.row, r.stamp]));
  const hourOf = (row) => stampOf.get(row)?.hour;
  const keyOf = (row) => stampOf.get(row)?.key;
  const epPlayRows = eps.map((r) => r.row);
  const filmPlayRows = films.map((r) => r.row);

  return {
    key: rangeKey,
    start: window.start,
    end,
    totals,
    previous,
    trend: { unit: trend.unit, buckets: trend.buckets },
    rhythm: buildHourRhythm(epPlayRows, filmPlayRows, timeZone, hourOf),
    biggestNight: attachEpisodePosters(
      buildBiggestNight(epPlayRows, filmPlayRows, timeZone, dayMap, keyOf),
      [...trackById.values()]
    ),
    topShows: topShows(eps, trackById, rangeKey === 'all' ? 10 : 5),
    films: recentFilms(films),
    hotTakes: buildHotTakes(uniqueFilms, filmMetaMap, 4),
    taste: trimTaste(
      buildTasteProfileFromMaps(uniqueFilms, epPlayRows, filmMetaMap, tvMetaMap || new Map())
    ),
  };
}

/**
 * @param {object} input
 * @param {Array} input.episodes first-watch rows
 * @param {Array} input.episodePlays first watches + rewatches (runtime-enriched)
 * @param {Array} input.rawFilms every film play
 */
function buildStatsRanges({ episodes, episodePlays, rawFilms, tracks, filmMetaMap, tvMetaMap, timeZone, bounds }) {
  const stamp = makeStamper(timeZone);
  const firstWatch = new Set(episodes);
  const epRows = [];
  for (const row of episodePlays) {
    const s = stamp(row.watchedAt);
    if (s) epRows.push({ row, stamp: s, rewatch: !firstWatch.has(row) });
  }
  const filmRows = [];
  for (const row of rawFilms) {
    const s = stamp(row.watchedAt);
    if (s) filmRows.push({ row, stamp: s });
  }
  let firstKey = null;
  for (const r of [...epRows, ...filmRows]) {
    if (!firstKey || r.stamp.key < firstKey) firstKey = r.stamp.key;
  }

  const ctx = {
    epRows,
    filmRows,
    bounds,
    timeZone,
    firstKey,
    filmMetaMap,
    tvMetaMap,
    trackById: new Map(tracks.map((t) => [String(t.tvId), t])),
  };
  const windows = rangeWindows(bounds);
  return {
    week: buildRange('week', windows.week, ctx),
    month: buildRange('month', windows.month, ctx),
    year: buildRange('year', windows.year, ctx),
    all: buildRange('all', windows.all, ctx),
  };
}

/** Your highest-rated titles (diary ratings are stored 1–10 → stars). */
function topRated(items, map, limit = 10) {
  return items
    .filter((it) => Number.isFinite(Number(it.rating)) && Number(it.rating) > 0)
    .sort(
      (a, b) =>
        Number(b.rating) - Number(a.rating) ||
        new Date(b.watchedAt || b.updatedAt || 0) - new Date(a.watchedAt || a.updatedAt || 0)
    )
    .slice(0, limit)
    .map((it) => ({ ...map(it), rating: Number(it.rating) / 2 }));
}

/** Half-star buckets 0.5…5 → 10 counts. */
function ratingDistribution(items) {
  const buckets = Array.from({ length: 10 }, (_, i) => ({ stars: (i + 1) / 2, count: 0 }));
  for (const it of items) {
    const r = Math.round(Number(it.rating));
    if (Number.isFinite(r) && r >= 1 && r <= 10) buckets[r - 1].count += 1;
  }
  return buckets;
}

/** All-time minutes per weekday (Mon…Sun) from the combined day map. */
function weekdayTotals(dayMap) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const out = labels.map((label) => ({ label, tvMins: 0, filmMins: 0, plays: 0, days: 0 }));
  for (const [key, b] of Object.entries(dayMap || {})) {
    const dow = new Date(keyToUtc(key)).getUTCDay(); // 0 = Sun
    const i = (dow + 6) % 7;
    out[i].tvMins += b.tvMinutes || 0;
    out[i].filmMins += b.filmMinutes || 0;
    out[i].plays += (b.episodes || 0) + (b.films || 0);
    out[i].days += 1;
  }
  return out;
}

module.exports = {
  buildStatsRanges,
  rangeWindows,
  makeStamper,
  topRated,
  ratingDistribution,
  weekdayTotals,
};
