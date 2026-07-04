import { useCallback, useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { Star } from 'lucide-react';
import { API_URL, API_KEY, IMAGE_URL } from '../../config/keys';
import Favorite from './Favorite';
import MainImageforDetail from './MainImageforDetail';
import SimilarMoviesData from './ShowSimilarMovies';
import PageTitle from '../../utils/PageTitle';
import DetailInfoGrid from '../ui/DetailInfoGrid';
import BackNav from '../ui/BackNav';
import DetailPageSkeleton from '../ui/DetailPageSkeleton';
import DetailPageError from '../ui/DetailPageError';

export default function MovieDetail() {
  const { Id: movieId } = useParams();
  const [movie, setMovie] = useState({});
  const [actors, setActors] = useState([]);
  const [crews, setCrews] = useState([]);
  const [watchProviders, setWatchProviders] = useState([]);
  const [genres, setGenres] = useState([]);
  const [actorToggle, setActorToggle] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [reloadKey, setReloadKey] = useState(0);

  const loadMovie = useCallback(async (signal) => {
    setLoading(true);
    setError('');
    setMovie({});
    setActors([]);
    setCrews([]);
    setGenres([]);
    setWatchProviders([]);

    try {
      const movieRes = await fetch(
        `${API_URL}movie/${movieId}?api_key=${API_KEY}&language=en-US`,
        { signal }
      );
      const movieData = await movieRes.json();

      if (!movieRes.ok || movieData.success === false || !movieData.id) {
        throw new Error('not_found');
      }

      setMovie(movieData);
      setGenres(movieData.genres || []);

      const creditsRes = await fetch(`${API_URL}movie/${movieId}/credits?api_key=${API_KEY}`, {
        signal,
      });
      const creditsData = await creditsRes.json();
      setActors(creditsData.cast || []);
      setCrews(creditsData.crew || []);

      fetch(`${API_URL}movie/${movieId}/watch/providers?api_key=${API_KEY}`, { signal })
        .then((r) => r.json())
        .then((response) => {
          const india = response.results?.IN;
          if (india) setWatchProviders(india.flatrate || india.buy || india.rent || []);
        })
        .catch(() => {});
    } catch (err) {
      if (err.name === 'AbortError') return;
      setError("Couldn't load this film. Check your connection and try again.");
    } finally {
      if (!signal.aborted) setLoading(false);
    }
  }, [movieId]);

  useEffect(() => {
    const controller = new AbortController();
    loadMovie(controller.signal);
    window.scrollTo(0, 0);
    return () => controller.abort();
  }, [loadMovie, reloadKey]);

  const convertToReadable = (n) => {
    const v = Math.abs(Number(n));
    if (v >= 1e9) return `${(v / 1e9).toFixed(1)}B`;
    if (v >= 1e6) return `${(v / 1e6).toFixed(1)}M`;
    if (v >= 1e3) return `${(v / 1e3).toFixed(1)}K`;
    return v;
  };

  const timeConvert = (num) => {
    const h = Math.floor(num / 60);
    const m = num % 60;
    return `${h}h ${m}m`;
  };

  const airdate = (prop) =>
    new Date(prop).toLocaleDateString('en-US', { month: 'short', year: 'numeric' });

  const infoItems = [
    ['Title', movie.title],
    ['Released', movie.release_date && airdate(movie.release_date)],
    ['Director', crews.filter((v) => v.job === 'Director').map((v) => v.name).join(', ')],
    ['Genre', genres.map((g) => g.name).join(', ')],
    ['Runtime', movie.runtime ? timeConvert(movie.runtime) : null],
    ['Revenue', movie.revenue ? `$${convertToReadable(movie.revenue)}` : null],
  ];

  if (loading) {
    return (
      <>
        <PageTitle title="Loading…" />
        <DetailPageSkeleton fallback="/movies" backLabel="Back to films" />
      </>
    );
  }

  if (error) {
    return (
      <>
        <PageTitle title="Film" />
        <DetailPageError
          fallback="/movies"
          backLabel="Back to films"
          message={error}
          onRetry={() => setReloadKey((k) => k + 1)}
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
              <p className="line-clamp-2 font-serif text-lg font-semibold text-ink-bright">{movie.title}</p>
              <div className="mt-2 flex items-center gap-1.5 text-sm">
                <Star className="h-4 w-4 fill-accent text-accent" />
                <span className="font-bold text-accent">{movie.vote_average?.toFixed(1)}</span>
                <span className="text-muted">/ 10</span>
              </div>
              {movie.release_date && (
                <p className="mt-1 text-xs text-muted">{airdate(movie.release_date)}</p>
              )}
            </div>
          </div>
        )}

        <nav aria-label="Breadcrumb" className="mb-4 hidden text-xs text-muted md:mb-6 md:block">
          <Link to="/" className="hover:text-ink-bright cursor-pointer">Home</Link>
          <span className="mx-1.5">/</span>
          <Link to="/movies" className="hover:text-ink-bright cursor-pointer">Films</Link>
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
              imageUrlPrefix={`${IMAGE_URL}w500`}
            />
          </div>
        </div>

        <div className="mt-6 text-center md:mt-8">
          <button type="button" onClick={() => setActorToggle(!actorToggle)} className="btn-secondary w-full sm:w-auto">
            {actorToggle ? 'Hide cast' : 'Show cast'}
          </button>
        </div>

        {actorToggle && (
          <div className="mt-6">
            <h3 className="section-title mb-3">Cast</h3>
            <div className="poster-rail">
              {actors.map(
                (crew) =>
                  crew.profile_path && (
                    <article key={crew.id} className="w-[88px] shrink-0 sm:w-[100px]">
                      <img
                        className="aspect-[2/3] w-full rounded-xl object-cover"
                        alt={crew.name}
                        src={`${IMAGE_URL}original${crew.profile_path}`}
                        loading="lazy"
                      />
                      <p className="mt-1.5 line-clamp-1 text-xs font-medium">{crew.name}</p>
                      <p className="line-clamp-1 text-[10px] text-muted">as {crew.character}</p>
                    </article>
                  )
              )}
            </div>
          </div>
        )}

        <SimilarMoviesData movieId={movieId} />
      </div>
    </>
  );
}
