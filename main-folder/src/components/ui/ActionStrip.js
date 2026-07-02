export function ActionButton({ active, onClick, icon: Icon, label, badge, compactLabel }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      aria-pressed={active}
      className={`flex flex-col items-center justify-center gap-1.5 rounded-sm border px-2 py-3 transition-all duration-200 cursor-pointer min-h-[72px] md:min-h-[44px] md:flex-row md:gap-2 md:rounded-sm md:px-4 md:py-2 ${
        active
          ? 'border-accent bg-accent/15 text-accent'
          : 'border-border bg-surface text-ink hover:border-muted md:hover:bg-surface-raised'
      }`}
    >
      {Icon && <Icon className="h-5 w-5 shrink-0 md:h-4 md:w-4" aria-hidden="true" />}
      <span className="text-[10px] font-bold uppercase tracking-wide leading-tight text-center md:text-sm md:normal-case md:tracking-normal md:font-medium">
        <span className="md:hidden">{compactLabel || label}</span>
        <span className="hidden md:inline">{label}</span>
      </span>
      {badge != null && (
        <span className="rounded-full bg-canvas px-1.5 py-0.5 text-[10px] font-bold md:ml-0">{badge}</span>
      )}
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
