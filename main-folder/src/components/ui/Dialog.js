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
      className="fixed inset-0 z-50 m-auto w-[min(100%,24rem)] rounded-2xl border border-border bg-surface p-0 text-ink shadow-glass backdrop:bg-black/50 backdrop:backdrop-blur-sm"
    >
      <div className="flex items-center justify-between border-b border-border px-4 py-3">
        <h2 className="text-sm font-bold uppercase tracking-wide text-ink-bright">{title}</h2>
        <button type="button" onClick={onClose} aria-label="Close" className="btn-ghost !min-h-[32px] !px-2">
          <X className="h-5 w-5" />
        </button>
      </div>
      <div className="px-4 py-4">{children}</div>
      {footer && <div className="flex justify-end gap-2 border-t border-border px-4 py-3">{footer}</div>}
    </dialog>
  );
}
