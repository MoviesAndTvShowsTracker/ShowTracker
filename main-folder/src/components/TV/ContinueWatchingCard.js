import { Link } from 'react-router-dom';
import { Check, Play } from 'lucide-react';
import { IMAGE_URL } from '../../config/keys';
import { progressPercent } from '../../utils/tvProgress';

export default function ContinueWatchingCard({ track, onMark, marking }) {
  const pct = progressPercent(track.watchedEpisodeCount, track.totalEpisodes);
  const isComplete = track.status === 'completed' || pct >= 100;
  const hasNext = track.nextSeason && track.nextEpisode;

  return (
    <article className="glass-card overflow-hidden">
      <Link
        to={`/tv/${track.tvId}/continue`}
        className="flex gap-3 p-3 sm:gap-4 sm:p-4 cursor-pointer"
      >
        {track.tvPosterImage && (
          <img
            src={`${IMAGE_URL}w342${track.tvPosterImage}`}
            alt=""
            className="h-24 w-16 shrink-0 rounded-xl object-cover shadow-poster sm:h-28 sm:w-[4.5rem]"
          />
        )}
        <div className="min-w-0 flex-1">
          <h3 className="line-clamp-2 font-serif text-base leading-snug text-ink-bright sm:text-lg">
            {track.tvTitle}
          </h3>
          {isComplete ? (
            <p className="mt-1 text-xs text-accent font-semibold">Finished</p>
          ) : hasNext ? (
            <p className="mt-1 text-xs text-muted">
              Next · S{track.nextSeason} E{track.nextEpisode}
              {track.nextEpisodeName ? ` — ${track.nextEpisodeName}` : ''}
            </p>
          ) : (
            <p className="mt-1 text-xs text-muted">Tap to pick up where you left off</p>
          )}
          <div className="mt-2.5 flex items-center gap-2">
            <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-surface-raised">
              <div
                className="h-full rounded-full bg-accent transition-all duration-500"
                style={{ width: `${pct}%` }}
              />
            </div>
            <span className="text-[10px] font-bold tabular-nums text-muted">{pct}%</span>
          </div>
        </div>
      </Link>

      {!isComplete && hasNext && onMark && (
        <div className="border-t border-border/60 px-3 py-2.5 sm:px-4">
          <button
            type="button"
            disabled={marking}
            onClick={(e) => {
              e.preventDefault();
              onMark(track);
            }}
            className="flex w-full min-h-[44px] items-center justify-center gap-2 rounded-xl bg-accent/10 text-sm font-semibold text-accent transition-colors hover:bg-accent/20 disabled:opacity-50 cursor-pointer"
          >
            {marking ? (
              'Saving…'
            ) : (
              <>
                <Check className="h-4 w-4" />
                Mark S{track.nextSeason} E{track.nextEpisode} watched
              </>
            )}
          </button>
        </div>
      )}

      {isComplete && (
        <div className="border-t border-border/60 px-3 py-2.5 sm:px-4">
          <Link
            to={`/tv/${track.tvId}`}
            className="flex w-full min-h-[44px] items-center justify-center gap-2 text-sm font-semibold text-link cursor-pointer"
          >
            <Play className="h-4 w-4" />
            View show
          </Link>
        </div>
      )}
    </article>
  );
}
