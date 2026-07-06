import { useEffect, useMemo, useState } from 'react';
import {
  deriveProgressFromTrack,
  deriveShowProgress,
  fetchShowEpisodeIndex,
  watchedSetFromEpisodes,
} from '../utils/tvProgress';

/**
 * @param {object} track — TvShowTracking row from our API
 * @param {Array|null} watchedEpisodes — optional watched episode rows
 * @param {{ trackOnly?: boolean }} options — trackOnly: use backend counts, no TMDB
 */
export default function useShowProgress(track, watchedEpisodes = null, { trackOnly = false } = {}) {
  const trackProgress = useMemo(
    () => (trackOnly && track ? deriveProgressFromTrack(track) : null),
    [track, trackOnly]
  );

  const [fetchedProgress, setFetchedProgress] = useState(null);

  useEffect(() => {
    if (trackOnly || !track?.tvId) {
      setFetchedProgress(null);
      return undefined;
    }

    let cancelled = false;
    const watchedKeys = watchedEpisodes ? watchedSetFromEpisodes(watchedEpisodes) : null;

    fetchShowEpisodeIndex(track.tvId)
      .then(({ episodes }) => {
        if (cancelled) return;
        setFetchedProgress(deriveShowProgress(track, episodes, watchedKeys));
      })
      .catch(() => {
        if (!cancelled) setFetchedProgress(deriveProgressFromTrack(track));
      });

    return () => {
      cancelled = true;
    };
  }, [track, watchedEpisodes, trackOnly]);

  if (trackOnly) return trackProgress;
  return fetchedProgress;
}
