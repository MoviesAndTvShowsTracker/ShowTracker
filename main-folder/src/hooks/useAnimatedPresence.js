import { useEffect, useState } from 'react';

/**
 * Keeps conditionally-rendered UI mounted briefly so its CSS exit animation can
 * finish. The caller remains the source of truth for whether the surface is open.
 */
export default function useAnimatedPresence(visible, exitMs = 120) {
  const [rendered, setRendered] = useState(visible);
  const [exiting, setExiting] = useState(false);

  useEffect(() => {
    if (visible) {
      setRendered(true);
      setExiting(false);
      return undefined;
    }

    if (!rendered) return undefined;
    setExiting(true);
    const timer = window.setTimeout(() => {
      setRendered(false);
      setExiting(false);
    }, exitMs);
    return () => window.clearTimeout(timer);
  }, [visible, rendered, exitMs]);

  return { rendered, exiting };
}
