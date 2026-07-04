import { useCallback, useEffect, useRef, useState } from 'react';
import { Loader2 } from 'lucide-react';

const THRESHOLD = 72;

export default function usePullToRefresh(onRefresh, enabled = true) {
  const [pull, setPull] = useState(0);
  const [refreshing, setRefreshing] = useState(false);
  const startY = useRef(0);
  const pulling = useRef(false);
  const pullRef = useRef(0);
  const refreshingRef = useRef(false);

  const runRefresh = useCallback(async () => {
    if (refreshingRef.current) return;
    refreshingRef.current = true;
    setRefreshing(true);
    try {
      await onRefresh();
    } finally {
      refreshingRef.current = false;
      setRefreshing(false);
      setPull(0);
      pullRef.current = 0;
    }
  }, [onRefresh]);

  useEffect(() => {
    if (!enabled) return;

    const onTouchStart = (e) => {
      if (window.scrollY > 8 || refreshingRef.current) return;
      startY.current = e.touches[0].clientY;
      pulling.current = true;
    };

    const onTouchMove = (e) => {
      if (!pulling.current || window.scrollY > 8) return;
      const delta = e.touches[0].clientY - startY.current;
      if (delta > 0) {
        const next = Math.min(delta * 0.45, 100);
        pullRef.current = next;
        setPull(next);
      }
    };

    const onTouchEnd = () => {
      if (!pulling.current) return;
      pulling.current = false;
      if (pullRef.current >= THRESHOLD) {
        runRefresh();
      } else {
        setPull(0);
        pullRef.current = 0;
      }
    };

    window.addEventListener('touchstart', onTouchStart, { passive: true });
    window.addEventListener('touchmove', onTouchMove, { passive: true });
    window.addEventListener('touchend', onTouchEnd);

    return () => {
      window.removeEventListener('touchstart', onTouchStart);
      window.removeEventListener('touchmove', onTouchMove);
      window.removeEventListener('touchend', onTouchEnd);
    };
  }, [enabled, runRefresh]);

  const indicator =
    pull > 0 || refreshing ? (
      <div
        className="pointer-events-none flex items-center justify-center overflow-hidden text-muted transition-[height] duration-150"
        style={{ height: refreshing ? 40 : pull }}
        aria-hidden
      >
        {refreshing ? (
          <Loader2 className="h-5 w-5 animate-spin text-accent" />
        ) : (
          <span className="text-[10px] font-semibold uppercase tracking-wide">
            {pull >= THRESHOLD ? 'Release to refresh' : 'Pull to refresh'}
          </span>
        )}
      </div>
    ) : null;

  return { indicator, refreshing, refresh: runRefresh };
}
