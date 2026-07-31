import { Link } from 'react-router-dom';
import { ArrowRight } from 'lucide-react';
import { formatCount, formatDuration } from '../../utils/statsFormat';
import RhythmStrip from './stats/RhythmStrip';
import { TimeSplitBar } from './stats/StatsPrimitives';

function streakLine(streak) {
  if (!streak) return 'No streak going';
  return streak === 1 ? '1-day streak' : `${streak}-day streak`;
}

export default function ProfileStats({ stats, loading, error }) {
  const overview = stats?.overview;
  const activity = stats?.activity;

  const catalogue = [
    overview?.filmCount ? `${formatCount(overview.filmCount)} films` : null,
    overview?.episodeCount ? `${formatCount(overview.episodeCount)} episodes` : null,
    overview?.tvShowCount ? `${formatCount(overview.tvShowCount)} shows` : null,
  ].filter(Boolean);

  return (
    <section aria-label="Your diary at a glance" className="glass-card overflow-hidden">
      <div className="grid gap-6 p-5 sm:p-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,18rem)] lg:gap-10">
        <div className="min-w-0">
          <div className="flex items-start justify-between gap-4">
            <p className="section-title text-accent">Estimated watch time</p>
            <Link
              to="/profile/stats"
              className="focus-ring group inline-flex shrink-0 items-center gap-1 text-xs font-semibold text-link hover:text-ink-bright cursor-pointer"
            >
              All stats
              <ArrowRight className="h-3.5 w-3.5 transition-transform duration-150 group-hover:translate-x-0.5" />
            </Link>
          </div>

          {loading && !stats ? (
            <div className="mt-3 h-11 w-40 animate-pulse rounded-lg bg-border/60" />
          ) : (
            <p className="tnum mt-2 font-serif text-[2.75rem] leading-[1.05] text-ink-bright sm:text-5xl">
              {formatDuration(overview?.totalMins)}
            </p>
          )}

          <p className="mt-2 text-sm text-muted">
            {error
              ? 'Stats are unavailable right now.'
              : catalogue.length
                ? catalogue.join(' · ')
                : 'Nothing logged yet.'}
          </p>

          {overview?.totalMins > 0 && (
            <div className="mt-5">
              <TimeSplitBar
                filmShare={overview.filmShare}
                tvShare={overview.tvShare}
                filmMins={overview.filmMins}
                tvMins={overview.tvMins}
              />
            </div>
          )}
        </div>

        <div className="min-w-0 border-t border-border/60 pt-5 lg:border-l lg:border-t-0 lg:pl-8 lg:pt-0">
          <div className="flex items-baseline justify-between gap-3">
            <p className="section-title">Last 30 days</p>
            <p className="text-xs font-semibold text-accent">{streakLine(activity?.streak)}</p>
          </div>
          <div className="mt-3">
            <RhythmStrip days={activity?.dailyActivity} />
          </div>
          <p className="mt-2 text-[11px] text-muted-dim">
            {activity?.activeDaysThisYear
              ? `${activity.activeDaysThisYear} days logged this year`
              : 'Log something to start the line'}
          </p>
        </div>
      </div>
    </section>
  );
}
