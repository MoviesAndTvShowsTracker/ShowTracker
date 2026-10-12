import { IMAGE_URL } from '../../config/keys';
import { tmdbFetch } from '../../utils/tmdb';
import useCachedResource, { CACHE_KEYS } from '../../utils/routeCache';
import PosterTile from '../ui/PosterTile';

export default function SimilarTvShows({ showId }) {
  const { data } = useCachedResource(
    showId ? CACHE_KEYS.tvSimilar(showId) : null,
    (signal) =>
      tmdbFetch(`tv/${showId}/recommendations`, { page: 1 }, { signal })
        .then((d) => d.results || [])
        .catch(() => []),
    { ttl: 24 * 60 * 60_000, enabled: Boolean(showId) }
  );

  const similarShows = data || [];
  if (!similarShows.length) return null;

  return (
    <section className="mt-8">
      <h2 className="section-title mb-3">More like this</h2>
      <div className="poster-rail">
        {similarShows.map(
          (show) =>
            show.poster_path && (
              <PosterTile
                key={show.id}
                to={`/tv/${show.id}`}
                poster={show.poster_path}
                title={show.name}
                imageUrlPrefix={`${IMAGE_URL}w342`}
                size="sm"
              />
            )
        )}
      </div>
    </section>
  );
}
