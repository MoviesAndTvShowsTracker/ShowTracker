import { IMAGE_URL } from '../../config/keys';
import { tmdbFetch } from '../../utils/tmdb';
import useCachedResource, { CACHE_KEYS } from '../../utils/routeCache';
import PosterTile from '../ui/PosterTile';

export default function SimilarMoviesData({ movieId }) {
  const { data } = useCachedResource(
    movieId ? CACHE_KEYS.movieSimilar(movieId) : null,
    (signal) =>
      tmdbFetch(`movie/${movieId}/similar`, { page: 1 }, { signal })
        .then((d) => d.results || [])
        .catch(() => []),
    { ttl: 24 * 60 * 60_000, enabled: Boolean(movieId) }
  );

  const similarMovies = data || [];
  if (!similarMovies.length) return null;

  return (
    <section className="mt-8">
      <h2 className="section-title mb-3">More like this</h2>
      <div className="poster-rail">
        {similarMovies.map(
          (movie) =>
            movie.poster_path && (
              <PosterTile
                key={movie.id}
                to={`/movies/${movie.id}`}
                poster={movie.poster_path}
                title={movie.title}
                imageUrlPrefix={`${IMAGE_URL}w342`}
                size="sm"
              />
            )
        )}
      </div>
    </section>
  );
}
