import { useLayoutEffect, useState } from 'react';

const VIEWPORT_PADDING = 8;
const GAP = 4;

function getBottomReserve() {
  const shell = document.querySelector('.mobile-nav-shell');
  if (!shell) return 92;
  const { top, height } = shell.getBoundingClientRect();
  if (height <= 0) return 92;
  return window.innerHeight - top + GAP;
}

/**
 * Positions a fixed popover near an anchor, flipping above when the bottom nav
 * or viewport edge would obscure it (same idea as Floating UI / Radix flip).
 */
export function useAnchoredPopover(open, anchorRef, popoverRef) {
  const [style, setStyle] = useState(null);

  useLayoutEffect(() => {
    if (!open) {
      setStyle(null);
      return undefined;
    }

    const anchor = anchorRef.current;
    if (!anchor) return undefined;

    const update = () => {
      const rect = anchor.getBoundingClientRect();
      const popover = popoverRef.current;
      const popoverHeight = popover?.offsetHeight || 88;
      const popoverWidth = popover?.offsetWidth || 168;
      const bottomReserve = getBottomReserve();

      const spaceBelow = window.innerHeight - rect.bottom - bottomReserve;
      const spaceAbove = rect.top - VIEWPORT_PADDING;
      const placeAbove = spaceBelow < popoverHeight && spaceAbove >= spaceBelow;

      let top = placeAbove ? rect.top - popoverHeight - GAP : rect.bottom + GAP;
      const maxTop = window.innerHeight - bottomReserve - popoverHeight;
      top = Math.max(VIEWPORT_PADDING, Math.min(top, maxTop));

      let left = rect.right - popoverWidth;
      left = Math.max(
        VIEWPORT_PADDING,
        Math.min(left, window.innerWidth - popoverWidth - VIEWPORT_PADDING),
      );

      setStyle({
        position: 'fixed',
        top: `${top}px`,
        left: `${left}px`,
        zIndex: 60,
      });
    };

    update();
    const raf = requestAnimationFrame(update);
    window.addEventListener('resize', update);
    window.addEventListener('scroll', update, true);
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('resize', update);
      window.removeEventListener('scroll', update, true);
    };
  }, [open, anchorRef, popoverRef]);

  return style;
}
