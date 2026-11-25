const Watch = require('../models/watch');
const TvEpisodeWatch = require('../models/tvEpisodeWatch');
const TvShowTracking = require('../models/tvShowTracking');

const MAX_NOTES = 300;

/** Every logged film and episode that has a note, newest first. */
function notesFromRows({ films, episodes, shows }) {
  const filmNotes = films
    .filter((f) => f.note && f.note.trim())
    .map((f) => ({
      id: `film-${f._id}`,
      kind: 'film',
      mediaId: String(f.movieId),
      title: f.movieTitle || 'Film',
      posterPath: f.moviePosterImage || f.movieImage || null,
      subtitle: null,
      seasonNumber: null,
      episodeNumber: null,
      watchedAt: f.watchedAt,
      note: f.note,
      rating: f.rating ?? null,
    }));
  const episodeNotes = episodes
    .filter((e) => e.note && e.note.trim())
    .map((e) => {
      const show = shows[String(e.tvId)] || {};
      return {
        id: `episode-${e._id}`,
        kind: 'episode',
        mediaId: String(e.tvId),
        title: show.title || 'Show',
        posterPath: show.posterPath || null,
        subtitle: `S${e.seasonNumber} · E${e.episodeNumber}${e.episodeName ? `  ${e.episodeName}` : ''}`,
        seasonNumber: e.seasonNumber,
        episodeNumber: e.episodeNumber,
        watchedAt: e.watchedAt,
        note: e.note,
        rating: e.rating ?? null,
      };
    });
  return [...filmNotes, ...episodeNotes].sort((a, b) => new Date(b.watchedAt || 0) - new Date(a.watchedAt || 0));
}

/** Plain-text match on the note, title or episode line, ignoring case. */
function matchesQuery(entry, q) {
  const needle = String(q || '').trim().toLowerCase();
  if (!needle) return true;
  return [entry.note, entry.title, entry.subtitle].some((text) => String(text || '').toLowerCase().includes(needle));
}

async function buildNotes(userId, { q = '', limit = MAX_NOTES } = {}) {
  const hasNote = { userFrom: userId, note: { $nin: [null, ''] } };
  const [films, episodes, tracks] = await Promise.all([
    Watch.find(hasNote).select('movieId movieTitle moviePosterImage movieImage watchedAt note rating').lean(),
    TvEpisodeWatch.find(hasNote).select('tvId seasonNumber episodeNumber episodeName watchedAt note rating').lean(),
    TvShowTracking.find({ userFrom: userId }).select('tvId tvTitle tvPosterImage tvPost').lean(),
  ]);
  const shows = Object.fromEntries(tracks.map((t) => [String(t.tvId), { title: t.tvTitle, posterPath: t.tvPosterImage || t.tvPost || null }]));
  return notesFromRows({ films, episodes, shows })
    .filter((n) => matchesQuery(n, q))
    .slice(0, Math.min(Number(limit) || MAX_NOTES, MAX_NOTES));
}

module.exports = { buildNotes, notesFromRows, matchesQuery };
