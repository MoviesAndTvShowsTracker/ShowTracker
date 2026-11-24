import { Link } from 'react-router-dom';
import { ArrowRight } from 'lucide-react';

export default function ProfileStats({ stats, loading, error }) {
  const lobby = stats?.lobbyType;
  const rhythm = stats?.rhythm;
  const line = error
    ? 'Stats are unavailable right now.'
    : lobby?.blurb || rhythm?.caption || 'Log something and the lobby fills in.';

  return (
    <section aria-label="Your diary at a glance" className="glass-card overflow-hidden">
      <div className="p-5 sm:p-6">
        <div className="flex items-start justify-between gap-4">
          <p className="section-title text-link">Lobby</p>
          <Link
            to="/profile/stats"
            className="focus-ring group inline-flex shrink-0 items-center gap-1 text-xs font-semibold text-link hover:text-ink-bright cursor-pointer"
          >
            Open diary
            <ArrowRight className="h-3.5 w-3.5 transition-transform duration-150 group-hover:translate-x-0.5" />
          </Link>
        </div>
        {loading && !stats ? (
          <div className="mt-3 h-8 w-48 animate-pulse rounded-lg bg-border/60" />
        ) : (
          <>
            <p className="mt-2 font-serif text-2xl leading-snug text-ink-bright">
              {lobby?.label || 'Your lobby'}
            </p>
            <p className="mt-2 text-sm text-muted">{line}</p>
          </>
        )}
      </div>
    </section>
  );
}
