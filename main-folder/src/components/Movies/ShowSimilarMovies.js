import { useEffect, useState } from 'react';
import { IMAGE_URL } from '../../config/keys';
import { tmdbFetch } from '../../utils/tmdb';
import PosterTile from '../ui/PosterTile';

export default function SimilarMoviesData({ movieId }) {
  const [similarMovies, setSimilarMovies] = useState([]);

  useEffect(() => {
    tmdbFetch(`movie/${movieId}/similar`, { page: 1 })
      .then((data) => setSimilarMovies(data.results || []))
      .catch(() => setSimilarMovies([]));
  }, [movieId]);

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
