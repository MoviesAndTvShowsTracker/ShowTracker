import { useEffect, useState } from 'react';
import api from '../../api/axios';
import { fetchTvWatchlist } from '../../api/tvWatchlist';
import { IMAGE_URL } from '../../config/keys';
import { profileListPath } from '../../config/profileLists';
import PosterRail from '../ui/PosterRail';
import PosterTile from '../ui/PosterTile';

const CONFIG = {
  movie: {
    endpoint: '/api/watchlist/getMovieWatchlist',
    listKey: 'film-watchlist',
    title: 'Your watchlist',
    idKey: 'movieId',
    titleKey: 'movieTitle',
    posterKey: 'moviePosterImage',
    basePath: '/movies',
  },
  tv: {
    fetch: fetchTvWatchlist,
    listKey: 'tv-watchlist',
    title: 'Your watchlist',
    idKey: 'tvId',
    titleKey: 'tvTitle',
    posterKey: 'tvPosterImage',
    basePath: '/tv',
  },
};

export default function MyWatchlistRail({ type }) {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const cfg = CONFIG[type];

  useEffect(() => {
    setLoading(true);
    const cfg = CONFIG[type];
    const load = cfg.fetch || (() => api.post(cfg.endpoint, {}).then((r) => r.data.watchlist || []));
    load()
      .then((watchlist) => setItems(watchlist || []))
      .catch(() => setItems([]))
      .finally(() => setLoading(false));
  }, [type]);

  if (loading || !items.length) return null;

  return (
    <PosterRail
      title={cfg.title}
      actionTo={profileListPath(cfg.listKey)}
      actionLabel="View all"
    >
      {items.map((item) => (
        <PosterTile
          key={item[cfg.idKey]}
          to={`${cfg.basePath}/${item[cfg.idKey]}`}
          poster={item[cfg.posterKey]}
          title={item[cfg.titleKey]}
          imageUrlPrefix={`${IMAGE_URL}w342`}
          size="sm"
        />
      ))}
    </PosterRail>
  );
}
