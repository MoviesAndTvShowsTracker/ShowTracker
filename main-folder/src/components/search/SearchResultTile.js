import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { Link } from 'react-router-dom';
import { Bookmark, Film, MoreVertical, Star, Tv } from 'lucide-react';
import api from '../../api/axios';
import { IMAGE_URL } from '../../config/keys';
import { useAuth } from '../../context/AuthContext';
import useConfirmDialog from '../../hooks/useConfirmDialog';
import { useAnchoredPopover } from '../../hooks/useAnchoredPopover';
import { watchlistRemoveConfirm } from '../../utils/removeConfirm';

function yearFrom(item, mediaType) {
  const date = mediaType === 'tv' ? item.first_air_date : item.release_date || item.first_air_date;
  return date ? date.slice(0, 4) : null;
}

export default function SearchResultTile({ item, mediaType }) {
  const { isAuthenticated } = useAuth();
  const { confirm, confirmDialog } = useConfirmDialog();
  const type = mediaType || item.media_type;
  const isTv = type === 'tv';
  const title = isTv ? item.name : item.title;
  const to = isTv ? `/tv/${item.id}` : `/movies/${item.id}`;
  const year = yearFrom(item, type);
  const rating = item.vote_average > 0 ? Number(item.vote_average).toFixed(1) : null;

  const [watchlisted, setWatchlisted] = useState(false);
  const [tracking, setTracking] = useState(false);
  const [busy, setBusy] = useState(false);
  const [hint, setHint] = useState('');
  const [menuOpen, setMenuOpen] = useState(false);
  const buttonRef = useRef(null);
  const popoverRef = useRef(null);
  const menuStyle = useAnchoredPopover(menuOpen, buttonRef, popoverRef);

  useEffect(() => {
    if (!isAuthenticated) return;

    const watchlistEndpoint = isTv
      ? '/api/tv/watchlist/watchlisted'
      : '/api/watchlist/watchlisted';
    const idKey = isTv ? 'tvId' : 'movieId';

    api.post(watchlistEndpoint, { [idKey]: String(item.id) }).then((r) => {
      if (r.data.success) setWatchlisted(r.data.watchlisted);
    });

    if (isTv) {
      api.get(`/api/tv/tracking/show/${item.id}`).then((r) => {
        if (r.data.success) setTracking(Boolean(r.data.tracking));
      });
    }
  }, [isAuthenticated, isTv, item.id]);

  useEffect(() => {
    if (!menuOpen) return;
    const close = (e) => {
      if (buttonRef.current?.contains(e.target) || popoverRef.current?.contains(e.target)) return;
      setMenuOpen(false);
    };
    const onScroll = () => setMenuOpen(false);
    document.addEventListener('pointerdown', close);
    window.addEventListener('scroll', onScroll, true);
    return () => {
      document.removeEventListener('pointerdown', close);
      window.removeEventListener('scroll', onScroll, true);
    };
  }, [menuOpen]);

  const flash = (msg) => {
    setHint(msg);
    setTimeout(() => setHint(''), 1800);
  };

  const applyWatchlistChange = async () => {
    if (!isAuthenticated || busy) return;
    setBusy(true);
    setMenuOpen(false);
    try {
      if (isTv) {
        const payload = {
          tvId: String(item.id),
          tvTitle: item.name,
          tvImage: item.backdrop_path || item.poster_path,
          tvPosterImage: item.poster_path,
        };
        const endpoint = watchlisted
          ? '/api/tv/watchlist/removeFromWatchlist'
          : '/api/tv/watchlist/addToWatchlist';
        const r = await api.post(endpoint, watchlisted ? { tvId: String(item.id) } : payload);
        if (r.data.success) {
          setWatchlisted(!watchlisted);
          flash(watchlisted ? 'Removed from list' : 'Added to watchlist');
        }
      } else {
        const payload = {
          movieId: String(item.id),
          movieTitle: item.title,
          movieImage: item.backdrop_path || item.poster_path,
          moviePosterImage: item.poster_path,
          movieRuntime: 0,
        };
        const endpoint = watchlisted
          ? '/api/watchlist/removeFromWatchlist'
          : '/api/watchlist/addToWatchlist';
        const r = await api.post(endpoint, watchlisted ? { movieId: String(item.id) } : payload);
        if (r.data.success) {
          setWatchlisted(!watchlisted);
          flash(watchlisted ? 'Removed from list' : 'Added to watchlist');
        }
      }
    } finally {
      setBusy(false);
    }
  };

  const toggleWatchlist = (e) => {
    e?.preventDefault?.();
    e?.stopPropagation?.();
    if (!isAuthenticated || busy) return;
    if (watchlisted) {
      setMenuOpen(false);
      confirm({
        ...watchlistRemoveConfirm(title),
        onConfirm: applyWatchlistChange,
      });
      return;
    }
    applyWatchlistChange();
  };

  const startTracking = async (e) => {
    e?.preventDefault?.();
    e?.stopPropagation?.();
    if (!isAuthenticated || busy || tracking) return;
    setBusy(true);
    setMenuOpen(false);
    try {
      const r = await api.post('/api/tv/tracking/start', {
        tvId: String(item.id),
        tvTitle: item.name,
        tvPosterImage: item.poster_path,
        tvBackdropImage: item.backdrop_path || item.poster_path,
        totalEpisodes: 0,
      });
      if (r.data.success) {
        setTracking(true);
        flash('Now watching');
      }
    } finally {
      setBusy(false);
    }
  };

  if (!item.poster_path) return null;

  const ratingClass =
    type === 'multi' && isAuthenticated
      ? 'left-1.5 top-8 md:left-auto md:top-1.5 md:right-1.5'
      : isAuthenticated
        ? 'left-1.5 top-1.5 md:left-auto md:top-1.5 md:right-1.5'
        : 'right-1.5 top-1.5';

  return (
    <>
    <article className={`group relative ${menuOpen ? 'z-40' : ''}`}>
      <div className="relative">
        <div className="relative overflow-hidden rounded-xl bg-surface-raised shadow-poster transition-all duration-300 hover:-translate-y-0.5 hover:shadow-poster-hover">
          <Link to={to} className="block cursor-pointer">
            <img
              src={`${IMAGE_URL}w342${item.poster_path}`}
              alt=""
              className="aspect-[2/3] w-full object-cover"
              loading="lazy"
            />
          </Link>

          {type === 'multi' && (
            <span className="pointer-events-none absolute left-1.5 top-1.5 inline-flex items-center gap-0.5 rounded-md bg-canvas/90 px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wide text-ink-bright backdrop-blur-sm">
              {isTv ? <Tv className="h-2.5 w-2.5" /> : <Film className="h-2.5 w-2.5" />}
              {isTv ? 'TV' : 'Film'}
            </span>
          )}
          {rating && (
            <span
              className={`pointer-events-none absolute inline-flex items-center gap-0.5 rounded-md bg-canvas/90 px-1.5 py-0.5 text-[10px] font-semibold text-ink-bright backdrop-blur-sm ${ratingClass}`}
            >
              <Star className="h-2.5 w-2.5 fill-accent text-accent" />
              {rating}
            </span>
          )}

          {isAuthenticated && (
            <button
              ref={buttonRef}
              type="button"
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                setMenuOpen((o) => !o);
              }}
              aria-label={`Actions for ${title}`}
              aria-expanded={menuOpen}
              className="absolute right-1.5 top-1.5 z-10 flex h-8 w-8 items-center justify-center rounded-full bg-canvas/95 text-ink-bright shadow-sm backdrop-blur-sm md:hidden cursor-pointer"
            >
              <MoreVertical className="h-4 w-4" />
            </button>
          )}

          {isAuthenticated && (
            <div className="absolute inset-x-0 bottom-0 hidden gap-1 bg-gradient-to-t from-canvas/95 via-canvas/80 to-transparent p-1.5 pt-6 md:flex">
              <button
                type="button"
                onClick={toggleWatchlist}
                disabled={busy}
                aria-label={watchlisted ? 'Remove from watchlist' : 'Add to watchlist'}
                className={`flex h-9 min-w-[2.25rem] flex-1 items-center justify-center gap-1 rounded-lg text-[10px] font-semibold transition-colors cursor-pointer disabled:opacity-50 ${
                  watchlisted
                    ? 'bg-accent text-on-accent'
                    : 'bg-surface/90 text-ink hover:bg-surface-raised'
                }`}
              >
                <Bookmark className="h-3.5 w-3.5" />
                {watchlisted ? 'Listed' : 'List'}
              </button>
              {isTv && (
                <button
                  type="button"
                  onClick={startTracking}
                  disabled={busy || tracking}
                  aria-label={tracking ? 'Watching' : 'Start watching'}
                  className={`flex h-9 min-w-[2.25rem] flex-1 items-center justify-center gap-1 rounded-lg text-[10px] font-semibold transition-colors cursor-pointer disabled:opacity-50 ${
                    tracking
                      ? 'bg-accent text-on-accent'
                      : 'bg-surface/90 text-ink hover:bg-surface-raised'
                  }`}
                >
                  <Tv className="h-3.5 w-3.5" />
                  {tracking ? 'Watching' : 'Watch'}
                </button>
              )}
            </div>
          )}
        </div>

        {isAuthenticated && menuOpen && typeof document !== 'undefined' && createPortal(
          <>
            <div
              className="fixed inset-0 z-[55] bg-canvas/20 md:hidden"
              aria-hidden
              onClick={() => setMenuOpen(false)}
            />
            <div
              ref={popoverRef}
              style={menuStyle ?? { position: 'fixed', top: 0, left: 0, zIndex: 60, visibility: 'hidden' }}
              role="menu"
              aria-label={`Actions for ${title}`}
              className="w-max min-w-[10.5rem] max-w-[calc(100vw-1rem)] overflow-hidden rounded-xl border border-border bg-surface py-1 shadow-glass md:hidden"
            >
              <button
                type="button"
                role="menuitem"
                onClick={toggleWatchlist}
                disabled={busy}
                className="flex w-full items-center gap-2.5 px-3 py-3 text-left text-sm font-medium text-ink active:bg-surface-raised cursor-pointer disabled:opacity-50"
              >
                <Bookmark className="h-4 w-4 shrink-0 text-accent" />
                <span className="whitespace-nowrap">{watchlisted ? 'Remove from list' : 'Add to watchlist'}</span>
              </button>
              {isTv && (
                <button
                  type="button"
                  role="menuitem"
                  onClick={startTracking}
                  disabled={busy || tracking}
                  className="flex w-full items-center gap-2.5 border-t border-border/50 px-3 py-3 text-left text-sm font-medium text-ink active:bg-surface-raised cursor-pointer disabled:opacity-50"
                >
                  <Tv className="h-4 w-4 shrink-0 text-link" />
                  <span className="whitespace-nowrap">{tracking ? 'Watching' : 'Start watching'}</span>
                </button>
              )}
            </div>
          </>,
          document.body,
        )}
      </div>

      <Link to={to} className="mt-1.5 block cursor-pointer">
        <p className="line-clamp-2 text-[11px] font-medium leading-snug text-ink sm:text-xs">{title}</p>
        {hint ? (
          <p className="text-[10px] font-medium text-accent">{hint}</p>
        ) : (
          year && <p className="text-[10px] text-muted">{year}</p>
        )}
      </Link>
    </article>
    {confirmDialog}
    </>
  );
}
