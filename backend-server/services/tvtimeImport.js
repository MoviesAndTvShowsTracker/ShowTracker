const fs = require('fs');
const path = require('path');
const Watch = require('../models/watch');
const Favorite = require('../models/favorite');
const Watchlist = require('../models/moviewatchlist');
const FavoriteTv = require('../models/favoritefortv');
const TvWatchlist = require('../models/tvwatchlist');
const TvWatch = require('../models/tvwatch');
const TvEpisodeWatch = require('../models/tvEpisodeWatch');
const TvShowTracking = require('../models/tvShowTracking');
const { loadGdprData, TmdbMapper, buildEpisodeDocs, buildTrackingDoc } = require('../scripts/tvtime-lib');

const REQUIRED_FILES = [
  'tracking-prod-records-v2.csv',
  'tracking-prod-records.csv',
  'user_tv_show_data.csv',
];

function validateGdprFolder(dataDir) {
  const missing = REQUIRED_FILES.filter((f) => !fs.existsSync(path.join(dataDir, f)));
  if (missing.length) {
    throw new Error(
      `This doesn't look like a TV Time export. Missing: ${missing.join(', ')}. Upload the full GDPR zip.`
    );
  }
}

async function clearUserData(userId) {
  await Promise.all([
    TvEpisodeWatch.deleteMany({ userFrom: userId }),
    TvShowTracking.deleteMany({ userFrom: userId }),
    Watch.deleteMany({ userFrom: userId }),
    Favorite.deleteMany({ userFrom: userId }),
    Watchlist.deleteMany({ userFrom: userId }),
    FavoriteTv.deleteMany({ userFrom: userId }),
    TvWatch.deleteMany({ userFrom: userId }),
    TvWatchlist.deleteMany({ userFrom: userId }),
  ]);
}

function moviePayload(userId, mapped, extra = {}) {
  return {
    userFrom: userId,
    movieId: mapped.tmdbId,
    movieTitle: mapped.title,
    movieImage: mapped.backdrop_path || '',
    moviePosterImage: mapped.poster_path || '',
    movieRuntime: mapped.runtime != null ? String(mapped.runtime) : '',
    ...extra,
  };
}

function tvPayload(userId, mapped, extra = {}) {
  return {
    userFrom: userId,
    tvId: mapped.tmdbId,
    tvTitle: mapped.name,
    tvImage: mapped.backdrop_path || '',
    tvPosterImage: mapped.poster_path || '',
    tvRuntime: [],
    ...extra,
  };
}

async function runTvTimeImport({
  userId,
  dataDir,
  apiKey,
  cachePath,
  replace = true,
  dryRun = false,
  onProgress = () => {},
}) {
  validateGdprFolder(dataDir);

  onProgress('parsing');
  const gdpr = loadGdprData(dataDir);
  const mapper = new TmdbMapper(apiKey, cachePath);

  const report = {
    generatedAt: new Date().toISOString(),
    dryRun,
    replace,
    userId: String(userId),
    parsed: gdpr.stats,
    tv: { mapped: 0, unmapped: [], episodesImported: 0, shows: 0, favorites: 0, watchlist: 0 },
    movies: {
      watchedMapped: 0,
      watchedUnmapped: [],
      favoritesMapped: 0,
      favoritesUnmapped: [],
      towatchMapped: 0,
      towatchUnmapped: [],
    },
  };

  const episodesByTvdb = new Map();
  for (const ep of gdpr.tvEpisodes) {
    if (!ep.tvdbId) continue;
    if (!episodesByTvdb.has(ep.tvdbId)) episodesByTvdb.set(ep.tvdbId, []);
    episodesByTvdb.get(ep.tvdbId).push(ep);
  }

  const uniqueTvdbIds = new Set([
    ...episodesByTvdb.keys(),
    ...gdpr.tvFavorites.map((s) => s.tvdbId),
    ...gdpr.tvWatchlist.map((s) => s.tvdbId),
  ]);

  onProgress('mapping_tv', { total: uniqueTvdbIds.size });
  const tvMapped = new Map();
  let tvDone = 0;
  for (const tvdbId of uniqueTvdbIds) {
    const sample =
      gdpr.tvShowMeta.get(tvdbId)?.name ||
      episodesByTvdb.get(tvdbId)?.[0]?.seriesName ||
      gdpr.tvFavorites.find((s) => s.tvdbId === tvdbId)?.name ||
      gdpr.tvWatchlist.find((s) => s.tvdbId === tvdbId)?.name ||
      '';

    const mapped = await mapper.mapTvdbToTmdb(tvdbId, sample);
    if (mapped) {
      tvMapped.set(tvdbId, mapped);
      report.tv.mapped += 1;
    } else {
      report.tv.unmapped.push({ tvdbId, name: sample });
    }
    tvDone += 1;
    if (tvDone % 20 === 0) onProgress('mapping_tv', { done: tvDone, total: uniqueTvdbIds.size });
  }

  onProgress('mapping_movies');
  const watchedMapped = new Map();
  for (const movie of gdpr.moviesWatched) {
    const mapped = await mapper.mapMovie(movie.uuid, movie.name, movie.year);
    if (mapped) watchedMapped.set(movie.uuid, mapped);
    else report.movies.watchedUnmapped.push({ uuid: movie.uuid, name: movie.name, year: movie.year });
  }
  report.movies.watchedMapped = watchedMapped.size;

  const towatchMapped = new Map();
  for (const movie of gdpr.moviesTowatch) {
    const mapped = await mapper.mapMovie(movie.uuid, movie.name, movie.year);
    if (mapped) towatchMapped.set(movie.uuid, mapped);
    else report.movies.towatchUnmapped.push({ uuid: movie.uuid, name: movie.name, year: movie.year });
  }
  report.movies.towatchMapped = towatchMapped.size;

  const favoriteMoviesMapped = new Map();
  for (const movie of gdpr.movieFavorites) {
    const mapped = await mapper.mapMovie(movie.uuid, movie.name, movie.year);
    if (mapped) favoriteMoviesMapped.set(movie.uuid, { mapped, favoritedAt: movie.favoritedAt });
    else report.movies.favoritesUnmapped.push({ uuid: movie.uuid, name: movie.name, year: movie.year });
  }
  report.movies.favoritesMapped = favoriteMoviesMapped.size;

  mapper.saveCache();

  if (dryRun) {
    report.tv.episodesImported = gdpr.tvEpisodes.length;
    report.tv.shows = episodesByTvdb.size;
    report.tv.favorites = gdpr.tvFavorites.filter((s) => tvMapped.has(s.tvdbId)).length;
    report.tv.watchlist = gdpr.tvWatchlist.filter((s) => tvMapped.has(s.tvdbId)).length;
    return report;
  }

  if (replace) {
    onProgress('clearing');
    await clearUserData(userId);
  }

  onProgress('writing_tv', { total: episodesByTvdb.size });
  let showNum = 0;
  for (const [tvdbId, watchedEps] of episodesByTvdb) {
    const show = tvMapped.get(tvdbId);
    if (!show) continue;

    showNum += 1;
    if (showNum % 5 === 0) onProgress('writing_tv', { done: showNum, total: episodesByTvdb.size });

    const progress = await mapper.resolveShowProgress(show.tmdbId, watchedEps);
    const docs = buildEpisodeDocs(userId, show.tmdbId, progress.show, progress.episodes, watchedEps);
    if (docs.length) {
      await TvEpisodeWatch.insertMany(docs, { ordered: false }).catch((err) => {
        if (err.code !== 11000) throw err;
      });
    }

    const tracking = buildTrackingDoc(
      userId,
      show.tmdbId,
      progress.show,
      progress.episodes,
      watchedEps,
      progress.next
    );
    await TvShowTracking.findOneAndUpdate({ userFrom: userId, tvId: show.tmdbId }, tracking, {
      upsert: true,
      new: true,
    });
    report.tv.episodesImported += docs.length;
    report.tv.shows += 1;
  }
  mapper.saveCache();

  onProgress('writing_movies');
  for (const [uuid, mapped] of watchedMapped) {
    const source = gdpr.moviesWatched.find((m) => m.uuid === uuid);
    const data = moviePayload(userId, mapped, { watchedAt: source?.watchedAt || new Date() });
    await Watch.findOneAndUpdate({ userFrom: userId, movieId: data.movieId }, data, { upsert: true });
  }

  for (const [, { mapped, favoritedAt }] of favoriteMoviesMapped) {
    const data = moviePayload(userId, mapped, { favoritedAt: favoritedAt || new Date() });
    await Favorite.findOneAndUpdate({ userFrom: userId, movieId: data.movieId }, data, { upsert: true });
  }

  for (const [, mapped] of towatchMapped) {
    const data = moviePayload(userId, mapped);
    const exists = await Watchlist.findOne({ userFrom: userId, movieId: data.movieId });
    if (!exists) await Watchlist.create(data);
  }

  onProgress('writing_lists');
  for (const fav of gdpr.tvFavorites) {
    const mapped = tvMapped.get(fav.tvdbId);
    if (!mapped) continue;
    const data = tvPayload(userId, mapped, { favoritedAt: fav.favoritedAt || new Date() });
    await FavoriteTv.findOneAndUpdate({ userFrom: userId, tvId: data.tvId }, data, { upsert: true });
    report.tv.favorites += 1;
  }

  for (const item of gdpr.tvWatchlist) {
    const mapped = tvMapped.get(item.tvdbId);
    if (!mapped) continue;
    const tracking = await TvShowTracking.findOne({ userFrom: userId, tvId: mapped.tmdbId });
    if (tracking) continue;
    const data = tvPayload(userId, mapped);
    const exists = await TvWatchlist.findOne({ userFrom: userId, tvId: data.tvId });
    if (!exists) await TvWatchlist.create(data);
    report.tv.watchlist += 1;
  }

  mapper.saveCache();
  return report;
}

module.exports = {
  runTvTimeImport,
  validateGdprFolder,
  REQUIRED_FILES,
};
