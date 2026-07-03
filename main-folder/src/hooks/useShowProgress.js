import { useEffect, useState } from 'react';
import { fetchShowEpisodeIndex, deriveShowProgress, watchedSetFromEpisodes } from '../utils/tvProgress';

export default function useShowProgress(track, watchedEpisodes = null) {
  const [progress, setProgress] = useState(null);

  useEffect(() => {
    if (!track?.tvId) {
      setProgress(null);
      return undefined;
    }

    let cancelled = false;
    const watchedKeys = watchedEpisodes ? watchedSetFromEpisodes(watchedEpisodes) : null;

    fetchShowEpisodeIndex(track.tvId)
      .then(({ episodes }) => {
        if (cancelled) return;
        setProgress(deriveShowProgress(track, episodes, watchedKeys));
      })
      .catch(() => {
        if (!cancelled) {
          const fallbackTotal = track.airedEpisodeCount || track.totalEpisodes;
          setProgress({
            airedTotal: fallbackTotal,
            totalEpisodes: track.totalEpisodes,
            pct: fallbackTotal
              ? Math.min(100, Math.round((track.watchedEpisodeCount / fallbackTotal) * 100))
              : 0,
            caughtUpWithAired: false,
            fullyComplete: track.status === 'completed',
            nextAired: null,
            nextUnaired: null,
            upcomingLabel: null,
            isComplete: track.status === 'completed',
          });
        }
      });

    return () => {
      cancelled = true;
    };
  }, [track, watchedEpisodes]);

  return progress;
}
