import { Link } from 'react-router-dom';
import { IMAGE_URL } from '../../config/keys';
import useShowProgress from '../../hooks/useShowProgress';
import MarkFab from '../ui/MarkFab';

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
          <div className="relative overflow-hidden rounded-xl bg-surface-raised shadow-poster transition-all duration-200 ease-out hover:-translate-y-0.5 hover:scale-[1.04] hover:shadow-poster-hover active:scale-[0.97]">
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

            <div
              className="progress-track absolute inset-x-0 bottom-0 h-1 rounded-none bg-black/40"
              role="progressbar"
              aria-valuenow={pct}
              aria-valuemin={0}
              aria-valuemax={100}
            >
              <div
                className="progress-fill rounded-none"
                style={{ '--progress': pct / 100 }}
              />
            </div>

            {isComplete && (
              <span
                key="done"
                className="state-enter absolute left-1.5 top-1.5 rounded-md bg-canvas/90 px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wide text-accent"
              >
                Done
              </span>
            )}
            {caughtUp && !isComplete && (
              <span
                key="caught-up"
                className="state-enter absolute left-1.5 top-1.5 rounded-md bg-canvas/90 px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wide text-accent"
              >
                Caught up
              </span>
            )}
          </div>
        </Link>

        {canMark && (
          <MarkFab
            size="lg"
            disabled={marking}
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              onMark(track);
            }}
            ariaLabel={`Mark S${track.nextSeason} E${track.nextEpisode} watched`}
            className="absolute right-1 top-1"
          />
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
