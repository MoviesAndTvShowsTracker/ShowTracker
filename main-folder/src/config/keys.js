// Public TMDB image CDN base. Key-protected API calls now go through the
// backend proxy at /api/tmdb/* — see src/utils/tmdb.js.
export const IMAGE_URL = process.env.REACT_APP_TMDB_IMAGE_URL || 'https://image.tmdb.org/t/p/';
