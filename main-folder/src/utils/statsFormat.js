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
  return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
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
