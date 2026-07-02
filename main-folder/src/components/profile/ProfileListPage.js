import { useEffect, useState } from 'react';
import { Link, Navigate, useParams } from 'react-router-dom';
import api from '../../api/axios';
import { IMAGE_URL } from '../../config/keys';
import { PROFILE_LISTS } from '../../config/profileLists';
import PageTitle from '../../utils/PageTitle';
import BackNav from '../ui/BackNav';
import PosterTile from '../ui/PosterTile';

async function fetchListItems(listKey) {
  switch (listKey) {
    case 'favorite-films': {
      const r = await api.post('/api/favorite/getFavoriteMovie', {});
      return r.data.success ? r.data.favorites || [] : [];
    }
    case 'favorite-tv': {
      const r = await api.post('/api/tv/favorite/getFavoriteMovie', {});
      return r.data.success ? r.data.favorites || [] : [];
    }
    case 'watched-films': {
      const r = await api.post('/api/watch/getWatchMovie', {});
      return r.data.success ? r.data.watch || [] : [];
    }
    case 'watched-tv': {
      const r = await api.post('/api/tv/watch/getWatchTv', {});
      return r.data.success ? r.data.watch || [] : [];
    }
    case 'film-watchlist': {
      const r = await api.post('/api/watchlist/getMovieWatchlist', {});
      return r.data.success ? r.data.watchlist || [] : [];
    }
    case 'tv-watchlist': {
      const r = await api.post('/api/tv/watchlist/getTvWatchlist', {});
      return r.data.success ? r.data.watchlist || [] : [];
    }
    default:
      return null;
  }
}

function removeFromList(listKey, id) {
  switch (listKey) {
    case 'favorite-films':
      return api.post('/api/favorite/removeFromFavorite', { movieId: id });
    case 'favorite-tv':
      return api.post('/api/tv/favorite/removeFromFavorite', { tvId: id });
    case 'watched-films':
      return api.post('/api/watch/removeFromWatched', { movieId: id });
    case 'watched-tv':
      return api.post('/api/tv/watch/removeFromWatched', { tvId: id });
    case 'film-watchlist':
      return api.post('/api/watchlist/removeFromWatchlist', { movieId: id });
    case 'tv-watchlist':
      return api.post('/api/tv/watchlist/removeFromWatchlist', { tvId: id });
    default:
      return Promise.resolve();
  }
}

const REMOVABLE = new Set([
  'favorite-films',
  'favorite-tv',
  'watched-films',
  'watched-tv',
  'film-watchlist',
  'tv-watchlist',
]);

export default function ProfileListPage() {
  const { listKey } = useParams();
  const config = PROFILE_LISTS[listKey];
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);

  const load = () => {
    if (!config) return;
    setLoading(true);
    fetchListItems(listKey)
      .then((data) => setItems(data || []))
      .catch(() => setItems([]))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    load();
    window.scrollTo(0, 0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [listKey]);

  if (!config) return <Navigate to="/profile" replace />;

  const isMovie = config.kind === 'movie';
  const canRemove = REMOVABLE.has(listKey);

  const handleRemove = (id) => {
    removeFromList(listKey, id).then(load);
  };

  return (
    <>
      <PageTitle title={config.title} />

      <div className="mx-auto max-w-content px-4 py-6 sm:px-6 md:py-10">
        <BackNav fallback="/profile" label="Back to profile" className="mb-4" />

        <header className="mb-6 md:mb-8">
          <h1 className="page-title">{config.title}</h1>
          {!loading && (
            <p className="mt-2 text-sm text-muted">
              {items.length} {items.length === 1 ? 'title' : 'titles'}
            </p>
          )}
        </header>

        {loading ? (
          <div className="poster-grid">
            {[1, 2, 3, 4, 5, 6].map((i) => (
              <div key={i} className="aspect-[2/3] animate-pulse rounded-xl bg-surface-raised" />
            ))}
          </div>
        ) : items.length === 0 ? (
          <div className="glass-card p-8 text-center">
            <p className="text-sm text-muted">{config.empty}</p>
            <Link
              to={isMovie ? '/movies' : '/tv'}
              className="btn-primary mt-5 inline-flex"
            >
              Browse {isMovie ? 'films' : 'TV'}
            </Link>
          </div>
        ) : (
          <div className="poster-grid">
            {items.map((item) =>
              isMovie ? (
                <PosterTile
                  key={item.movieId}
                  to={`/movies/${item.movieId}`}
                  poster={item.moviePosterImage}
                  title={item.movieTitle}
                  imageUrlPrefix={`${IMAGE_URL}w342`}
                  size="fill"
                  onRemove={canRemove ? () => handleRemove(item.movieId) : undefined}
                />
              ) : (
                <PosterTile
                  key={item.tvId}
                  to={`/tv/${item.tvId}`}
                  poster={item.tvPosterImage}
                  title={item.tvTitle}
                  imageUrlPrefix={`${IMAGE_URL}w342`}
                  size="fill"
                  onRemove={canRemove ? () => handleRemove(item.tvId) : undefined}
                />
              )
            )}
          </div>
        )}
      </div>
    </>
  );
}
