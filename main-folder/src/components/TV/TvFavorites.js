import { useEffect, useState } from 'react';
import { Bookmark, Heart } from 'lucide-react';
import api from '../../api/axios';
import ActionStrip, { ActionButton } from '../ui/ActionStrip';

export default function TvFavorites({ tvId, tvInfo }) {
  const [favoriteNumber, setFavoriteNumber] = useState(0);
  const [favorited, setFavorited] = useState(false);
  const [watchlisted, setWatchlisted] = useState(false);

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
  }, [tvId]);

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
      <ActionButton
        active={watchlisted}
        onClick={toggleWatchlist}
        icon={Bookmark}
        label={watchlisted ? 'On watchlist' : 'Watchlist'}
        compactLabel="List"
      />
    </ActionStrip>
  );
}
