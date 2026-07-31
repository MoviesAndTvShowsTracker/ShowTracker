/** Keep one Watch row per movieId (prefer newest watchedAt / createdAt). */
function dedupeFilms(films) {
  const byId = new Map();
  for (const film of films) {
    const id = String(film.movieId);
    const prev = byId.get(id);
    if (!prev) {
      byId.set(id, film);
      continue;
    }
    const prevAt = new Date(prev.watchedAt || prev.updatedAt || prev.createdAt || 0).getTime();
    const nextAt = new Date(film.watchedAt || film.updatedAt || film.createdAt || 0).getTime();
    if (nextAt >= prevAt) byId.set(id, film);
  }
  return [...byId.values()];
}

module.exports = { dedupeFilms };
