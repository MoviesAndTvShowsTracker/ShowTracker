import { useEffect, useState } from 'react';
import { IMAGE_URL } from '../../config/keys';
import { tmdbFetch } from '../../utils/tmdb';
import PosterTile from '../ui/PosterTile';

export default function SimilarTvShows({ showId }) {
  const [similarShows, setSimilarShows] = useState([]);

  useEffect(() => {
    tmdbFetch(`tv/${showId}/recommendations`, { page: 1 })
      .then((data) => setSimilarShows(data.results || []))
      .catch(() => setSimilarShows([]));
  }, [showId]);

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
