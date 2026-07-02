import { Link } from 'react-router-dom';

export default function BentoCard({ to, icon: Icon, title, description, delay = 0, className = '' }) {
  const style = delay ? { animationDelay: `${delay}ms` } : undefined;

  const inner = (
    <>
      {Icon && (
        <div className="mb-2 inline-flex rounded-xl bg-accent/10 p-2 text-accent sm:mb-4 sm:p-2.5">
          <Icon className="h-4 w-4 sm:h-5 sm:w-5" aria-hidden="true" />
        </div>
      )}
      <h3 className="text-[11px] font-bold uppercase tracking-wide text-ink-bright sm:text-sm">{title}</h3>
      <p className="mt-1 line-clamp-3 text-[11px] leading-snug text-muted sm:mt-2 sm:line-clamp-none sm:text-sm sm:leading-relaxed">
        {description}
      </p>
    </>
  );

  const classes = `bento-card animate-fade-up opacity-0 !p-3 sm:!p-5 ${className}`;

  if (to) {
    return (
      <Link to={to} className={classes} style={style}>
        {inner}
      </Link>
    );
  }

  return (
    <article className={classes} style={style}>
      {inner}
    </article>
  );
}
