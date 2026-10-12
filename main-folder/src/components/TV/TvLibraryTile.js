import { Link } from 'react-router-dom';
import { IMAGE_URL } from '../../config/keys';
import useShowProgress from '../../hooks/useShowProgress';
import MarkFab from '../ui/MarkFab';

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
  const progress = useShowProgress(track, null, { trackOnly: true });
  const pct = progress?.pct ?? 0;
  const caughtUp = progress?.caughtUpWithAired;
  const isComplete = progress?.isComplete ?? track.status === 'completed';
  const hasNext = !caughtUp && !isComplete && track.nextSeason && track.nextEpisode;
  const canMark = tab === 'watching' && hasNext && onMark;
  const isStopped = tab === 'stopped' || track.status === 'paused';

  const metaLine = () => {
    if (isComplete) return `${pct}% · Finished`;
    if (caughtUp) {
      return progress.upcomingLabel
        ? `Next ${progress.upcomingLabel} · ${pct}%`
        : `Caught up · ${pct}%`;
    }
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
              <div className="progress-fill rounded-none" style={{ '--progress': pct / 100 }} />
            </div>

            {isComplete && (
              <span
                key="finished"
                className="state-enter absolute left-1.5 top-1.5 rounded-md bg-canvas/90 px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wide text-accent"
              >
                Finished
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
            {isStopped && !isComplete && (
              <span
                key="paused"
                className="state-enter absolute left-1.5 top-1.5 rounded-md bg-canvas/90 px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wide text-muted"
              >
                Paused
              </span>
            )}
          </div>
        </Link>

        {canMark && (
          <MarkFab
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

        {isStopped && onResume && (
          <MarkFab
            icon="play"
            disabled={resuming}
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              onResume(track);
            }}
            ariaLabel={`Resume ${track.tvTitle}`}
            className="absolute right-1 top-1"
          />
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
