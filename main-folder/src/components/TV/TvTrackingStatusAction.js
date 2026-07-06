import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { PauseCircle, PlayCircle } from 'lucide-react';
import api from '../../api/axios';
import { tvLibraryPath } from '../../config/tvLibrary';
import { deriveShowProgress, fetchShowEpisodeIndex } from '../../utils/tvProgress';

export default function TvTrackingStatusAction({
  tvId,
  track: trackProp,
  navigateOnStop = false,
  onStatusChange,
  className = 'mt-4',
}) {
  const navigate = useNavigate();
  const [fetchedTrack, setFetchedTrack] = useState(null);
  const [progress, setProgress] = useState(null);
  const [busy, setBusy] = useState(false);
  const selfLoaded = trackProp === undefined;
  const track = selfLoaded ? fetchedTrack : trackProp;

  useEffect(() => {
    if (!selfLoaded) return;
    api.get(`/api/tv/tracking/show/${tvId}`).then((r) => {
      if (r.data.success) setFetchedTrack(r.data.tracking || null);
    });
  }, [tvId, selfLoaded]);

  useEffect(() => {
    if (!track) {
      setProgress(null);
      return;
    }
    fetchShowEpisodeIndex(tvId)
      .then(({ episodes }) => setProgress(deriveShowProgress(track, episodes)))
      .catch(() => setProgress(null));
  }, [track, tvId]);

  const isComplete = progress?.isComplete ?? track?.status === 'completed';

  const applyStatusChange = (nextTrack) => {
    if (selfLoaded) setFetchedTrack(nextTrack || null);
    onStatusChange?.({ tracking: nextTrack ?? null });
  };

  const stopWatching = async () => {
    setBusy(true);
    try {
      const r = await api.post('/api/tv/tracking/stop', { tvId, status: 'paused' });
      if (r.data.success) {
        applyStatusChange(r.data.tracking);
        if (navigateOnStop) navigate(tvLibraryPath('stopped'));
      }
    } finally {
      setBusy(false);
    }
  };

  const resumeWatching = async () => {
    setBusy(true);
    try {
      const r = await api.post('/api/tv/tracking/resume', { tvId });
      if (r.data.success) applyStatusChange(r.data.tracking);
    } finally {
      setBusy(false);
    }
  };

  if (!track || isComplete || track.status === 'dropped') return null;

  return (
    <div className={`flex justify-end ${className}`}>
      {track.status === 'paused' ? (
        <button
          type="button"
          disabled={busy}
          onClick={resumeWatching}
          className="inline-flex min-h-[40px] items-center gap-1.5 px-1 text-sm font-medium text-link transition-colors hover:text-link/80 disabled:opacity-50"
        >
          <PlayCircle className="h-4 w-4" />
          {busy ? 'Saving…' : 'Resume watching'}
        </button>
      ) : track.status === 'watching' ? (
        <button
          type="button"
          disabled={busy}
          onClick={stopWatching}
          className="inline-flex min-h-[40px] items-center gap-1.5 px-1 text-sm font-medium text-muted transition-colors hover:text-ink disabled:opacity-50"
        >
          <PauseCircle className="h-4 w-4" />
          {busy ? 'Saving…' : 'Move to stopped'}
        </button>
      ) : null}
    </div>
  );
}
