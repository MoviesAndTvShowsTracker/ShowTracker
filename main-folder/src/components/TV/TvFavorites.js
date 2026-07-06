import { useNavigate } from 'react-router-dom';
import { Bookmark, CheckCircle2, Heart, PauseCircle, PlayCircle } from 'lucide-react';
import api from '../../api/axios';
import useConfirmDialog from '../../hooks/useConfirmDialog';
import { favoriteRemoveConfirm, watchlistRemoveConfirm } from '../../utils/removeConfirm';
import ActionStrip, { ActionButton } from '../ui/ActionStrip';

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
  const showTitle = tvInfo.name || 'this show';

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
      }
    });
  };

  const toggleWatchlist = () => {
    if (watchlisted) {
      confirm({
        ...watchlistRemoveConfirm(showTitle),
        onConfirm: () =>
          api.post('/api/tv/watchlist/removeFromWatchlist', payload).then((r) => {
            if (r.data.success) onDiaryPatch({ watchlisted: false });
          }),
      });
      return;
    }
    api.post('/api/tv/watchlist/addToWatchlist', payload).then((r) => {
      if (r.data.success) onDiaryPatch({ watchlisted: true });
    });
  };

  const listState = listStateFromTrack(tracking);
  const goToProgress = () => navigate(`/tv/${tvId}/continue`);

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
          label="Stopped"
          compactLabel="Stopped"
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
    {confirmDialog}
    </>
  );
}
