import api from './axios';

function normTvId(id) {
  return String(id ?? '').trim();
}

/** All shows in Watching / Stopped / Finished — works with existing library APIs. */
async function fetchInLibraryTvIds() {
  const [watching, stopped, finished] = await Promise.all([
    api.get('/api/tv/tracking/continue').catch(() => ({ data: {} })),
    api.get('/api/tv/tracking/library/paused').catch(() => ({ data: {} })),
    api.get('/api/tv/tracking/library/completed').catch(() => ({ data: {} })),
  ]);

  const ids = new Set();
  for (const res of [watching, stopped, finished]) {
    const tracks = res.data?.tracks || [];
    tracks.forEach((t) => {
      const id = normTvId(t.tvId);
      if (id) ids.add(id);
    });
  }
  return ids;
}

/**
 * Single source for TV watchlist: queued shows only (not Watching / Stopped / Finished).
 * Filters against the TV library on the client so Home and View all stay in sync even
 * if stale rows remain in the database.
 */
export async function fetchTvWatchlist() {
  const [watchlistRes, inLibraryIds] = await Promise.all([
    api.post('/api/tv/watchlist/getTvWatchlist', {}),
    fetchInLibraryTvIds(),
  ]);

  const raw = watchlistRes.data?.success ? watchlistRes.data.watchlist || [] : [];
  return raw.filter((show) => !inLibraryIds.has(normTvId(show.tvId)));
}
