import PosterTile from '../ui/PosterTile';

export default function GridCard({ movieId, movieTitle, image }) {
  return (
    <PosterTile
      to={`/movies/${movieId}`}
      poster={image}
      title={movieTitle}
      size="fill"
      showTitle={true}
    />
  );
}
