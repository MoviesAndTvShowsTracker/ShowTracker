import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { Star } from 'lucide-react';
import { IMAGE_URL } from '../../config/keys';
import { tmdbFetch } from '../../utils/tmdb';
import Favorite from './Favorite';
import MainImageforDetail from './MainImageforDetail';
import SimilarMoviesData from './ShowSimilarMovies';
import PageTitle from '../../utils/PageTitle';
import DetailInfoGrid from '../ui/DetailInfoGrid';
import BackNav from '../ui/BackNav';
import DetailPageSkeleton from '../ui/DetailPageSkeleton';
import DetailPageError from '../ui/DetailPageError';
import PosterTile from '../ui/PosterTile';
import useCachedResource, { CACHE_KEYS } from '../../utils/routeCache';
import { formatLanguage, formatShortDate, releaseFieldLabel } from '../../utils/statsFormat';
import { movieCertification, pickWatchProviders } from '../../utils/watchRegion';

const EMPTY_DETAIL = {
  movie: {},
  actors: [],
  crews: [],
  genres: [],
  watchProviders: [],
  watchRegion: null,
  certification: null,
};

/** Single bundle fetch so the detail page is one atomic cache entry. */
async function fetchMovieDetailBundle(movieId, signal) {
  const movieData = await tmdbFetch(`movie/${movieId}`, {}, { signal });
  if (!movieData || !movieData.id) throw new Error('not_found');

  const [creditsData, providersData, releaseDatesData] = await Promise.all([
    tmdbFetch(`movie/${movieId}/credits`, {}, { signal }).catch(() => ({ cast: [], crew: [] })),
    tmdbFetch(`movie/${movieId}/watch/providers`, {}, { signal }).catch(() => null),
    tmdbFetch(`movie/${movieId}/release_dates`, {}, { signal }).catch(() => null),
  ]);

  const { providers = [], region = null } = providersData
    ? pickWatchProviders(providersData.results)
    : {};

  return {
    movie: movieData,
    actors: creditsData.cast || [],
    crews: creditsData.crew || [],
    genres: movieData.genres || [],
    watchProviders: providers,
    watchRegion: region,
    certification: releaseDatesData ? movieCertification(releaseDatesData) : null,
  };
}

export default function MovieDetail() {
  const { Id: movieId } = useParams();
  const {
    data,
    loading,
    error,
    fromCache,
    refresh,
  } = useCachedResource(
    movieId ? CACHE_KEYS.movieDetail(movieId) : null,
    (signal) => fetchMovieDetailBundle(movieId, signal),
    // TMDB detail data is effectively immutable per id — stay fresh for 24h.
    { ttl: 24 * 60 * 60_000, enabled: Boolean(movieId) }
  );

  const [actorToggle, setActorToggle] = useState(false);

  const { movie, actors, crews, genres, watchProviders, watchRegion, certification } =
    data || EMPTY_DETAIL;

  const timeConvert = (num) => {
    const h = Math.floor(num / 60);
    const m = num % 60;
    return `${h}h ${m}m`;
  };

  const infoItems = [
    [
      releaseFieldLabel(movie.release_date),
      movie.release_date && formatShortDate(movie.release_date),
    ],
    ['Director', crews.filter((v) => v.job === 'Director').map((v) => v.name).join(', ')],
    ['Genre', genres.map((g) => g.name).join(', ')],
    ['Runtime', movie.runtime ? timeConvert(movie.runtime) : null],
    ['Language', formatLanguage(movie.original_language)],
    ['Certification', certification],
  ];

  // Only block with a skeleton on the very first fetch; cache hits show
  // real content immediately so Back-nav scroll restoration works.
  if (loading && !fromCache && !data) {
    return (
      <>
        <PageTitle title="Loading…" />
        <DetailPageSkeleton fallback="/movies" backLabel="Back to films" />
      </>
    );
  }

  if (error && !data) {
    return (
      <>
        <PageTitle title="Film" />
        <DetailPageError
          fallback="/movies"
          backLabel="Back to films"
          message="Couldn't load this film. Check your connection and try again."
          onRetry={() => refresh().catch(() => {})}
        />
      </>
    );
  }

  return (
    <>
      <PageTitle title={movie.title || 'Film'} />

      {movie.backdrop_path && (
        <MainImageforDetail
          image={`${IMAGE_URL}w1280${movie.backdrop_path}`}
          title={movie.title}
          text={movie.overview}
        />
      )}

      <div className="mx-auto max-w-content px-4 py-5 sm:px-6 md:py-8">
        <BackNav fallback="/movies" label="Back to films" className="mb-4 md:hidden" />

        {movie.poster_path && (
          <div className="mb-4 flex gap-3 md:hidden">
            <img
              src={`${IMAGE_URL}w342${movie.poster_path}`}
              alt=""
              className="h-28 w-[4.5rem] shrink-0 rounded-xl object-cover shadow-poster"
            />
            <div className="flex min-w-0 flex-col justify-center">
              <p className="line-clamp-2 font-serif text-lg font-semibold text-ink-bright">
                {movie.title}
              </p>
              <div className="mt-2 flex items-center gap-1.5 text-sm">
                <Star className="h-4 w-4 fill-accent text-accent" />
                <span className="font-bold text-accent">{movie.vote_average?.toFixed(1)}</span>
                <span className="text-muted">/ 10</span>
              </div>
              {movie.release_date && (
                <p className="mt-1 text-xs text-muted">{formatShortDate(movie.release_date)}</p>
              )}
            </div>
          </div>
        )}

        <nav aria-label="Breadcrumb" className="mb-4 hidden text-xs text-muted md:mb-6 md:block">
          <Link to="/" className="hover:text-ink-bright cursor-pointer">
            Home
          </Link>
          <span className="mx-1.5">/</span>
          <Link to="/movies" className="hover:text-ink-bright cursor-pointer">
            Films
          </Link>
          <span className="mx-1.5">/</span>
          <span className="text-ink">{movie.title}</span>
        </nav>

        {movie.title && (
          <section className="mb-5 md:mb-8">
            <h2 className="section-title mb-3 md:hidden">Your diary</h2>
            <Favorite movieId={movieId} movieInfo={movie} />
          </section>
        )}

        <div className="grid gap-6 md:grid-cols-12 md:gap-8">
          <div className="hidden md:col-span-3 md:block">
            {movie.poster_path && (
              <div className="glass-card overflow-hidden">
                <img src={`${IMAGE_URL}w500${movie.poster_path}`} alt="" className="w-full" />
                <div className="flex items-center gap-2 border-t border-border px-4 py-3 text-sm">
                  <Star className="h-4 w-4 text-accent" />
                  <span className="font-bold text-accent">{movie.vote_average}</span>
                  <span className="text-muted">/ 10</span>
                </div>
              </div>
            )}
          </div>

          <div className="md:col-span-9">
            <h2 className="section-title mb-3 hidden md:block">Details</h2>
            <DetailInfoGrid
              items={infoItems}
              providers={watchProviders}
              providersRegion={watchRegion}
              imageUrlPrefix={`${IMAGE_URL}w500`}
            />
          </div>
        </div>

        <div className="mt-6 text-center md:mt-8">
          <button
            type="button"
            onClick={() => setActorToggle(!actorToggle)}
            className="btn-secondary w-full sm:w-auto"
            aria-expanded={actorToggle}
            aria-controls="film-cast-panel"
          >
            {actorToggle ? 'Hide cast' : 'Show cast'}
          </button>
        </div>

        <div
          id="film-cast-panel"
          className="collapsible-grid"
          style={{ gridTemplateRows: actorToggle ? '1fr' : '0fr' }}
          aria-hidden={!actorToggle}
        >
          <div className="min-h-0 overflow-hidden">
            <div className="mt-6">
              <h3 className="section-title mb-3">Cast</h3>
              <div className="poster-rail">
                {actors
                  .filter((actor) => actor.profile_path)
                  .map((actor) => (
                    <PosterTile
                      key={actor.id}
                      poster={actor.profile_path}
                      title={actor.name}
                      subtitle={actor.character ? `as ${actor.character}` : undefined}
                      imageUrlPrefix={`${IMAGE_URL}w185`}
                      size="sm"
                    />
                  ))}
              </div>
            </div>
          </div>
        </div>

        <SimilarMoviesData movieId={movieId} />
      </div>
    </>
  );
}
