import { useCallback, useEffect, useState } from 'react';
import { Link, useParams, useSearchParams } from 'react-router-dom';
import { Star } from 'lucide-react';
import { IMAGE_URL } from '../../config/keys';
import { tmdbFetch } from '../../utils/tmdb';
import { fetchTvShowDiary } from '../../api/tvShowDiary';
import MainImageforDetail from './MainImageforDetail';
import SimilarTvShows from './SimilarTvShows';
import TvFavorites from './TvFavorites';
import TvTrackingBanner from './TvTrackingBanner';
import TvTrackingStatusAction from './TvTrackingStatusAction';
import TvDiarySkeleton from './TvDiarySkeleton';
import TvSeasonEpisodesPanel from './TvSeasonEpisodesPanel';
import PageTitle from '../../utils/PageTitle';
import DetailInfoGrid from '../ui/DetailInfoGrid';
import BackNav from '../ui/BackNav';
import DetailPageSkeleton from '../ui/DetailPageSkeleton';
import DetailPageError from '../ui/DetailPageError';
import PosterTile from '../ui/PosterTile';
import useCachedResource, { CACHE_KEYS, writeCache } from '../../utils/routeCache';
import { formatLanguage, formatShortDate, premiereFieldLabel } from '../../utils/statsFormat';
import { pickWatchProviders, tvCertification } from '../../utils/watchRegion';

const EMPTY_DETAIL = {
  tvShow: {},
  createdBy: [],
  genres: [],
  seasons: [],
  crews: [],
  watchProviders: [],
  watchRegion: null,
  certification: null,
};

async function fetchTvDetailBundle(tvShowId, signal) {
  const showData = await tmdbFetch(`tv/${tvShowId}`, {}, { signal });
  if (!showData || !showData.id) throw new Error('not_found');

  const [creditsData, providersData, ratingsData] = await Promise.all([
    tmdbFetch(`tv/${tvShowId}/credits`, {}, { signal }).catch(() => ({ cast: [], crew: [] })),
    tmdbFetch(`tv/${tvShowId}/watch/providers`, {}, { signal }).catch(() => null),
    tmdbFetch(`tv/${tvShowId}/content_ratings`, {}, { signal }).catch(() => null),
  ]);

  const { providers = [], region = null } = providersData
    ? pickWatchProviders(providersData.results)
    : {};

  return {
    tvShow: showData,
    createdBy: showData.created_by || [],
    genres: showData.genres || [],
    seasons: showData.seasons || [],
    crews: creditsData.cast || [],
    watchProviders: providers,
    watchRegion: region,
    certification: ratingsData ? tvCertification(ratingsData) : null,
  };
}

export default function TvDetail() {
  const { Id: tvShowId } = useParams();
  const [searchParams] = useSearchParams();
  const initialSeason = searchParams.get('season')
    ? Number(searchParams.get('season'))
    : undefined;

  const {
    data,
    loading,
    error,
    fromCache,
    refresh,
  } = useCachedResource(
    tvShowId ? CACHE_KEYS.tvDetail(tvShowId) : null,
    (signal) => fetchTvDetailBundle(tvShowId, signal),
    { ttl: 24 * 60 * 60_000, enabled: Boolean(tvShowId) }
  );

  const { tvShow, createdBy, genres, seasons, crews, watchProviders, watchRegion, certification } =
    data || EMPTY_DETAIL;

  // Diary (favorite / watchlist / tracking) IS user-specific, so cache
  // separately with a short TTL and expose write access so mutations can
  // keep the cache honest without a round-trip.
  const diaryKey = tvShowId ? `tv:diary:${tvShowId}` : null;
  const { data: diary, refresh: refreshDiary } = useCachedResource(
    diaryKey,
    () => fetchTvShowDiary(tvShowId),
    { ttl: 15_000, enabled: Boolean(tvShowId) }
  );

  const patchDiary = useCallback(
    (patch) => {
      if (!diaryKey) return;
      const current = diary || null;
      if (!current) return;
      writeCache(diaryKey, { ...current, ...patch });
    },
    [diary, diaryKey]
  );

  const handleProgressChange = useCallback(
    (payload) => {
      if (!payload || !('tracking' in payload) || !diaryKey) return;
      const current = diary;
      if (!current) {
        refreshDiary().catch(() => {});
        return;
      }
      writeCache(diaryKey, {
        ...current,
        tracking: payload.tracking ?? null,
        watchlisted: payload.tracking ? false : current.watchlisted,
      });
    },
    [diary, diaryKey, refreshDiary]
  );

  const [actorToggle, setActorToggle] = useState(false);

  useEffect(() => {
    if (initialSeason && tvShow.name) {
      document.getElementById('episodes')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }, [initialSeason, tvShow.name]);

  const infoItems = [
    [
      premiereFieldLabel(tvShow.first_air_date),
      tvShow.first_air_date && formatShortDate(tvShow.first_air_date),
    ],
    ['Created by', createdBy.map((c) => c.name).join(', ')],
    ['Genre', genres.map((g) => g.name).join(', ')],
    [
      'Seasons',
      tvShow.number_of_seasons
        ? `${tvShow.number_of_seasons} season${tvShow.number_of_seasons !== 1 ? 's' : ''}${
            tvShow.number_of_episodes ? ` · ${tvShow.number_of_episodes} eps` : ''
          }`
        : null,
    ],
    ['Language', formatLanguage(tvShow.original_language)],
    ['Certification', certification],
  ];

  if (loading && !fromCache && !data) {
    return (
      <>
        <PageTitle title="Loading…" />
        <DetailPageSkeleton fallback="/tv" backLabel="Back to TV" />
      </>
    );
  }

  if (error && !data) {
    return (
      <>
        <PageTitle title="TV Show" />
        <DetailPageError
          fallback="/tv"
          backLabel="Back to TV"
          message="Couldn't load this show. Check your connection and try again."
          onRetry={() => refresh().catch(() => {})}
        />
      </>
    );
  }

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
        <BackNav fallback="/tv" label="Back to TV" className="mb-4 md:hidden" />

        {tvShow.poster_path && (
          <div className="mb-4 flex gap-3 md:hidden">
            <img
              src={`${IMAGE_URL}w342${tvShow.poster_path}`}
              alt=""
              className="h-28 w-[4.5rem] shrink-0 rounded-xl object-cover shadow-poster"
            />
            <div className="flex min-w-0 flex-col justify-center">
              <p className="line-clamp-2 font-serif text-lg font-semibold text-ink-bright">
                {tvShow.name}
              </p>
              <div className="mt-2 flex items-center gap-1.5 text-sm">
                <Star className="h-4 w-4 fill-accent text-accent" />
                <span className="font-bold text-accent">{tvShow.vote_average?.toFixed(1)}</span>
                <span className="text-muted">/ 10</span>
              </div>
              {tvShow.first_air_date && (
                <p className="mt-1 text-xs text-muted">{formatShortDate(tvShow.first_air_date)}</p>
              )}
            </div>
          </div>
        )}

        <nav aria-label="Breadcrumb" className="mb-4 hidden text-xs text-muted md:mb-6 md:block">
          <Link to="/" className="hover:text-ink-bright cursor-pointer">
            Home
          </Link>
          <span className="mx-1.5">/</span>
          <Link to="/tv" className="hover:text-ink-bright cursor-pointer">
            TV
          </Link>
          <span className="mx-1.5">/</span>
          <span className="text-ink">{tvShow.original_name}</span>
        </nav>

        {tvShow.name && (
          <section className="mb-5 md:mb-8">
            {!diary ? (
              <TvDiarySkeleton />
            ) : (
              <>
                <TvTrackingStatusAction
                  tvId={tvShowId}
                  track={diary.tracking}
                  onStatusChange={handleProgressChange}
                  className="mb-1"
                />
                <TvTrackingBanner tvId={tvShowId} track={diary.tracking} />
                <h2 className="section-title mb-3 md:hidden">Your diary</h2>
                <TvFavorites
                  tvId={tvShowId}
                  tvInfo={tvShow}
                  diary={diary}
                  onDiaryPatch={patchDiary}
                />
              </>
            )}
          </section>
        )}

        <div className="grid gap-6 md:grid-cols-12 md:gap-8">
          <div className="hidden md:col-span-3 md:block">
            {tvShow.poster_path && (
              <div className="glass-card overflow-hidden">
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
              providersRegion={watchRegion}
              imageUrlPrefix={`${IMAGE_URL}w92`}
            />
          </div>
        </div>

        <div className="mt-6 text-center md:mt-8">
          <button
            type="button"
            onClick={() => setActorToggle(!actorToggle)}
            className="btn-secondary w-full sm:w-auto"
            aria-expanded={actorToggle}
            aria-controls="tv-cast-panel"
          >
            {actorToggle ? 'Hide cast' : 'Show cast'}
          </button>
        </div>

        <div
          id="tv-cast-panel"
          className="collapsible-grid"
          style={{ gridTemplateRows: actorToggle ? '1fr' : '0fr' }}
          aria-hidden={!actorToggle}
        >
          <div className="min-h-0 overflow-hidden">
            <div className="mt-6">
              <h3 className="section-title mb-3">Cast</h3>
              <div className="poster-rail">
                {crews
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

        {tvShow.name && (
          <TvSeasonEpisodesPanel
            tvShowId={tvShowId}
            tvShow={tvShow}
            seasons={seasons}
            initialSeason={initialSeason}
            onProgressChange={handleProgressChange}
          />
        )}

        <SimilarTvShows showId={tvShowId} />
      </div>
    </>
  );
}
