import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Upload, X } from 'lucide-react';
import api from '../../api/axios';
import { useAuth } from '../../context/AuthContext';

const TVTIME_GDPR_URL = 'https://gdpr.tvtime.com/gdpr/self-service';
const dismissKey = (userId) => `marquee-tvtime-prompt-${userId}`;

export default function TvTimeWelcomeBanner() {
  const { user } = useAuth();
  const [visible, setVisible] = useState(false);
  const [checking, setChecking] = useState(true);

  useEffect(() => {
    if (!user?.id) {
      setChecking(false);
      return;
    }

    if (localStorage.getItem(dismissKey(user.id)) === '1') {
      setChecking(false);
      return;
    }

    Promise.all([
      api.get('/api/tv/tracking/continue').catch(() => ({ data: { tracks: [] } })),
      api.post('/api/watch/getWatchMovie', {}).catch(() => ({ data: { watch: [] } })),
      api.post('/api/tv/watch/getWatchTv', {}).catch(() => ({ data: { watch: [] } })),
      api.post('/api/watchlist/getMovieWatchlist', {}).catch(() => ({ data: { watchlist: [] } })),
      api.post('/api/tv/watchlist/getTvWatchlist', {}).catch(() => ({ data: { watchlist: [] } })),
      api.post('/api/favorite/getFavoriteMovie', {}).catch(() => ({ data: { favorites: [] } })),
      api.post('/api/tv/favorite/getFavoriteMovie', {}).catch(() => ({ data: { favorites: [] } })),
    ])
      .then(([tracks, movies, tv, filmWl, tvWl, favFilms, favTv]) => {
        const hasData =
          (tracks.data.tracks?.length || 0) > 0 ||
          (movies.data.watch?.length || 0) > 0 ||
          (tv.data.watch?.length || 0) > 0 ||
          (filmWl.data.watchlist?.length || 0) > 0 ||
          (tvWl.data.watchlist?.length || 0) > 0 ||
          (favFilms.data.favorites?.length || 0) > 0 ||
          (favTv.data.favorites?.length || 0) > 0;
        setVisible(!hasData);
      })
      .finally(() => setChecking(false));
  }, [user?.id]);

  const dismiss = () => {
    if (user?.id) localStorage.setItem(dismissKey(user.id), '1');
    setVisible(false);
  };

  if (checking || !visible) return null;

  return (
    <section className="mb-8 rounded-2xl border border-accent/30 bg-accent/10 p-5 sm:p-6">
      <div className="flex items-start gap-4">
        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-accent/20 text-accent">
          <Upload className="h-5 w-5" />
        </div>
        <div className="min-w-0 flex-1">
          <h2 className="font-serif text-lg font-semibold text-ink-bright">Coming from TV Time?</h2>
          <p className="mt-2 text-sm text-muted">
            Request your data from TV Time, download the zip, then import it here to pick up your
            watched episodes, films, favorites, and watchlists.
          </p>
          <ol className="mt-3 list-decimal space-y-1 pl-4 text-sm text-muted">
            <li>
              Request your export at{' '}
              <a
                href={TVTIME_GDPR_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="font-medium text-link hover:text-ink-bright"
              >
                gdpr.tvtime.com
              </a>
            </li>
            <li>Upload the zip in Settings when it arrives</li>
          </ol>
          <div className="mt-4 flex flex-wrap gap-2">
            <a
              href={TVTIME_GDPR_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="btn-secondary !text-xs"
            >
              Get TV Time export
            </a>
            <Link to="/settings" className="btn-primary !text-xs">
              Import in Settings
            </Link>
          </div>
        </div>
        <button
          type="button"
          onClick={dismiss}
          className="shrink-0 rounded-lg p-1 text-muted transition-colors hover:bg-surface-raised hover:text-ink"
          aria-label="Dismiss"
        >
          <X className="h-4 w-4" />
        </button>
      </div>
    </section>
  );
}
