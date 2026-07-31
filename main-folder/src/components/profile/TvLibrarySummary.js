import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowUpRight } from 'lucide-react';
import api from '../../api/axios';
import { tvLibraryPath } from '../../config/tvLibrary';
import { formatCount } from '../../utils/statsFormat';

const CARDS = [
  { key: 'watching', title: 'Watching', countKey: 'watching' },
  { key: 'stopped', title: 'Paused', countKey: 'paused' },
  { key: 'finished', title: 'Finished', countKey: 'completed' },
];

export default function TvLibrarySummary() {
  const [counts, setCounts] = useState({ watching: 0, paused: 0, completed: 0 });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api
      .get('/api/tv/tracking/library/summary')
      .then((r) => {
        if (r.data.success) setCounts(r.data.counts || { watching: 0, paused: 0, completed: 0 });
      })
      .catch(() => setCounts({ watching: 0, paused: 0, completed: 0 }))
      .finally(() => setLoading(false));
  }, []);

  const total = counts.watching + counts.paused + counts.completed;
  if (!loading && total === 0) return null;

  return (
    <section aria-label="Your shows">
      <div className="mb-3 flex items-end justify-between gap-3">
        <h2 className="section-title">Your shows</h2>
        <Link
          to={tvLibraryPath('watching')}
          className="shrink-0 text-xs font-semibold text-link hover:text-ink-bright cursor-pointer"
        >
          Open library
        </Link>
      </div>

      <div className="grid grid-cols-3 gap-2 sm:gap-3">
        {CARDS.map(({ key, title, countKey }) => (
          <Link
            key={key}
            to={tvLibraryPath(key)}
            className="group glass-card flex items-end justify-between gap-2 px-3 py-4 transition-colors hover:border-accent/30 sm:px-4 cursor-pointer"
          >
            <span className="flex min-w-0 flex-col gap-1">
              {loading ? (
                <span className="h-7 w-10 animate-pulse rounded-md bg-border/60" />
              ) : (
                <span className="tnum font-serif text-2xl leading-none text-ink-bright sm:text-3xl">
                  {formatCount(counts[countKey] || 0)}
                </span>
              )}
              <span className="text-[10px] font-bold uppercase tracking-widest text-muted">{title}</span>
            </span>
            <ArrowUpRight
              className="hidden h-4 w-4 shrink-0 text-muted-dim transition-colors group-hover:text-accent sm:block"
              aria-hidden
            />
          </Link>
        ))}
      </div>
    </section>
  );
}
