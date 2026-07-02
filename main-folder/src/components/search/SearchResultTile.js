import { Link } from 'react-router-dom';
import { Film, Star, Tv } from 'lucide-react';
import { IMAGE_URL } from '../../config/keys';

function yearFrom(item, mediaType) {
  const date = mediaType === 'tv' ? item.first_air_date : item.release_date || item.first_air_date;
  return date ? date.slice(0, 4) : null;
}

export default function SearchResultTile({ item, mediaType }) {
  const type = mediaType || item.media_type;
  const isTv = type === 'tv';
  const title = isTv ? item.name : item.title;
  const to = isTv ? `/tv/${item.id}` : `/movies/${item.id}`;
  const year = yearFrom(item, type);
  const rating = item.vote_average > 0 ? Number(item.vote_average).toFixed(1) : null;

  if (!item.poster_path) return null;

  return (
    <article className="group">
      <Link to={to} className="block cursor-pointer">
        <div className="relative overflow-hidden rounded-xl bg-surface-raised shadow-poster transition-all duration-300 hover:-translate-y-0.5 hover:shadow-poster-hover">
          <img
            src={`${IMAGE_URL}w342${item.poster_path}`}
            alt=""
            className="aspect-[2/3] w-full object-cover"
            loading="lazy"
          />
          {type === 'multi' && (
            <span className="absolute left-1.5 top-1.5 inline-flex items-center gap-0.5 rounded-md bg-canvas/90 px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wide text-ink-bright backdrop-blur-sm">
              {isTv ? <Tv className="h-2.5 w-2.5" /> : <Film className="h-2.5 w-2.5" />}
              {isTv ? 'TV' : 'Film'}
            </span>
          )}
          {rating && (
            <span className="absolute bottom-1.5 right-1.5 inline-flex items-center gap-0.5 rounded-md bg-canvas/90 px-1.5 py-0.5 text-[10px] font-semibold text-ink-bright backdrop-blur-sm">
              <Star className="h-2.5 w-2.5 fill-accent text-accent" />
              {rating}
            </span>
          )}
        </div>
        <p className="mt-1.5 line-clamp-2 text-[11px] font-medium leading-snug text-ink sm:text-xs">
          {title}
        </p>
        {year && <p className="text-[10px] text-muted">{year}</p>}
      </Link>
    </article>
  );
}
