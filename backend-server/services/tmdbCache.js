/**
 * Small in-memory LRU for the TMDB proxy. Catalogue data changes slowly, so
 * repeat visits (and other users) skip the TMDB round trip entirely.
 */

const MINUTE = 60;
const HOUR = 60 * MINUTE;

/** Seconds a TMDB path stays fresh. */
function ttlFor(path) {
  if (/^search\//.test(path)) return 5 * MINUTE;
  if (/\/watch\/providers$/.test(path)) return 6 * HOUR;
  if (/^(trending|discover)\//.test(path)) return 10 * MINUTE;
  if (/^(movie|tv)\/(popular|top_rated|now_playing|upcoming|on_the_air|airing_today)$/.test(path)) {
    return 10 * MINUTE;
  }
  return 24 * HOUR;
}

function createTmdbCache({ maxEntries = 500, now = Date.now } = {}) {
  const map = new Map(); // insertion order = recency

  return {
    get(key) {
      const hit = map.get(key);
      if (!hit) return undefined;
      if (hit.expires <= now()) {
        map.delete(key);
        return undefined;
      }
      map.delete(key);
      map.set(key, hit);
      return hit.value;
    },
    set(key, value, ttlSeconds) {
      map.delete(key);
      map.set(key, { value, expires: now() + ttlSeconds * 1000 });
      while (map.size > maxEntries) {
        map.delete(map.keys().next().value);
      }
    },
    get size() {
      return map.size;
    },
  };
}

module.exports = { createTmdbCache, ttlFor };
