import { useEffect, useState } from 'react';
import api from '../api/axios';
import { useAuth } from '../context/AuthContext';

function normId(id) {
  return String(id ?? '').trim();
}

/**
 * One-shot diary maps for search tiles — avoids N per-result status requests.
 */
export default function useSearchDiaryContext() {
  const { isAuthenticated } = useAuth();
  const [context, setContext] = useState(null);
  const [ready, setReady] = useState(!isAuthenticated);

  useEffect(() => {
    if (!isAuthenticated) {
      setContext(null);
      setReady(true);
      return undefined;
    }

    let cancelled = false;
    setReady(false);

    Promise.all([
      api.get('/api/tv/tracking/library/watching').catch(() => ({ data: {} })),
      api.get('/api/tv/tracking/library/stopped').catch(() => ({ data: {} })),
      api.get('/api/tv/tracking/library/finished').catch(() => ({ data: {} })),
      api.post('/api/watchlist/getMovieWatchlist', {}).catch(() => ({ data: {} })),
      api.post('/api/tv/watchlist/getTvWatchlist', {}).catch(() => ({ data: {} })),
      api.post('/api/watch/getWatchMovie', {}).catch(() => ({ data: {} })),
    ])
      .then(([watching, stopped, finished, movieWl, tvWl, watchedFilms]) => {
        if (cancelled) return;

        const tvTracks = new Map();
        for (const res of [watching, stopped, finished]) {
          for (const track of res.data?.tracks || []) {
            const id = normId(track.tvId);
            if (id) tvTracks.set(id, track);
          }
        }

        const movieWatchlist = new Set(
          (movieWl.data?.success ? movieWl.data.watchlist || [] : [])
            .map((m) => normId(m.movieId))
            .filter(Boolean)
        );

        const tvWatchlist = new Set(
          (tvWl.data?.success ? tvWl.data.watchlist || [] : [])
            .map((s) => normId(s.tvId))
            .filter((id) => id && !tvTracks.has(id))
        );

        const watchedMovies = new Set(
          (watchedFilms.data?.success ? watchedFilms.data.watch || [] : [])
            .map((m) => normId(m.movieId))
            .filter(Boolean)
        );

        setContext({ tvTracks, movieWatchlist, tvWatchlist, watchedMovies });
        setReady(true);
      })
      .catch(() => {
        if (cancelled) return;
        setContext({
          tvTracks: new Map(),
          movieWatchlist: new Set(),
          tvWatchlist: new Set(),
          watchedMovies: new Set(),
        });
        setReady(true);
      });

    return () => {
      cancelled = true;
    };
  }, [isAuthenticated]);

  const patchWatchlist = (media, id, listed) => {
    const key = normId(id);
    if (!key) return;
    setContext((prev) => {
      if (!prev) return prev;
      const next = {
        ...prev,
        movieWatchlist: new Set(prev.movieWatchlist),
        tvWatchlist: new Set(prev.tvWatchlist),
      };
      const set = media === 'tv' ? next.tvWatchlist : next.movieWatchlist;
      if (listed) set.add(key);
      else set.delete(key);
      return next;
    });
  };

  return { context, ready, patchWatchlist };
}
