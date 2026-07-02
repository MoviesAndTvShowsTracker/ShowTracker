import { API_KEY, API_URL, IMAGE_URL } from '../config/keys';

export { IMAGE_URL };

export function tmdbFetch(path, params = {}) {
  const url = new URL(`${API_URL}${path.replace(/^\//, '')}`);
  url.searchParams.set('api_key', API_KEY);
  url.searchParams.set('language', 'en-US');
  Object.entries(params).forEach(([key, value]) => {
    if (value != null && value !== '') url.searchParams.set(key, String(value));
  });
  return fetch(url).then((res) => {
    if (!res.ok) throw new Error(`TMDB ${path} failed`);
    return res.json();
  });
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
