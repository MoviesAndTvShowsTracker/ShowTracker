import { useEffect, useRef, useState } from 'react';
import { Star, X } from 'lucide-react';

/**
 * Half-star rating control.
 *
 * UI: 0 (unrated) or 0.5–5. Storage at the API boundary: integer 1–10.
 *
 * Each star sits in a cell with two non-overlapping half hit zones (left = .5, right = full).
 *
 * density:
 *   - "comfortable" — detail pages (larger hit targets)
 *   - "compact"     — episode rows / dense lists
 */
export default function StarRating({
  value = 0,
  onChange,
  readOnly = false,
  size = 'md',
  density = 'comfortable',
  compact = false,
  allowClear = true,
  label = 'Rate',
  disabled = false,
  className = '',
}) {
  const current = Number(value) || 0;
  const [hover, setHover] = useState(0);
  const [finePointer, setFinePointer] = useState(false);

  useEffect(() => {
    if (typeof window === 'undefined' || !window.matchMedia) return undefined;
    const mq = window.matchMedia('(hover: hover) and (pointer: fine)');
    const sync = () => setFinePointer(mq.matches);
    sync();
    mq.addEventListener?.('change', sync);
    return () => mq.removeEventListener?.('change', sync);
  }, []);

  // cell = full touch target for one star (two equal halves). star = glyph size inside.
  const dims =
    {
      sm: {
        star: 'h-3.5 w-3.5',
        cell: density === 'compact' ? 'h-8 w-8' : 'h-9 w-9',
      },
      md: {
        star: 'h-5 w-5',
        cell: 'h-11 w-10',
      },
      lg: {
        star: 'h-6 w-6',
        cell: 'h-11 w-11',
      },
    }[size] || {
      star: 'h-5 w-5',
      cell: 'h-11 w-10',
    };

  const effective = (finePointer && hover) || current;

  if (compact) {
    if (!current) return null;
    return (
      <span
        className={`inline-flex items-center gap-0.5 rounded-md bg-canvas/90 px-1.5 py-0.5 text-[10px] font-semibold text-ink-bright backdrop-blur-sm ${className}`}
        aria-label={`Rated ${formatStars(current)} out of 5`}
      >
        <Star className="h-2.5 w-2.5 fill-accent text-accent" aria-hidden="true" />
        {formatStars(current)}
      </span>
    );
  }

  if (readOnly) {
    return <StarDisplay value={current} size={size} className={className} />;
  }

  const commit = (next) => {
    if (disabled) return;
    const clamped = Math.max(0, Math.min(5, Math.round(next * 2) / 2));
    onChange?.(clamped || null);
  };

  const handleKey = (e) => {
    if (disabled) return;
    const step = 0.5;
    if (e.key === 'ArrowRight' || e.key === 'ArrowUp') {
      e.preventDefault();
      commit(Math.min(5, (current || 0) + step));
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowDown') {
      e.preventDefault();
      commit(Math.max(0, (current || 0) - step));
    } else if (e.key === 'Home') {
      e.preventDefault();
      commit(0.5);
    } else if (e.key === 'End') {
      e.preventDefault();
      commit(5);
    } else if (e.key === 'Delete' || e.key === 'Backspace' || e.key === '0') {
      e.preventDefault();
      commit(0);
    } else if (/^[1-5]$/.test(e.key)) {
      e.preventDefault();
      commit(Number(e.key));
    }
  };

  return (
    <div className={`inline-flex items-center gap-1 ${className}`} role="group" aria-label={label}>
      <div
        className={`relative inline-flex items-center ${disabled ? 'opacity-50' : ''}`}
        onMouseLeave={() => finePointer && setHover(0)}
        onKeyDown={handleKey}
        tabIndex={disabled ? -1 : 0}
      >
        {[1, 2, 3, 4, 5].map((pos) => (
          <StarCell
            key={pos}
            pos={pos}
            effective={effective}
            onHover={finePointer ? setHover : undefined}
            onCommit={commit}
            disabled={disabled}
            dims={dims}
          />
        ))}
      </div>
      {allowClear && current > 0 && !disabled && (
        <button
          type="button"
          onClick={() => commit(0)}
          className="focus-ring pressable inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-muted hover:bg-surface-raised/70 hover:text-ink-bright cursor-pointer"
          aria-label="Clear rating"
        >
          <X className="h-3.5 w-3.5" aria-hidden="true" />
        </button>
      )}
    </div>
  );
}

function StarCell({ pos, effective, onHover, onCommit, disabled, dims }) {
  const halfValue = pos - 0.5;
  const fullValue = pos;
  const fillLevel = effective >= fullValue ? 'full' : effective >= halfValue ? 'half' : 'empty';

  return (
    <span className={`relative inline-flex shrink-0 items-center justify-center ${dims.cell}`}>
      <span className={`relative inline-flex ${dims.star}`} aria-hidden="true">
        <Star
          className={`absolute inset-0 ${dims.star} transition-colors duration-150 ${
            fillLevel === 'empty' ? 'text-muted/35' : 'text-accent'
          }`}
        />
        {fillLevel !== 'empty' && (
          <span
            className="absolute inset-y-0 left-0 overflow-hidden transition-[width] duration-150"
            style={{ width: fillLevel === 'half' ? '50%' : '100%' }}
          >
            <Star className={`${dims.star} fill-accent text-accent`} />
          </span>
        )}
      </span>
      {!disabled && (
        <>
          <button
            type="button"
            className="absolute inset-y-0 left-0 w-1/2 cursor-pointer"
            onMouseEnter={() => onHover?.(halfValue)}
            onClick={() => onCommit(halfValue)}
            aria-label={`${halfValue} stars`}
            tabIndex={-1}
          />
          <button
            type="button"
            className="absolute inset-y-0 right-0 w-1/2 cursor-pointer"
            onMouseEnter={() => onHover?.(fullValue)}
            onClick={() => onCommit(fullValue)}
            aria-label={`${fullValue} stars`}
            tabIndex={-1}
          />
        </>
      )}
    </span>
  );
}

function StarDisplay({ value, size = 'md', className = '' }) {
  const dims = { sm: 'h-3.5 w-3.5', md: 'h-4 w-4', lg: 'h-5 w-5' }[size] || 'h-4 w-4';

  return (
    <span
      className={`inline-flex items-center ${className}`}
      aria-label={`${formatStars(value)} of 5 stars`}
    >
      {[1, 2, 3, 4, 5].map((pos) => {
        const fillLevel = value >= pos ? 'full' : value >= pos - 0.5 ? 'half' : 'empty';
        return (
          <span key={pos} className={`relative inline-flex ${dims}`} aria-hidden="true">
            <Star
              className={`absolute inset-0 ${dims} ${
                fillLevel === 'empty' ? 'text-muted/35' : 'text-accent'
              }`}
            />
            {fillLevel !== 'empty' && (
              <span
                className="absolute inset-y-0 left-0 overflow-hidden"
                style={{ width: fillLevel === 'half' ? '50%' : '100%' }}
              >
                <Star className={`${dims} fill-accent text-accent`} />
              </span>
            )}
          </span>
        );
      })}
    </span>
  );
}

function formatStars(value) {
  if (!value) return '0';
  return value % 1 === 0 ? value.toFixed(0) : value.toFixed(1);
}

/** Collapsed control for dense lists (episode rows). Expands only when editing. */
export function EpisodeRatingControl({
  value = null,
  onChange,
  disabled = false,
  label = 'Rate episode',
}) {
  const stars = ratingToStars(value);
  const [open, setOpen] = useState(false);
  const wrapRef = useRef(null);

  useEffect(() => {
    if (!open) return undefined;
    const onPointer = (e) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target)) setOpen(false);
    };
    document.addEventListener('pointerdown', onPointer);
    return () => document.removeEventListener('pointerdown', onPointer);
  }, [open]);

  if (!open) {
    if (stars > 0) {
      return (
        <button
          type="button"
          disabled={disabled}
          onClick={() => setOpen(true)}
          className="focus-ring pressable inline-flex min-h-[28px] items-center gap-1 rounded-md px-1.5 py-0.5 text-[11px] font-semibold text-accent hover:bg-accent/10 cursor-pointer disabled:opacity-50"
          aria-label={`${label}: ${formatStars(stars)} stars. Tap to edit`}
        >
          <Star className="h-3 w-3 fill-accent text-accent" aria-hidden="true" />
          {formatStars(stars)}
        </button>
      );
    }
    return (
      <button
        type="button"
        disabled={disabled}
        onClick={() => setOpen(true)}
        className="focus-ring pressable inline-flex min-h-[28px] items-center gap-1 rounded-md px-1.5 py-0.5 text-[11px] font-medium text-muted hover:bg-surface-raised hover:text-ink cursor-pointer disabled:opacity-50"
        aria-label={label}
      >
        <Star className="h-3 w-3" aria-hidden="true" />
        Rate
      </button>
    );
  }

  return (
    <div
      ref={wrapRef}
      className="state-enter basis-full flex flex-wrap items-center gap-1.5 pt-0.5"
    >
      <StarRating
        value={stars}
        onChange={(next) => {
          onChange?.(next);
          if (next) setOpen(false);
        }}
        size="sm"
        density="compact"
        allowClear
        disabled={disabled}
        label={label}
      />
    </div>
  );
}

/** Detail-page strip used under film/show action rows. */
export function RatingField({
  value,
  onChange,
  disabled = false,
  label = 'Your rating',
  title,
}) {
  return (
    <div className="mt-3 flex min-h-[44px] flex-wrap items-center gap-x-3 gap-y-2 rounded-xl border border-border/60 bg-surface/50 px-3 py-2.5 shadow-glass backdrop-blur-md">
      <span className="shrink-0 text-[10px] font-bold uppercase tracking-[0.14em] text-muted">
        {label}
      </span>
      <StarRating
        value={value}
        onChange={onChange}
        size="md"
        density="comfortable"
        disabled={disabled}
        label={title ? `Rate ${title}` : label}
      />
    </div>
  );
}

/** Storage (1..10 int) -> UI (0..5 half-step). */
export function ratingToStars(stored) {
  if (stored == null) return 0;
  const num = Number(stored);
  if (!Number.isFinite(num) || num <= 0) return 0;
  return Math.max(0.5, Math.min(5, num / 2));
}

/** UI (0..5 half-step) -> API payload. 0 or null clears. */
export function starsToPayload(stars) {
  if (!stars) return null;
  return Number(stars);
}
