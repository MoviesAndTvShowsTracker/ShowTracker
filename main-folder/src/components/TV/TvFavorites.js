import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Bookmark, CheckCircle2, Heart, PauseCircle, PlayCircle } from 'lucide-react';
import api from '../../api/axios';
import useConfirmDialog from '../../hooks/useConfirmDialog';
import { favoriteRemoveConfirm, watchlistRemoveConfirm } from '../../utils/removeConfirm';
import { clearSessionStats } from '../../utils/statsCache';
import { invalidateUserTvLists } from '../../utils/routeCache';
import ActionStrip, { ActionButton } from '../ui/ActionStrip';
import { RatingField, ratingToStars, starsToPayload } from '../ui/StarRating';
import { haptic } from '../../utils/haptics';

function listStateFromTrack(track) {
  if (!track || track.status === 'dropped') return null;
  if (track.status === 'completed') return 'completed';
  if (track.status === 'paused') return 'stopped';
  return 'watching';
}

export default function TvFavorites({ tvId, tvInfo, diary, onDiaryPatch }) {
  const navigate = useNavigate();
  const { confirm, confirmDialog } = useConfirmDialog();
  const { tracking, favoriteNumber, favorited, watchlisted } = diary;
  const [ratingSaving, setRatingSaving] = useState(false);
  const showTitle = tvInfo.name || 'this show';
  const canRateShow = Boolean(tracking && (tracking.watchedEpisodeCount || 0) >= 1);
  const showRating = ratingToStars(tracking?.rating);

  const payload = {
    tvId,
    tvTitle: tvInfo.name,
    tvImage: tvInfo.backdrop_path,
    tvPosterImage: tvInfo.poster_path,
    tvRuntime: tvInfo.episode_run_time,
  };

  const toggleFavorite = () => {
    if (favorited) {
      confirm({
        ...favoriteRemoveConfirm(showTitle),
        onConfirm: () =>
          api.post('/api/tv/favorite/removeFromFavorite', payload).then((r) => {
            if (r.data.success) {
              onDiaryPatch({
                favorited: false,
                favoriteNumber: favoriteNumber - 1,
              });
              invalidateUserTvLists();
            }
          }),
      });
      return;
    }
    api.post('/api/tv/favorite/addToFavorite', payload).then((r) => {
      if (r.data.success) {
        onDiaryPatch({
          favorited: true,
          favoriteNumber: favoriteNumber + 1,
        });
        invalidateUserTvLists();
        haptic('light');
      }
    });
  };

  const toggleWatchlist = () => {
    if (watchlisted) {
      confirm({
        ...watchlistRemoveConfirm(showTitle),
        onConfirm: () =>
          api.post('/api/tv/watchlist/removeFromWatchlist', payload).then((r) => {
            if (r.data.success) {
              onDiaryPatch({ watchlisted: false });
              invalidateUserTvLists();
            }
          }),
      });
      return;
    }
    api.post('/api/tv/watchlist/addToWatchlist', payload).then((r) => {
      if (r.data.success) {
        onDiaryPatch({ watchlisted: true });
        invalidateUserTvLists();
      }
    });
  };

  const listState = listStateFromTrack(tracking);
  const goToProgress = () => navigate(`/tv/${tvId}/continue`);

  const handleRateShow = async (stars) => {
    if (!canRateShow || ratingSaving) return;
    const prevRating = tracking?.rating ?? null;
    const next = starsToPayload(stars);
    // Optimistic: patch tracking.rating locally.
    onDiaryPatch({
      tracking: tracking ? { ...tracking, rating: next ? next : null } : tracking,
    });
    setRatingSaving(true);
    try {
      const r = await api.post('/api/tv/tracking/rate', { tvId, rating: next });
      if (r.data?.success) {
        onDiaryPatch({ tracking: r.data.tracking || tracking });
        clearSessionStats();
      } else {
        onDiaryPatch({
          tracking: tracking ? { ...tracking, rating: prevRating } : tracking,
        });
      }
    } catch {
      onDiaryPatch({
        tracking: tracking ? { ...tracking, rating: prevRating } : tracking,
      });
    } finally {
      setRatingSaving(false);
    }
  };

  const statusButton = (() => {
    if (listState === 'completed') {
      return (
        <ActionButton
          active
          static
          icon={CheckCircle2}
          label="Completed"
          compactLabel="Done"
          variant="success"
        />
      );
    }
    if (listState === 'stopped') {
      return (
        <ActionButton
          active
          onClick={goToProgress}
          icon={PauseCircle}
          label="Paused"
          compactLabel="Paused"
          variant="warning"
        />
      );
    }
    if (listState === 'watching') {
      return (
        <ActionButton
          active
          onClick={goToProgress}
          icon={PlayCircle}
          label="Watching"
          compactLabel="Watching"
          variant="accent"
        />
      );
    }
    return (
      <ActionButton
        active={watchlisted}
        onClick={toggleWatchlist}
        icon={Bookmark}
        label={watchlisted ? 'On watchlist' : 'Watchlist'}
        compactLabel="List"
      />
    );
  })();

  return (
    <>
      <ActionStrip columns={2}>
        <ActionButton
          active={favorited}
          onClick={toggleFavorite}
          icon={Heart}
          label={favorited ? 'Favorited' : 'Favorite'}
          compactLabel="Favorite"
          badge={favoriteNumber}
        />
        {statusButton}
      </ActionStrip>
      <RatingField
        visible={canRateShow}
        value={showRating}
        onChange={handleRateShow}
        disabled={ratingSaving}
        title={showTitle}
      />
      {confirmDialog}
    </>
  );
}
