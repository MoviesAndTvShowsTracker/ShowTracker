const STATS_SESSION_KEY = 'marquee_stats_v3';
const LEGACY_KEYS = ['marquee_stats_v1', 'marquee_stats_v2'];

export function readSessionStats() {
  try {
    const raw = sessionStorage.getItem(STATS_SESSION_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (!parsed?.stats) return null;
    return parsed;
  } catch {
    return null;
  }
}

export function writeSessionStats(stats, builtAt) {
  try {
    sessionStorage.setItem(
      STATS_SESSION_KEY,
      JSON.stringify({ stats, builtAt: builtAt || new Date().toISOString() })
    );
  } catch {
    /* quota or private mode */
  }
}

export function clearSessionStats() {
  try {
    sessionStorage.removeItem(STATS_SESSION_KEY);
    LEGACY_KEYS.forEach((key) => sessionStorage.removeItem(key));
  } catch {
    /* ignore */
  }
}
