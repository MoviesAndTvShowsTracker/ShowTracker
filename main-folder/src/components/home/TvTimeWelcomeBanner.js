import { Link } from 'react-router-dom';
import { Upload, X } from 'lucide-react';

const TVTIME_GDPR_URL = 'https://gdpr.tvtime.com/gdpr/self-service';

export default function TvTimeWelcomeBanner({ visible, onDismiss }) {
  if (!visible) return null;

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
          onClick={onDismiss}
          className="shrink-0 rounded-lg p-1 text-muted transition-colors hover:bg-surface-raised hover:text-ink"
          aria-label="Dismiss"
        >
          <X className="h-4 w-4" />
        </button>
      </div>
    </section>
  );
}

export function tvTimeDismissKey(userId) {
  return `marquee-tvtime-prompt-${userId}`;
}

export function isTvTimeDismissed(userId) {
  return userId && localStorage.getItem(tvTimeDismissKey(userId)) === '1';
}

export function dismissTvTimePrompt(userId) {
  if (userId) localStorage.setItem(tvTimeDismissKey(userId), '1');
}

export function shouldShowTvTimeBanner({
  userId,
  tracks,
  movieWatchlist,
  tvWatchlist,
  watchedMovies,
  watchedTv,
  favoriteMovies,
  favoriteTv,
}) {
  if (!userId || isTvTimeDismissed(userId)) return false;
  const hasData =
    tracks.length > 0 ||
    movieWatchlist.length > 0 ||
    tvWatchlist.length > 0 ||
    watchedMovies.length > 0 ||
    watchedTv.length > 0 ||
    favoriteMovies.length > 0 ||
    favoriteTv.length > 0;
  return !hasData;
}
