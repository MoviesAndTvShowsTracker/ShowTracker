const { singleFlight } = require('../lib/singleFlight');

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Ratings lookups: a bounded in-memory LRU, then a persisted copy (survives deploys, so OMDb's
 * daily quota isn't spent again), then one shared build. A persistence failure never fails ratings.
 */
function createRatingsStore({ build, persist, memoryMax = 2000, ttlMs = DAY_MS, now = Date.now }) {
  const memory = new Map(); // key -> { payload, expires }; insertion order = recency

  function remember(key, payload) {
    memory.delete(key);
    memory.set(key, { payload, expires: now() + ttlMs });
    while (memory.size > memoryMax) memory.delete(memory.keys().next().value);
  }

  async function get(kind, id) {
    // v3: scores only from TMDB and OMDb's API (older cached copies may hold scraped values).
    const key = `v3:${kind}:${id}`;
    const hit = memory.get(key);
    if (hit && hit.expires > now()) {
      memory.delete(key);
      memory.set(key, hit);
      return hit.payload;
    }
    return singleFlight(`ratings:${key}`, async () => {
      const stored = await persist.get(key).catch(() => null);
      if (stored) {
        remember(key, stored);
        return stored;
      }
      const payload = await build(kind, id);
      remember(key, payload);
      await persist.set(key, payload).catch((err) => console.warn('[ratings] persist failed', err.message));
      return payload;
    });
  }

  return { get, memorySize: () => memory.size };
}

module.exports = { createRatingsStore };
