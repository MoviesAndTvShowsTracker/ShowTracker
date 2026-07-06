import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { CheckCircle2, PauseCircle, PlayCircle } from 'lucide-react';
import api from '../../api/axios';
import { tvLibraryPath } from '../../config/tvLibrary';

const CARDS = [
  {
    key: 'watching',
    title: 'Watching',
    icon: PlayCircle,
    countKey: 'watching',
    hint: 'In progress',
  },
  {
    key: 'stopped',
    title: 'Stopped',
    icon: PauseCircle,
    countKey: 'paused',
    hint: 'Paused shows',
  },
  {
    key: 'finished',
    title: 'Finished',
    icon: CheckCircle2,
    countKey: 'completed',
    hint: 'Completed',
  },
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
    <section aria-label="TV library">
      <div className="mb-4 flex items-end justify-between gap-3">
        <div>
          <h2 className="section-title">TV library</h2>
          <p className="mt-1 text-sm text-muted">Watching, stopped, and finished shows</p>
        </div>
        <Link
          to={tvLibraryPath('watching')}
          className="text-xs font-semibold text-link hover:text-ink-bright cursor-pointer shrink-0"
        >
          Open library
        </Link>
      </div>

      <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
        {CARDS.map(({ key, title, icon: Icon, countKey, hint }) => (
          <Link
            key={key}
            to={tvLibraryPath(key)}
            className="glass-card flex min-h-[72px] items-center gap-3 p-4 transition-colors hover:border-accent/30 cursor-pointer"
          >
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-accent/10 text-accent">
              <Icon className="h-5 w-5" />
            </div>
            <div className="min-w-0">
              <p className="text-sm font-semibold text-ink-bright">{title}</p>
              <p className="text-xs text-muted">
                {loading ? '…' : `${counts[countKey] || 0} · ${hint}`}
              </p>
            </div>
          </Link>
        ))}
      </div>
    </section>
  );
}
