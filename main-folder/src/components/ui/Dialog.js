import { useEffect, useRef } from 'react';
import { X } from 'lucide-react';

export default function Dialog({ open, onClose, title, children, footer }) {
  const dialogRef = useRef(null);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    if (open && !dialog.open) dialog.showModal();
    else if (!open && dialog.open) dialog.close();
  }, [open]);

  return (
    <dialog
      ref={dialogRef}
      onClose={onClose}
      className="app-dialog fixed z-50 m-0 max-h-[min(90vh,100%)] w-full max-w-none overflow-y-auto rounded-t-2xl border border-border border-b-0 bg-surface p-0 text-ink shadow-glass backdrop:bg-black/50 backdrop:backdrop-blur-sm inset-x-0 bottom-0 top-auto md:inset-auto md:bottom-auto md:top-auto md:m-auto md:max-h-[min(85vh,100%)] md:w-[min(100%,24rem)] md:max-w-[24rem] md:rounded-2xl md:border-b"
    >
      <div className="mx-auto mt-2.5 h-1 w-10 shrink-0 rounded-full bg-border/80 md:hidden" aria-hidden />
      <div className="flex items-center justify-between border-b border-border px-4 py-3">
        <h2 className="text-sm font-bold uppercase tracking-wide text-ink-bright">{title}</h2>
        <button type="button" onClick={onClose} aria-label="Close" className="btn-ghost !min-h-[44px] !min-w-[44px] !px-2">
          <X className="h-5 w-5" />
        </button>
      </div>
      <div className="px-4 py-4">{children}</div>
      {footer && (
        <div className="flex flex-col-reverse gap-2 border-t border-border px-4 py-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] md:flex-row md:justify-end md:pb-3 [&_button]:w-full md:[&_button]:w-auto">
          {footer}
        </div>
      )}
    </dialog>
  );
}
