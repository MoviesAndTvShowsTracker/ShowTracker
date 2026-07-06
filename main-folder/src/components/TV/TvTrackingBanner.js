import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { ChevronRight } from 'lucide-react';
import { deriveShowProgress, fetchShowEpisodeIndex } from '../../utils/tvProgress';

const BANNER_STYLES = {
  completed: {
    wrap: 'border-link/35 bg-link/10',
    label: 'text-link',
    bar: 'bg-link',
  },
  stopped: {
    wrap: 'border-amber-500/35 bg-amber-500/10 hover:bg-amber-500/15',
    label: 'text-amber-700 dark:text-amber-400',
    bar: 'bg-amber-500',
    chevron: 'text-amber-600 dark:text-amber-400',
  },
  default: {
    wrap: 'border-accent/30 bg-accent/10 hover:bg-accent/15',
    label: 'text-accent',
    bar: 'bg-accent',
    chevron: 'text-accent',
  },
};

function BannerContent({ track, progress, styles, isComplete, isPaused, caughtUp, pct }) {
  return (
    <div className="flex items-center justify-between gap-3">
      <div className="min-w-0">
        <p className={`text-[10px] font-bold uppercase tracking-widest ${styles.label}`}>
          {isComplete ? 'Completed' : isPaused ? 'Stopped' : caughtUp ? 'Caught up' : 'Watching'}
        </p>
        {isPaused ? (
          <p className="mt-1 text-sm font-medium text-ink-bright">Paused — mark an episode to resume</p>
        ) : isComplete ? (
          <p className="mt-1 text-sm font-medium text-ink-bright">All episodes logged</p>
        ) : caughtUp && progress.upcomingLabel ? (
          <p className="mt-1 text-sm font-medium text-ink-bright">
            Next episode {progress.upcomingLabel}
            {progress.nextUnaired
              ? ` · S${progress.nextUnaired.seasonNumber} E${progress.nextUnaired.episodeNumber}`
              : ''}
          </p>
        ) : track.nextSeason ? (
          <p className="mt-1 text-sm font-medium text-ink-bright">
            Up next · S{track.nextSeason} E{track.nextEpisode}
            {track.nextEpisodeName ? ` — ${track.nextEpisodeName}` : ''}
          </p>
        ) : (
          <p className="mt-1 text-sm text-muted">Continue your progress</p>
        )}
        <div className="mt-2 flex items-center gap-2">
          <div className="h-1 flex-1 overflow-hidden rounded-full bg-surface-raised">
            <div className={`h-full rounded-full ${styles.bar}`} style={{ width: `${pct}%` }} />
          </div>
          <span className="text-[10px] font-bold text-muted">{pct}%</span>
        </div>
      </div>
      {styles.chevron && <ChevronRight className={`h-5 w-5 shrink-0 ${styles.chevron}`} />}
    </div>
  );
}

export default function TvTrackingBanner({ tvId, track }) {
  const [progress, setProgress] = useState(null);

  useEffect(() => {
    if (!track) {
      setProgress(null);
      return;
    }
    fetchShowEpisodeIndex(tvId)
      .then(({ episodes }) => setProgress(deriveShowProgress(track, episodes)))
      .catch(() => setProgress(null));
  }, [track, tvId]);

  if (!track || track.status === 'dropped') return null;

  const pct = progress?.pct ?? 0;
  const caughtUp = progress?.caughtUpWithAired && progress?.upcomingLabel;
  const isComplete = progress?.isComplete ?? track.status === 'completed';
  const isPaused = track.status === 'paused';

  const styleKey = isComplete ? 'completed' : isPaused ? 'stopped' : 'default';
  const styles = BANNER_STYLES[styleKey];

  if (isComplete) {
    return (
      <div className={`mb-5 rounded-xl border p-4 md:mb-8 ${styles.wrap}`}>
        <BannerContent
          track={track}
          progress={progress}
          styles={styles}
          isComplete={isComplete}
          isPaused={isPaused}
          caughtUp={caughtUp}
          pct={pct}
        />
      </div>
    );
  }

  return (
    <Link
      to={`/tv/${tvId}/continue`}
      className={`mb-5 block rounded-xl border p-4 transition-colors cursor-pointer md:mb-8 ${styles.wrap}`}
    >
      <BannerContent
        track={track}
        progress={progress}
        styles={styles}
        isComplete={isComplete}
        isPaused={isPaused}
        caughtUp={caughtUp}
        pct={pct}
      />
    </Link>
  );
}
