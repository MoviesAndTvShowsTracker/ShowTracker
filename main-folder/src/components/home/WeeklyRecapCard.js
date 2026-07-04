import { Link } from 'react-router-dom';
import { Flame, TrendingUp } from 'lucide-react';
import { formatDuration } from '../../utils/statsFormat';
import { clearSessionStats } from '../../utils/statsCache';

function recapMessage(recap) {
  const parts = [];
  if (recap.episodesThisWeek > 0) {
    parts.push(
      `${recap.episodesThisWeek} episode${recap.episodesThisWeek !== 1 ? 's' : ''}`
    );
  }
  if (recap.filmsThisWeek > 0) {
    parts.push(`${recap.filmsThisWeek} film${recap.filmsThisWeek !== 1 ? 's' : ''}`);
  }

  if (parts.length) {
    return `You logged ${parts.join(' and ')} this week.`;
  }
  if (recap.streak > 1) {
    return `${recap.streak}-day watching streak — keep it going!`;
  }
  if (recap.streak === 1) {
    return 'You logged something yesterday — build a streak today.';
  }
  return 'Log a film or episode to start your week.';
}

export default function WeeklyRecapCard({ recap, loading }) {
  if (loading) {
    return (
      <div className="mb-6 min-h-[5.5rem] animate-pulse rounded-xl bg-surface-raised" aria-hidden />
    );
  }

  if (!recap) {
    return <div className="mb-6 min-h-0" aria-hidden />;
  }

  const activeWeek =
    recap.episodesThisWeek > 0 ||
    recap.filmsThisWeek > 0 ||
    recap.tvMinsThisWeek > 0 ||
    recap.filmMinsThisWeek > 0;
  const totalMins = (recap.tvMinsThisWeek || 0) + (recap.filmMinsThisWeek || 0);

  return (
    <Link
      to="/profile/stats"
      onClick={() => clearSessionStats()}
      className="mb-6 block min-h-[5.5rem] rounded-xl border border-border/60 bg-surface-raised/30 p-4 transition-colors hover:border-accent/40 hover:bg-surface-raised/50 cursor-pointer"
    >
      <div className="flex items-start gap-3">
        <span className="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-accent/15 text-accent">
          {recap.streak > 1 ? <Flame className="h-5 w-5" /> : <TrendingUp className="h-5 w-5" />}
        </span>
        <div className="min-w-0 flex-1">
          <p className="text-xs font-bold uppercase tracking-widest text-muted">This week</p>
          <p className="mt-1 font-serif text-lg text-ink-bright">{recapMessage(recap)}</p>
          <div className="mt-1.5 flex flex-wrap gap-x-3 gap-y-1 text-xs text-muted">
            {recap.streak > 0 && (
              <span>
                {recap.streak}-day streak
              </span>
            )}
            {activeWeek && totalMins > 0 && <span>{formatDuration(totalMins)} screen time</span>}
            <span className="text-link">See stats →</span>
          </div>
        </div>
      </div>
    </Link>
  );
}
