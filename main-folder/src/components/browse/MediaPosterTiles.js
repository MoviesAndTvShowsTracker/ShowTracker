import PosterTile from '../ui/PosterTile';
import { IMAGE_URL } from '../../utils/tmdb';

export default function MediaPosterTiles({ items, basePath, titleKey = 'title' }) {
  return items
    .filter((item) => item.poster_path)
    .map((item) => (
      <PosterTile
        key={item.id}
        to={`${basePath}/${item.id}`}
        poster={item.poster_path}
        title={item[titleKey]}
        imageUrlPrefix={`${IMAGE_URL}w342`}
      />
    ));
}
