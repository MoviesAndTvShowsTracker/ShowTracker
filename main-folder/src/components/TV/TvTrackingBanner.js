import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { ChevronRight } from 'lucide-react';
import api from '../../api/axios';
import { deriveShowProgress, fetchShowEpisodeIndex } from '../../utils/tvProgress';

export default function TvTrackingBanner({ tvId }) {
  const [track, setTrack] = useState(null);
  const [progress, setProgress] = useState(null);

  useEffect(() => {
    api.get(`/api/tv/tracking/show/${tvId}`).then((r) => {
      if (r.data.success && r.data.tracking) setTrack(r.data.tracking);
    });
  }, [tvId]);

  useEffect(() => {
    if (!track) return;
    fetchShowEpisodeIndex(tvId)
      .then(({ episodes }) => setProgress(deriveShowProgress(track, episodes)))
      .catch(() => setProgress(null));
  }, [track, tvId]);

  if (!track || track.status === 'dropped') return null;

  const pct = progress?.pct ?? 0;
  const caughtUp = progress?.caughtUpWithAired && progress?.upcomingLabel;
  const isComplete = progress?.isComplete ?? track.status === 'completed';

  return (
    <Link
      to={`/tv/${tvId}/continue`}
      className="mb-5 block rounded-xl border border-accent/30 bg-accent/10 p-4 transition-colors hover:bg-accent/15 cursor-pointer md:mb-8"
    >
      <div className="flex items-center justify-between gap-3">
        <div className="min-w-0">
          <p className="text-[10px] font-bold uppercase tracking-widest text-accent">
            {isComplete ? 'Completed' : caughtUp ? 'Caught up' : 'Tracking'}
          </p>
          {isComplete ? (
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
              <div className="h-full rounded-full bg-accent" style={{ width: `${pct}%` }} />
            </div>
            <span className="text-[10px] font-bold text-muted">{pct}%</span>
          </div>
        </div>
        <ChevronRight className="h-5 w-5 shrink-0 text-accent" />
      </div>
    </Link>
  );
}
