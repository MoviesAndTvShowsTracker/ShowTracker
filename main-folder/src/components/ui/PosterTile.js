import { Link } from 'react-router-dom';
import { Star, X } from 'lucide-react';
import { ratingToStars } from './StarRating';

const sizes = {
  sm: 'w-[88px] sm:w-[100px] md:w-[112px] lg:w-[128px]',
  md: 'w-[100px] sm:w-[112px] md:w-[128px] lg:w-[152px]',
  fill: 'w-full',
};

export default function PosterTile({
  to,
  poster,
  title,
  subtitle,
  imageUrlPrefix = '',
  size = 'sm',
  showTitle = true,
  onRemove,
  rating = null,
}) {
  const src = imageUrlPrefix ? `${imageUrlPrefix}${poster}` : poster;
  const widthClass = sizes[size] || sizes.sm;
  const stars = ratingToStars(rating);

  const posterImage = (
    <div className={`group relative shrink-0 overflow-hidden rounded-xl bg-surface-raised shadow-poster transition-shadow duration-200 ease-out hover:shadow-poster-hover ${widthClass}`}>
      <img
        src={src}
        alt={title || 'Poster'}
        className="aspect-[2/3] w-full object-cover"
        loading="lazy"
      />
      {stars > 0 && (
        <span
          className="pointer-events-none absolute left-1 top-1 inline-flex items-center gap-0.5 rounded-md bg-canvas/90 px-1.5 py-0.5 text-[10px] font-semibold text-ink-bright shadow-sm backdrop-blur-sm"
          aria-label={`Rated ${stars} out of 5`}
        >
          <Star className="h-2.5 w-2.5 fill-accent text-accent" />
          {stars % 1 === 0 ? stars.toFixed(0) : stars.toFixed(1)}
        </span>
      )}
      {onRemove && (
        <button
          type="button"
          onClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
            onRemove();
          }}
          aria-label={`Remove ${title}`}
          className="pressable absolute right-1 top-1 hidden h-8 w-8 items-center justify-center rounded-full bg-canvas/80 p-1 text-ink-bright opacity-0 transition-opacity duration-200 group-hover:opacity-100 group-focus-within:opacity-100 md:flex cursor-pointer"
        >
          <X className="h-3.5 w-3.5" />
        </button>
      )}
    </div>
  );

  const titleEl = showTitle && title && (
    <>
      <p className="mt-1.5 line-clamp-2 text-[11px] font-medium leading-snug text-ink sm:text-xs">{title}</p>
      {subtitle && (
        <p className="mt-0.5 text-[10px] font-medium text-accent sm:text-[11px]">{subtitle}</p>
      )}
    </>
  );

  if (!to) {
    return (
      <article className={`shrink-0 ${widthClass}`}>
        {posterImage}
        {titleEl}
      </article>
    );
  }

  return (
    <article className={`shrink-0 ${widthClass}`}>
      <Link to={to} className="block cursor-pointer">
        {posterImage}
      </Link>
      {titleEl && <Link to={to} className="mt-1.5 block cursor-pointer">{titleEl}</Link>}
    </article>
  );
}
