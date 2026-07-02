import { useCallback, useEffect, useState } from 'react';
import { API_KEY, API_URL, IMAGE_URL } from '../../config/keys';
import GridCard from './GridCard';
import PageTitle from '../../utils/PageTitle';
import HeroCarousel from '../ui/HeroCarousel';
import PosterRail from '../ui/PosterRail';
import GenreChips, { filterCuratedGenres } from '../ui/GenreChips';
import MediaPosterTiles from '../browse/MediaPosterTiles';
import { heroSlides, tmdbFetch, withPoster } from '../../utils/tmdb';

export default function LandingPage() {
  const [loading, setLoading] = useState(true);
  const [hero, setHero] = useState([]);
  const [trendingToday, setTrendingToday] = useState([]);
  const [nowPlaying, setNowPlaying] = useState([]);
  const [upcoming, setUpcoming] = useState([]);
  const [topRated, setTopRated] = useState([]);
  const [popular, setPopular] = useState([]);
  const [popularPage, setPopularPage] = useState(1);
  const [genres, setGenres] = useState([]);
  const [selectedGenre, setSelectedGenre] = useState(null);
  const [genreResults, setGenreResults] = useState([]);
  const [genreLoading, setGenreLoading] = useState(false);

  useEffect(() => {
    Promise.all([
      tmdbFetch('trending/movie/week'),
      tmdbFetch('trending/movie/day'),
      tmdbFetch('movie/now_playing', { region: 'IN', page: 1 }),
      tmdbFetch('movie/upcoming', { region: 'IN', page: 1 }),
      tmdbFetch('movie/top_rated', { page: 1 }),
      tmdbFetch('movie/popular', { page: 1 }),
      tmdbFetch('genre/movie/list'),
    ])
      .then(([trendingWeek, trendingDay, inTheaters, comingSoon, rated, pop, genreList]) => {
        const slides = heroSlides(trendingWeek.results, '/movies', 'title').map((s, i) =>
          i === 0 ? { ...s, badge: 'Trending this week' } : s
        );
        setHero(slides);
        setTrendingToday(withPoster(trendingDay.results).slice(0, 16));
        setNowPlaying(withPoster(inTheaters.results).slice(0, 16));
        setUpcoming(withPoster(comingSoon.results).slice(0, 16));
        setTopRated(withPoster(rated.results).slice(0, 16));
        setPopular(withPoster(pop.results));
        setPopularPage(pop.page || 1);
        setGenres(filterCuratedGenres(genreList.genres || [], 'movie'));
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    if (!selectedGenre) {
      setGenreResults([]);
      return;
    }
    setGenreLoading(true);
    tmdbFetch('discover/movie', {
      with_genres: selectedGenre,
      sort_by: 'popularity.desc',
      page: 1,
      region: 'IN',
    })
      .then((data) => setGenreResults(withPoster(data.results).slice(0, 16)))
      .catch(() => setGenreResults([]))
      .finally(() => setGenreLoading(false));
  }, [selectedGenre]);

  const loadMorePopular = useCallback(() => {
    fetch(`${API_URL}movie/popular?api_key=${API_KEY}&language=en-US&page=${popularPage + 1}`)
      .then((r) => r.json())
      .then((data) => {
        setPopular((prev) => [...prev, ...withPoster(data.results)]);
        setPopularPage(data.page);
      });
  }, [popularPage]);

  const selectedGenreName = genres.find((g) => g.id === selectedGenre)?.name;

  return (
    <>
      <PageTitle title="Browse films" />

      {loading ? (
        <div className="h-52 animate-pulse bg-surface sm:h-64 md:h-80" />
      ) : (
        <HeroCarousel slides={hero} />
      )}

      <div className="mx-auto max-w-content space-y-10 px-4 py-8 sm:px-6 md:space-y-12 md:py-10">
        <header>
          <p className="section-title">Discover</p>
          <h1 className="page-title mt-1">Films</h1>
          <p className="mt-2 max-w-lg text-sm text-muted">
            What&apos;s trending, in theaters near you, coming soon, and the highest rated — explore by genre.
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
              <div className="poster-rail -mx-4 px-4 sm:-mx-0 sm:px-0">
                {Array.from({ length: 6 }).map((_, i) => (
                  <div key={i} className="h-[132px] w-[88px] shrink-0 animate-pulse rounded-[3px] bg-surface-raised sm:w-[100px]" />
                ))}
              </div>
            ) : genreResults.length > 0 ? (
              <div className="poster-rail -mx-4 px-4 sm:-mx-0 sm:px-0">
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
            {popular.map((movie) => (
              <GridCard
                key={movie.id}
                image={movie.poster_path ? `${IMAGE_URL}w342${movie.poster_path}` : ''}
                movieId={movie.id}
                movieTitle={movie.title}
              />
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
