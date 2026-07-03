import { Link } from 'react-router-dom';
import { Check, Play } from 'lucide-react';
import { IMAGE_URL } from '../../config/keys';
import useShowProgress from '../../hooks/useShowProgress';

function formatLastWatched(date) {
  if (!date) return null;
  return new Date(date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

export default function TvLibraryTile({
  track,
  tab,
  onMark,
  onResume,
  marking,
  resuming,
}) {
  const progress = useShowProgress(track);
  const pct = progress?.pct ?? 0;
  const caughtUp = progress?.caughtUpWithAired && progress?.upcomingLabel;
  const isComplete = progress?.isComplete ?? track.status === 'completed';
  const hasNext = !caughtUp && !isComplete && track.nextSeason && track.nextEpisode;
  const canMark = tab === 'watching' && hasNext && onMark;
  const isStopped = tab === 'stopped' || track.status === 'paused';

  const metaLine = () => {
    if (isComplete) return `${pct}% · Finished`;
    if (caughtUp && progress.upcomingLabel) return `Next ${progress.upcomingLabel} · ${pct}%`;
    if (hasNext) return `S${track.nextSeason} · E${track.nextEpisode} · ${pct}%`;
    const last = formatLastWatched(track.lastWatchedAt);
    if (last) return `${pct}% · Last watched ${last}`;
    return `${pct}% watched`;
  };

  return (
    <article className="group relative">
      <div className="relative">
        <Link
          to={`/tv/${track.tvId}/continue`}
          className="block cursor-pointer"
          aria-label={track.tvTitle}
        >
          <div className="relative overflow-hidden rounded-xl bg-surface-raised shadow-poster transition-transform duration-200 active:scale-[0.98]">
            {track.tvPosterImage ? (
              <img
                src={`${IMAGE_URL}w342${track.tvPosterImage}`}
                alt=""
                className="aspect-[2/3] w-full object-cover"
                loading="lazy"
              />
            ) : (
              <div className="aspect-[2/3] w-full bg-surface-raised" />
            )}

            <div className="absolute inset-x-0 bottom-0 h-1 bg-black/40" aria-hidden>
              <div className="h-full bg-accent transition-all duration-500" style={{ width: `${pct}%` }} />
            </div>

            {isComplete && (
              <span className="absolute left-1.5 top-1.5 rounded-md bg-canvas/90 px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wide text-accent">
                Done
              </span>
            )}
            {caughtUp && !isComplete && (
              <span className="absolute left-1.5 top-1.5 rounded-md bg-canvas/90 px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wide text-accent">
                Caught up
              </span>
            )}
            {isStopped && !isComplete && (
              <span className="absolute left-1.5 top-1.5 rounded-md bg-canvas/90 px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wide text-muted">
                Stopped
              </span>
            )}
          </div>
        </Link>

        {canMark && (
          <button
            type="button"
            disabled={marking}
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              onMark(track);
            }}
            aria-label={`Mark S${track.nextSeason} E${track.nextEpisode} watched`}
            className="absolute right-1 top-1 flex h-9 w-9 items-center justify-center rounded-full border border-border/80 bg-canvas/95 text-accent shadow-sm transition-colors hover:bg-accent hover:text-on-accent disabled:opacity-50 cursor-pointer"
          >
            <Check className="h-4 w-4" strokeWidth={2.5} />
          </button>
        )}

        {isStopped && onResume && (
          <button
            type="button"
            disabled={resuming}
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              onResume(track);
            }}
            aria-label={`Resume ${track.tvTitle}`}
            className="absolute right-1 top-1 flex h-9 w-9 items-center justify-center rounded-full border border-border/80 bg-canvas/95 text-accent shadow-sm transition-colors hover:bg-accent hover:text-on-accent disabled:opacity-50 cursor-pointer"
          >
            <Play className="h-4 w-4 fill-current" />
          </button>
        )}
      </div>

      <Link to={`/tv/${track.tvId}/continue`} className="mt-2 block cursor-pointer">
        <p className="line-clamp-2 text-[11px] font-semibold leading-snug text-ink-bright sm:text-xs">
          {track.tvTitle}
        </p>
        <p className="mt-0.5 text-[10px] font-medium text-muted">{metaLine()}</p>
      </Link>
    </article>
  );
}
