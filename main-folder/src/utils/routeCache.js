import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';

/**
 * Lightweight stale-while-revalidate cache used by list / landing / detail
 * pages so that Back-navigation paints the previous screen *instantly* —
 * which is the only way SPA scroll restoration can land users on the row
 * they left (the previous render was empty → list had zero height → the
 * browser could not scroll back to position Y).
 *
 * - In-memory `Map` is the source of truth within a session.
 * - A single sessionStorage mirror lets a soft reload or PWA relaunch
 *   stay instant too. Writes are debounced and bounded in size.
 * - Subscribers (`subscribe`) are notified when an entry is written or
 *   invalidated, so hook instances stay in sync across the tree.
 * - In-flight promises dedupe duplicate concurrent fetches for the
 *   same key (e.g. two tiles asking for the same TMDB endpoint).
 */

const CACHE = new Map(); // key -> { data, builtAt }
const SUBS = new Map(); // key -> Set<fn>
const INFLIGHT = new Map(); // key -> Promise<data>

const SESSION_KEY = 'marquee-route-cache';
const SESSION_MAX_BYTES = 400_000; // keep the mirror under ~400KB

function hydrateFromSession() {
  if (typeof sessionStorage === 'undefined') return;
  try {
    const raw = sessionStorage.getItem(SESSION_KEY);
    if (!raw) return;
    const parsed = JSON.parse(raw);
    Object.entries(parsed || {}).forEach(([key, entry]) => {
      if (entry && entry.data !== undefined && typeof entry.builtAt === 'number') {
        CACHE.set(key, entry);
      }
    });
  } catch {
    /* ignore */
  }
}

let persistPending = false;
function schedulePersist() {
  if (persistPending || typeof sessionStorage === 'undefined') return;
  persistPending = true;
  const flush = () => {
    persistPending = false;
    try {
      const obj = {};
      CACHE.forEach((entry, key) => {
        obj[key] = entry;
      });
      const serialized = JSON.stringify(obj);
      if (serialized.length <= SESSION_MAX_BYTES) {
        sessionStorage.setItem(SESSION_KEY, serialized);
      } else {
        // Drop oldest half if we exceed the mirror budget.
        const entries = Array.from(CACHE.entries()).sort(
          (a, b) => a[1].builtAt - b[1].builtAt
        );
        const keep = entries.slice(Math.floor(entries.length / 2));
        const trimmed = Object.fromEntries(keep);
        try {
          sessionStorage.setItem(SESSION_KEY, JSON.stringify(trimmed));
        } catch {
          /* give up quietly */
        }
      }
    } catch {
      /* ignore quota / cycles */
    }
  };
  if (typeof queueMicrotask === 'function') queueMicrotask(flush);
  else setTimeout(flush, 0);
}

hydrateFromSession();

function notify(key) {
  const set = SUBS.get(key);
  if (!set) return;
  set.forEach((fn) => {
    try {
      fn();
    } catch {
      /* subscriber errors must not break others */
    }
  });
}

export function readCache(key) {
  if (!key) return null;
  return CACHE.get(key) || null;
}

export function writeCache(key, data) {
  if (!key) return;
  CACHE.set(key, { data, builtAt: Date.now() });
  schedulePersist();
  notify(key);
}

export function invalidateCache(key) {
  if (!key) return;
  if (CACHE.delete(key)) schedulePersist();
  notify(key);
}

export function invalidateCachePrefix(prefix) {
  if (!prefix) return;
  let changed = false;
  const toNotify = [];
  CACHE.forEach((_, key) => {
    if (key.startsWith(prefix)) {
      CACHE.delete(key);
      changed = true;
      toNotify.push(key);
    }
  });
  if (changed) schedulePersist();
  toNotify.forEach(notify);
}

export function clearRouteCache() {
  CACHE.clear();
  if (typeof sessionStorage !== 'undefined') {
    try {
      sessionStorage.removeItem(SESSION_KEY);
    } catch {
      /* ignore */
    }
  }
  const keys = Array.from(SUBS.keys());
  keys.forEach(notify);
}

function subscribe(key, fn) {
  if (!SUBS.has(key)) SUBS.set(key, new Set());
  SUBS.get(key).add(fn);
  return () => {
    const set = SUBS.get(key);
    if (!set) return;
    set.delete(fn);
    if (set.size === 0) SUBS.delete(key);
  };
}

/**
 * Named cache keys. Keeping them in one place lets us invalidate groups
 * (e.g. "all profile lists") without hunting through components.
 */
export const CACHE_KEYS = {
  home: 'home:dashboard',
  movieLanding: 'landing:movies',
  tvLanding: 'landing:tv',
  movieGenre: (id) => `landing:movies:genre:${id}`,
  tvGenre: (id) => `landing:tv:genre:${id}`,
  movieDetail: (id) => `detail:movie:${id}`,
  movieSimilar: (id) => `detail:movie:${id}:similar`,
  movieDiary: (id) => `movie:diary:${id}`,
  tvDetail: (id) => `detail:tv:${id}`,
  tvSimilar: (id) => `detail:tv:${id}:similar`,
  tvContinue: (id) => `tv:continue:${id}`,
  tvLibrary: (tab) => `tv:library:${tab}`,
  profile: 'profile:main',
  profileList: (listKey) => `profile:list:${listKey}`,
};

/** Invalidate all surfaces that read user-owned movie / film data. */
export function invalidateUserMovieLists() {
  invalidateCache(CACHE_KEYS.home);
  invalidateCache(CACHE_KEYS.profile);
  invalidateCachePrefix('profile:list:');
  invalidateCachePrefix('movie:diary:');
}

/** Invalidate all surfaces that read user-owned TV data. */
export function invalidateUserTvLists() {
  invalidateCache(CACHE_KEYS.home);
  invalidateCache(CACHE_KEYS.profile);
  invalidateCachePrefix('profile:list:');
  invalidateCachePrefix('tv:library:');
  invalidateCachePrefix('tv:continue:');
}

/** Clear everything — used on sign-out so the next user never sees stale rows. */
export function clearUserRouteCaches() {
  clearRouteCache();
}

/**
 * SWR-style resource hook.
 *
 * @param {string|null} key    Cache key (null disables).
 * @param {(signal: AbortSignal) => Promise<any>} fetcher
 * @param {{ ttl?: number, enabled?: boolean }} [options]
 *        `ttl` ms before cached data is considered stale and we revalidate
 *        in the background (data still returned instantly).
 */
export default function useCachedResource(key, fetcher, options = {}) {
  const { ttl = 60_000, enabled = true } = options;
  const fetcherRef = useRef(fetcher);
  fetcherRef.current = fetcher;
  const mountedRef = useRef(true);
  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
    };
  }, []);

  const [state, setState] = useState(() => {
    if (!key || !enabled) {
      return { data: null, builtAt: 0, loading: false, error: null, fromCache: false };
    }
    const cached = readCache(key);
    if (cached) {
      return {
        data: cached.data,
        builtAt: cached.builtAt,
        loading: false,
        error: null,
        fromCache: true,
      };
    }
    return { data: null, builtAt: 0, loading: true, error: null, fromCache: false };
  });

  const load = useCallback(
    async (force) => {
      if (!key) return undefined;
      let inflight = INFLIGHT.get(key);
      if (!inflight || force) {
        const controller = new AbortController();
        inflight = Promise.resolve()
          .then(() => fetcherRef.current(controller.signal))
          .then((data) => {
            INFLIGHT.delete(key);
            writeCache(key, data); // notifies subscribers
            return data;
          })
          .catch((err) => {
            INFLIGHT.delete(key);
            throw err;
          });
        INFLIGHT.set(key, inflight);
      }
      try {
        const data = await inflight;
        if (mountedRef.current) {
          setState({
            data,
            builtAt: Date.now(),
            loading: false,
            error: null,
            fromCache: false,
          });
        }
        return data;
      } catch (err) {
        if (mountedRef.current) {
          setState((s) => ({
            ...s,
            loading: s.data == null,
            error: err,
          }));
        }
        throw err;
      }
    },
    [key]
  );

  // Sync state to the new key *before* paint so switching genres / tabs
  // never flashes the previous key's data.
  const lastKeyRef = useRef(key);
  useLayoutEffect(() => {
    if (lastKeyRef.current === key) return;
    lastKeyRef.current = key;
    if (!key || !enabled) {
      setState({ data: null, builtAt: 0, loading: false, error: null, fromCache: false });
      return;
    }
    const cached = readCache(key);
    if (cached) {
      setState({
        data: cached.data,
        builtAt: cached.builtAt,
        loading: false,
        error: null,
        fromCache: true,
      });
    } else {
      setState({ data: null, builtAt: 0, loading: true, error: null, fromCache: false });
    }
  }, [key, enabled]);

  useEffect(() => {
    if (!key || !enabled) return undefined;
    const cached = readCache(key);
    if (cached) {
      const isStale = Date.now() - cached.builtAt > ttl;
      if (isStale) load(false).catch(() => {});
    } else {
      load(false).catch(() => {});
    }
    return subscribe(key, () => {
      const latest = readCache(key);
      if (!mountedRef.current) return;
      if (latest) {
        setState({
          data: latest.data,
          builtAt: latest.builtAt,
          loading: false,
          error: null,
          fromCache: true,
        });
      } else {
        // Explicit invalidation elsewhere — refetch so this view stays live.
        load(true).catch(() => {});
      }
    });
  }, [key, enabled, ttl, load]);

  const refresh = useCallback(() => load(true), [load]);

  return {
    data: state.data,
    builtAt: state.builtAt,
    loading: state.loading,
    error: state.error,
    fromCache: state.fromCache,
    refresh,
  };
}
