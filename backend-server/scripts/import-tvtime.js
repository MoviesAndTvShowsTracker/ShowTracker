#!/usr/bin/env node
/**
 * Import TV Time GDPR export into Marquee.
 *
 * Usage:
 *   node scripts/import-tvtime.js --dry-run --user admin --data ../gdpr-data
 *   node scripts/import-tvtime.js --user admin --data ../gdpr-data --replace
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const keys = require('../config/keys');

const User = require('../models/user');
const Watch = require('../models/watch');
const Favorite = require('../models/favorite');
const Watchlist = require('../models/moviewatchlist');
const FavoriteTv = require('../models/favoritefortv');
const TvWatchlist = require('../models/tvwatchlist');
const TvWatch = require('../models/tvwatch');
const TvEpisodeWatch = require('../models/tvEpisodeWatch');
const TvShowTracking = require('../models/tvShowTracking');

const { loadGdprData, TmdbMapper, buildEpisodeDocs, buildTrackingDoc } = require('./tvtime-lib');

const DEFAULT_API_KEY = '52d02319c559a6d63b20f42a6b95064c';

function parseArgs(argv) {
  const opts = {
    dryRun: false,
    replace: true,
    user: 'admin',
    dataDir: path.resolve(__dirname, '../../gdpr-data'),
    report: null,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--dry-run') opts.dryRun = true;
    else if (arg === '--replace') opts.replace = true;
    else if (arg === '--no-replace') opts.replace = false;
    else if (arg === '--user') opts.user = argv[++i];
    else if (arg === '--data') opts.dataDir = path.resolve(argv[++i]);
    else if (arg === '--report') opts.report = path.resolve(argv[++i]);
    else if (arg === '--help' || arg === '-h') {
      console.log(`Usage: node scripts/import-tvtime.js [options]

Options:
  --dry-run          Map titles and print report without writing to DB
  --user <name>      Marquee username (default: admin)
  --data <dir>       Path to gdpr-data folder (default: ../../gdpr-data)
  --replace          Clear existing progress for user before import (default)
  --no-replace       Keep existing data and skip duplicates
  --report <file>    Write JSON report (default: <data>/import-report.json)
`);
      process.exit(0);
    }
  }

  if (!opts.report) opts.report = path.join(opts.dataDir, 'import-report.json');
  return opts;
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

async function run() {
  const opts = parseArgs(process.argv.slice(2));
  const apiKey = process.env.TMDB_API_KEY || DEFAULT_API_KEY;

  if (!fs.existsSync(opts.dataDir)) {
    console.error(`Data folder not found: ${opts.dataDir}`);
    process.exit(1);
  }

  console.log(`Loading GDPR data from ${opts.dataDir}...`);
  const gdpr = loadGdprData(opts.dataDir);
  console.log('Parsed:', gdpr.stats);

  const cachePath = path.join(__dirname, '.tvtime-import-cache.json');
  const mapper = new TmdbMapper(apiKey, cachePath);

  const report = {
    generatedAt: new Date().toISOString(),
    dryRun: opts.dryRun,
    replace: opts.replace,
    user: opts.user,
    parsed: gdpr.stats,
    tv: { mapped: 0, unmapped: [], episodesImported: 0, shows: 0, favorites: 0, watchlist: 0 },
    movies: { watchedMapped: 0, watchedUnmapped: [], favoritesMapped: 0, favoritesUnmapped: [], towatchMapped: 0, towatchUnmapped: [] },
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

  console.log(`\nMapping ${uniqueTvdbIds.size} TV shows via TMDB...`);
  const tvMapped = new Map();
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
  }

  console.log(`\nMapping ${gdpr.moviesWatched.length} watched movies...`);
  const watchedMapped = new Map();
  for (const movie of gdpr.moviesWatched) {
    const mapped = await mapper.mapMovie(movie.uuid, movie.name, movie.year);
    if (mapped) watchedMapped.set(movie.uuid, mapped);
    else report.movies.watchedUnmapped.push({ uuid: movie.uuid, name: movie.name, year: movie.year });
  }
  report.movies.watchedMapped = watchedMapped.size;

  console.log(`Mapping ${gdpr.moviesTowatch.length} watchlist movies...`);
  const towatchMapped = new Map();
  for (const movie of gdpr.moviesTowatch) {
    const mapped = await mapper.mapMovie(movie.uuid, movie.name, movie.year);
    if (mapped) towatchMapped.set(movie.uuid, mapped);
    else report.movies.towatchUnmapped.push({ uuid: movie.uuid, name: movie.name, year: movie.year });
  }
  report.movies.towatchMapped = towatchMapped.size;

  const favoriteMoviesMapped = new Map();
  console.log(`Mapping ${gdpr.movieFavorites.length} favorite movies...`);
  for (const movie of gdpr.movieFavorites) {
    const mapped = await mapper.mapMovie(movie.uuid, movie.name, movie.year);
    if (mapped) favoriteMoviesMapped.set(movie.uuid, { mapped, favoritedAt: movie.favoritedAt });
    else report.movies.favoritesUnmapped.push({ uuid: movie.uuid, name: movie.name, year: movie.year });
  }
  report.movies.favoritesMapped = favoriteMoviesMapped.size;

  mapper.saveCache();

  const episodeDocs = [];
  const trackingDocs = [];

  console.log('\nBuilding TV episode records...');
  for (const [tvdbId, watchedEps] of episodesByTvdb) {
    const show = tvMapped.get(tvdbId);
    if (!show) continue;

    let episodeIndex = [];
    let showMeta = { name: show.name, poster_path: show.poster_path, backdrop_path: show.backdrop_path, number_of_episodes: 0 };

    if (!opts.dryRun) {
      const index = await mapper.getEpisodeIndex(show.tmdbId);
      episodeIndex = index.episodes;
      showMeta = index.show;
    }

    episodeDocs.push(...buildEpisodeDocs(null, show.tmdbId, showMeta, episodeIndex, watchedEps));
    trackingDocs.push(buildTrackingDoc(null, show.tmdbId, showMeta, episodeIndex, watchedEps));
  }

  report.tv.episodesImported = episodeDocs.length;
  report.tv.shows = trackingDocs.length;

  if (opts.dryRun) {
    report.tv.favorites = gdpr.tvFavorites.filter((s) => tvMapped.has(s.tvdbId)).length;
    report.tv.watchlist = gdpr.tvWatchlist.filter((s) => tvMapped.has(s.tvdbId)).length;
    report.movies.favoritesMapped = gdpr.movieFavorites.filter((m) =>
      watchedMapped.has(m.uuid) || favoriteMoviesMapped.has(m.uuid)
    ).length;
    fs.writeFileSync(opts.report, JSON.stringify(report, null, 2));
    console.log('\n--- Dry run summary ---');
    console.log(`TV shows mapped: ${report.tv.mapped}/${uniqueTvdbIds.size}`);
    console.log(`TV episodes ready: ${report.tv.episodesImported}`);
    console.log(`TV unmapped: ${report.tv.unmapped.length}`);
    console.log(`Movies watched mapped: ${report.movies.watchedMapped}/${gdpr.moviesWatched.length}`);
    console.log(`Movie favorites mapped: ${report.movies.favoritesMapped}/${gdpr.movieFavorites.length}`);
    console.log(`Movies watchlist mapped: ${report.movies.towatchMapped}/${gdpr.moviesTowatch.length}`);
    console.log(`Report: ${opts.report}`);
    return;
  }

  await mongoose.connect(keys.mongoURL);
  const user = await User.findOne({ username: opts.user });
  if (!user) {
    console.error(`User not found: ${opts.user}`);
    process.exit(1);
  }
  const userId = user._id;
  report.userId = String(userId);

  if (opts.replace) {
    console.log('\nReplacing existing user progress...');
    await clearUserData(userId);
  }

  console.log('Inserting TV episodes and tracking...');
  let showNum = 0;
  for (const [tvdbId, watchedEps] of episodesByTvdb) {
    const show = tvMapped.get(tvdbId);
    if (!show) continue;

    showNum += 1;
    if (showNum % 10 === 0) console.log(`  ${showNum}/${episodesByTvdb.size} shows...`);

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
  }
  mapper.saveCache();

  console.log('Inserting watched movies...');
  for (const [uuid, mapped] of watchedMapped) {
    const source = gdpr.moviesWatched.find((m) => m.uuid === uuid);
    const data = moviePayload(userId, mapped, {
      watchedAt: source?.watchedAt || new Date(),
    });
    await Watch.findOneAndUpdate({ userFrom: userId, movieId: data.movieId }, data, { upsert: true });
  }

  console.log('Inserting favorite movies...');
  for (const [, { mapped, favoritedAt }] of favoriteMoviesMapped) {
    const data = moviePayload(userId, mapped, { favoritedAt: favoritedAt || new Date() });
    await Favorite.findOneAndUpdate({ userFrom: userId, movieId: data.movieId }, data, { upsert: true });
  }

  console.log('Inserting movie watchlist...');
  for (const [, mapped] of towatchMapped) {
    const data = moviePayload(userId, mapped);
    const exists = await Watchlist.findOne({ userFrom: userId, movieId: data.movieId });
    if (!exists) await Watchlist.create(data);
  }

  console.log('Inserting TV favorites...');
  for (const fav of gdpr.tvFavorites) {
    const mapped = tvMapped.get(fav.tvdbId);
    if (!mapped) continue;
    const data = tvPayload(userId, mapped, { favoritedAt: fav.favoritedAt || new Date() });
    await FavoriteTv.findOneAndUpdate({ userFrom: userId, tvId: data.tvId }, data, { upsert: true });
    report.tv.favorites += 1;
  }

  console.log('Inserting TV watchlist...');
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

  await mongoose.disconnect();
  mapper.saveCache();

  fs.writeFileSync(opts.report, JSON.stringify(report, null, 2));
  console.log('\n--- Import complete ---');
  console.log(`TV episodes: ${report.tv.episodesImported}`);
  console.log(`TV shows tracked: ${report.tv.shows}`);
  console.log(`TV favorites: ${report.tv.favorites}`);
  console.log(`TV watchlist: ${report.tv.watchlist}`);
  console.log(`Movies watched: ${report.movies.watchedMapped}`);
  console.log(`Movie favorites: ${report.movies.favoritesMapped}`);
  console.log(`Movies watchlist: ${report.movies.towatchMapped}`);
  console.log(`Report: ${opts.report}`);
}

run().catch((err) => {
  console.error(err);
  mongoose.disconnect().finally(() => process.exit(1));
});
