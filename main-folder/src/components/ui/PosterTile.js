import { Link } from 'react-router-dom';
import { X } from 'lucide-react';

const sizes = {
  sm: 'w-[88px] sm:w-[100px] md:w-[112px] lg:w-[128px]',
  md: 'w-[100px] sm:w-[112px] md:w-[128px] lg:w-[152px]',
  fill: 'w-full',
};

export default function PosterTile({
  to,
  poster,
  title,
  imageUrlPrefix = '',
  size = 'sm',
  showTitle = true,
  onRemove,
}) {
  const src = imageUrlPrefix ? `${imageUrlPrefix}${poster}` : poster;
  const widthClass = sizes[size] || sizes.sm;

  const posterImage = (
    <div className={`group relative shrink-0 overflow-hidden rounded-xl bg-surface-raised shadow-poster transition-all duration-300 ease-out hover:shadow-poster-hover hover:scale-[1.04] hover:-translate-y-0.5 ${widthClass}`}>
      <img
        src={src}
        alt={title || 'Poster'}
        className="aspect-[2/3] w-full object-cover"
        loading="lazy"
      />
      {onRemove && (
        <button
          type="button"
          onClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
            onRemove();
          }}
          aria-label={`Remove ${title}`}
          className="absolute right-1 top-1 rounded-full bg-canvas/80 p-1 text-ink-bright opacity-0 transition-opacity duration-200 group-hover:opacity-100 cursor-pointer"
        >
          <X className="h-3.5 w-3.5" />
        </button>
      )}
    </div>
  );

  const titleEl = showTitle && title && (
    <p className="mt-1.5 line-clamp-2 text-[11px] font-medium leading-snug text-ink sm:text-xs">{title}</p>
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
