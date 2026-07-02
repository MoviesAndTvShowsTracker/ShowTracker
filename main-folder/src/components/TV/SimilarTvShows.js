import { useEffect, useState } from 'react';
import { API_KEY, API_URL, IMAGE_URL } from '../../config/keys';
import PosterTile from '../ui/PosterTile';

export default function SimilarTvShows({ showId }) {
  const [similarShows, setSimilarShows] = useState([]);

  useEffect(() => {
    fetch(`${API_URL}tv/${showId}/recommendations?api_key=${API_KEY}&language=en-US&page=1`)
      .then((r) => r.json())
      .then((data) => setSimilarShows(data.results || []));
  }, [showId]);

  if (!similarShows.length) return null;

  return (
    <section className="mt-8">
      <h2 className="section-title mb-3">More like this</h2>
      <div className="poster-rail -mx-4 px-4 sm:-mx-0 sm:px-0">
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
