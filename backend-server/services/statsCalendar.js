const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

/** Validate IANA timezone; fall back to UTC when invalid. */
function resolveTimeZone(timeZone) {
  if (!timeZone || typeof timeZone !== 'string') return 'UTC';
  try {
    Intl.DateTimeFormat('en-US', { timeZone }).format(new Date());
    return timeZone;
  } catch {
    return 'UTC';
  }
}

function zonedParts(date, timeZone) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);

  const get = (type) => parts.find((p) => p.type === type)?.value;
  const weekdayMap = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };

  return {
    year: Number(get('year')),
    month: Number(get('month')),
    day: Number(get('day')),
    weekday: weekdayMap[get('weekday')] ?? 0,
    hour: Number(get('hour')),
    minute: Number(get('minute')),
    second: Number(get('second')),
  };
}

/** YYYY-MM-DD for an instant in the given timezone. */
function dateKeyInZone(date, timeZone) {
  if (!date) return null;
  const p = zonedParts(new Date(date), timeZone);
  return `${p.year}-${String(p.month).padStart(2, '0')}-${String(p.day).padStart(2, '0')}`;
}

/** UTC instant for local midnight of YYYY-MM-DD in timezone. */
function zonedMidnightUtc(dateKey, timeZone) {
  const [y, m, d] = dateKey.split('-').map(Number);
  // Guess noon UTC then correct by measured offset
  let guess = Date.UTC(y, m - 1, d, 12, 0, 0);
  for (let i = 0; i < 3; i += 1) {
    const p = zonedParts(new Date(guess), timeZone);
    const asUtc = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second);
    const desired = Date.UTC(y, m - 1, d, 0, 0, 0);
    guess += desired - asUtc;
  }
  return new Date(guess);
}

function addDaysToKey(dateKey, days) {
  const [y, m, d] = dateKey.split('-').map(Number);
  const utc = new Date(Date.UTC(y, m - 1, d + days));
  return utc.toISOString().slice(0, 10);
}

function weekdayOfKey(dateKey, timeZone) {
  return zonedParts(zonedMidnightUtc(dateKey, timeZone), timeZone).weekday;
}

/** Monday-based calendar week containing `date` in timezone. Returns { weekStart, weekEnd }. */
function mondayWeekContaining(date, timeZone) {
  const key = dateKeyInZone(date, timeZone);
  const weekday = weekdayOfKey(key, timeZone); // 0=Sun … 6=Sat
  const daysFromMonday = weekday === 0 ? 6 : weekday - 1;
  const weekStart = addDaysToKey(key, -daysFromMonday);
  const weekEnd = addDaysToKey(weekStart, 6);
  return { weekStart, weekEnd };
}

function startOfMonthKey(date, timeZone) {
  const p = zonedParts(new Date(date), timeZone);
  return `${p.year}-${String(p.month).padStart(2, '0')}-01`;
}

function startOfYearKey(date, timeZone) {
  const p = zonedParts(new Date(date), timeZone);
  return `${p.year}-01-01`;
}

function periodBounds(timeZone, now = new Date()) {
  const tz = resolveTimeZone(timeZone);
  const todayKey = dateKeyInZone(now, tz);
  const { weekStart } = mondayWeekContaining(now, tz);
  const monthStart = startOfMonthKey(now, tz);
  const yearStart = startOfYearKey(now, tz);
  return {
    timeZone: tz,
    todayKey,
    weekStart,
    weekStartDate: zonedMidnightUtc(weekStart, tz),
    monthStart,
    monthStartDate: zonedMidnightUtc(monthStart, tz),
    yearStart,
    yearStartDate: zonedMidnightUtc(yearStart, tz),
  };
}

function isOnOrAfterKey(eventKey, boundKey) {
  return Boolean(eventKey && boundKey && eventKey >= boundKey);
}

/** Consecutive-day streak ending today or yesterday (local). */
function computeStreakFromDaySet(daySet, todayKey) {
  if (!daySet.size) return 0;
  let cursor = todayKey;
  if (!daySet.has(cursor)) {
    cursor = addDaysToKey(todayKey, -1);
  }
  let streak = 0;
  while (daySet.has(cursor)) {
    streak += 1;
    cursor = addDaysToKey(cursor, -1);
  }
  return streak;
}

/** Best consecutive-day run ever recorded. */
function longestStreakFromDaySet(daySet) {
  if (!daySet.size) return 0;
  const keys = [...daySet].sort();
  let best = 1;
  let run = 1;
  for (let i = 1; i < keys.length; i += 1) {
    if (keys[i] === addDaysToKey(keys[i - 1], 1)) {
      run += 1;
      if (run > best) best = run;
    } else {
      run = 1;
    }
  }
  return best;
}

/** Trailing month keys (YYYY-MM), oldest first, ending with the current month. */
function trailingMonthKeys(timeZone, count = 12, now = new Date()) {
  const tz = resolveTimeZone(timeZone);
  const p = zonedParts(new Date(now), tz);
  const keys = [];
  for (let i = count - 1; i >= 0; i -= 1) {
    const monthIndex = p.month - 1 - i;
    const year = p.year + Math.floor(monthIndex / 12);
    const month = ((monthIndex % 12) + 12) % 12;
    keys.push(`${year}-${String(month + 1).padStart(2, '0')}`);
  }
  return keys;
}

function busiestWeekdayFromDayKeys(dayKeysWithCounts) {
  const counts = [0, 0, 0, 0, 0, 0, 0];
  for (const { key, count, weekday } of dayKeysWithCounts) {
    if (!count) continue;
    const day = typeof weekday === 'number' ? weekday : new Date(`${key}T12:00:00Z`).getUTCDay();
    counts[day] += count;
  }
  const max = Math.max(...counts);
  if (max === 0) return null;
  const index = counts.indexOf(max);
  return { day: DAY_NAMES[index], count: max, weekday: index };
}

/**
 * Monday-based calendar weeks ending with the current week.
 * Each bucket: { weekStart, weekEnd, episodes, films, minutes, filmMinutes, tvMinutes }
 */
function calendarWeeklyTrend(dayMap, timeZone, weeks = 12, now = new Date()) {
  const tz = resolveTimeZone(timeZone);
  const { weekStart: currentWeekStart } = mondayWeekContaining(now, tz);
  const result = [];

  for (let w = weeks - 1; w >= 0; w -= 1) {
    const weekStart = addDaysToKey(currentWeekStart, -w * 7);
    const weekEnd = addDaysToKey(weekStart, 6);
    let episodes = 0;
    let films = 0;
    let tvMinutes = 0;
    let filmMinutes = 0;

    for (let i = 0; i < 7; i += 1) {
      const key = addDaysToKey(weekStart, i);
      const bucket = dayMap[key];
      if (!bucket) continue;
      episodes += bucket.episodes || 0;
      films += bucket.films || 0;
      tvMinutes += bucket.tvMinutes || 0;
      filmMinutes += bucket.filmMinutes || 0;
    }

    result.push({
      weekStart,
      weekEnd,
      episodes,
      films,
      minutes: tvMinutes + filmMinutes,
      tvMinutes,
      filmMinutes,
    });
  }

  return result;
}

module.exports = {
  DAY_NAMES,
  resolveTimeZone,
  zonedParts,
  dateKeyInZone,
  zonedMidnightUtc,
  addDaysToKey,
  weekdayOfKey,
  mondayWeekContaining,
  startOfMonthKey,
  startOfYearKey,
  periodBounds,
  isOnOrAfterKey,
  computeStreakFromDaySet,
  longestStreakFromDaySet,
  trailingMonthKeys,
  busiestWeekdayFromDayKeys,
  calendarWeeklyTrend,
};
