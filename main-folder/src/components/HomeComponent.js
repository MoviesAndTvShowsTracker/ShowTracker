import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Bookmark, CheckCircle2, Heart, List, Search, Sparkles } from 'lucide-react';
import { API_KEY, API_URL, IMAGE_URL } from '../config/keys';
import PageTitle from '../utils/PageTitle';
import { useAuth } from '../context/AuthContext';
import { BRAND_NAME } from '../config/brand';
import BentoCard from './ui/BentoCard';
import PosterRail from './ui/PosterRail';
import PosterTile from './ui/PosterTile';

export default function Home() {
  const { isAuthenticated } = useAuth();
  const [trendingMovies, setTrendingMovies] = useState([]);
  const [trendingTv, setTrendingTv] = useState([]);

  useEffect(() => {
    fetch(`${API_URL}trending/movie/week?api_key=${API_KEY}&language=en-US`)
      .then((r) => r.json())
      .then((d) => setTrendingMovies((d.results || []).slice(0, 16)));

    fetch(`${API_URL}trending/tv/week?api_key=${API_KEY}&language=en-US`)
      .then((r) => r.json())
      .then((d) => setTrendingTv((d.results || []).slice(0, 16)));
  }, []);

  return (
    <>
      <PageTitle title="Track films & TV" />

      {/* Hero — Letterboxd editorial band */}
      <section className="hero-band">
        <div
          className="absolute inset-0 bg-cover bg-center opacity-40"
          style={{
            backgroundImage:
              "url('https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=2000&q=80')",
          }}
        />
        <div className="absolute inset-0 bg-gradient-to-r from-canvas via-canvas/95 to-canvas/70" />
        <div className="relative mx-auto max-w-content px-4 py-12 sm:px-6 sm:py-16 md:py-20">
          <p className="animate-fade-up text-xs font-bold uppercase tracking-[0.2em] text-accent opacity-0" style={{ animationDelay: '0ms' }}>
            Marquee — your watch diary
          </p>
          <h1
            className="animate-fade-up mt-3 max-w-2xl font-serif text-3xl leading-tight text-ink-bright opacity-0 sm:text-4xl md:text-5xl"
            style={{ animationDelay: '80ms' }}
          >
            Log films. Build lists. Never forget what to watch next.
          </h1>
          <p
            className="animate-fade-up mt-4 max-w-lg text-base leading-relaxed text-muted opacity-0"
            style={{ animationDelay: '160ms' }}
          >
            {BRAND_NAME} is where you track every film and show — mark watched, save favorites, curate watchlists, and discover what&apos;s trending.
          </p>
          {!isAuthenticated ? (
            <div className="animate-fade-up mt-8 flex flex-wrap gap-3 opacity-0" style={{ animationDelay: '240ms' }}>
              <Link to="/signup" className="btn-primary">
                Get started — it&apos;s free
              </Link>
              <Link to="/login" className="btn-secondary">
                Sign in
              </Link>
            </div>
          ) : (
            <div className="animate-fade-up mt-8 flex flex-wrap gap-3 opacity-0" style={{ animationDelay: '240ms' }}>
              <Link to="/profile" className="btn-primary">
                My diary
              </Link>
              <Link to="/movies" className="btn-secondary">
                Browse films
              </Link>
            </div>
          )}
        </div>
      </section>

      <div className="mx-auto max-w-content px-4 py-12 sm:px-6 md:py-16">
        {/* Identity bento — what we do */}
        <section className="mb-14 md:mb-16">
          <h2 className="section-title mb-6">What you can do</h2>
          <div className="grid grid-cols-2 gap-2 sm:gap-3 lg:grid-cols-4">
            <BentoCard
              to={isAuthenticated ? '/movies' : '/signup'}
              icon={CheckCircle2}
              title="Track watched"
              description="Mark films and episodes as watched. Build a permanent record of your viewing history."
              delay={0}
            />
            <BentoCard
              to={isAuthenticated ? '/profile' : '/signup'}
              icon={Heart}
              title="Save favorites"
              description="Heart the titles you love. Your favorites live on your profile, always within reach."
              delay={80}
            />
            <BentoCard
              to={isAuthenticated ? '/profile' : '/signup'}
              icon={List}
              title="Watchlists"
              description="Queue what to watch next. Separate lists for movies and TV — plan your next binge."
              delay={160}
            />
            <BentoCard
              to="/search"
              icon={Search}
              title="Discover"
              description="Search TMDB's catalog. Find new releases, classics, and hidden gems to add to your lists."
              delay={240}
            />
          </div>
        </section>

        {/* Secondary bento row */}
        <section className="mb-14 grid grid-cols-2 gap-2 sm:gap-3 md:mb-16 md:grid-cols-3">
          <BentoCard
            to="/movies"
            icon={Bookmark}
            title="Browse movies"
            description="Explore popular and trending films. Tap any poster to log, favorite, or watchlist."
            delay={100}
            className="md:col-span-1"
          />
          <BentoCard
            to="/tv"
            icon={Sparkles}
            title="Browse TV"
            description="Follow shows season by season. Track episodes and build your series library."
            delay={180}
            className="md:col-span-1"
          />
          <article
            className="bento-card animate-fade-up col-span-2 flex flex-col justify-center opacity-0 md:col-span-1"
            style={{ animationDelay: '260ms' }}
          >
            <h3 className="font-serif text-base text-ink-bright sm:text-xl">Built for cinephiles</h3>
            <p className="mt-1.5 text-xs leading-relaxed text-muted sm:mt-2 sm:text-sm">
              Poster-first layout, smooth rails, and a profile like your personal screening room.
            </p>
          </article>
        </section>

        {/* Trending rails */}
        <div className="space-y-12 md:space-y-16">
          <PosterRail title="Trending this week — films" actionTo="/movies" actionLabel="All films">
            {trendingMovies.map(
              (m) =>
                m.poster_path && (
                  <PosterTile
                    key={m.id}
                    to={isAuthenticated ? `/movies/${m.id}` : '/signup'}
                    poster={m.poster_path}
                    title={m.title}
                    imageUrlPrefix={`${IMAGE_URL}w342`}
                    size="sm"
                  />
                )
            )}
          </PosterRail>

          <PosterRail title="Trending this week — TV" actionTo="/tv" actionLabel="All TV">
            {trendingTv.map(
              (s) =>
                s.poster_path && (
                  <PosterTile
                    key={s.id}
                    to={isAuthenticated ? `/tv/${s.id}` : '/signup'}
                    poster={s.poster_path}
                    title={s.name}
                    imageUrlPrefix={`${IMAGE_URL}w342`}
                    size="sm"
                  />
                )
            )}
          </PosterRail>
        </div>

        {!isAuthenticated && (
          <section className="glass-card mt-16 p-8 text-center md:p-12">
            <h2 className="font-serif text-2xl text-ink-bright">Ready to start tracking?</h2>
            <p className="mx-auto mt-3 max-w-md text-muted">
              Join {BRAND_NAME} and turn your watch habits into a beautiful, organized diary.
            </p>
            <Link to="/signup" className="btn-primary mt-6">
              Create free account
            </Link>
          </section>
        )}
      </div>
    </>
  );
}
