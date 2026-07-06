import api from './axios';

/** User-specific diary state for a TV show (tracking, favorites, watchlist). */
export async function fetchTvShowDiary(tvId) {
  const [trackingRes, favoriteNumberRes, favoritedRes, watchlistedRes] = await Promise.all([
    api.get(`/api/tv/tracking/show/${tvId}`).catch(() => ({ data: { success: false } })),
    api.post('/api/tv/favorite/favoriteNumber', { tvId }).catch(() => ({ data: { success: false } })),
    api.post('/api/tv/favorite/favorited', { tvId }).catch(() => ({ data: { success: false } })),
    api.post('/api/tv/watchlist/watchlisted', { tvId }).catch(() => ({ data: { success: false } })),
  ]);

  return {
    tracking: trackingRes.data?.success ? trackingRes.data.tracking || null : null,
    favoriteNumber: favoriteNumberRes.data?.success ? favoriteNumberRes.data.favoriteNumber : 0,
    favorited: favoritedRes.data?.success ? favoritedRes.data.favorited : false,
    watchlisted: watchlistedRes.data?.success ? watchlistedRes.data.watchlisted : false,
  };
}
