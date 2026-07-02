import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Pencil, Phone } from 'lucide-react';
import api from '../api/axios';
import { IMAGE_URL } from '../config/keys';
import { useAuth } from '../context/AuthContext';
import PageTitle from '../utils/PageTitle';
import Dialog from './ui/Dialog';
import PosterRail from './ui/PosterRail';
import PosterTile from './ui/PosterTile';

export default function Profile() {
  const { user } = useAuth();
  const [favoritedMovies, setFavoritedMovies] = useState([]);
  const [favoritedShows, setFavoritedShows] = useState([]);
  const [watchedMovies, setWatchedMovies] = useState([]);
  const [userInfo, setUserInfo] = useState(null);
  const [phoneDialog, setPhoneDialog] = useState(false);
  const [inputValue, setInputValue] = useState('');
  const [phoneError, setPhoneError] = useState('');
  const [showWatchlists, setShowWatchlists] = useState(false);
  const [movieWatchlist, setMovieWatchlist] = useState([]);
  const [tvWatchlist, setTvWatchlist] = useState([]);

  const fetchFavoriteMovies = () => {
    api.post('/api/favorite/getFavoriteMovie', {}).then((r) => {
      if (r.data.success) setFavoritedMovies(r.data.favorites);
    });
  };

  const fetchFavoriteShows = () => {
    api.post('/api/tv/favorite/getFavoriteMovie', {}).then((r) => {
      if (r.data.success) setFavoritedShows(r.data.favorites);
    });
  };

  const fetchUserInfo = () => {
    api.get(`/users/getUser/${user.id}`).then((r) => {
      if (r.data.success) setUserInfo(r.data.found);
    });
  };

  const fetchWatchedMovies = () => {
    api.post('/api/watch/getWatchMovie', {}).then((r) => {
      if (r.data.success) setWatchedMovies(r.data.watch);
    });
  };

  const fetchWatchlists = () => {
    api.post('/api/watchlist/getMovieWatchlist', {}).then((r) => {
      if (r.data.success) setMovieWatchlist(r.data.watchlist);
    });
    api.post('/api/tv/watchlist/getTvWatchlist', {}).then((r) => {
      if (r.data.success) setTvWatchlist(r.data.watchlist);
    });
  };

  useEffect(() => {
    if (!user?.id) return;
    fetchUserInfo();
    fetchFavoriteMovies();
    fetchWatchedMovies();
    fetchFavoriteShows();
    window.scrollTo(0, 0);
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
        fetchUserInfo();
      }
    });
  };

  const joinDate = userInfo?.createdAt
    ? new Date(userInfo.createdAt).toLocaleDateString('en-US', { month: 'short', year: 'numeric' })
    : '';

  return (
    <>
      <PageTitle title={userInfo?.username ? `${userInfo.username}'s diary` : 'Profile'} />

      <div className="mx-auto max-w-content px-4 py-8 sm:px-6 md:py-12">
        {userInfo && (
          <header className="mb-8 flex flex-col gap-6 border-b border-border pb-8 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex items-center gap-4">
              <div className="flex h-16 w-16 shrink-0 items-center justify-center rounded-sm bg-accent text-2xl font-bold text-canvas">
                {userInfo.username?.charAt(0).toUpperCase()}
              </div>
              <div>
                <h1 className="page-title">{userInfo.username}</h1>
                <p className="text-sm text-muted">
                  Member since {joinDate} · {userInfo.firstName} {userInfo.lastName}
                </p>
                <div className="mt-1 flex items-center gap-2 text-sm text-muted">
                  <Phone className="h-3.5 w-3.5" />
                  {userInfo.phonenumber || 'No phone'}
                  <button type="button" onClick={() => setPhoneDialog(true)} className="text-link hover:text-ink-bright cursor-pointer">
                    <Pencil className="h-3.5 w-3.5" />
                  </button>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-3 gap-2 sm:gap-3">
              {[
                { label: 'Watched', value: watchedMovies.length },
                { label: 'Favorites', value: favoritedMovies.length + favoritedShows.length },
                {
                  label: showWatchlists ? 'Lists' : 'Lists',
                  value: showWatchlists ? movieWatchlist.length + tvWatchlist.length : '—',
                  action: () => {
                    if (!showWatchlists) fetchWatchlists();
                    setShowWatchlists(!showWatchlists);
                  },
                },
              ].map(({ label, value, action }) =>
                action ? (
                  <button
                    key={label}
                    type="button"
                    onClick={action}
                    className="rounded-sm border border-border bg-surface px-3 py-3 text-center transition-colors hover:border-muted cursor-pointer"
                  >
                    <span className="block text-xl font-bold text-ink-bright">{value}</span>
                    <span className="text-[10px] font-bold uppercase tracking-widest text-muted">{label}</span>
                  </button>
                ) : (
                  <div key={label} className="rounded-sm border border-border bg-surface px-3 py-3 text-center">
                    <span className="block text-xl font-bold text-ink-bright">{value}</span>
                    <span className="text-[10px] font-bold uppercase tracking-widest text-muted">{label}</span>
                  </div>
                )
              )}
            </div>
          </header>
        )}

        <div className="space-y-12">
          <PosterRail
            title="Favorite films"
            actionTo="/movies"
            empty={
              <>
                No favorites yet.{' '}
                <Link to="/movies" className="text-link hover:text-ink-bright cursor-pointer">Browse films</Link>
              </>
            }
          >
            {favoritedMovies.map((m) => (
              <PosterTile
                key={m.movieId}
                to={`/movies/${m.movieId}`}
                poster={m.moviePosterImage}
                title={m.movieTitle}
                imageUrlPrefix={`${IMAGE_URL}w342`}
                onRemove={() =>
                  api.post('/api/favorite/removeFromFavorite', { movieId: m.movieId }).then(() => fetchFavoriteMovies())
                }
              />
            ))}
          </PosterRail>

          <PosterRail
            title="Watched"
            actionTo="/movies"
            empty={
              <>
                Nothing logged.{' '}
                <Link to="/movies" className="text-link hover:text-ink-bright cursor-pointer">Find a film</Link>
              </>
            }
          >
            {[...watchedMovies].reverse().map((m) => (
              <PosterTile
                key={m.movieId}
                to={`/movies/${m.movieId}`}
                poster={m.moviePosterImage}
                title={m.movieTitle}
                imageUrlPrefix={`${IMAGE_URL}w342`}
                onRemove={() =>
                  api.post('/api/watch/removeFromWatched', { movieId: m.movieId }).then(() => fetchWatchedMovies())
                }
              />
            ))}
          </PosterRail>

          <PosterRail
            title="Favorite TV"
            actionTo="/tv"
            empty={
              <>
                No shows saved.{' '}
                <Link to="/tv" className="text-link hover:text-ink-bright cursor-pointer">Browse TV</Link>
              </>
            }
          >
            {favoritedShows.map((s) => (
              <PosterTile
                key={s.tvId}
                to={`/tv/${s.tvId}`}
                poster={s.tvPosterImage}
                title={s.tvTitle}
                imageUrlPrefix={`${IMAGE_URL}w342`}
                onRemove={() =>
                  api.post('/api/tv/favorite/removeFromFavorite', { tvId: s.tvId }).then(() => fetchFavoriteShows())
                }
              />
            ))}
          </PosterRail>

          {showWatchlists && (
            <>
              <PosterRail title="Film watchlist">
                {movieWatchlist.map((m) => (
                  <PosterTile
                    key={m.movieId}
                    to={`/movies/${m.movieId}`}
                    poster={m.moviePosterImage}
                    title={m.movieTitle}
                    imageUrlPrefix={`${IMAGE_URL}w342`}
                  />
                ))}
              </PosterRail>
              <PosterRail title="TV watchlist">
                {tvWatchlist.map((s) => (
                  <PosterTile
                    key={s.tvId}
                    to={`/tv/${s.tvId}`}
                    poster={s.tvPosterImage}
                    title={s.tvTitle}
                    imageUrlPrefix={`${IMAGE_URL}w342`}
                  />
                ))}
              </PosterRail>
            </>
          )}
        </div>
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
            <button type="button" onClick={() => setPhoneDialog(false)} className="btn-secondary">Cancel</button>
            <button type="submit" form="phone-form" className="btn-primary">Save</button>
          </>
        }
      >
        <form id="phone-form" onSubmit={submitPhone}>
          <input className="input-field" type="tel" placeholder="10-digit number" maxLength={10} value={inputValue} onChange={(e) => { setInputValue(e.target.value); setPhoneError(''); }} />
          {phoneError && <p className="mt-2 text-sm text-red-400">{phoneError}</p>}
        </form>
      </Dialog>
    </>
  );
}
