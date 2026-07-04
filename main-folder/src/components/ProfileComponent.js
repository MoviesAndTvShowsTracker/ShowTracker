import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Pencil, Phone, Settings, LogOut } from 'lucide-react';
import api from '../api/axios';
import { IMAGE_URL } from '../config/keys';
import { profileListPath } from '../config/profileLists';
import { useAuth } from '../context/AuthContext';
import PageTitle from '../utils/PageTitle';
import Dialog from './ui/Dialog';
import PosterRail from './ui/PosterRail';
import PosterTile from './ui/PosterTile';
import ProfileEmptyState from './profile/ProfileEmptyState';
import ProfileStats from './profile/ProfileStats';
import TvLibrarySummary from './profile/TvLibrarySummary';
import ProfileJumpNav from './profile/ProfileJumpNav';
import BackNav from './ui/BackNav';

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
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [favoritedMovies, setFavoritedMovies] = useState([]);
  const [favoritedShows, setFavoritedShows] = useState([]);
  const [watchedMovies, setWatchedMovies] = useState([]);
  const [watchedShows, setWatchedShows] = useState([]);
  const [userInfo, setUserInfo] = useState(null);
  const [phoneDialog, setPhoneDialog] = useState(false);
  const [inputValue, setInputValue] = useState('');
  const [phoneError, setPhoneError] = useState('');
  const [showLogout, setShowLogout] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState('');
  const [tvStats, setTvStats] = useState({ episodes: 0, tvMins: 0, tvShowCount: 0 });
  const [tvStatsLoading, setTvStatsLoading] = useState(false);

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
      .catch(() =>
        api
          .post('/api/favorite/getFavoriteMovie', {})
          .then((r) => {
            if (r.data.success) setWatchedMovies(r.data.favorites || []);
          })
          .catch(() => setWatchedMovies([]))
      );

  const fetchWatchedShows = () =>
    api
      .post('/api/tv/watch/getWatchTv', {})
      .then((r) => {
        if (r.data.success) setWatchedShows(r.data.watch || []);
      })
      .catch(() =>
        api
          .post('/api/tv/favorite/getFavoriteMovie', {})
          .then((r) => {
            if (r.data.success) setWatchedShows(r.data.favorites || []);
          })
          .catch(() => setWatchedShows([]))
      );

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

  const submitPhone = (e) => {
    e.preventDefault();
    if (!/^\d{10}$/.test(inputValue)) {
      setPhoneError('Enter a valid 10-digit number.');
      return;
    }
    api.post('/users/updateOrAddPhone', { inputValue, userId: user.id }).then((r) => {
      if (r.data.success) {
        setInputValue('');
        setPhoneDialog(false);
        setPhoneError('');
        api.get(`/users/getUser/${user.id}`).then((res) => {
          if (res.data.success) setUserInfo(res.data.found);
        });
      }
    });
  };

  const handleLogout = async () => {
    await logout();
    setShowLogout(false);
    navigate('/');
  };

  const joinDate = userInfo?.createdAt
    ? new Date(userInfo.createdAt).toLocaleDateString('en-US', { month: 'short', year: 'numeric' })
    : '';

  const profileDisplay = useMemo(() => {
    if (!userInfo) return { title: '', subtitle: '', avatarLetter: '?' };
    const firstName = userInfo.firstName?.trim() || '';
    const email = userInfo.email || '';
    const title = firstName || (email ? email.split('@')[0] : userInfo.username) || 'You';

    return {
      title,
      subtitle: email ? `${email} · Member since ${joinDate}` : `Member since ${joinDate}`,
      avatarLetter: (firstName || title).charAt(0).toUpperCase() || '?',
    };
  }, [userInfo, joinDate]);

  const watchedMins = useMemo(
    () => watchedMovies.reduce((sum, m) => sum + (parseInt(m.movieRuntime, 10) || 0), 0),
    [watchedMovies]
  );

  useEffect(() => {
    if (!user?.id) return;
    setTvStatsLoading(true);
    api
      .get('/api/tv/episodes/stats')
      .then((r) => {
        if (r.data.success) {
          setTvStats({
            episodes: r.data.episodeCount || 0,
            tvMins: r.data.tvMins || 0,
            tvShowCount: r.data.tvShowCount || 0,
          });
        }
      })
      .catch(() => setTvStats({ episodes: 0, tvMins: 0, tvShowCount: 0 }))
      .finally(() => setTvStatsLoading(false));
  }, [user?.id]);

  const isProfileEmpty = useMemo(
    () =>
      favoritedMovies.length === 0 &&
      favoritedShows.length === 0 &&
      watchedMovies.length === 0 &&
      watchedShows.length === 0,
    [favoritedMovies, favoritedShows, watchedMovies, watchedShows]
  );

  const removeFavoriteFilm = (movieId) =>
    api.post('/api/favorite/removeFromFavorite', { movieId }).then(fetchFavoriteMovies);

  const removeFavoriteShow = (tvId) =>
    api.post('/api/tv/favorite/removeFromFavorite', { tvId }).then(fetchFavoriteShows);

  const removeWatchedFilm = (movieId) =>
    api.post('/api/watch/removeFromWatched', { movieId }).then(fetchWatchedMovies);

  const removeWatchedShow = (tvId) =>
    api.post('/api/tv/watch/removeFromWatched', { tvId }).then(fetchWatchedShows);

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
            <div className="h-24 animate-pulse rounded-2xl bg-surface-raised" />
            <div className="h-40 animate-pulse rounded-2xl bg-surface-raised" />
          </div>
        ) : (
          userInfo && (
            <div className="space-y-8 md:space-y-10">
              {loadError && (
                <p className="rounded-xl border border-accent/30 bg-accent/10 px-4 py-3 text-sm text-accent">
                  {loadError}
                </p>
              )}
              <header className="flex items-start gap-4">
                <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-accent text-xl font-bold text-on-accent sm:h-16 sm:w-16 sm:text-2xl">
                  {profileDisplay.avatarLetter}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-start justify-between gap-3">
                    <h1 className="page-title">{profileDisplay.title}</h1>
                    <Link
                      to="/settings"
                      className="hidden h-10 w-10 shrink-0 items-center justify-center rounded-xl border border-border text-muted transition-colors hover:border-accent/40 hover:text-accent cursor-pointer sm:flex"
                      aria-label="Settings"
                    >
                      <Settings className="h-4 w-4" />
                    </Link>
                  </div>
                  <p className="mt-1 text-sm text-muted">{profileDisplay.subtitle}</p>
                  <div className="mt-2 flex items-center gap-2 text-sm text-muted">
                    <Phone className="h-3.5 w-3.5 shrink-0" />
                    <span>{userInfo.phonenumber || 'No phone'}</span>
                    <button
                      type="button"
                      onClick={() => setPhoneDialog(true)}
                      className="text-link hover:text-ink-bright cursor-pointer"
                      aria-label="Edit phone"
                    >
                      <Pencil className="h-3.5 w-3.5" />
                    </button>
                  </div>
                </div>
              </header>

              <div className="grid grid-cols-2 gap-2 sm:max-w-xs">
                <Link
                  to="/settings"
                  className="flex min-h-[44px] items-center justify-center gap-2 rounded-xl border border-border bg-surface/60 px-3 text-sm font-medium text-ink transition-colors hover:border-accent/40 hover:text-accent cursor-pointer"
                >
                  <Settings className="h-4 w-4 shrink-0" />
                  Settings
                </Link>
                <button
                  type="button"
                  onClick={() => setShowLogout(true)}
                  className="flex min-h-[44px] items-center justify-center gap-2 rounded-xl border border-border bg-surface/60 px-3 text-sm font-medium text-ink transition-colors hover:border-red-400/40 hover:text-red-400 cursor-pointer"
                >
                  <LogOut className="h-4 w-4 shrink-0" />
                  Sign out
                </button>
              </div>

              <ProfileJumpNav showLists={!isProfileEmpty} />

              <div id="profile-stats" className="scroll-mt-24">
                <ProfileStats
                  filmCount={watchedMovies.length}
                  tvCount={tvStats.tvShowCount || watchedShows.length}
                  episodeCount={tvStats.episodes}
                  filmMins={watchedMins}
                  tvMins={tvStats.tvMins}
                  tvStatsLoading={tvStatsLoading}
                />
              </div>

              <div id="profile-library" className="scroll-mt-24">
                <TvLibrarySummary />
              </div>

              {isProfileEmpty ? (
                <ProfileEmptyState name={profileDisplay.title} />
              ) : (
                <div className="space-y-10 md:space-y-12">
                  <div id="profile-films" className="scroll-mt-24 space-y-10 md:space-y-12">
                    <PosterRail
                      title="Favorite films"
                      actionTo={favoritedMovies.length ? profileListPath('favorite-films') : undefined}
                      actionLabel="View all"
                      empty={emptyFilm('Browse films')}
                    >
                      {favoritedMovies.map((m) => filmTile(m, () => removeFavoriteFilm(m.movieId)))}
                    </PosterRail>

                    <PosterRail
                      title="Watched films"
                      actionTo={watchedMovies.length ? profileListPath('watched-films') : undefined}
                      actionLabel="View all"
                      empty={emptyFilm('Find a film')}
                    >
                      {watchedMovies.map((m) => filmTile(m, () => removeWatchedFilm(m.movieId)))}
                    </PosterRail>
                  </div>

                  <div id="profile-tv" className="scroll-mt-24 space-y-10 md:space-y-12">
                    <PosterRail
                      title="Favorite TV"
                      actionTo={favoritedShows.length ? profileListPath('favorite-tv') : undefined}
                      actionLabel="View all"
                      empty={emptyTv('Browse TV')}
                    >
                      {favoritedShows.map((s) => tvTile(s, () => removeFavoriteShow(s.tvId)))}
                    </PosterRail>

                    <PosterRail
                      title="Watched TV"
                      actionTo={watchedShows.length ? profileListPath('watched-tv') : undefined}
                      actionLabel="View all"
                      empty={emptyTv('Browse TV')}
                    >
                      {watchedShows.map((s) => tvTile(s, () => removeWatchedShow(s.tvId)))}
                    </PosterRail>
                  </div>
                </div>
              )}
            </div>
          )
        )}
      </div>

      <Dialog
        open={phoneDialog}
        onClose={() => {
          setPhoneDialog(false);
          setPhoneError('');
        }}
        title="Phone number"
        footer={
          <>
            <button type="button" onClick={() => setPhoneDialog(false)} className="btn-secondary">
              Cancel
            </button>
            <button type="submit" form="phone-form" className="btn-primary">
              Save
            </button>
          </>
        }
      >
        <form id="phone-form" onSubmit={submitPhone}>
          <input
            className="input-field"
            type="tel"
            placeholder="10-digit number"
            maxLength={10}
            value={inputValue}
            onChange={(e) => {
              setInputValue(e.target.value);
              setPhoneError('');
            }}
          />
          {phoneError && <p className="mt-2 text-sm text-red-400">{phoneError}</p>}
        </form>
      </Dialog>

      <Dialog
        open={showLogout}
        onClose={() => setShowLogout(false)}
        title="Sign out?"
        footer={
          <>
            <button type="button" onClick={() => setShowLogout(false)} className="btn-secondary">
              Cancel
            </button>
            <button type="button" onClick={handleLogout} className="btn-primary">
              Sign out
            </button>
          </>
        }
      >
        <p className="text-sm text-muted">Your lists and history will be here when you return.</p>
      </Dialog>
    </>
  );
}
