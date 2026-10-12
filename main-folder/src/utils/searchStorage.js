const CACHE_KEY = 'marquee-search-cache';
const RECENT_KEY = 'marquee-recent-searches';
const MAX_RECENT = 8;

export function loadSearchCache() {
  try {
    const raw = sessionStorage.getItem(CACHE_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

export function saveSearchCache(payload) {
  try {
    sessionStorage.setItem(CACHE_KEY, JSON.stringify(payload));
  } catch {
    /* ignore quota */
  }
}

export function clearSearchCache() {
  sessionStorage.removeItem(CACHE_KEY);
}

/** Returns cached search payload when query + type match, else null. */
export function getMatchingSearchCache(query, type) {
  const trimmed = query.trim();
  if (trimmed.length < 2) return null;
  const cache = loadSearchCache();
  if (cache?.query === trimmed && cache?.type === type && cache.results?.length) {
    return cache;
  }
  return null;
}

export function loadRecentSearches() {
  try {
    const raw = localStorage.getItem(RECENT_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

export function pushRecentSearch(query, type) {
  const trimmed = query.trim();
  if (!trimmed) return;
  const entry = { query: trimmed, type };
  const prev = loadRecentSearches().filter(
    (item) => !(item.query === entry.query && item.type === entry.type)
  );
  const next = [entry, ...prev].slice(0, MAX_RECENT);
  localStorage.setItem(RECENT_KEY, JSON.stringify(next));
  return next;
}

export function clearRecentSearches() {
  localStorage.removeItem(RECENT_KEY);
}
