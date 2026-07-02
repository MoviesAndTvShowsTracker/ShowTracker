import { Children } from 'react';
import { Link } from 'react-router-dom';
import { ChevronRight } from 'lucide-react';

export default function PosterRail({ title, actionLabel, actionTo, children, empty }) {
  const items = Children.toArray(children).filter(Boolean);
  const isEmpty = items.length === 0;

  if (isEmpty) {
    return (
      <section className="space-y-3">
        <h2 className="section-title">{title}</h2>
        <p className="text-sm text-muted">{empty || 'Nothing here yet.'}</p>
      </section>
    );
  }

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
      <div className="poster-rail">{items}</div>
    </section>
  );
}
