import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { Star } from 'lucide-react';
import { API_KEY, API_URL, IMAGE_URL } from '../../config/keys';
import PageTitle from '../../utils/PageTitle';

export default function SeasonEpisodes() {
  const { Id: tvShowId, seasonNumber } = useParams();
  const seasonNum = parseInt(seasonNumber, 10);
  const [season, setSeason] = useState({});
  const [episodes, setEpisodes] = useState([]);
  const [tvShow, setTvShow] = useState({});

  useEffect(() => {
    fetch(`${API_URL}tv/${tvShowId}/season/${seasonNum}?api_key=${API_KEY}&language=en-US`)
      .then((response) => response.json())
      .then((response) => {
        setSeason(response);
        setEpisodes(response.episodes || []);
      });

    fetch(`${API_URL}tv/${tvShowId}?api_key=${API_KEY}&language=en-US`)
      .then((response) => response.json())
      .then((response) => setTvShow(response));

    window.scrollTo(0, 0);
  }, [tvShowId, seasonNum]);

  const airdate = (prop) =>
    new Date(prop).toLocaleDateString('en-US', { day: 'numeric', month: 'short', year: 'numeric' });

  return (
    <>
      <PageTitle
        title={tvShow.name ? `Episodes S${season.season_number} — ${tvShow.name}` : 'TV Shows'}
      />

      <div className="mx-auto max-w-content px-4 py-5 sm:px-6 md:py-8">
        <nav aria-label="Breadcrumb" className="mb-4 hidden text-xs text-muted md:mb-6 md:block">
          <Link to="/" className="hover:text-ink-bright cursor-pointer">Home</Link>
          <span className="mx-1.5">/</span>
          <Link to="/tv" className="hover:text-ink-bright cursor-pointer">TV</Link>
          <span className="mx-1.5">/</span>
          <Link to={`/tv/${tvShow.id}`} className="hover:text-ink-bright cursor-pointer">
            {tvShow.name}
          </Link>
          <span className="mx-1.5">/</span>
          <span className="text-ink">{season.name}</span>
        </nav>

        <div className="mb-6 flex gap-3 md:mb-8 md:gap-4">
          {season.poster_path && (
            <img
              className="h-28 w-[4.5rem] shrink-0 rounded-[3px] object-cover shadow-poster md:h-48 md:w-32"
              src={`${IMAGE_URL}w500${season.poster_path}`}
              alt={season.name}
            />
          )}
          <div className="min-w-0">
            <h1 className="page-title line-clamp-2">{tvShow.name}</h1>
            <p className="mt-1 text-sm text-muted">{season.name}</p>
            <p className="text-xs text-muted">{episodes.length} episodes</p>
          </div>
        </div>

        <div className="space-y-3 md:space-y-4">
          {episodes.map((episode) => (
            <article key={episode.id} className="overflow-hidden rounded-sm border border-border bg-surface">
              <div className="border-b border-border px-4 py-3 md:px-5 md:py-4">
                <h2 className="text-sm font-semibold leading-snug md:text-base">
                  <span className="text-accent">{episode.episode_number}.</span> {episode.name}
                </h2>
                <p className="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-muted md:text-sm">
                  {episode.air_date ? airdate(episode.air_date) : '—'}
                  {episode.vote_average > 0 && (
                    <span className="inline-flex items-center gap-1">
                      <Star className="h-3 w-3 fill-accent text-accent" />
                      {Number(episode.vote_average).toFixed(1)}/10
                    </span>
                  )}
                </p>
              </div>
              <div className="p-4 md:p-5">
                <p className="line-clamp-4 text-sm text-muted md:line-clamp-none">
                  {episode.overview || 'No information available.'}
                </p>
                {episode.crew?.length > 0 && (
                  <div className="mt-3 grid grid-cols-2 gap-2 text-xs md:mt-4 md:block md:space-y-1 md:text-sm">
                    <p>
                      <span className="font-semibold text-accent">Director</span>
                      <br />
                      <span className="text-muted">
                        {episode.crew
                          .filter((v) => v.job === 'Director')
                          .map((v) => v.name)
                          .join(', ') || '—'}
                      </span>
                    </p>
                    <p>
                      <span className="font-semibold text-accent">Writer</span>
                      <br />
                      <span className="text-muted">
                        {episode.crew
                          .filter((v) => v.department === 'Writing')
                          .map((v) => v.name)
                          .join(', ') || '—'}
                      </span>
                    </p>
                  </div>
                )}
              </div>
            </article>
          ))}
        </div>
      </div>
    </>
  );
}
