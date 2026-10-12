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

/**
 * Call after a list/page has painted enough height for a POP restore
 * (e.g. search cache hydrated). Safe to call anytime.
 */
export function confirmScrollRestore() {
  if (!pendingRestore) return;
  applyY(pendingRestore.y);
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

  useLayoutEffect(() => {
    const { key, pathname } = location;
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

      const timers = [80, 200, 400].map((ms) =>
        window.setTimeout(() => {
          if (pendingRestore?.key === key) applyY(pendingRestore.y);
        }, ms)
      );
      const clear = window.setTimeout(() => {
        if (pendingRestore?.key === key) pendingRestore = null;
      }, 600);

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
  }, [location.key, location.pathname, navigationType]);

  return null;
}
