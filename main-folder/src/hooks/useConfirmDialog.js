import { useCallback, useRef, useState } from 'react';
import Dialog from '../components/ui/Dialog';

/**
 * Promise-style confirm for removals and bulk actions. Adds stay one-tap.
 * @returns {{ confirm: (opts) => void, confirmDialog: JSX.Element }}
 */
export default function useConfirmDialog() {
  const [pending, setPending] = useState(null);
  const [busy, setBusy] = useState(false);
  // The dialog animates out after `pending` clears, so keep the last copy on screen
  // instead of letting the title and body blank out mid-transition.
  const lastPending = useRef(null);
  if (pending) lastPending.current = pending;
  const shown = pending ?? lastPending.current;

  const confirm = useCallback((opts) => {
    setPending(opts);
  }, []);

  const close = useCallback(() => {
    if (!busy) setPending(null);
  }, [busy]);

  const handleConfirm = useCallback(async () => {
    if (!pending?.onConfirm) return;
    setBusy(true);
    try {
      await pending.onConfirm();
      setPending(null);
    } finally {
      setBusy(false);
    }
  }, [pending]);

  const confirmDialog = (
    <Dialog
      open={Boolean(pending)}
      onClose={close}
      title={shown?.title ?? ''}
      footer={
        <>
          <button type="button" onClick={close} disabled={busy} className="btn-secondary">
            {shown?.cancelLabel ?? 'Cancel'}
          </button>
          <button
            type="button"
            onClick={handleConfirm}
            disabled={busy}
            className="btn-primary disabled:opacity-50"
          >
            {busy ? 'Saving…' : shown?.confirmLabel ?? 'Confirm'}
          </button>
        </>
      }
    >
      {shown?.body && <p className="text-sm text-muted">{shown.body}</p>}
    </Dialog>
  );

  return { confirm, confirmDialog };
}
