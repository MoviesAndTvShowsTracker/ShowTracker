import { useCallback, useEffect, useRef } from 'react';
import { X } from 'lucide-react';

const DRAG_CLOSE_PX = 100;

export default function Dialog({ open, onClose, title, children, footer, bodyClassName, wide, sheet }) {
  const dialogRef = useRef(null);
  const panelRef = useRef(null);
  const dragRef = useRef({ active: false, startY: 0, offsetY: 0 });

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    if (open && !dialog.open) dialog.showModal();
    else if (!open && dialog.open) dialog.close();
  }, [open]);

  useEffect(() => {
    if (!open && panelRef.current) {
      panelRef.current.style.transform = '';
      panelRef.current.style.transition = '';
    }
  }, [open]);

  const handleBackdropClick = useCallback(
    (e) => {
      if (e.target === dialogRef.current) onClose();
    },
    [onClose]
  );

  const resetDrag = useCallback(() => {
    const panel = panelRef.current;
    if (!panel) return;
    panel.style.transition = 'transform 0.28s cubic-bezier(0.32, 0.72, 0, 1)';
    panel.style.transform = '';
  }, []);

  const onDragStart = useCallback((clientY) => {
    dragRef.current = { active: true, startY: clientY, offsetY: 0 };
    if (panelRef.current) panelRef.current.style.transition = 'none';
  }, []);

  const onDragMove = useCallback((clientY) => {
    if (!dragRef.current.active || !panelRef.current) return;
    const dy = Math.max(0, clientY - dragRef.current.startY);
    dragRef.current.offsetY = dy;
    panelRef.current.style.transform = `translateY(${dy}px)`;
  }, []);

  const onDragEnd = useCallback(() => {
    if (!dragRef.current.active || !panelRef.current) return;
    dragRef.current.active = false;
    const { offsetY } = dragRef.current;

    if (offsetY > DRAG_CLOSE_PX) {
      const panel = panelRef.current;
      panel.style.transition = 'transform 0.22s ease-in';
      panel.style.transform = 'translateY(100%)';
      window.setTimeout(onClose, 180);
    } else {
      resetDrag();
    }
  }, [onClose, resetDrag]);

  const sheetPanelClass = sheet
    ? 'w-full max-h-[min(92vh,100%)] rounded-t-2xl border-b-0 md:max-h-[min(85vh,100%)] md:rounded-2xl md:border-b'
    : 'w-full max-h-[min(85vh,100%)] rounded-2xl';

  const sheetWidthClass = wide
    ? 'md:w-[min(100%,40rem)] md:max-w-[40rem]'
    : 'md:w-[min(100%,24rem)] md:max-w-[24rem]';

  return (
    <dialog
      ref={dialogRef}
      onClose={onClose}
      onClick={handleBackdropClick}
      className="app-dialog-host fixed inset-0 z-50 m-0 hidden h-full w-full max-h-none max-w-none items-end justify-center border-0 bg-transparent p-0 backdrop:bg-black/50 backdrop:backdrop-blur-sm open:flex md:items-center"
    >
      <div
        ref={panelRef}
        role="document"
        onClick={(e) => e.stopPropagation()}
        className={`app-dialog-panel flex max-h-[inherit] flex-col overflow-hidden border border-border bg-surface text-ink shadow-glass ${sheetPanelClass} ${sheetWidthClass}`}
      >
        {sheet && (
          <div
            className="shrink-0 touch-none md:hidden"
            onTouchStart={(e) => onDragStart(e.touches[0].clientY)}
            onTouchMove={(e) => onDragMove(e.touches[0].clientY)}
            onTouchEnd={onDragEnd}
            onTouchCancel={onDragEnd}
          >
            <div className="flex justify-center pt-2.5 pb-1" aria-hidden>
              <div className="h-1 w-10 rounded-full bg-border/80" />
            </div>
          </div>
        )}

        <div
          className={`flex shrink-0 items-center justify-between border-b border-border px-4 py-3 ${
            sheet ? 'md:pt-3' : ''
          }`}
          {...(sheet
            ? {
                onTouchStart: (e) => onDragStart(e.touches[0].clientY),
                onTouchMove: (e) => onDragMove(e.touches[0].clientY),
                onTouchEnd: onDragEnd,
                onTouchCancel: onDragEnd,
              }
            : {})}
        >
          <h2 className="text-sm font-bold uppercase tracking-wide text-ink-bright">{title}</h2>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close"
            className="btn-ghost !min-h-[44px] !min-w-[44px] !px-2"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className={`min-h-0 flex-1 overflow-y-auto ${bodyClassName ?? 'px-4 py-4'}`}>{children}</div>

        {footer && (
          <div className="flex shrink-0 flex-col-reverse gap-2 border-t border-border px-4 py-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] md:flex-row md:justify-end md:pb-3 [&_button]:w-full md:[&_button]:w-auto">
            {footer}
          </div>
        )}
      </div>
    </dialog>
  );
}
