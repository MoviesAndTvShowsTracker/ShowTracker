const VARIANT_ACTIVE = {
  default: 'border-accent/60 bg-accent/15 text-accent shadow-glass backdrop-blur-md',
  accent: 'border-accent/60 bg-accent/15 text-accent shadow-glass backdrop-blur-md',
  success: 'border-link/50 bg-link/12 text-link shadow-glass backdrop-blur-md',
  warning: 'border-amber-500/50 bg-amber-500/12 text-amber-700 dark:text-amber-400 shadow-glass backdrop-blur-md',
};

export function ActionButton({
  active,
  onClick,
  icon: Icon,
  label,
  badge,
  compactLabel,
  subLabel,
  variant = 'default',
  static: isStatic = false,
}) {
  const activeClass = VARIANT_ACTIVE[variant] || VARIANT_ACTIVE.default;
  const className = `flex flex-col items-center justify-center gap-1 rounded-xl border px-2 py-3 transition-all duration-300 min-h-[72px] md:min-h-[44px] md:flex-row md:gap-2 md:px-4 md:py-2 ${
    isStatic
      ? `cursor-default ${active ? activeClass : 'border-border bg-surface/80 text-ink shadow-glass backdrop-blur-md'}`
      : `cursor-pointer ${
          active
            ? activeClass
            : 'border-border bg-surface/80 text-ink shadow-glass backdrop-blur-md hover:border-accent/30 hover:bg-surface md:hover:scale-[1.02]'
        }`
  }`;

  const content = (
    <>
      {Icon && <Icon className="h-5 w-5 shrink-0 md:h-4 md:w-4" aria-hidden="true" />}
      <span className="flex flex-col items-center gap-0.5 md:flex-row md:gap-2">
        <span className="text-[10px] font-bold uppercase tracking-wide leading-tight text-center md:text-sm md:normal-case md:tracking-normal md:font-medium">
          <span className="md:hidden">{compactLabel || label}</span>
          <span className="hidden md:inline">{label}</span>
        </span>
        {subLabel && (
          <span className="text-[10px] font-semibold normal-case tracking-normal text-accent/90 md:text-xs">
            {subLabel}
          </span>
        )}
      </span>
      {badge != null && (
        <span className="rounded-full bg-canvas px-1.5 py-0.5 text-[10px] font-bold md:ml-0">{badge}</span>
      )}
    </>
  );

  if (isStatic) {
    return (
      <div className={className} aria-label={subLabel ? `${label}. ${subLabel}` : label}>
        {content}
      </div>
    );
  }

  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={subLabel ? `${label}. ${subLabel}` : label}
      aria-pressed={active}
      className={className}
    >
      {content}
    </button>
  );
}

export default function ActionStrip({ children, columns = 3 }) {
  const colClass = columns === 2 ? 'grid-cols-2' : 'grid-cols-3';
  return (
    <div className={`grid ${colClass} gap-2 md:flex md:flex-wrap md:gap-3`}>
      {children}
    </div>
  );
}
