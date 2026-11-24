import { Link } from 'react-router-dom';
import { RefreshCw } from 'lucide-react';
import PageTitle from '../../utils/PageTitle';
import BackNav from '../ui/BackNav';
import useDashboardStats from '../../hooks/useDashboardStats';
import {
  BiggestNight,
  HotTakes,
  HouseLightsDial,
  Ledger,
  LobbyTypePlaque,
  QuietTaste,
  SeasonArcs,
  Shelves,
} from './stats/LobbyDiary';

export default function ProfileStatsPage() {
  const { stats, loading, refreshing, error, refresh } = useDashboardStats();
  const o = stats?.overview;
  const lib = stats?.library;
  const isEmpty = !o?.episodeCount && !o?.filmCount && !(lib?.totalTracked > 0);

  return (
    <>
      <PageTitle title="Your stats" />
      <div className="mx-auto max-w-content px-4 py-6 sm:px-6 md:py-10">
        <div className="mb-5 flex items-center justify-between gap-3">
          <BackNav to="/profile" label="Back to profile" />
          {stats && (
            <button
              type="button"
              disabled={refreshing}
              onClick={refresh}
              className="focus-ring inline-flex min-h-[44px] items-center gap-1.5 rounded-lg px-2 text-xs font-semibold text-link hover:text-ink-bright disabled:opacity-50 cursor-pointer"
            >
              <RefreshCw className={`h-3.5 w-3.5 ${refreshing ? 'animate-spin' : ''}`} />
              Refresh
            </button>
          )}
        </div>

        {loading && !stats ? (
          <div className="space-y-4">
            <div className="h-72 animate-pulse rounded-3xl bg-surface-raised" />
            <div className="h-28 animate-pulse rounded-3xl bg-surface-raised" />
          </div>
        ) : error && !stats ? (
          <div className="glass-card p-8 text-center">
            <p className="text-sm text-muted">{error}</p>
            <button type="button" onClick={refresh} className="btn-primary mt-4">
              Try again
            </button>
          </div>
        ) : isEmpty ? (
          <div className="glass-card p-8 text-center">
            <p className="font-serif text-lg text-ink-bright">The house lights are still up</p>
            <p className="mt-1.5 text-sm text-muted">
              Mark a film or an episode and this page becomes your lobby diary.
            </p>
            <Link to="/tv" className="btn-primary mt-5 inline-flex">
              Browse TV
            </Link>
          </div>
        ) : (
          <div className="space-y-8">
            <section>
              {stats?.insight?.text && (
                <p className="text-sm leading-relaxed text-muted">{stats.insight.text}</p>
              )}
              <div className="mt-4">
                <HouseLightsDial rhythm={stats?.rhythm} />
              </div>
            </section>
            <LobbyTypePlaque lobby={stats?.lobbyType} />
            <SeasonArcs arcs={stats?.seasonArcs} />
            <BiggestNight night={stats?.biggestNight} />
            <HotTakes takes={stats?.hotTakes} />
            <Shelves library={lib} />
            <QuietTaste taste={stats?.taste} />
            <Ledger overview={o} previousYear={stats?.previousYear} />
          </div>
        )}
      </div>
    </>
  );
}
