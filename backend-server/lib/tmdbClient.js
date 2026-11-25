/**
 * The one way the server talks to TMDB. Every caller (the /api/tmdb proxy, tracking,
 * stats metadata) shares:
 *  - a cache capped in bytes, each entry with its own lifetime (least recently used goes first)
 *  - one in-flight request per cache key, so ten users opening the same page cost one call
 *  - at most `maxConcurrent` upstream requests at once
 *  - a timeout on every request, and one retry after TMDB's 429 Retry-After
 */

const DEFAULT_MAX_BYTES = 32 * 1024 * 1024;
const MAX_RETRY_WAIT_MS = 5000;

function createTmdbClient({
  fetchImpl = (...args) => fetch(...args),
  maxBytes = DEFAULT_MAX_BYTES,
  maxConcurrent = 8,
  timeoutMs = 8000,
  now = Date.now,
  sleep = (ms) => new Promise((r) => setTimeout(r, ms)),
} = {}) {
  const cache = new Map(); // key -> { value, bytes, expires }; insertion order = recency
  let bytes = 0;
  const inFlight = new Map();
  let active = 0;
  const waiting = [];

  function drop(key) {
    const hit = cache.get(key);
    if (!hit) return;
    bytes -= hit.bytes;
    cache.delete(key);
  }

  function read(key) {
    const hit = cache.get(key);
    if (!hit) return null;
    if (hit.expires <= now()) {
      drop(key);
      return null;
    }
    cache.delete(key);
    cache.set(key, hit);
    return hit.value;
  }

  function write(key, value, ttlSeconds) {
    const size = Buffer.byteLength(value.body);
    if (size > maxBytes) return;
    drop(key);
    cache.set(key, { value, bytes: size, expires: now() + ttlSeconds * 1000 });
    bytes += size;
    while (bytes > maxBytes) drop(cache.keys().next().value);
  }

  async function withSlot(fn) {
    if (active >= maxConcurrent) await new Promise((resolve) => waiting.push(resolve));
    active += 1;
    try {
      return await fn();
    } finally {
      active -= 1;
      const next = waiting.shift();
      if (next) next();
    }
  }

  async function upstream(url) {
    const res = await withSlot(() => fetchImpl(url, { signal: AbortSignal.timeout(timeoutMs) }));
    return {
      status: res.status,
      ok: res.ok,
      body: await res.text(),
      contentType: res.headers.get('content-type') || 'application/json',
      retryAfter: res.headers.get('retry-after'),
    };
  }

  async function load(url) {
    let res = await upstream(url);
    if (res.status === 429) {
      const seconds = Number(res.retryAfter);
      const wait = Number.isFinite(seconds) ? Math.min(seconds * 1000, MAX_RETRY_WAIT_MS) : 1000;
      await sleep(wait);
      res = await upstream(url);
    }
    return res;
  }

  /** { status, body, contentType, cache: 'HIT' | 'MISS' }. Throws on a transport failure or timeout. */
  async function getText(url, { cacheKey = url, ttlSeconds = 24 * 60 * 60 } = {}) {
    const cached = read(cacheKey);
    if (cached) return { ...cached, cache: 'HIT' };
    if (!inFlight.has(cacheKey)) {
      const promise = load(url)
        .then((res) => {
          const value = { status: res.status, body: res.body, contentType: res.contentType };
          if (res.ok) write(cacheKey, value, ttlSeconds);
          return value;
        })
        .finally(() => inFlight.delete(cacheKey));
      inFlight.set(cacheKey, promise);
    }
    const value = await inFlight.get(cacheKey);
    return { ...value, cache: 'MISS' };
  }

  /** Parsed JSON, or null when TMDB fails, times out or answers with an error. */
  async function getJson(url, options) {
    try {
      const res = await getText(url, options);
      if (res.status < 200 || res.status >= 300) return null;
      return JSON.parse(res.body);
    } catch {
      return null;
    }
  }

  return {
    getText,
    getJson,
    stats: () => ({ entries: cache.size, bytes, active, waiting: waiting.length }),
  };
}

let shared = null;

/** The process-wide client, so the proxy and the server's own lookups share one cache and limit. */
function tmdbClient() {
  if (!shared) shared = createTmdbClient();
  return shared;
}

module.exports = { createTmdbClient, tmdbClient };
