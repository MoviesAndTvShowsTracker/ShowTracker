import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Bookmark, CheckCircle2, Heart, PauseCircle, PlayCircle } from 'lucide-react';
import api from '../../api/axios';
import ActionStrip, { ActionButton } from '../ui/ActionStrip';

function listStateFromTrack(track) {
  if (!track || track.status === 'dropped') return null;
  if (track.status === 'completed') return 'completed';
  if (track.status === 'paused') return 'stopped';
  return 'watching';
}

export default function TvFavorites({ tvId, tvInfo, refreshKey = 0 }) {
  const navigate = useNavigate();
  const [favoriteNumber, setFavoriteNumber] = useState(0);
  const [favorited, setFavorited] = useState(false);
  const [watchlisted, setWatchlisted] = useState(false);
  const [track, setTrack] = useState(null);

  const payload = {
    tvId,
    tvTitle: tvInfo.name,
    tvImage: tvInfo.backdrop_path,
    tvPosterImage: tvInfo.poster_path,
    tvRuntime: tvInfo.episode_run_time,
  };

  useEffect(() => {
    api.post('/api/tv/favorite/favoriteNumber', { tvId }).then((r) => {
      if (r.data.success) setFavoriteNumber(r.data.favoriteNumber);
    });
    api.post('/api/tv/favorite/favorited', { tvId }).then((r) => {
      if (r.data.success) setFavorited(r.data.favorited);
    });
    api.post('/api/tv/watchlist/watchlisted', { tvId }).then((r) => {
      if (r.data.success) setWatchlisted(r.data.watchlisted);
    });
    api.get(`/api/tv/tracking/show/${tvId}`).then((r) => {
      if (r.data.success) setTrack(r.data.tracking || null);
    });
  }, [tvId, refreshKey]);

  const toggleFavorite = () => {
    const endpoint = favorited
      ? '/api/tv/favorite/removeFromFavorite'
      : '/api/tv/favorite/addToFavorite';
    api.post(endpoint, payload).then((r) => {
      if (r.data.success) {
        setFavoriteNumber(favorited ? favoriteNumber - 1 : favoriteNumber + 1);
        setFavorited(!favorited);
      }
    });
  };

  const toggleWatchlist = () => {
    const endpoint = watchlisted
      ? '/api/tv/watchlist/removeFromWatchlist'
      : '/api/tv/watchlist/addToWatchlist';
    api.post(endpoint, payload).then((r) => {
      if (r.data.success) setWatchlisted(!watchlisted);
    });
  };

  const listState = listStateFromTrack(track);
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
  );
}
