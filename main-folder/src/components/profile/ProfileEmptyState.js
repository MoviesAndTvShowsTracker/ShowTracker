import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Check, Film, Heart, Sparkles } from 'lucide-react';
import { IMAGE_URL } from '../../config/keys';
import { tmdbFetch } from '../../utils/tmdb';
import PosterRail from '../ui/PosterRail';
import PosterTile from '../ui/PosterTile';

const STEPS = [
  {
    icon: Film,
    title: 'Browse',
    text: 'Find a film or show worth tracking.',
    to: '/movies',
    label: 'Browse films',
  },
  {
    icon: Check,
    title: 'Log it',
    text: 'Mark watched — films and episodes become your diary.',
    to: '/tv',
    label: 'Browse TV',
  },
  {
    icon: Heart,
    title: 'Save favorites',
    text: 'Heart titles you love so they stay easy to find.',
    to: '/movies',
    label: 'Start logging',
  },
];

export default function ProfileEmptyState({ name }) {
  const [trendingFilms, setTrendingFilms] = useState([]);
  const [trendingTv, setTrendingTv] = useState([]);
  const [trendingLoading, setTrendingLoading] = useState(true);

  useEffect(() => {
    Promise.all([tmdbFetch('trending/movie/week'), tmdbFetch('trending/tv/week')])
      .then(([films, tv]) => {
        setTrendingFilms((films.results || []).slice(0, 10));
        setTrendingTv((tv.results || []).slice(0, 10));
      })
      .catch(() => {})
      .finally(() => setTrendingLoading(false));
  }, []);

  return (
    <div className="space-y-10 md:space-y-12">
      <section className="glass-card animate-fade-up relative overflow-hidden p-6 opacity-0 sm:p-8">
        <div
          className="pointer-events-none absolute -right-8 -top-8 h-40 w-40 rounded-full opacity-30 blur-3xl"
          style={{ background: 'var(--bg-glow-1)' }}
        />
        <div className="relative max-w-xl">
          <p className="flex items-center gap-2 text-xs font-bold uppercase tracking-[0.15em] text-accent">
            <Sparkles className="h-4 w-4" />
            Welcome{name ? `, ${name}` : ''}
          </p>
          <h2 className="mt-3 font-serif text-2xl text-ink-bright sm:text-3xl">
            Your diary is ready for its first entry
          </h2>
          <p className="mt-3 text-sm leading-relaxed text-muted sm:text-base">
            Log what you watch, save favorites, and build a personal screening room over time.
          </p>
          <div className="mt-6 flex flex-wrap gap-3">
            <Link to="/movies" className="btn-primary">
              Browse films
            </Link>
            <Link to="/tv" className="btn-secondary">
              Explore TV
            </Link>
          </div>
        </div>
      </section>

      <section className="space-y-4">
        <h2 className="section-title">How it works</h2>
        <div className="grid gap-3 sm:grid-cols-3">
          {STEPS.map(({ icon: Icon, title, text, to, label }, i) => (
            <article
              key={title}
              className="glass-card animate-fade-up flex flex-col p-4 opacity-0 sm:p-5"
              style={{ animationDelay: `${120 + i * 80}ms` }}
            >
              <span className="inline-flex h-8 w-8 items-center justify-center rounded-xl bg-accent/10 text-sm font-bold text-accent">
                {i + 1}
              </span>
              <Icon className="mt-3 h-5 w-5 text-accent" aria-hidden="true" />
              <h3 className="mt-2 font-medium text-ink-bright">{title}</h3>
              <p className="mt-1 flex-1 text-xs leading-relaxed text-muted sm:text-sm">{text}</p>
              <Link to={to} className="btn-link mt-4 inline-block">
                {label}
              </Link>
            </article>
          ))}
        </div>
      </section>

      <PosterRail title="Trending films — tap to start" actionTo="/movies">
        {trendingLoading
          ? [1, 2, 3, 4].map((item) => (
              <div
                key={item}
                className="h-[132px] w-[88px] shrink-0 animate-pulse rounded-xl bg-surface-raised sm:w-[100px]"
                aria-hidden
              />
            ))
          : trendingFilms.map(
              (m) =>
                m.poster_path && (
                  <PosterTile
                    key={m.id}
                    to={`/movies/${m.id}`}
                    poster={m.poster_path}
                    title={m.title}
                    imageUrlPrefix={`${IMAGE_URL}w342`}
                  />
                )
            )}
      </PosterRail>

      <PosterRail title="Trending TV — tap to start" actionTo="/tv">
        {trendingLoading
          ? [1, 2, 3, 4].map((item) => (
              <div
                key={item}
                className="h-[132px] w-[88px] shrink-0 animate-pulse rounded-xl bg-surface-raised sm:w-[100px]"
                aria-hidden
              />
            ))
          : trendingTv.map(
              (s) =>
                s.poster_path && (
                  <PosterTile
                    key={s.id}
                    to={`/tv/${s.id}`}
                    poster={s.poster_path}
                    title={s.name}
                    imageUrlPrefix={`${IMAGE_URL}w342`}
                  />
                )
            )}
      </PosterRail>
    </div>
  );
}
