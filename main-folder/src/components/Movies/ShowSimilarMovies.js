import { useEffect, useState } from 'react';
import { API_KEY, API_URL, IMAGE_URL } from '../../config/keys';
import PosterTile from '../ui/PosterTile';

export default function SimilarMoviesData({ movieId }) {
  const [similarMovies, setSimilarMovies] = useState([]);

  useEffect(() => {
    fetch(`${API_URL}movie/${movieId}/similar?api_key=${API_KEY}&language=en-US&page=1`)
      .then((r) => r.json())
      .then((data) => setSimilarMovies(data.results || []));
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
