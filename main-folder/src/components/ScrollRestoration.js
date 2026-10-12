import { useEffect, useLayoutEffect, useRef } from 'react';
import { useLocation, useNavigationType } from 'react-router-dom';

const STORAGE_KEY = 'marquee-scroll-positions';

/** @type {Map<string, number>} */
const positions = new Map();

/** Pending POP restore — reapplied when async lists (search, profile) paint. */
let pendingRestore = null;

function readStoredPositions() {
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY);
    if (!raw) return;
    const parsed = JSON.parse(raw);
    Object.entries(parsed).forEach(([key, y]) => {
      if (typeof y === 'number' && y >= 0) positions.set(key, y);
    });
  } catch {
    /* ignore */
  }
}

function writeStoredPositions() {
  try {
    const obj = {};
    positions.forEach((y, key) => {
      obj[key] = y;
    });
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify(obj));
  } catch {
    /* ignore quota */
  }
}

readStoredPositions();

function applyY(y) {
  window.scrollTo({ top: y, left: 0, behavior: 'auto' });
}

function maxScrollY() {
  return Math.max(
    0,
    (document.documentElement?.scrollHeight || 0) - window.innerHeight
  );
}

/**
 * Call after a list/page has painted enough height for a POP restore
 * (e.g. search cache hydrated). Safe to call anytime. If we're still waiting
 * on a restore target, re-apply now that the page has grown.
 */
export function confirmScrollRestore() {
  if (!pendingRestore) return;
  const target = pendingRestore.y;
  // Only re-apply if we haven't yet landed close enough to the target —
  // avoids fighting a user who already started scrolling after Back.
  if (Math.abs(window.scrollY - target) < 4) return;
  // Also skip if the document still isn't tall enough; the scheduled
  // retries below will try again once more content paints.
  if (maxScrollY() + 16 < target) return;
  applyY(target);
}

/**
 * Browser-like scroll ownership for the SPA:
 * - PUSH → top (new screen)
 * - POP (Back/Forward) → restore that history entry's offset
 * - REPLACE on same pathname → keep scroll (search params / in-place updates)
 * - REPLACE with new pathname → top (e.g. library tabs)
 *
 * Why manual: page effects and URL replaces otherwise fight the browser and
 * dump deep list scroll (search) back to 0.
 */
export default function ScrollRestoration() {
  const location = useLocation();
  const navigationType = useNavigationType();
  const prevKeyRef = useRef(location.key);
  const prevPathRef = useRef(location.pathname);

  useEffect(() => {
    if ('scrollRestoration' in window.history) {
      window.history.scrollRestoration = 'manual';
    }
    const persist = () => {
      positions.set(prevKeyRef.current, window.scrollY);
      writeStoredPositions();
    };
    window.addEventListener('pagehide', persist);
    return () => window.removeEventListener('pagehide', persist);
  }, []);

  const { key: locationKey, pathname: locationPathname } = location;

  useLayoutEffect(() => {
    const key = locationKey;
    const pathname = locationPathname;
    const prevKey = prevKeyRef.current;
    const prevPath = prevPathRef.current;

    if (prevKey !== key) {
      positions.set(prevKey, window.scrollY);
      writeStoredPositions();
      prevKeyRef.current = key;
    }

    if (navigationType === 'POP') {
      const y = positions.get(key) ?? 0;
      pendingRestore = { key, y };
      applyY(y);

      // Retry across a wider window so slow mobile networks (first visit, no
      // cache) still get a correct restore once images/data expand the page.
      // When cached data is available, the first retry usually wins instantly.
      const timers = [60, 160, 320, 640, 1200, 2000].map((ms) =>
        window.setTimeout(() => {
          if (pendingRestore?.key !== key) return;
          // Nothing to do if we already reached the target.
          if (Math.abs(window.scrollY - pendingRestore.y) < 4) return;
          // Only re-apply once the page has grown tall enough.
          if (maxScrollY() + 16 >= pendingRestore.y) applyY(pendingRestore.y);
        }, ms)
      );
      const clear = window.setTimeout(() => {
        if (pendingRestore?.key === key) pendingRestore = null;
      }, 2500);

      prevPathRef.current = pathname;
      return () => {
        timers.forEach((t) => window.clearTimeout(t));
        window.clearTimeout(clear);
      };
    }

    if (navigationType === 'REPLACE' && prevPath === pathname) {
      // In-place URL update (search q/type). Keep the user's place.
      pendingRestore = null;
      prevPathRef.current = pathname;
      return undefined;
    }

    // PUSH, or REPLACE that changed the path (library tabs, etc.)
    pendingRestore = null;
    applyY(0);
    prevPathRef.current = pathname;
    return undefined;
  }, [locationKey, locationPathname, navigationType]);

  return null;
}
