import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Bookmark, Check, Film, Heart, Sparkles, Tv } from 'lucide-react';
import { API_KEY, API_URL, IMAGE_URL } from '../../config/keys';
import PosterRail from '../ui/PosterRail';
import PosterTile from '../ui/PosterTile';

const STEPS = [
  {
    icon: Film,
    title: 'Pick a film or show',
    text: 'Browse trending titles or search the catalog.',
    to: '/movies',
    label: 'Browse films',
  },
  {
    icon: Heart,
    title: 'Heart TV shows',
    text: 'Favoriting a show adds it to your watched TV list automatically.',
    to: '/tv',
    label: 'Browse TV',
  },
  {
    icon: Check,
    title: 'Log films you watch',
    text: 'Mark films watched and build your diary over time.',
    to: '/movies',
    label: 'Start logging',
  },
];

export default function ProfileEmptyState({ username }) {
  const [trendingFilms, setTrendingFilms] = useState([]);
  const [trendingTv, setTrendingTv] = useState([]);

  useEffect(() => {
    fetch(`${API_URL}trending/movie/week?api_key=${API_KEY}&language=en-US`)
      .then((r) => r.json())
      .then((d) => setTrendingFilms((d.results || []).slice(0, 10)));

    fetch(`${API_URL}trending/tv/week?api_key=${API_KEY}&language=en-US`)
      .then((r) => r.json())
      .then((d) => setTrendingTv((d.results || []).slice(0, 10)));
  }, []);

  return (
    <div className="space-y-10 md:space-y-12">
      <section className="glass-card relative overflow-hidden p-6 sm:p-8 md:p-10">
        <div
          className="pointer-events-none absolute -right-8 -top-8 h-40 w-40 rounded-full opacity-30 blur-3xl"
          style={{ background: 'var(--bg-glow-1)' }}
        />
        <div className="relative max-w-xl">
          <p className="flex items-center gap-2 text-xs font-bold uppercase tracking-[0.15em] text-accent">
            <Sparkles className="h-4 w-4" />
            Welcome{username ? `, ${username}` : ''}
          </p>
          <h2 className="mt-3 font-serif text-2xl text-ink-bright sm:text-3xl">
            Your diary is ready for its first entry
          </h2>
          <p className="mt-3 text-sm leading-relaxed text-muted sm:text-base">
            Track films and TV, save favorites, and queue what to watch next. Heart a TV show and
            it&apos;s added to watched TV — films get logged with one tap.
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
            <article key={title} className="glass-card flex flex-col p-4 sm:p-5">
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

      <section className="grid grid-cols-2 gap-2 sm:gap-3">
        {[
          { icon: Heart, label: 'Favorite films', desc: 'Heart films you love', to: '/movies' },
          { icon: Check, label: 'Watched films', desc: 'Log viewing history', to: '/movies' },
          { icon: Heart, label: 'Favorite TV', desc: 'Also adds to watched TV', to: '/tv' },
          { icon: Bookmark, label: 'Watchlists', desc: 'Queue what\'s next', to: '/movies' },
        ].map(({ icon: Icon, label, desc, to }) => (
          <Link
            key={label}
            to={to}
            className="glass-card group flex items-center gap-3 p-4 transition-all hover:border-accent/30 hover:scale-[1.01] cursor-pointer"
          >
            <span className="inline-flex rounded-xl bg-accent/10 p-2.5 text-accent transition-colors group-hover:bg-accent/15">
              <Icon className="h-5 w-5" />
            </span>
            <div className="min-w-0">
              <p className="text-sm font-semibold text-ink-bright">{label}</p>
              <p className="text-xs text-muted">{desc}</p>
            </div>
          </Link>
        ))}
      </section>

      <PosterRail title="Trending films — tap to start" actionTo="/movies">
        {trendingFilms.map(
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
        {trendingTv.map(
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
