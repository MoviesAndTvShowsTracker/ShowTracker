import api from './axios';

function normTvId(id) {
  return String(id ?? '').trim();
}

/** All shows in Watching / Paused / Finished — library tab paths, not status names. */
async function fetchInLibraryTvIds() {
  const [watching, stopped, finished] = await Promise.all([
    api.get('/api/tv/tracking/library/watching').catch(() => ({ data: {} })),
    api.get('/api/tv/tracking/library/stopped').catch(() => ({ data: {} })),
    api.get('/api/tv/tracking/library/finished').catch(() => ({ data: {} })),
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
