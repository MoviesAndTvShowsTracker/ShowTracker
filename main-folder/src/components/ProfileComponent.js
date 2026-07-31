import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { Settings } from 'lucide-react';
import api from '../api/axios';
import { IMAGE_URL } from '../config/keys';
import { profileListPath } from '../config/profileLists';
import { useAuth } from '../context/AuthContext';
import PageTitle from '../utils/PageTitle';
import PosterRail from './ui/PosterRail';
import PosterTile from './ui/PosterTile';
import ProfileEmptyState from './profile/ProfileEmptyState';
import ProfileStats from './profile/ProfileStats';
import TvLibrarySummary from './profile/TvLibrarySummary';
import BackNav from './ui/BackNav';
import useConfirmDialog from '../hooks/useConfirmDialog';
import useDashboardStats from '../hooks/useDashboardStats';
import { formatMemberSince } from '../utils/statsFormat';
import {
  favoriteRemoveConfirm,
  watchedFilmRemoveConfirm,
  watchedTvRemoveConfirm,
} from '../utils/removeConfirm';

const emptyFilm = (browse) => (
  <>
    Nothing here yet.{' '}
    <Link to="/movies" className="text-link hover:text-ink-bright cursor-pointer">
      {browse}
    </Link>
  </>
);

const emptyTv = (browse) => (
  <>
    Nothing here yet.{' '}
    <Link to="/tv" className="text-link hover:text-ink-bright cursor-pointer">
      {browse}
    </Link>
  </>
);

export default function Profile() {
  const { user } = useAuth();
  const { confirm, confirmDialog } = useConfirmDialog();
  const [favoritedMovies, setFavoritedMovies] = useState([]);
  const [favoritedShows, setFavoritedShows] = useState([]);
  const [watchedMovies, setWatchedMovies] = useState([]);
  const [watchedShows, setWatchedShows] = useState([]);
  const [userInfo, setUserInfo] = useState(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState('');

  const {
    stats,
    loading: statsLoading,
    error: statsError,
  } = useDashboardStats({ enabled: Boolean(user?.id) });

  const fetchFavoriteMovies = () =>
    api
      .post('/api/favorite/getFavoriteMovie', {})
      .then((r) => {
        if (r.data.success) setFavoritedMovies(r.data.favorites || []);
      })
      .catch(() => setFavoritedMovies([]));

  const fetchFavoriteShows = () =>
    api
      .post('/api/tv/favorite/getFavoriteMovie', {})
      .then((r) => {
        if (r.data.success) setFavoritedShows(r.data.favorites || []);
      })
      .catch(() => setFavoritedShows([]));

  const fetchWatchedMovies = () =>
    api
      .post('/api/watch/getWatchMovie', {})
      .then((r) => {
        if (r.data.success) setWatchedMovies(r.data.watch || []);
      })
      .catch(() => setWatchedMovies([]));

  const fetchWatchedShows = () =>
    api
      .post('/api/tv/watch/getWatchTv', {})
      .then((r) => {
        if (r.data.success) setWatchedShows(r.data.watch || []);
      })
      .catch(() => setWatchedShows([]));

  useEffect(() => {
    if (!user?.id) return;
    setLoading(true);
    setLoadError('');

    api
      .get(`/users/getUser/${user.id}`)
      .then((r) => {
        if (r.data.success) setUserInfo(r.data.found);
        else setUserInfo({ username: user.username, email: user.email || '', firstName: '', lastName: '' });
      })
      .catch(() => {
        setLoadError('Could not reach the server. Run npm start from backend-server, then log in again.');
        setUserInfo({ username: user.username, email: user.email || '', firstName: '', lastName: '' });
      })
      .finally(() => {
        Promise.all([
          fetchFavoriteMovies(),
          fetchFavoriteShows(),
          fetchWatchedMovies(),
          fetchWatchedShows(),
        ]).finally(() => {
          setLoading(false);
          window.scrollTo(0, 0);
        });
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]);

  const profileDisplay = useMemo(() => {
    if (!userInfo) return { title: '', subtitle: '', avatarLetter: '?' };
    const firstName = userInfo.firstName?.trim() || '';
    const email = userInfo.email || '';
    const title = firstName || (email ? email.split('@')[0] : userInfo.username) || 'You';
    const since = userInfo.createdAt ? formatMemberSince(userInfo.createdAt) : '';

    return {
      title,
      subtitle: since ? `Member since ${since}` : email,
      email,
      avatarLetter: (firstName || title).charAt(0).toUpperCase() || '?',
    };
  }, [userInfo]);

  const isProfileEmpty = useMemo(
    () =>
      favoritedMovies.length === 0 &&
      favoritedShows.length === 0 &&
      watchedMovies.length === 0 &&
      watchedShows.length === 0,
    [favoritedMovies, favoritedShows, watchedMovies, watchedShows]
  );

  const removeFavoriteFilm = (m) =>
    confirm({
      ...favoriteRemoveConfirm(m.movieTitle),
      onConfirm: () =>
        api.post('/api/favorite/removeFromFavorite', { movieId: m.movieId }).then(fetchFavoriteMovies),
    });

  const removeFavoriteShow = (s) =>
    confirm({
      ...favoriteRemoveConfirm(s.tvTitle),
      onConfirm: () =>
        api.post('/api/tv/favorite/removeFromFavorite', { tvId: s.tvId }).then(fetchFavoriteShows),
    });

  const removeWatchedFilm = (m) =>
    confirm({
      ...watchedFilmRemoveConfirm(m.movieTitle),
      onConfirm: () =>
        api.post('/api/watch/removeFromWatched', { movieId: m.movieId }).then(fetchWatchedMovies),
    });

  const removeWatchedShow = (s) =>
    confirm({
      ...watchedTvRemoveConfirm(s.tvTitle),
      onConfirm: () =>
        api.post('/api/tv/watch/removeFromWatched', { tvId: s.tvId }).then(fetchWatchedShows),
    });

  const filmTile = (m, onRemove) => (
    <PosterTile
      key={m.movieId}
      to={`/movies/${m.movieId}`}
      poster={m.moviePosterImage}
      title={m.movieTitle}
      imageUrlPrefix={`${IMAGE_URL}w342`}
      size="sm"
      onRemove={onRemove}
    />
  );

  const tvTile = (s, onRemove) => (
    <PosterTile
      key={s.tvId}
      to={`/tv/${s.tvId}`}
      poster={s.tvPosterImage}
      title={s.tvTitle}
      imageUrlPrefix={`${IMAGE_URL}w342`}
      size="sm"
      onRemove={onRemove}
    />
  );

  return (
    <>
      <PageTitle title={profileDisplay.title ? `${profileDisplay.title}'s diary` : 'Profile'} />

      <div className="mx-auto max-w-content px-4 py-6 sm:px-6 md:py-10">
        <BackNav fallback="/" label="Back to home" className="mb-4 md:hidden" />

        {loading && !userInfo ? (
          <div className="space-y-6">
            <div className="h-40 animate-pulse rounded-2xl bg-surface-raised" />
            <div className="h-40 animate-pulse rounded-2xl bg-surface-raised" />
          </div>
        ) : (
          userInfo && (
            <div className="space-y-10 md:space-y-12">
              {loadError && (
                <p className="state-enter rounded-xl border border-accent/30 bg-accent/10 px-4 py-3 text-sm text-accent">
                  {loadError}
                </p>
              )}

              <header className="animate-soft-rise flex items-center gap-4 opacity-0">
                <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-accent font-serif text-2xl font-semibold text-on-accent sm:h-16 sm:w-16 sm:text-3xl">
                  {profileDisplay.avatarLetter}
                </div>
                <div className="min-w-0 flex-1">
                  <p className="section-title text-accent">Your diary</p>
                  <h1 className="page-title mt-1 truncate">{profileDisplay.title}</h1>
                  <p className="mt-1 truncate text-sm text-muted">{profileDisplay.subtitle}</p>
                </div>
                <Link
                  to="/settings"
                  className="focus-ring pressable flex h-11 w-11 shrink-0 items-center justify-center rounded-xl border border-border text-muted transition-colors hover:border-accent/40 hover:text-accent cursor-pointer"
                  aria-label="Settings"
                >
                  <Settings className="h-4 w-4" />
                </Link>
              </header>

              <ProfileStats stats={stats} loading={statsLoading} error={statsError} />

              <TvLibrarySummary />

              {isProfileEmpty ? (
                <ProfileEmptyState name={profileDisplay.title} />
              ) : (
                <div className="space-y-10 md:space-y-12">
                  {(favoritedMovies.length > 0 || watchedMovies.length > 0) && (
                    <div className="space-y-10 md:space-y-12">
                      <PosterRail
                        title="Favorite films"
                        actionTo={favoritedMovies.length ? profileListPath('favorite-films') : undefined}
                        actionLabel="View all"
                        empty={emptyFilm('Browse films')}
                      >
                        {favoritedMovies.map((m) => filmTile(m, () => removeFavoriteFilm(m)))}
                      </PosterRail>

                      <PosterRail
                        title="Watched films"
                        actionTo={watchedMovies.length ? profileListPath('watched-films') : undefined}
                        actionLabel="View all"
                        empty={emptyFilm('Find a film')}
                      >
                        {watchedMovies.map((m) => filmTile(m, () => removeWatchedFilm(m)))}
                      </PosterRail>
                    </div>
                  )}

                  {(favoritedShows.length > 0 || watchedShows.length > 0) && (
                    <div className="space-y-10 md:space-y-12">
                      <PosterRail
                        title="Favorite TV"
                        actionTo={favoritedShows.length ? profileListPath('favorite-tv') : undefined}
                        actionLabel="View all"
                        empty={emptyTv('Browse TV')}
                      >
                        {favoritedShows.map((s) => tvTile(s, () => removeFavoriteShow(s)))}
                      </PosterRail>

                      <PosterRail
                        title="Watched TV"
                        actionTo={watchedShows.length ? profileListPath('watched-tv') : undefined}
                        actionLabel="View all"
                        empty={emptyTv('Browse TV')}
                      >
                        {watchedShows.map((s) => tvTile(s, () => removeWatchedShow(s)))}
                      </PosterRail>
                    </div>
                  )}
                </div>
              )}
            </div>
          )
        )}
      </div>

      {confirmDialog}
    </>
  );
}
