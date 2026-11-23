import { useCallback, useRef, useState } from 'react';
import Dialog from '../components/ui/Dialog';

/**
 * Promise-style confirm for removals and bulk actions.
 * Supports either a single confirm CTA or a list of `actions`.
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

  const runAction = useCallback(
    async (fn) => {
      if (!fn) return;
      setBusy(true);
      try {
        await fn();
        setPending(null);
      } finally {
        setBusy(false);
      }
    },
    []
  );

  const handleConfirm = useCallback(async () => {
    await runAction(pending?.onConfirm);
  }, [pending, runAction]);

  const multiActions = Array.isArray(shown?.actions) ? shown.actions : null;

  const confirmDialog = (
    <Dialog
      open={Boolean(pending)}
      onClose={close}
      title={shown?.title ?? ''}
      footer={
        multiActions ? (
          <div className="flex w-full flex-col gap-2">
            {multiActions.map((action) => (
              <button
                key={action.label}
                type="button"
                disabled={busy}
                onClick={() => runAction(action.onClick)}
                className={
                  action.destructive
                    ? 'btn-primary bg-danger text-white disabled:opacity-50'
                    : action.primary
                      ? 'btn-primary disabled:opacity-50'
                      : 'btn-secondary disabled:opacity-50'
                }
              >
                {busy ? 'Saving…' : action.label}
              </button>
            ))}
            <button type="button" onClick={close} disabled={busy} className="btn-secondary">
              {shown?.cancelLabel ?? 'Cancel'}
            </button>
          </div>
        ) : (
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
        )
      }
    >
      {shown?.body && <p className="text-sm text-muted">{shown.body}</p>}
    </Dialog>
  );

  return { confirm, confirmDialog };
}
