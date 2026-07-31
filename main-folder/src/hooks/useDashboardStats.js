import { useCallback, useEffect, useState } from 'react';
import api from '../api/axios';
import {
  clearSessionStats,
  readSessionStats,
  writeSessionStats,
} from '../utils/statsCache';

function clientTimeZone() {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
  } catch {
    return 'UTC';
  }
}

function statsUrl(force) {
  const tz = encodeURIComponent(clientTimeZone());
  const base = force ? '/api/stats/dashboard?refresh=1' : '/api/stats/dashboard';
  return `${base}${base.includes('?') ? '&' : '?'}tz=${tz}`;
}

/**
 * Shared dashboard stats loader for Profile + Stats.
 * Uses session cache for instant paint, then refreshes from the API.
 */
export default function useDashboardStats({ enabled = true } = {}) {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState('');
  const [fromCache, setFromCache] = useState(false);
  const [builtAt, setBuiltAt] = useState(null);

  const loadStats = useCallback((force = false) => {
    if (!enabled) return () => {};

    const controller = new AbortController();
    let hasLocalData = false;

    if (!force) {
      const session = readSessionStats();
      if (session?.stats) {
        hasLocalData = true;
        setStats(session.stats);
        setBuiltAt(session.builtAt || null);
        setFromCache(true);
        setLoading(false);
      } else {
        setLoading(true);
      }
    } else {
      setRefreshing(true);
      clearSessionStats();
    }

    api
      .get(statsUrl(force), { signal: controller.signal, timeout: 90000 })
      .then((r) => {
        if (r.data.success) {
          setStats(r.data.stats);
          writeSessionStats(r.data.stats, r.data.builtAt);
          setBuiltAt(r.data.builtAt || null);
          setFromCache(Boolean(r.data.cached));
          setError('');
        } else if (!hasLocalData) {
          setError('Could not load stats.');
        }
      })
      .catch((err) => {
        if (err.code === 'ERR_CANCELED') return;
        if (!hasLocalData) {
          setError(
            err.code === 'ECONNABORTED'
              ? 'Stats took too long — tap refresh to try again.'
              : 'Could not load stats.'
          );
        }
      })
      .finally(() => {
        setLoading(false);
        setRefreshing(false);
      });

    return () => controller.abort();
  }, [enabled]);

  useEffect(() => {
    if (!enabled) {
      setLoading(false);
      return undefined;
    }
    return loadStats(false);
  }, [enabled, loadStats]);

  return {
    stats,
    loading,
    refreshing,
    error,
    fromCache,
    builtAt,
    refresh: () => loadStats(true),
    reload: () => loadStats(false),
  };
}

export { clientTimeZone };
