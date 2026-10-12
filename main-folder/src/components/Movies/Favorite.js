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
import useAnimatedPresence from '../../hooks/useAnimatedPresence';
import ActionStrip, { ActionButton } from '../ui/ActionStrip';
import { RatingField, ratingToStars, starsToPayload } from '../ui/StarRating';
import { haptic } from '../../utils/haptics';

export default function Favorite({ movieId, movieInfo }) {
  const { confirm, confirmDialog } = useConfirmDialog();
  const [favoriteNumber, setFavoriteNumber] = useState(0);
  const [favorited, setFavorited] = useState(false);
  const [watched, setWatched] = useState(false);
  const [watchedAt, setWatchedAt] = useState(null);
  const [watchlisted, setWatchlisted] = useState(false);
  const [rating, setRating] = useState(0);
  const [ratingSaving, setRatingSaving] = useState(false);

  const payload = {
    movieId,
    movieTitle: movieInfo.title,
    movieImage: movieInfo.backdrop_path,
    moviePosterImage: movieInfo.poster_path,
    movieRuntime: movieInfo.runtime,
  };

  const movieTitle = movieInfo.title || 'this film';
  const watchedDateLabel = watchedAt ? formatShortDate(watchedAt) : null;
  const watchlistPresence = useAnimatedPresence(!watched, 160);

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
        setRating(ratingToStars(watch.data.rating));
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
        haptic('light');
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
              setRating(0);
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
        setRating(ratingToStars(r.data.rating));
        clearSessionStats();
        haptic('success');
      }
    });
  };

  const handleRate = async (stars) => {
    if (!watched || ratingSaving) return;
    const prev = rating;
    setRating(stars || 0);
    setRatingSaving(true);
    try {
      const r = await api.post('/api/watch/rate', {
        movieId,
        rating: starsToPayload(stars),
      });
      if (r.data.success) {
        setRating(ratingToStars(r.data.rating));
        clearSessionStats();
      } else {
        setRating(prev);
      }
    } catch {
      setRating(prev);
    } finally {
      setRatingSaving(false);
    }
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
      <ActionStrip columns={watchlistPresence.rendered ? 3 : 2}>
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
        {watchlistPresence.rendered && (
          <ActionButton
            active={watchlisted}
            onClick={toggleWatchlist}
            icon={Bookmark}
            label={watchlisted ? 'On watchlist' : 'Watchlist'}
            compactLabel="List"
            className={watchlistPresence.exiting ? 'action-slot-exit' : ''}
          />
        )}
      </ActionStrip>
      <RatingField
        visible={watched}
        value={rating}
        onChange={handleRate}
        disabled={ratingSaving}
        title={movieTitle}
      />
      {confirmDialog}
    </div>
  );
}
