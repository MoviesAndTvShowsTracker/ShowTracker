import { Check, Play } from 'lucide-react';

export default function MarkFab({
  icon = 'check',
  onClick,
  disabled = false,
  size = 'md',
  ariaLabel,
  className = '',
}) {
  const dimensions = size === 'lg' ? 'h-11 w-11' : 'h-9 w-9';
  const Icon = icon === 'play' ? Play : Check;

  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-label={ariaLabel}
      className={`focus-ring inline-flex ${dimensions} items-center justify-center rounded-full border border-border/80 bg-canvas/95 text-accent shadow-glass transition-all duration-200 hover:bg-accent hover:text-on-accent active:scale-90 disabled:opacity-50 disabled:active:scale-100 cursor-pointer ${className}`}
    >
      <Icon className={`h-4 w-4 ${icon === 'play' ? 'fill-current' : ''}`} strokeWidth={2.5} aria-hidden />
    </button>
  );
}
