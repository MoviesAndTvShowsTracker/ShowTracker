const Watch = require('../models/watch');
const TvEpisodeWatch = require('../models/tvEpisodeWatch');
const TvRewatchEpisode = require('../models/tvRewatchEpisode');
const TvShowTracking = require('../models/tvShowTracking');
const MovieWatchlist = require('../models/moviewatchlist');
const TvWatchlist = require('../models/tvwatchlist');
const Favorite = require('../models/favorite');
const FavoriteTv = require('../models/favoritefortv');

/** Ratings are stored out of 10 (older) or 5; exports always say out of 5. */
function stars(rating) {
  if (!(rating > 0)) return null;
  return rating > 5 ? rating / 2 : rating;
}

function day(date) {
  return date ? new Date(date).toISOString().slice(0, 10) : '';
}

/** One CSV cell: quoted when needed, and never a formula when a spreadsheet opens the file. */
function csvCell(value) {
  if (value === null || value === undefined) return '';
  let text = String(value);
  // Cells starting with these run as formulas in Excel, Numbers and Sheets (CSV injection).
  if (/^[=+\-@\t\r]/.test(text)) text = `'${text}`;
  return /[",\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

const CSV_COLUMNS = [
  { key: 'date', label: 'Date' },
  { key: 'type', label: 'Type' },
  { key: 'title', label: 'Title' },
  { key: 'episode', label: 'Episode' },
  { key: 'rating', label: 'Rating (out of 5)' },
  { key: 'rewatch', label: 'Rewatch' },
  { key: 'note', label: 'Note' },
  { key: 'tmdbId', label: 'TMDB ID' },
];

function toCsv(rows, columns = CSV_COLUMNS) {
  const header = columns.map((c) => csvCell(c.label)).join(',');
  const body = rows.map((row) => columns.map((c) => csvCell(row[c.key])).join(','));
  return [header, ...body].join('\r\n');
}

/** Every logged watch as one diary, newest first. */
function diaryRows({ films, episodes, rewatches, showTitles }) {
  const episodeRow = (e, rewatch) => ({
    at: e.watchedAt,
    date: day(e.watchedAt),
    type: 'episode',
    title: showTitles[e.tvId] || `TV ${e.tvId}`,
    episode: `S${e.seasonNumber}E${e.episodeNumber}${e.episodeName ? ` ${e.episodeName}` : ''}`,
    rating: stars(e.rating),
    rewatch: rewatch ? 'yes' : 'no',
    note: e.note || '',
    tmdbId: e.tvId,
  });
  return [
    ...films.map((f) => ({
      at: f.watchedAt,
      date: day(f.watchedAt),
      type: 'film',
      title: f.movieTitle || `Film ${f.movieId}`,
      episode: '',
      rating: stars(f.rating),
      rewatch: f.isRewatch ? 'yes' : 'no',
      note: f.note || '',
      tmdbId: f.movieId,
    })),
    ...episodes.map((e) => episodeRow(e, false)),
    ...rewatches.map((e) => episodeRow(e, true)),
  ].sort((a, b) => new Date(b.at || 0) - new Date(a.at || 0));
}

/** Everything the user has put into Marquee, for the export file. */
async function buildExport(userId) {
  const scope = { userFrom: userId };
  const [films, episodes, rewatches, shows, filmWatchlist, showWatchlist, favFilms, favShows] = await Promise.all([
    Watch.find(scope).lean(),
    TvEpisodeWatch.find(scope).lean(),
    TvRewatchEpisode.find(scope).lean(),
    TvShowTracking.find(scope).lean(),
    MovieWatchlist.find(scope).lean(),
    TvWatchlist.find(scope).lean(),
    Favorite.find(scope).lean(),
    FavoriteTv.find(scope).lean(),
  ]);
  const showTitles = Object.fromEntries(shows.map((s) => [String(s.tvId), s.tvTitle || null]));
  const rows = diaryRows({ films, episodes, rewatches, showTitles });
  return {
    rows,
    json: {
      exportedAt: new Date().toISOString(),
      app: 'Marquee',
      diary: rows.map(({ at, ...row }) => row),
      shows: shows.map((s) => ({
        tmdbId: s.tvId,
        title: s.tvTitle || null,
        status: s.status,
        episodesWatched: s.watchedEpisodeCount || 0,
        rating: stars(s.rating),
      })),
      watchlist: {
        films: filmWatchlist.map((w) => ({ tmdbId: w.movieId, title: w.movieTitle || null })),
        shows: showWatchlist.map((w) => ({ tmdbId: w.tvId, title: w.tvTitle || null })),
      },
      favorites: {
        films: favFilms.map((f) => ({ tmdbId: f.movieId, title: f.movieTitle || null })),
        shows: favShows.map((f) => ({ tmdbId: f.tvId, title: f.tvTitle || null })),
      },
    },
  };
}

module.exports = { buildExport, diaryRows, toCsv, csvCell, CSV_COLUMNS };
