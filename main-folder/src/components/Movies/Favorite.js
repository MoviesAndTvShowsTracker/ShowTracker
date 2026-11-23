import { useEffect, useState } from 'react';
import { Bookmark, Check, Heart } from 'lucide-react';
import api from '../../api/axios';
import { clearSessionStats } from '../../utils/statsCache';
import { invalidateUserMovieLists } from '../../utils/routeCache';
import { formatShortDate } from '../../utils/statsFormat';
import {
  favoriteRemoveConfirm,
  watchlistRemoveConfirm,
  watchedFilmManageConfirm,
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
  const [watchCount, setWatchCount] = useState(0);
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
  const watchedSubLabel = watched
    ? watchCount > 1
      ? `×${watchCount}`
      : watchedAt
        ? formatShortDate(watchedAt)
        : 'Logged'
    : null;
  const watchlistPresence = useAnimatedPresence(!watched, 140);

  const applyWatchState = (data = {}) => {
    const count = Math.max(0, Number(data.watchCount) || (data.watched ? 1 : 0));
    setWatchCount(count);
    setWatched(count > 0 || Boolean(data.watched));
    setWatchedAt(data.watchedAt || null);
    if (data.rating !== undefined) {
      setRating(ratingToStars(data.rating));
    } else if (count === 0) {
      setRating(0);
    }
  };

  useEffect(() => {
    api.post('/api/favorite/favoriteNumber', { movieId }).then((r) => {
      if (r.data.success) setFavoriteNumber(r.data.favoriteNumber);
    });
    api.post('/api/favorite/favorited', { movieId }).then((fav) => {
      if (fav.data.success) setFavorited(fav.data.favorited);
    });
    api.post('/api/watch/watched', { movieId }).then((watch) => {
      if (watch.data.success) applyWatchState(watch.data);
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
              invalidateUserMovieLists();
            }
          }),
      });
      return;
    }
    api.post('/api/favorite/addToFavorite', payload).then((r) => {
      if (r.data.success) {
        setFavoriteNumber(favoriteNumber + 1);
        setFavorited(true);
        invalidateUserMovieLists();
        haptic('light');
      }
    });
  };

  const logWatch = async ({ isRewatch } = {}) => {
    const r = await api.post('/api/watch/addToWatch', payload);
    if (r.data.success) {
      applyWatchState({
        watched: true,
        watchCount: r.data.watchCount,
        watchedAt: r.data.watchedAt || new Date().toISOString(),
        rating: r.data.rating,
      });
      setWatchlisted(false);
      clearSessionStats();
      invalidateUserMovieLists();
      haptic(isRewatch ? 'medium' : 'success');
    }
  };

  const removeWatch = async (mode) => {
    const r = await api.post('/api/watch/removeFromWatched', { ...payload, mode });
    if (r.data.success) {
      applyWatchState(r.data);
      clearSessionStats();
      invalidateUserMovieLists();
      haptic('light');
    }
  };

  const toggleWatched = () => {
    if (watched) {
      const sheet = watchedFilmManageConfirm(movieTitle, watchCount);
      const actions = [
        {
          label: 'Log again',
          primary: true,
          onClick: () => logWatch({ isRewatch: true }),
        },
      ];
      if (watchCount > 1) {
        actions.push({
          label: 'Remove last log',
          onClick: () => removeWatch('latest'),
        });
      }
      actions.push({
        label: watchCount > 1 ? 'Clear all watches' : 'Remove from watched',
        destructive: true,
        onClick: () => removeWatch('all'),
      });
      confirm({ ...sheet, actions });
      return;
    }
    logWatch({ isRewatch: false });
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
            if (r.data.success) {
              setWatchlisted(false);
              invalidateUserMovieLists();
            }
          }),
      });
      return;
    }
    api.post('/api/watchlist/addToWatchlist', payload).then((r) => {
      if (r.data.success) {
        setWatchlisted(true);
        invalidateUserMovieLists();
      }
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
          subLabel={watchedSubLabel}
          badge={watchCount > 1 ? watchCount : null}
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
