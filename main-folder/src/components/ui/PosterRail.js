import { Link } from 'react-router-dom';
import { ChevronRight } from 'lucide-react';

export default function PosterRail({ title, actionLabel, actionTo, children, empty }) {
  if (empty) {
    return (
      <section className="space-y-3">
        <h2 className="section-title">{title}</h2>
        <p className="text-sm text-muted">{empty}</p>
      </section>
    );
  }

  if (!children) return null;

  return (
    <section className="space-y-3">
      <div className="flex items-center justify-between gap-3 pr-1">
        <h2 className="section-title">{title}</h2>
        {actionTo && (
          <Link to={actionTo} className="btn-link inline-flex items-center gap-0.5 shrink-0">
            {actionLabel || 'View all'}
            <ChevronRight className="h-4 w-4" aria-hidden="true" />
          </Link>
        )}
      </div>
      <div className="poster-rail -mx-4 px-4 sm:-mx-0 sm:px-0">{children}</div>
    </section>
  );
}
