export default function EmptyState({ icon: Icon, title, description, children, className = '' }) {
  return (
    <div className={`glass-card state-enter p-6 text-center sm:p-8 ${className}`}>
      {Icon && <Icon className="mx-auto h-8 w-8 text-accent/70" aria-hidden />}
      {title && <p className="mt-3 font-serif text-lg text-ink-bright">{title}</p>}
      {description && <p className="mt-2 text-sm text-muted">{description}</p>}
      {children && <div className="mt-5 flex flex-wrap justify-center gap-3">{children}</div>}
    </div>
  );
}
