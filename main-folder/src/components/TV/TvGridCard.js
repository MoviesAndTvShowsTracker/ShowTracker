import PosterTile from '../ui/PosterTile';

export default function TvGridCard({ tvShowId, tvShowTitle, image }) {
  return (
    <PosterTile
      to={`/tv/${tvShowId}`}
      poster={image}
      title={tvShowTitle}
      size="fill"
      showTitle={true}
    />
  );
}
