import { useEffect, useState } from 'react';
import { Bookmark, Check, Heart } from 'lucide-react';
import api from '../../api/axios';
import ActionStrip, { ActionButton } from '../ui/ActionStrip';

export default function Favorite({ movieId, movieInfo }) {
  const [favoriteNumber, setFavoriteNumber] = useState(0);
  const [favorited, setFavorited] = useState(false);
  const [watched, setWatched] = useState(false);
  const [watchlisted, setWatchlisted] = useState(false);

  const payload = {
    movieId,
    movieTitle: movieInfo.title,
    movieImage: movieInfo.backdrop_path,
    moviePosterImage: movieInfo.poster_path,
    movieRuntime: movieInfo.runtime,
  };

  useEffect(() => {
    api.post('/api/favorite/favoriteNumber', { movieId }).then((r) => {
      if (r.data.success) setFavoriteNumber(r.data.favoriteNumber);
    });
    Promise.all([
      api.post('/api/favorite/favorited', { movieId }),
      api.post('/api/watch/watched', { movieId }),
    ]).then(([fav, watch]) => {
      const isFav = fav.data.success && fav.data.favorited;
      const isWatched = watch.data.success && watch.data.watched;
      setFavorited(isFav);
      setWatched(isFav || isWatched);
    });
    api.post('/api/watchlist/watchlisted', { movieId }).then((r) => {
      if (r.data.success) setWatchlisted(r.data.watchlisted);
    });
  }, [movieId]);

  const toggleFavorite = () => {
    const endpoint = favorited ? '/api/favorite/removeFromFavorite' : '/api/favorite/addToFavorite';
    api.post(endpoint, payload).then((r) => {
      if (r.data.success) {
        setFavoriteNumber(favorited ? favoriteNumber - 1 : favoriteNumber + 1);
        setFavorited(!favorited);
        setWatched(!favorited);
      }
    });
  };

  const toggleWatched = () => {
    const endpoint = watched ? '/api/watch/removeFromWatched' : '/api/watch/addToWatch';
    api.post(endpoint, payload).then((r) => {
      if (r.data.success) setWatched(!watched);
    });
  };

  const toggleWatchlist = () => {
    const endpoint = watchlisted
      ? '/api/watchlist/removeFromWatchlist'
      : '/api/watchlist/addToWatchlist';
    api.post(endpoint, payload).then((r) => {
      if (r.data.success) setWatchlisted(!watchlisted);
    });
  };

  return (
    <ActionStrip columns={watched ? 2 : 3}>
      <ActionButton
        active={favorited}
        onClick={toggleFavorite}
        icon={Heart}
        label={favorited ? 'Favorited' : 'Favorite'}
        compactLabel="Favorite"
        badge={favoriteNumber}
      />
      <ActionButton
        active={watched}
        onClick={toggleWatched}
        icon={Check}
        label={watched ? 'Watched' : 'Mark watched'}
        compactLabel="Watched"
      />
      {!watched && (
        <ActionButton
          active={watchlisted}
          onClick={toggleWatchlist}
          icon={Bookmark}
          label={watchlisted ? 'On watchlist' : 'Watchlist'}
          compactLabel="List"
        />
      )}
    </ActionStrip>
  );
}
