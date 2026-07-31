export function formatDuration(totalMins) {
  if (!totalMins || totalMins <= 0) return '—';
  const rounded = Math.round(totalMins);
  if (rounded < 60) return `${rounded}m`;
  const h = Math.floor(rounded / 60);
  const m = rounded % 60;
  if (h >= 24) {
    const d = Math.floor(h / 24);
    const rh = h % 24;
    return rh > 0 ? `${d}d ${rh}h` : `${d}d`;
  }
  return m > 0 ? `${h}h ${m}m` : `${h}h`;
}

export function formatCount(n) {
  if (n == null || Number.isNaN(n)) return '0';
  if (n >= 1000) return `${(n / 1000).toFixed(1).replace(/\.0$/, '')}k`;
  return String(n);
}

export function formatShortDate(iso) {
  if (!iso) return '—';
  // Date-only keys (YYYY-MM-DD) should not shift by timezone
  const value = /^\d{4}-\d{2}-\d{2}$/.test(iso) ? `${iso}T12:00:00` : iso;
  return new Date(value).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

/** True when an ISO date (YYYY-MM-DD) is after today in local time. */
export function isFutureRelease(iso) {
  if (!iso) return false;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const release = new Date(`${iso}T00:00:00`);
  return release > today;
}

export function releaseFieldLabel(iso) {
  return isFutureRelease(iso) ? 'Release date' : 'Released';
}

export function premiereFieldLabel(iso) {
  return isFutureRelease(iso) ? 'Premieres' : 'First aired';
}

const languageNames = typeof Intl !== 'undefined' ? new Intl.DisplayNames(['en'], { type: 'language' }) : null;

export function formatLanguage(code) {
  if (!code) return null;
  try {
    return languageNames?.of(code) || code.toUpperCase();
  } catch {
    return code.toUpperCase();
  }
}

export function formatMemberSince(iso) {
  if (!iso) return '';
  return new Date(iso).toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
}

/** Local calendar day as YYYY-MM-DD, free of UTC drift. */
export function toDayKey(date) {
  const d = new Date(date);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export function todayKey() {
  return toDayKey(new Date());
}

export function addDays(dayKey, delta) {
  const [y, m, d] = dayKey.split('-').map(Number);
  const date = new Date(y, m - 1, d);
  date.setDate(date.getDate() + delta);
  return toDayKey(date);
}

/** Monday of the week containing dayKey. */
export function mondayOf(dayKey) {
  const [y, m, d] = dayKey.split('-').map(Number);
  const date = new Date(y, m - 1, d);
  return addDays(dayKey, -((date.getDay() + 6) % 7));
}

export function formatDayLabel(dayKey, options) {
  const [y, m, d] = dayKey.split('-').map(Number);
  return new Date(y, m - 1, d).toLocaleDateString(
    'en-US',
    options || { weekday: 'short', month: 'short', day: 'numeric' }
  );
}

export function formatMonthLabel(monthKey, withYear = false) {
  const [y, m] = monthKey.split('-').map(Number);
  return new Date(y, m - 1, 1).toLocaleDateString('en-US', {
    month: 'short',
    ...(withYear ? { year: 'numeric' } : {}),
  });
}

/** Year-over-year change, or null when there is nothing to compare against. */
export function formatDelta(current, previous) {
  if (!previous || previous <= 0 || !current) return null;
  const change = Math.round(((current - previous) / previous) * 100);
  if (Math.abs(change) < 1) return { text: 'about the same', direction: 'flat' };
  return {
    text: `${change > 0 ? '+' : ''}${change}%`,
    direction: change > 0 ? 'up' : 'down',
  };
}

/** ISO week number and year for a date (week starts Monday). */
export function isoWeekParts(isoDate) {
  const d = new Date(isoDate);
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() + 3 - ((d.getDay() + 6) % 7));
  const isoYear = d.getFullYear();
  const week1 = new Date(isoYear, 0, 4);
  const week =
    1 +
    Math.round(
      ((d - week1) / 86400000 - 3 + ((week1.getDay() + 6) % 7)) / 7
    );
  const yearShort = String(isoYear).slice(-2);
  return {
    week,
    year: isoYear,
    label: `W${week} '${yearShort}`,
    compact: `${week}·${yearShort}`,
    full: `Week ${week}, ${isoYear}`,
  };
}
