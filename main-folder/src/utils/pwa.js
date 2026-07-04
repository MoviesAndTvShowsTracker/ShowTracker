const PWA_DISMISS_KEY = 'marquee-pwa-dismissed';

export function isPwaDismissed() {
  try {
    return localStorage.getItem(PWA_DISMISS_KEY) === '1';
  } catch {
    return false;
  }
}

export function dismissPwaPrompt() {
  try {
    localStorage.setItem(PWA_DISMISS_KEY, '1');
  } catch {
    /* ignore */
  }
}

export function isStandalonePwa() {
  return (
    window.matchMedia('(display-mode: standalone)').matches ||
    window.navigator.standalone === true
  );
}
