import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { Clock, Film, Loader2, Search, Tv, X } from 'lucide-react';
import { IMAGE_URL } from '../config/keys';
import { tmdbFetch, withPoster } from '../utils/tmdb';
import {
  clearRecentSearches,
  clearSearchCache,
  getMatchingSearchCache,
  loadRecentSearches,
  pushRecentSearch,
  saveSearchCache,
} from '../utils/searchStorage';
import PageTitle from '../utils/PageTitle';
import useSearchDiaryContext from '../hooks/useSearchDiaryContext';
import { FOCUS_SEARCH_EVENT } from '../hooks/useSearchShortcut';
import { confirmScrollRestore } from './ScrollRestoration';
import BackNav from './ui/BackNav';
import PosterRail from './ui/PosterRail';
import PosterTile from './ui/PosterTile';
import SearchResultTile from './search/SearchResultTile';

const TABS = [
  { id: 'multi', label: 'All', icon: Search },
  { id: 'movie', label: 'Films', icon: Film },
  { id: 'tv', label: 'TV', icon: Tv },
];

const MIN_QUERY = 2;
const DEBOUNCE_MS = 400;

function normalizeMultiResults(results) {
  return (results || []).filter((item) => item.media_type === 'movie' || item.media_type === 'tv');
}

/** Sync hydrate from session cache so Back can restore scroll into a tall list. */
function initialFromUrl() {
  const params = new URLSearchParams(window.location.search);
  const q = params.get('q') || '';
  const type = params.get('type') || 'multi';
  const cache = getMatchingSearchCache(q, type);
  if (!cache) {
    return {
      query: q,
      type,
      results: [],
      page: 1,
      totalPages: 0,
      totalResults: 0,
      hasSearched: Boolean(q),
    };
  }
  return {
    query: cache.query,
    type: cache.type,
    results: cache.results,
    page: cache.page || 1,
    totalPages: cache.totalPages || 0,
    totalResults: cache.totalResults || 0,
    hasSearched: true,
  };
}

export default function SearchBox() {
  const [searchParams, setSearchParams] = useSearchParams();
  const inputRef = useRef(null);
  const { context: diary, ready: diaryReady, patchWatchlist } = useSearchDiaryContext();
  const boot = useRef(initialFromUrl()).current;

  const urlQuery = searchParams.get('q') || '';
  const urlType = searchParams.get('type') || 'multi';

  const [query, setQuery] = useState(boot.query);
  const [type, setType] = useState(boot.type);
  const [results, setResults] = useState(boot.results);
  const [page, setPage] = useState(boot.page);
  const [totalPages, setTotalPages] = useState(boot.totalPages);
  const [totalResults, setTotalResults] = useState(boot.totalResults);
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState('');
  const [recent, setRecent] = useState(loadRecentSearches);
  const [trendingFilms, setTrendingFilms] = useState([]);
  const [trendingTv, setTrendingTv] = useState([]);
  const [hasSearched, setHasSearched] = useState(boot.hasSearched);

  const applyCache = useCallback((cache) => {
    setResults(cache.results);
    setPage(cache.page || 1);
    setTotalPages(cache.totalPages || 0);
    setTotalResults(cache.totalResults || 0);
    setHasSearched(true);
    setError('');
    // Avoid replace navigations when the URL already matches — those used to
    // wipe restored scroll (treated as a fresh navigation).
    const q = searchParams.get('q') || '';
    const t = searchParams.get('type') || 'multi';
    if (q !== cache.query || t !== cache.type) {
      setSearchParams({ q: cache.query, type: cache.type }, { replace: true });
    }
  }, [searchParams, setSearchParams]);

  const runSearch = useCallback(async (searchQuery, searchType, pageNum, append = false) => {
    const trimmed = searchQuery.trim();
    if (trimmed.length < MIN_QUERY) {
      setResults([]);
      setHasSearched(false);
      setError('');
      return;
    }

    if (append) setLoadingMore(true);
    else setLoading(true);
    setError('');

    const path = searchType === 'multi' ? 'search/multi' : `search/${searchType}`;
    try {
      const data = await tmdbFetch(path, {
        query: trimmed,
        page: pageNum,
        include_adult: false,
      });

      const raw = searchType === 'multi' ? normalizeMultiResults(data.results) : data.results || [];

      setResults((prev) => {
        const next = append ? [...prev, ...raw] : raw;
        saveSearchCache({
          query: trimmed,
          type: searchType,
          results: next,
          page: pageNum,
          totalPages: data.total_pages || 0,
          totalResults: data.total_results || 0,
        });
        return next;
      });

      setPage(pageNum);
      setTotalPages(data.total_pages || 0);
      setTotalResults(data.total_results || 0);
      setHasSearched(true);

      if (!raw.length && !append) {
        setError(`No results for “${trimmed}”. Try another spelling — or browse what's trending below.`);
      }

      setSearchParams({ q: trimmed, type: searchType }, { replace: true });
      setRecent(pushRecentSearch(trimmed, searchType));
    } catch {
      setError('Search failed. Check your connection and try again.');
    } finally {
      setLoading(false);
      setLoadingMore(false);
    }
  }, [setSearchParams]);

  useEffect(() => {
    const focusInput = () => inputRef.current?.focus();
    window.addEventListener(FOCUS_SEARCH_EVENT, focusInput);
    return () => window.removeEventListener(FOCUS_SEARCH_EVENT, focusInput);
  }, []);

  // After cached results paint, re-apply POP scroll (page was short on first try).
  useLayoutEffect(() => {
    if (results.length > 0) confirmScrollRestore();
  }, [results.length, page]);

  // Trending discovery when idle
  useEffect(() => {
    if (hasSearched) return;
    tmdbFetch('trending/movie/week').then((d) => setTrendingFilms(withPoster(d.results).slice(0, 12)));
    tmdbFetch('trending/tv/week').then((d) => setTrendingTv(withPoster(d.results).slice(0, 12)));
  }, [hasSearched]);

  // Debounced search as you type
  useEffect(() => {
    const trimmed = query.trim();
    if (trimmed.length < MIN_QUERY) {
      if (!trimmed) {
        setResults([]);
        setHasSearched(false);
        setError('');
        if (urlQuery) setSearchParams({}, { replace: true });
      }
      return;
    }

    const cache = getMatchingSearchCache(trimmed, type);
    if (cache) {
      applyCache(cache);
      return;
    }

    const timer = setTimeout(() => {
      runSearch(trimmed, type, 1);
    }, DEBOUNCE_MS);

    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query]);

  const handleTabChange = (nextType) => {
    setType(nextType);
    if (query.trim().length >= MIN_QUERY) {
      runSearch(query, nextType, 1);
    } else {
      setSearchParams(query.trim() ? { q: query.trim(), type: nextType } : { type: nextType }, {
        replace: true,
      });
    }
  };

  const handleClear = () => {
    setQuery('');
    setResults([]);
    setHasSearched(false);
    setError('');
    setSearchParams({}, { replace: true });
    clearSearchCache();
    inputRef.current?.focus();
  };

  const handleRecentClick = (item) => {
    setQuery(item.query);
    setType(item.type);
    runSearch(item.query, item.type, 1);
  };

  const typeLabel = TABS.find((t) => t.id === type)?.label || 'Results';
  const showDiscovery = !hasSearched && !loading;

  return (
    <>
      <PageTitle title={query ? `Search: ${query}` : 'Search'} />

      <div className="mx-auto max-w-content px-4 pb-10 sm:px-6 md:pb-14">
        <div className="sticky top-[3.25rem] z-40 -mx-4 border-b border-border/60 bg-canvas/90 px-4 py-4 backdrop-blur-xl sm:-mx-6 sm:px-6 md:top-14">
          <BackNav fallback="/" label="Back" className="mb-3 md:hidden" />

          <div className="mx-auto max-w-2xl">
            <h1 className="page-title mb-4 hidden md:block">Search</h1>
            <p className="mb-3 hidden text-xs text-muted md:block">
              Press <kbd className="rounded border border-border bg-surface-raised px-1.5 py-0.5 font-mono text-[10px]">/</kbd> anywhere to jump here
            </p>

            <div className="relative">
              <Search className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
              <input
                ref={inputRef}
                className="input-field search-field min-h-[48px] pl-10 pr-10 text-base"
                type="search"
                placeholder="Films, TV shows, actors…"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                autoComplete="off"
                enterKeyHint="search"
              />
              {query && (
                <button
                  type="button"
                  onClick={handleClear}
                  className="pressable absolute right-1 top-1/2 flex h-11 w-11 -translate-y-1/2 items-center justify-center rounded-lg text-muted transition-colors hover:bg-surface-raised hover:text-ink-bright cursor-pointer"
                  aria-label="Clear search"
                >
                  <X className="h-4 w-4" />
                </button>
              )}
            </div>

            <div className="seg-tabs mt-3" role="tablist" aria-label="Search type">
              {TABS.map(({ id, label, icon: Icon }) => (
                <button
                  key={id}
                  type="button"
                  onClick={() => handleTabChange(id)}
                  className={`seg-tab gap-1.5 ${type === id ? 'seg-tab--active' : ''}`}
                  aria-pressed={type === id}
                >
                  <Icon className="h-3.5 w-3.5" />
                  {label}
                </button>
              ))}
            </div>
          </div>
        </div>

        <div className="mx-auto max-w-2xl pt-4 md:max-w-none">
          {recent.length > 0 && showDiscovery && (
            <section className="mb-8">
              <div className="mb-2 flex items-center justify-between">
                <h2 className="section-title flex items-center gap-1.5">
                  <Clock className="h-3.5 w-3.5" />
                  Recent
                </h2>
                <button
                  type="button"
                  onClick={() => {
                    clearRecentSearches();
                    setRecent([]);
                  }}
                  className="pressable min-h-[44px] rounded-lg px-3 py-2 text-xs font-semibold uppercase tracking-wide text-muted hover:text-ink-bright cursor-pointer"
                >
                  Clear
                </button>
              </div>
              <div className="flex flex-wrap gap-2">
                {recent.map((item) => (
                  <button
                    key={`${item.type}-${item.query}`}
                    type="button"
                    onClick={() => handleRecentClick(item)}
                    className="pressable min-h-[44px] rounded-full border border-border bg-surface/80 px-4 py-2.5 text-xs font-medium text-ink transition-colors hover:border-accent/40 hover:bg-accent/10 cursor-pointer"
                  >
                    {item.query}
                    <span className="ml-1.5 text-[10px] uppercase text-muted">
                      {item.type === 'multi' ? 'All' : item.type === 'tv' ? 'TV' : 'Films'}
                    </span>
                  </button>
                ))}
              </div>
            </section>
          )}

          {loading && (
            <div className="state-enter poster-grid mt-6" aria-busy="true" aria-label="Loading search results">
              {Array.from({ length: 12 }).map((_, i) => (
                <div key={i} className="animate-pulse rounded-xl bg-surface-raised aspect-[2/3]" />
              ))}
            </div>
          )}

          {!loading && error && (
            <p className="state-enter mt-6 rounded-xl border border-danger/30 bg-danger/10 px-4 py-3 text-sm text-danger">
              {error}
            </p>
          )}

          {!loading && hasSearched && results.length > 0 && (
            <section key={`${type}-${query.trim()}`} className="state-enter mt-6 md:mt-8">
              <div className="mb-4 flex flex-wrap items-end justify-between gap-2">
                <div>
                  <h2 className="font-serif text-lg text-ink-bright sm:text-xl">
                    {type === 'multi' ? 'Top matches' : `${typeLabel} for “${query.trim()}”`}
                  </h2>
                  <p className="mt-0.5 text-xs text-muted">
                    {type === 'multi'
                      ? `${results.length} title${results.length !== 1 ? 's' : ''} found`
                      : `${totalResults.toLocaleString()} result${totalResults !== 1 ? 's' : ''}`}
                    {page < totalPages ? ` · page ${page} of ${totalPages}` : ''}
                  </p>
                </div>
              </div>

              <div className="poster-grid">
                {results.map((item) => (
                  <SearchResultTile
                    key={`${item.media_type || type}-${item.id}`}
                    item={item}
                    mediaType={type === 'multi' ? item.media_type : type}
                    diaryReady={diaryReady}
                    diary={diary}
                    onWatchlistChange={patchWatchlist}
                  />
                ))}
              </div>

              {page < totalPages && (
                <div className="mt-8 flex justify-center">
                  <button
                    type="button"
                    disabled={loadingMore}
                    onClick={() => runSearch(query, type, page + 1, true)}
                    className="btn-secondary min-w-[10rem] gap-2 disabled:opacity-50"
                  >
                    {loadingMore ? (
                      <>
                        <Loader2 className="h-4 w-4 animate-spin" />
                        Loading…
                      </>
                    ) : (
                      'Load more'
                    )}
                  </button>
                </div>
              )}
            </section>
          )}

          {showDiscovery && (
            <div className="mt-4 space-y-10 md:mt-6">
              <p className="text-sm text-muted">
                Search films, TV, and cast — or start with what&apos;s trending.
              </p>

              <PosterRail title="Trending films" actionTo="/movies" actionLabel="Browse films">
                {trendingFilms.map((m) => (
                  <PosterTile
                    key={m.id}
                    to={`/movies/${m.id}`}
                    poster={m.poster_path}
                    title={m.title}
                    imageUrlPrefix={`${IMAGE_URL}w342`}
                    size="sm"
                  />
                ))}
              </PosterRail>

              <PosterRail title="Trending TV" actionTo="/tv" actionLabel="Browse TV">
                {trendingTv.map((s) => (
                  <PosterTile
                    key={s.id}
                    to={`/tv/${s.id}`}
                    poster={s.poster_path}
                    title={s.name}
                    imageUrlPrefix={`${IMAGE_URL}w342`}
                    size="sm"
                  />
                ))}
              </PosterRail>
            </div>
          )}
        </div>
      </div>
    </>
  );
}
