/**
 * Tiny mobile feedback. Safe no-op on desktop / unsupported browsers.
 *
 * Patterns stay short — confirmation, not a game controller.
 * Visual reduced-motion does not disable haptics (they're not visual),
 * but we skip when the page isn't focused so background tabs stay quiet.
 */
const PATTERNS = {
  selection: 6,
  light: 10,
  medium: 16,
  success: [10, 36, 14],
};

export function haptic(kind = 'light') {
  if (typeof navigator === 'undefined' || typeof navigator.vibrate !== 'function') return;
  if (typeof document !== 'undefined' && document.visibilityState === 'hidden') return;

  try {
    navigator.vibrate(PATTERNS[kind] ?? PATTERNS.light);
  } catch {
    // Some WebViews throw; ignore.
  }
}
