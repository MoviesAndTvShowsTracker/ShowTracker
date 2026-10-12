import api from '../api/axios';
import { IMAGE_URL } from '../config/keys';

export { IMAGE_URL };

/**
 * Call TMDB through the backend proxy. The API key never ships to the browser.
 *
 * @param {string} path  TMDB path without leading slash (e.g. `tv/1399`).
 * @param {object} [params]  Query params. Omit empty values; `language` defaults to en-US server-side.
 * @param {{ signal?: AbortSignal }} [options]  Optional AbortSignal for cancellation.
 */
export function tmdbFetch(path, params = {}, options = {}) {
  const cleanPath = String(path).replace(/^\/+/, '');
  const filtered = {};
  Object.entries(params).forEach(([key, value]) => {
    if (value != null && value !== '') filtered[key] = value;
  });
  return api
    .get(`/api/tmdb/${cleanPath}`, { params: filtered, signal: options.signal })
    .then((res) => res.data);
}

/** True when an error from `tmdbFetch` / axios is due to an aborted signal. */
export function isAbortError(err) {
  if (!err) return false;
  return (
    err.name === 'AbortError' ||
    err.name === 'CanceledError' ||
    err.code === 'ERR_CANCELED'
  );
}

export function heroSlides(items, basePath, titleKey = 'title') {
  return items
    .filter((item) => item.backdrop_path)
    .slice(0, 5)
    .map((item) => ({
      id: item.id,
      title: item[titleKey],
      text: item.overview,
      image: `${IMAGE_URL}w1280${item.backdrop_path}`,
      to: `${basePath}/${item.id}`,
    }));
}

export function withPoster(items) {
  return (items || []).filter((item) => item.poster_path);
}
