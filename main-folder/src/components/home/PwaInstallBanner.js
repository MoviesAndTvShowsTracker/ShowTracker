import { useCallback, useEffect, useRef, useState } from 'react';
import { BRAND_NAME } from '../../config/brand';
import { dismissPwaPrompt, isPwaDismissed, isStandalonePwa } from '../../utils/pwa';

export default function PwaInstallBanner() {
  const [deferredPrompt, setDeferredPrompt] = useState(null);
  const [visible, setVisible] = useState(false);
  const [installing, setInstalling] = useState(false);

  useEffect(() => {
    if (isStandalonePwa() || isPwaDismissed()) return;

    const onBeforeInstall = (e) => {
      e.preventDefault();
      setDeferredPrompt(e);
      setVisible(true);
    };

    const onInstalled = () => {
      setVisible(false);
      setDeferredPrompt(null);
    };

    window.addEventListener('beforeinstallprompt', onBeforeInstall);
    window.addEventListener('appinstalled', onInstalled);
    return () => {
      window.removeEventListener('beforeinstallprompt', onBeforeInstall);
      window.removeEventListener('appinstalled', onInstalled);
    };
  }, []);

  const install = async () => {
    if (!deferredPrompt) return;
    setInstalling(true);
    try {
      await deferredPrompt.prompt();
      await deferredPrompt.userChoice;
    } finally {
      setInstalling(false);
      setDeferredPrompt(null);
      setVisible(false);
    }
  };

  const dismiss = useCallback(() => {
    dismissPwaPrompt();
    setVisible(false);
  }, []);

  if (!visible) return null;

  return (
    <div className="mb-6 flex flex-col gap-3 rounded-xl border border-accent/30 bg-accent/10 px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
      <div className="min-w-0">
        <p className="text-sm font-semibold text-ink-bright">Install {BRAND_NAME}</p>
        <p className="mt-0.5 text-xs text-muted">Add to your home screen for quick access.</p>
      </div>
      <div className="flex shrink-0 gap-2">
        <button type="button" onClick={dismiss} className="btn-secondary !min-h-[40px] !px-4 !py-2 !text-xs">
          Not now
        </button>
        <button
          type="button"
          onClick={install}
          disabled={installing}
          className="btn-primary !min-h-[40px] !px-4 !py-2 !text-xs disabled:opacity-50"
        >
          {installing ? 'Installing…' : 'Install'}
        </button>
      </div>
    </div>
  );
}
