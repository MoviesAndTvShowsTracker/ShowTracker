import { Link } from 'react-router-dom';
import { Check } from 'lucide-react';
import { IMAGE_URL } from '../../config/keys';
import useShowProgress from '../../hooks/useShowProgress';

const TILE_WIDTH = 'w-[108px] sm:w-[120px]';

export default function ContinueWatchingTile({ track, onMark, marking }) {
  const progress = useShowProgress(track);
  const pct = progress?.pct ?? 0;
  const caughtUp = progress?.caughtUpWithAired && progress?.upcomingLabel;
  const isComplete = progress?.isComplete ?? track.status === 'completed';
  const hasNext = !caughtUp && !isComplete && track.nextSeason && track.nextEpisode;
  const canMark = hasNext && onMark;

  return (
    <article className={`shrink-0 snap-start ${TILE_WIDTH}`}>
      <div className="group relative">
        <Link
          to={`/tv/${track.tvId}/continue`}
          className="block cursor-pointer"
          aria-label={`${track.tvTitle}${hasNext ? `, next S${track.nextSeason} E${track.nextEpisode}` : ''}`}
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
              <div
                className="h-full bg-accent transition-all duration-500"
                style={{ width: `${pct}%` }}
              />
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
            className="absolute right-1 top-1 flex h-11 w-11 items-center justify-center rounded-full border border-border/80 bg-canvas/95 text-accent shadow-sm transition-colors hover:bg-accent hover:text-on-accent disabled:opacity-50 cursor-pointer"
          >
            <Check className="h-4 w-4" strokeWidth={2.5} />
          </button>
        )}
      </div>

      <Link to={`/tv/${track.tvId}/continue`} className="mt-2 block cursor-pointer">
        <p className="line-clamp-2 text-[11px] font-semibold leading-snug text-ink-bright sm:text-xs">
          {track.tvTitle}
        </p>
        {caughtUp && progress.upcomingLabel ? (
          <p className="mt-0.5 text-[10px] font-medium text-accent">
            Next {progress.upcomingLabel}
            <span className="text-muted"> · {pct}%</span>
          </p>
        ) : isComplete ? (
          <p className="mt-0.5 text-[10px] font-medium text-muted">{pct}% · Finished</p>
        ) : hasNext ? (
          <p className="mt-0.5 text-[10px] font-medium text-accent">
            S{track.nextSeason} · E{track.nextEpisode}
            <span className="text-muted"> · {pct}%</span>
          </p>
        ) : (
          <p className="mt-0.5 text-[10px] text-muted">{pct}% watched</p>
        )}
      </Link>
    </article>
  );
}
