import { useCallback, useLayoutEffect, useState } from 'react';
import { IMAGE_URL } from '../../config/keys';
import GridCard from './GridCard';
import PageTitle from '../../utils/PageTitle';
import HeroCarousel from '../ui/HeroCarousel';
import PosterRail from '../ui/PosterRail';
import GenreChips, { filterCuratedGenres } from '../ui/GenreChips';
import MediaPosterTiles from '../browse/MediaPosterTiles';
import { heroSlides, tmdbFetch, withPoster } from '../../utils/tmdb';
import useCachedResource, { CACHE_KEYS } from '../../utils/routeCache';
import { confirmScrollRestore } from '../ScrollRestoration';

const EMPTY_LANDING = {
  hero: [],
  trendingToday: [],
  nowPlaying: [],
  upcoming: [],
  topRated: [],
  popular: [],
  popularPage: 1,
  genres: [],
};

async function fetchMovieLanding() {
  const [trendingWeek, trendingDay, inTheaters, comingSoon, rated, pop, genreList] =
    await Promise.all([
      tmdbFetch('trending/movie/week'),
      tmdbFetch('trending/movie/day'),
      tmdbFetch('movie/now_playing', { region: 'IN', page: 1 }),
      tmdbFetch('movie/upcoming', { region: 'IN', page: 1 }),
      tmdbFetch('movie/top_rated', { page: 1 }),
      tmdbFetch('movie/popular', { page: 1 }),
      tmdbFetch('genre/movie/list'),
    ]);

  const slides = heroSlides(trendingWeek.results, '/movies', 'title').map((s, i) =>
    i === 0 ? { ...s, badge: 'Trending this week' } : s
  );

  return {
    hero: slides,
    trendingToday: withPoster(trendingDay.results).slice(0, 16),
    nowPlaying: withPoster(inTheaters.results).slice(0, 16),
    upcoming: withPoster(comingSoon.results).slice(0, 16),
    topRated: withPoster(rated.results).slice(0, 16),
    popular: withPoster(pop.results),
    popularPage: pop.page || 1,
    genres: filterCuratedGenres(genreList.genres || [], 'movie'),
  };
}

export default function LandingPage() {
  const {
    data,
    loading,
    error,
    fromCache,
    refresh,
  } = useCachedResource(CACHE_KEYS.movieLanding, fetchMovieLanding, {
    ttl: 10 * 60_000,
  });

  const {
    hero,
    trendingToday,
    nowPlaying,
    upcoming,
    topRated,
    popular: cachedPopular,
    popularPage: cachedPage,
    genres,
  } = data || EMPTY_LANDING;

  // Local extension of the popular grid for "Load more" — does not need
  // to live in the cache; it's only interesting while this page is mounted.
  const [extraPopular, setExtraPopular] = useState([]);
  const [extraPopularPage, setExtraPopularPage] = useState(0);

  const popular = extraPopularPage > 0 ? [...cachedPopular, ...extraPopular] : cachedPopular;
  const popularPage = Math.max(cachedPage, extraPopularPage);

  const [selectedGenre, setSelectedGenre] = useState(null);
  const { data: genreData, loading: genreLoading } = useCachedResource(
    selectedGenre ? CACHE_KEYS.movieGenre(selectedGenre) : null,
    (signal) =>
      tmdbFetch(
        'discover/movie',
        { with_genres: selectedGenre, sort_by: 'popularity.desc', page: 1, region: 'IN' },
        { signal }
      ).then((d) => withPoster(d.results).slice(0, 16)),
    { ttl: 10 * 60_000, enabled: Boolean(selectedGenre) }
  );
  const genreResults = genreData || [];

  const loadMorePopular = useCallback(() => {
    tmdbFetch('movie/popular', { page: popularPage + 1 })
      .then((d) => {
        setExtraPopular((prev) => [...prev, ...withPoster(d.results)]);
        setExtraPopularPage(d.page);
      })
      .catch(() => {});
  }, [popularPage]);

  // Snap scroll back to where the user left when cache hydrates us
  // instantly on a Back navigation.
  useLayoutEffect(() => {
    if (!loading) confirmScrollRestore();
  }, [loading, popular.length, genres.length]);

  const selectedGenreName = genres.find((g) => g.id === selectedGenre)?.name;
  const showHeroSkeleton = loading && !fromCache && hero.length === 0;

  return (
    <>
      <PageTitle title="Browse films" />

      {showHeroSkeleton ? (
        <div
          className="h-52 animate-pulse bg-surface sm:h-64 md:h-80"
          aria-busy="true"
          aria-label="Loading featured films"
        />
      ) : (
        <HeroCarousel slides={hero} />
      )}

      <div className="mx-auto max-w-content space-y-10 px-4 py-8 sm:px-6 md:space-y-12 md:py-10">
        {error && !fromCache && (
          <div className="state-enter rounded-xl border border-danger/30 bg-danger/10 p-3 text-sm text-danger">
            Couldn&apos;t reach the film catalog.{' '}
            <button
              type="button"
              onClick={() => refresh().catch(() => {})}
              className="focus-ring font-semibold underline"
            >
              Try again
            </button>
          </div>
        )}
        <header>
          <h1 className="page-title">Films</h1>
          <p className="mt-2 max-w-lg text-sm text-muted">
            Trending this week, in theaters now, coming soon, and the classics — pick a genre or scroll the rails.
          </p>
        </header>

        <GenreChips
          genres={genres}
          selectedId={selectedGenre}
          onSelect={setSelectedGenre}
        />

        {selectedGenre && (
          <section className="space-y-3">
            <h2 className="section-title">
              {genreLoading ? `${selectedGenreName}…` : selectedGenreName}
            </h2>
            {genreLoading ? (
              <div className="poster-rail" aria-busy="true" aria-label="Loading genre">
                {Array.from({ length: 6 }).map((_, i) => (
                  <div
                    key={i}
                    className="h-[132px] w-[88px] shrink-0 animate-pulse rounded-xl bg-surface-raised sm:w-[100px]"
                  />
                ))}
              </div>
            ) : genreResults.length > 0 ? (
              <div className="poster-rail">
                <MediaPosterTiles items={genreResults} basePath="/movies" titleKey="title" />
              </div>
            ) : (
              <p className="text-sm text-muted">No titles found for this genre.</p>
            )}
          </section>
        )}

        <PosterRail title="Trending today">
          <MediaPosterTiles items={trendingToday} basePath="/movies" titleKey="title" />
        </PosterRail>

        {nowPlaying.length > 0 && (
          <PosterRail title="In theaters now" actionLabel="India">
            <MediaPosterTiles items={nowPlaying} basePath="/movies" titleKey="title" />
          </PosterRail>
        )}

        {upcoming.length > 0 && (
          <PosterRail title="Coming soon">
            <MediaPosterTiles items={upcoming} basePath="/movies" titleKey="title" />
          </PosterRail>
        )}

        <PosterRail title="Top rated">
          <MediaPosterTiles items={topRated} basePath="/movies" titleKey="title" />
        </PosterRail>

        <section className="space-y-4 border-t border-border pt-8">
          <div>
            <h2 className="section-title">All popular</h2>
            <p className="mt-1 text-sm text-muted">The full catalog — load more as you scroll.</p>
          </div>
          <div className="poster-grid">
            {popular.map((movie, index) => (
              <div
                key={movie.id}
                className="animate-fade-up opacity-0"
                style={{ animationDelay: `${Math.min(index * 40, 400)}ms` }}
              >
                <GridCard
                  image={movie.poster_path ? `${IMAGE_URL}w342${movie.poster_path}` : ''}
                  movieId={movie.id}
                  movieTitle={movie.title}
                />
              </div>
            ))}
          </div>
          {popular.length > 0 && (
            <div className="text-center">
              <button type="button" className="btn-secondary" onClick={loadMorePopular}>
                Load more
              </button>
            </div>
          )}
        </section>
      </div>
    </>
  );
}
