import { useCallback, useEffect, useState } from 'react';
import { IMAGE_URL } from '../../config/keys';
import TvGridCard from './TvGridCard';
import PageTitle from '../../utils/PageTitle';
import HeroCarousel from '../ui/HeroCarousel';
import PosterRail from '../ui/PosterRail';
import GenreChips, { filterCuratedGenres } from '../ui/GenreChips';
import MediaPosterTiles from '../browse/MediaPosterTiles';
import { heroSlides, tmdbFetch, withPoster } from '../../utils/tmdb';

export default function TvLandingPage() {
  const [loading, setLoading] = useState(true);
  const [hero, setHero] = useState([]);
  const [trendingToday, setTrendingToday] = useState([]);
  const [onTheAir, setOnTheAir] = useState([]);
  const [airingToday, setAiringToday] = useState([]);
  const [topRated, setTopRated] = useState([]);
  const [popular, setPopular] = useState([]);
  const [popularPage, setPopularPage] = useState(1);
  const [genres, setGenres] = useState([]);
  const [selectedGenre, setSelectedGenre] = useState(null);
  const [genreResults, setGenreResults] = useState([]);
  const [genreLoading, setGenreLoading] = useState(false);
  const [loadError, setLoadError] = useState(false);
  const [reloadKey, setReloadKey] = useState(0);

  useEffect(() => {
    setLoading(true);
    setLoadError(false);
    Promise.all([
      tmdbFetch('trending/tv/week'),
      tmdbFetch('trending/tv/day'),
      tmdbFetch('tv/on_the_air', { page: 1 }),
      tmdbFetch('tv/airing_today', { page: 1 }),
      tmdbFetch('tv/top_rated', { page: 1 }),
      tmdbFetch('tv/popular', { page: 1 }),
      tmdbFetch('genre/tv/list'),
    ])
      .then(([trendingWeek, trendingDay, onAir, today, rated, pop, genreList]) => {
        const slides = heroSlides(trendingWeek.results, '/tv', 'name').map((s, i) =>
          i === 0 ? { ...s, badge: 'Trending this week' } : s
        );
        setHero(slides);
        setTrendingToday(withPoster(trendingDay.results).slice(0, 16));
        setOnTheAir(withPoster(onAir.results).slice(0, 16));
        setAiringToday(withPoster(today.results).slice(0, 16));
        setTopRated(withPoster(rated.results).slice(0, 16));
        setPopular(withPoster(pop.results));
        setPopularPage(pop.page || 1);
        setGenres(filterCuratedGenres(genreList.genres || [], 'tv'));
      })
      .catch(() => setLoadError(true))
      .finally(() => setLoading(false));
  }, [reloadKey]);

  useEffect(() => {
    if (!selectedGenre) {
      setGenreResults([]);
      return;
    }
    setGenreLoading(true);
    tmdbFetch('discover/tv', {
      with_genres: selectedGenre,
      sort_by: 'popularity.desc',
      page: 1,
    })
      .then((data) => setGenreResults(withPoster(data.results).slice(0, 16)))
      .catch(() => setGenreResults([]))
      .finally(() => setGenreLoading(false));
  }, [selectedGenre]);

  const loadMorePopular = useCallback(() => {
    tmdbFetch('tv/popular', { page: popularPage + 1 })
      .then((data) => {
        setPopular((prev) => [...prev, ...withPoster(data.results)]);
        setPopularPage(data.page);
      })
      .catch(() => {});
  }, [popularPage]);

  const selectedGenreName = genres.find((g) => g.id === selectedGenre)?.name;

  return (
    <>
      <PageTitle title="Browse TV" />

      {loading ? (
        <div
          className="h-52 animate-pulse bg-surface sm:h-64 md:h-80"
          aria-busy="true"
          aria-label="Loading featured TV shows"
        />
      ) : (
        <HeroCarousel slides={hero} />
      )}

      <div className="mx-auto max-w-content space-y-10 px-4 py-8 sm:px-6 md:space-y-12 md:py-10">
        {loadError && (
          <div className="state-enter rounded-xl border border-danger/30 bg-danger/10 p-3 text-sm text-danger">
            Couldn&apos;t reach the TV catalog.{' '}
            <button
              type="button"
              onClick={() => setReloadKey((key) => key + 1)}
              className="focus-ring font-semibold underline"
            >
              Try again
            </button>
          </div>
        )}
        <header>
          <p className="section-title">Series</p>
          <h1 className="page-title mt-1">TV shows</h1>
          <p className="mt-2 max-w-lg text-sm text-muted">
            Trending series, what&apos;s on the air tonight, and the ones people can&apos;t stop talking about.
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
                  <div key={i} className="h-[132px] w-[88px] shrink-0 animate-pulse rounded-xl bg-surface-raised sm:w-[100px]" />
                ))}
              </div>
            ) : genreResults.length > 0 ? (
              <div className="poster-rail">
                <MediaPosterTiles items={genreResults} basePath="/tv" titleKey="name" />
              </div>
            ) : (
              <p className="text-sm text-muted">No shows found for this genre.</p>
            )}
          </section>
        )}

        <PosterRail title="Trending today">
          <MediaPosterTiles items={trendingToday} basePath="/tv" titleKey="name" />
        </PosterRail>

        {onTheAir.length > 0 && (
          <PosterRail title="On the air">
            <MediaPosterTiles items={onTheAir} basePath="/tv" titleKey="name" />
          </PosterRail>
        )}

        {airingToday.length > 0 && (
          <PosterRail title="Airing today">
            <MediaPosterTiles items={airingToday} basePath="/tv" titleKey="name" />
          </PosterRail>
        )}

        <PosterRail title="Top rated">
          <MediaPosterTiles items={topRated} basePath="/tv" titleKey="name" />
        </PosterRail>

        <section className="space-y-4 border-t border-border pt-8">
          <div>
            <h2 className="section-title">All popular</h2>
            <p className="mt-1 text-sm text-muted">The full catalog — load more as you scroll.</p>
          </div>
          <div className="poster-grid">
            {popular.map((show, index) => (
              <div
                key={show.id}
                className="animate-fade-up opacity-0"
                style={{ animationDelay: `${Math.min(index * 40, 400)}ms` }}
              >
                <TvGridCard
                  image={show.poster_path ? `${IMAGE_URL}w342${show.poster_path}` : ''}
                  tvShowId={show.id}
                  tvShowTitle={show.name}
                />
              </div>
            ))}
          </div>
          <div className="text-center">
            <button type="button" className="btn-secondary" onClick={loadMorePopular}>
              Load more
            </button>
          </div>
        </section>
      </div>
    </>
  );
}
