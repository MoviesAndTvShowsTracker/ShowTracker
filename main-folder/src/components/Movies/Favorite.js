import { useEffect, useState } from 'react';
import { Bookmark, Check, Heart } from 'lucide-react';
import api from '../../api/axios';
import { clearSessionStats } from '../../utils/statsCache';
import { formatShortDate } from '../../utils/statsFormat';
import {
  favoriteRemoveConfirm,
  watchlistRemoveConfirm,
  watchedFilmRemoveConfirm,
} from '../../utils/removeConfirm';
import useConfirmDialog from '../../hooks/useConfirmDialog';
import ActionStrip, { ActionButton } from '../ui/ActionStrip';

export default function Favorite({ movieId, movieInfo }) {
  const { confirm, confirmDialog } = useConfirmDialog();
  const [favoriteNumber, setFavoriteNumber] = useState(0);
  const [favorited, setFavorited] = useState(false);
  const [watched, setWatched] = useState(false);
  const [watchedAt, setWatchedAt] = useState(null);
  const [watchlisted, setWatchlisted] = useState(false);

  const payload = {
    movieId,
    movieTitle: movieInfo.title,
    movieImage: movieInfo.backdrop_path,
    moviePosterImage: movieInfo.poster_path,
    movieRuntime: movieInfo.runtime,
  };

  const movieTitle = movieInfo.title || 'this film';
  const watchedDateLabel = watchedAt ? formatShortDate(watchedAt) : null;

  useEffect(() => {
    api.post('/api/favorite/favoriteNumber', { movieId }).then((r) => {
      if (r.data.success) setFavoriteNumber(r.data.favoriteNumber);
    });
    api.post('/api/favorite/favorited', { movieId }).then((fav) => {
      if (fav.data.success) setFavorited(fav.data.favorited);
    });
    api.post('/api/watch/watched', { movieId }).then((watch) => {
      if (watch.data.success) {
        setWatched(watch.data.watched);
        setWatchedAt(watch.data.watchedAt || null);
      }
    });
    api.post('/api/watchlist/watchlisted', { movieId }).then((r) => {
      if (r.data.success) setWatchlisted(r.data.watchlisted);
    });
  }, [movieId]);

  const toggleFavorite = () => {
    if (favorited) {
      confirm({
        ...favoriteRemoveConfirm(movieTitle),
        onConfirm: () =>
          api.post('/api/favorite/removeFromFavorite', payload).then((r) => {
            if (r.data.success) {
              setFavoriteNumber(favoriteNumber - 1);
              setFavorited(false);
            }
          }),
      });
      return;
    }
    api.post('/api/favorite/addToFavorite', payload).then((r) => {
      if (r.data.success) {
        setFavoriteNumber(favoriteNumber + 1);
        setFavorited(true);
      }
    });
  };

  const toggleWatched = () => {
    if (watched) {
      confirm({
        ...watchedFilmRemoveConfirm(movieTitle),
        onConfirm: () =>
          api.post('/api/watch/removeFromWatched', payload).then((r) => {
            if (r.data.success) {
              setWatched(false);
              setWatchedAt(null);
              clearSessionStats();
            }
          }),
      });
      return;
    }
    api.post('/api/watch/addToWatch', payload).then((r) => {
      if (r.data.success) {
        setWatched(true);
        setWatchedAt(r.data.watchedAt || new Date().toISOString());
        clearSessionStats();
      }
    });
  };

  const toggleWatchlist = () => {
    if (watchlisted) {
      confirm({
        ...watchlistRemoveConfirm(movieTitle),
        onConfirm: () =>
          api.post('/api/watchlist/removeFromWatchlist', payload).then((r) => {
            if (r.data.success) setWatchlisted(false);
          }),
      });
      return;
    }
    api.post('/api/watchlist/addToWatchlist', payload).then((r) => {
      if (r.data.success) setWatchlisted(true);
    });
  };

  return (
    <div>
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
          label="Watched"
          compactLabel="Watched"
          subLabel={watched ? watchedDateLabel : null}
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
      {confirmDialog}
    </div>
  );
}
