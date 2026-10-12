import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { Link, useNavigate } from 'react-router-dom';
import { Bookmark, Check, ChevronRight, Film, MoreVertical, Star, Tv } from 'lucide-react';
import api from '../../api/axios';
import { IMAGE_URL } from '../../config/keys';
import { useAuth } from '../../context/AuthContext';
import useConfirmDialog from '../../hooks/useConfirmDialog';
import { useAnchoredPopover } from '../../hooks/useAnchoredPopover';
import useAnimatedPresence from '../../hooks/useAnimatedPresence';
import { watchlistRemoveConfirm } from '../../utils/removeConfirm';

function yearFrom(item, mediaType) {
  const date = mediaType === 'tv' ? item.first_air_date : item.release_date || item.first_air_date;
  return date ? date.slice(0, 4) : null;
}

function libraryLabel(track) {
  if (!track) return null;
  if (track.status === 'completed') return 'Finished';
  if (track.status === 'paused') return 'Paused';
  return 'Watching';
}

function actionForTv(track) {
  if (!track) return null;
  if (track.status === 'completed') {
    return { label: 'Finished', icon: Check, toDetail: true };
  }
  if (track.status === 'paused') {
    return { label: 'Paused', icon: ChevronRight, toDetail: false };
  }
  return { label: 'Continue', icon: ChevronRight, toDetail: false };
}

export default function SearchResultTile({
  item,
  mediaType,
  diaryReady = true,
  diary = null,
  onWatchlistChange,
}) {
  const navigate = useNavigate();
  const { isAuthenticated } = useAuth();
  const { confirm, confirmDialog } = useConfirmDialog();
  const type = mediaType || item.media_type;
  const isTv = type === 'tv';
  const title = isTv ? item.name : item.title;
  const idKey = String(item.id);
  const to = isTv ? `/tv/${item.id}` : `/movies/${item.id}`;
  const year = yearFrom(item, type);
  const rating = item.vote_average > 0 ? Number(item.vote_average).toFixed(1) : null;

  const track = isTv ? diary?.tvTracks?.get(idKey) || null : null;
  const watchlisted = isTv
    ? Boolean(diary?.tvWatchlist?.has(idKey))
    : Boolean(diary?.movieWatchlist?.has(idKey));
  const filmWatched = !isTv && Boolean(diary?.watchedMovies?.has(idKey));

  const [busy, setBusy] = useState(false);
  const [hint, setHint] = useState('');
  const [menuOpen, setMenuOpen] = useState(false);
  const menuPresence = useAnimatedPresence(menuOpen);
  const buttonRef = useRef(null);
  const popoverRef = useRef(null);
  const { style: menuStyle, placeAbove } = useAnchoredPopover(
    menuPresence.rendered,
    buttonRef,
    popoverRef
  );

  const tvAction = actionForTv(track);
  const inLibrary = Boolean(track);

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
    if (!isAuthenticated || busy || inLibrary || filmWatched) return;
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
          onWatchlistChange?.('tv', item.id, !watchlisted);
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
          onWatchlistChange?.('movie', item.id, !watchlisted);
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
    if (!isAuthenticated || busy || inLibrary || filmWatched) return;
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

  const goPrimary = (e) => {
    e?.preventDefault?.();
    e?.stopPropagation?.();
    setMenuOpen(false);
    if (tvAction?.toDetail) navigate(`/tv/${item.id}`);
    else navigate(`/tv/${item.id}/continue`);
  };

  if (!item.poster_path) return null;

  const ratingClass =
    type === 'multi' && isAuthenticated
      ? 'left-1.5 top-8 md:left-auto md:top-1.5 md:right-1.5'
      : isAuthenticated
        ? 'left-1.5 top-1.5 md:left-auto md:top-1.5 md:right-1.5'
        : 'right-1.5 top-1.5';

  const statusLabel = libraryLabel(track);
  const showActions = isAuthenticated && diaryReady;
  const TvActionIcon = tvAction?.icon;

  let desktopAction = null;
  if (showActions) {
    if (isTv && tvAction && TvActionIcon) {
      desktopAction = (
        <button
          type="button"
          onClick={goPrimary}
          className="pressable flex h-9 min-w-[2.25rem] flex-1 items-center justify-center gap-1 rounded-lg bg-accent text-[10px] font-semibold text-on-accent transition-colors cursor-pointer"
        >
          <TvActionIcon className="h-3.5 w-3.5" />
          {tvAction.label}
        </button>
      );
    } else if (filmWatched) {
      desktopAction = (
        <span className="flex h-9 min-w-[2.25rem] flex-1 items-center justify-center gap-1 rounded-lg bg-accent text-[10px] font-semibold text-on-accent">
          <Check className="h-3.5 w-3.5" />
          Watched
        </span>
      );
    } else {
      desktopAction = (
        <button
          type="button"
          onClick={toggleWatchlist}
          disabled={busy}
          aria-label={watchlisted ? 'Remove from watchlist' : 'Add to watchlist'}
          className={`pressable flex h-9 min-w-[2.25rem] flex-1 items-center justify-center gap-1 rounded-lg text-[10px] font-semibold transition-colors cursor-pointer disabled:opacity-50 ${
            watchlisted
              ? 'bg-accent text-on-accent'
              : 'bg-surface/90 text-ink hover:bg-surface-raised'
          }`}
        >
          <Bookmark className="h-3.5 w-3.5" />
          {watchlisted ? 'Listed' : 'Watchlist'}
        </button>
      );
    }
  }

  return (
    <>
      <article className={`group relative ${menuOpen ? 'z-40' : ''}`}>
        <div className="relative">
          <div className="relative overflow-hidden rounded-xl bg-surface-raised shadow-poster transition-all duration-200 ease-out hover:-translate-y-0.5 hover:scale-[1.04] hover:shadow-poster-hover active:scale-[0.97]">
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

            {showActions && (
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
                className="focus-ring pressable absolute right-1.5 top-1.5 z-10 flex h-8 w-8 items-center justify-center rounded-full bg-canvas/95 text-ink-bright shadow-sm backdrop-blur-sm md:hidden cursor-pointer"
              >
                <MoreVertical className="h-4 w-4" />
              </button>
            )}

            {showActions && (
              <div className="absolute inset-x-0 bottom-0 hidden gap-1 bg-gradient-to-t from-canvas/95 via-canvas/80 to-transparent p-1.5 pt-6 md:flex">
                {desktopAction}
              </div>
            )}
          </div>

          {showActions && menuPresence.rendered && typeof document !== 'undefined' && createPortal(
            <>
              <div
                className={`popover-backdrop fixed inset-0 z-[55] bg-canvas/20 md:hidden ${
                  menuPresence.exiting ? 'is-exiting' : ''
                }`}
                aria-hidden
                onClick={() => setMenuOpen(false)}
              />
              <div
                ref={popoverRef}
                style={menuStyle ?? { position: 'fixed', top: 0, left: 0, zIndex: 60, visibility: 'hidden' }}
                role="menu"
                aria-label={`Actions for ${title}`}
                className={`menu-pop w-max min-w-[10.5rem] max-w-[calc(100vw-1rem)] overflow-hidden rounded-xl border border-border bg-surface py-1 shadow-glass md:hidden ${
                  placeAbove ? 'menu-pop--bottom-right' : ''
                } ${menuPresence.exiting ? 'is-exiting' : ''}`}
              >
                {isTv && tvAction && TvActionIcon ? (
                  <button
                    type="button"
                    role="menuitem"
                    onClick={goPrimary}
                    className="focus-ring flex w-full items-center gap-2.5 px-3 py-3 text-left text-sm font-medium text-ink active:bg-surface-raised cursor-pointer"
                  >
                    <TvActionIcon className="h-4 w-4 shrink-0 text-link" />
                    <span className="whitespace-nowrap">
                      {tvAction.label}
                      {statusLabel && tvAction.label !== statusLabel ? ` · ${statusLabel}` : ''}
                    </span>
                  </button>
                ) : filmWatched ? (
                  <div
                    role="menuitem"
                    className="flex w-full items-center gap-2.5 px-3 py-3 text-left text-sm font-medium text-ink"
                  >
                    <Check className="h-4 w-4 shrink-0 text-accent" />
                    <span className="whitespace-nowrap">Watched</span>
                  </div>
                ) : (
                  <button
                    type="button"
                    role="menuitem"
                    onClick={toggleWatchlist}
                    disabled={busy}
                    className="focus-ring flex w-full items-center gap-2.5 px-3 py-3 text-left text-sm font-medium text-ink active:bg-surface-raised cursor-pointer disabled:opacity-50"
                  >
                    <Bookmark className="h-4 w-4 shrink-0 text-accent" />
                    <span className="whitespace-nowrap">
                      {watchlisted ? 'Remove from watchlist' : 'Add to watchlist'}
                    </span>
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
