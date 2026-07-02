import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { Star } from 'lucide-react';
import { API_KEY, API_URL, IMAGE_URL } from '../../config/keys';
import MainImageforDetail from './MainImageforDetail';
import SimilarTvShows from './SimilarTvShows';
import TvFavorites from './TvFavorites';
import PageTitle from '../../utils/PageTitle';
import DetailInfoGrid from '../ui/DetailInfoGrid';

export default function TvDetail() {
  const { Id: tvShowId } = useParams();
  const [tvShow, setTvShow] = useState({});
  const [createdBy, setCreatedBy] = useState([]);
  const [genres, setGenres] = useState([]);
  const [seasons, setSeasons] = useState([]);
  const [crews, setCrews] = useState([]);
  const [watchProviders, setWatchProviders] = useState([]);
  const [actorToggle, setActorToggle] = useState(false);

  useEffect(() => {
    fetch(`${API_URL}tv/${tvShowId}?api_key=${API_KEY}&language=en-US`)
      .then((response) => response.json())
      .then((response) => {
        setTvShow(response);
        setCreatedBy(response.created_by || []);
        setGenres(response.genres || []);
        setSeasons(response.seasons || []);
      });

    fetch(`${API_URL}tv/${tvShowId}/credits?api_key=${API_KEY}`)
      .then((response) => response.json())
      .then((response) => setCrews(response.cast || []));

    fetch(`${API_URL}tv/${tvShowId}/watch/providers?api_key=${API_KEY}`)
      .then((response) => response.json())
      .then((response) => {
        const india = response.results?.IN;
        if (india) {
          setWatchProviders(india.flatrate || india.buy || india.free || []);
        }
      })
      .catch(() => {});

    window.scrollTo(0, 0);
  }, [tvShowId]);

  const airdate = (prop) =>
    new Date(prop).toLocaleDateString('en-US', { month: 'short', year: 'numeric' });

  const infoItems = [
    ['Title', tvShow.name],
    ['Created by', createdBy.map((c) => c.name).join(', ')],
    ['Genre', genres.map((g) => g.name).join(', ')],
    ['First aired', tvShow.first_air_date && airdate(tvShow.first_air_date)],
    ['Seasons', tvShow.number_of_seasons],
    ['Status', tvShow.status],
  ];

  return (
    <>
      <PageTitle title={tvShow.name ? `TV Show — ${tvShow.name}` : 'TV Shows'} />

      {tvShow.backdrop_path && (
        <MainImageforDetail
          image={`${IMAGE_URL}w1280${tvShow.backdrop_path}`}
          title={tvShow.original_name}
          text={tvShow.overview}
        />
      )}

      <div className="mx-auto max-w-content px-4 py-5 sm:px-6 md:py-8">
        {tvShow.poster_path && (
          <div className="mb-4 flex gap-3 md:hidden">
            <img
              src={`${IMAGE_URL}w342${tvShow.poster_path}`}
              alt=""
              className="h-28 w-[4.5rem] shrink-0 rounded-[3px] object-cover shadow-poster"
            />
            <div className="flex min-w-0 flex-col justify-center">
              <p className="line-clamp-2 font-serif text-lg font-semibold text-ink-bright">{tvShow.name}</p>
              <div className="mt-2 flex items-center gap-1.5 text-sm">
                <Star className="h-4 w-4 fill-accent text-accent" />
                <span className="font-bold text-accent">{tvShow.vote_average?.toFixed(1)}</span>
                <span className="text-muted">/ 10</span>
              </div>
              {tvShow.first_air_date && (
                <p className="mt-1 text-xs text-muted">{airdate(tvShow.first_air_date)}</p>
              )}
            </div>
          </div>
        )}

        <nav aria-label="Breadcrumb" className="mb-4 hidden text-xs text-muted md:mb-6 md:block">
          <Link to="/" className="hover:text-ink-bright cursor-pointer">Home</Link>
          <span className="mx-1.5">/</span>
          <Link to="/tv" className="hover:text-ink-bright cursor-pointer">TV</Link>
          <span className="mx-1.5">/</span>
          <span className="text-ink">{tvShow.original_name}</span>
        </nav>

        {tvShow.name && (
          <section className="mb-5 md:mb-8">
            <h2 className="section-title mb-3 md:hidden">Your diary</h2>
            <TvFavorites tvId={tvShowId} tvInfo={tvShow} />
          </section>
        )}

        <div className="grid gap-6 md:grid-cols-12 md:gap-8">
          <div className="hidden md:col-span-3 md:block">
            {tvShow.poster_path && (
              <div className="overflow-hidden rounded-sm border border-border bg-surface">
                <img
                  src={`${IMAGE_URL}w500${tvShow.poster_path}`}
                  alt={`${tvShow.name} poster`}
                  className="w-full object-cover"
                />
                <div className="flex items-center gap-2 border-t border-border px-4 py-3 text-sm">
                  <Star className="h-4 w-4 text-accent" />
                  <span className="font-bold text-accent">{tvShow.vote_average}</span>
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
              imageUrlPrefix={`${IMAGE_URL}w92`}
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
            <div className="poster-rail -mx-4 px-4 sm:mx-0 sm:px-0">
              {crews.map(
                (crew) =>
                  crew.profile_path && (
                    <article key={crew.id} className="w-[88px] shrink-0 sm:w-[100px]">
                      <img
                        className="aspect-[2/3] w-full rounded-[3px] object-cover"
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

        <section className="mt-8 space-y-3 md:mt-10 md:space-y-4">
          <h3 className="section-title">Seasons</h3>
          {[...seasons].reverse().map(
            (season) =>
              season.poster_path && (
                <article key={season.id} className="overflow-hidden rounded-sm border border-border bg-surface">
                  <div className="border-b border-border px-4 py-3 md:px-5 md:py-4">
                    <Link
                      to={`/tv/${tvShowId}/${season.season_number}/episodes`}
                      className="font-semibold text-accent hover:underline cursor-pointer"
                    >
                      {season.name}
                    </Link>
                    <p className="mt-1 text-xs text-muted md:text-sm">
                      {season.air_date ? new Date(season.air_date).getFullYear() : '—'} · {season.episode_count} episodes
                    </p>
                  </div>
                  <div className="flex gap-3 p-4 md:gap-4 md:p-5">
                    <img
                      src={`${IMAGE_URL}w500${season.poster_path}`}
                      alt={season.name}
                      className="h-28 w-[4.5rem] shrink-0 rounded-[3px] object-cover md:h-40 md:w-28"
                    />
                    <p className="line-clamp-4 text-sm text-muted">
                      {season.overview || 'No information available.'}
                    </p>
                  </div>
                </article>
              )
          )}
        </section>

        <SimilarTvShows showId={tvShowId} />
      </div>
    </>
  );
}
