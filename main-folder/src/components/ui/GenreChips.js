const CURATED_MOVIE_GENRES = [28, 12, 16, 35, 80, 99, 18, 14, 27, 9648, 10749, 878, 53];
const CURATED_TV_GENRES = [10759, 16, 35, 80, 99, 18, 10751, 9648, 10765, 10768, 37];

export function filterCuratedGenres(genres, type = 'movie') {
  const ids = type === 'movie' ? CURATED_MOVIE_GENRES : CURATED_TV_GENRES;
  const byId = new Map(genres.map((g) => [g.id, g]));
  return ids.map((id) => byId.get(id)).filter(Boolean);
}

export default function GenreChips({ genres, selectedId, onSelect, label = 'Browse by genre' }) {
  if (!genres?.length) return null;

  return (
    <section className="space-y-3">
      <h2 className="section-title">{label}</h2>
      <div className="poster-rail">
        <button
          type="button"
          onClick={() => onSelect(null)}
          className={`shrink-0 rounded-full border px-3.5 py-2 text-xs font-bold uppercase tracking-wide transition-colors cursor-pointer ${
            selectedId == null
              ? 'border-accent bg-accent/15 text-accent'
              : 'border-border bg-surface text-muted hover:border-muted hover:text-ink'
          }`}
        >
          All
        </button>
        {genres.map((genre) => (
          <button
            key={genre.id}
            type="button"
            onClick={() => onSelect(genre.id)}
            className={`shrink-0 rounded-full border px-3.5 py-2 text-xs font-bold uppercase tracking-wide transition-colors cursor-pointer ${
              selectedId === genre.id
                ? 'border-accent bg-accent/15 text-accent'
                : 'border-border bg-surface text-muted hover:border-muted hover:text-ink'
            }`}
          >
            {genre.name}
          </button>
        ))}
      </div>
    </section>
  );
}
