import { Navigate, useParams } from 'react-router-dom';

/** Legacy route — redirects to show detail with season pre-selected. */
export default function SeasonEpisodes() {
  const { Id: tvShowId, seasonNumber } = useParams();
  return <Navigate to={`/tv/${tvShowId}?season=${seasonNumber}`} replace />;
}
