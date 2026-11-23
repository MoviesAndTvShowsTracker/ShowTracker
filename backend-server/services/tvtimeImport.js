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
const TvRewatchSession = require('../models/tvRewatchSession');
const TvRewatchEpisode = require('../models/tvRewatchEpisode');
const {
  loadGdprData,
  TmdbMapper,
  buildEpisodeDocs,
  buildTrackingDoc,
  clusterRewatchSessions,
  buildRewatchEpisodeDocs,
} = require('../scripts/tvtime-lib');

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
    TvRewatchEpisode.deleteMany({ userFrom: userId }),
    TvRewatchSession.deleteMany({ userFrom: userId }),
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
    tv: {
      mapped: 0,
      unmapped: [],
      episodesImported: 0,
      shows: 0,
      favorites: 0,
      watchlist: 0,
      rewatchPlays: 0,
      rewatchSessions: 0,
      rewatchEpisodesImported: 0,
    },
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

  const rewatchesByTvdb = new Map();
  for (const play of gdpr.tvRewatchPlays || []) {
    if (!play.tvdbId) continue;
    if (!rewatchesByTvdb.has(play.tvdbId)) rewatchesByTvdb.set(play.tvdbId, []);
    rewatchesByTvdb.get(play.tvdbId).push(play);
  }

  const uniqueTvdbIds = new Set([
    ...episodesByTvdb.keys(),
    ...rewatchesByTvdb.keys(),
    ...gdpr.tvFavorites.map((s) => s.tvdbId),
    ...gdpr.tvWatchlist.map((s) => s.tvdbId),
  ]);

  onProgress('mapping_tv', { total: uniqueTvdbIds.size });
  const tvMapped = new Map();
  let tvDone = 0;
  for (const tvdbId of uniqueTvdbIds) {
    const sampleEp =
      episodesByTvdb.get(tvdbId)?.[0] || rewatchesByTvdb.get(tvdbId)?.[0] || null;
    if (sampleEp?.forcedMapping?.tmdbId) {
      let mapped = { ...sampleEp.forcedMapping };
      // Fill art from TMDB when possible.
      try {
        const detail = await mapper.fetch(`/tv/${mapped.tmdbId}`);
        mapped = {
          ...mapped,
          name: detail.name || mapped.name,
          poster_path: detail.poster_path || mapped.poster_path || '',
          backdrop_path: detail.backdrop_path || mapped.backdrop_path || '',
        };
      } catch {
        /* keep forced mapping */
      }
      tvMapped.set(tvdbId, mapped);
      report.tv.mapped += 1;
      tvDone += 1;
      if (tvDone % 20 === 0) onProgress('mapping_tv', { done: tvDone, total: uniqueTvdbIds.size });
      continue;
    }

    const sample =
      gdpr.tvShowMeta.get(tvdbId)?.name ||
      sampleEp?.seriesName ||
      gdpr.tvFavorites.find((s) => s.tvdbId === tvdbId)?.name ||
      gdpr.tvWatchlist.find((s) => s.tvdbId === tvdbId)?.name ||
      '';

    // Anthology parents may still appear on favorites/watchlist under the raw id.
    const rawId = String(tvdbId).split(':')[0];
    const mapped = await mapper.mapTvdbToTmdb(rawId === String(tvdbId) ? tvdbId : rawId, sample);
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
    report.tv.rewatchPlays = (gdpr.tvRewatchPlays || []).length;
    let drySessions = 0;
    for (const plays of rewatchesByTvdb.values()) {
      drySessions += clusterRewatchSessions(plays).length;
    }
    report.tv.rewatchSessions = drySessions;
    report.tv.favorites = gdpr.tvFavorites.filter((s) => tvMapped.has(s.tvdbId)).length;
    report.tv.watchlist = gdpr.tvWatchlist.filter((s) => tvMapped.has(s.tvdbId)).length;
    return report;
  }

  if (replace) {
    onProgress('clearing');
    await clearUserData(userId);
  }

  const tvdbIdsToWrite = new Set([...episodesByTvdb.keys(), ...rewatchesByTvdb.keys()]);
  onProgress('writing_tv', { total: tvdbIdsToWrite.size });
  let showNum = 0;
  for (const tvdbId of tvdbIdsToWrite) {
    const show = tvMapped.get(tvdbId);
    if (!show) continue;

    showNum += 1;
    if (showNum % 5 === 0) onProgress('writing_tv', { done: showNum, total: tvdbIdsToWrite.size });

    const watchedEps = episodesByTvdb.get(tvdbId) || [];
    const rewatchPlays = rewatchesByTvdb.get(tvdbId) || [];
    const progressSeed = [...watchedEps, ...rewatchPlays];
    const progress = await mapper.resolveShowProgress(show.tmdbId, progressSeed);
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

    const sessions = clusterRewatchSessions(rewatchPlays);
    let fullRewatchCompletions = 0;
    let latestRewatchAt = null;

    for (let i = 0; i < sessions.length; i += 1) {
      const sessionPlays = sessions[i];
      const startedAt = sessionPlays[0]?.watchedAt || new Date();
      const completedAt =
        sessionPlays[sessionPlays.length - 1]?.watchedAt || startedAt;
      const lastPlay = [...sessionPlays].sort(
        (a, b) =>
          a.seasonNumber - b.seasonNumber || a.episodeNumber - b.episodeNumber
      ).pop();
      const totalEpisodes =
        progress.show.number_of_episodes || progress.episodes.length || 0;

      const session = await TvRewatchSession.create({
        userFrom: userId,
        tvId: show.tmdbId,
        sessionNumber: i + 1,
        status: 'completed',
        startedAt,
        completedAt,
        watchedEpisodeCount: sessionPlays.length,
        totalEpisodes,
        airedEpisodeCount: totalEpisodes,
        nextSeason: null,
        nextEpisode: null,
        nextEpisodeName: null,
        lastSeason: lastPlay?.seasonNumber ?? null,
        lastEpisode: lastPlay?.episodeNumber ?? null,
        lastWatchedAt: completedAt,
      });

      const epDocs = buildRewatchEpisodeDocs(
        userId,
        show.tmdbId,
        session._id,
        progress.episodes,
        sessionPlays
      );
      if (epDocs.length) {
        await TvRewatchEpisode.insertMany(epDocs, { ordered: false }).catch((err) => {
          if (err.code !== 11000) throw err;
        });
        report.tv.rewatchEpisodesImported += epDocs.length;
      }

      report.tv.rewatchSessions += 1;
      report.tv.rewatchPlays += sessionPlays.length;
      if (!latestRewatchAt || completedAt > latestRewatchAt) latestRewatchAt = completedAt;
      if (totalEpisodes > 0 && sessionPlays.length >= totalEpisodes) {
        fullRewatchCompletions += 1;
      }
    }

    // Only full-show rewatch runs bump timesCompleted (partial season runs stay as plays).
    if (fullRewatchCompletions > 0 || tracking.status === 'completed') {
      const base = tracking.status === 'completed' ? 1 : 0;
      tracking.timesCompleted = Math.max(
        tracking.timesCompleted || 0,
        base + fullRewatchCompletions
      );
    }
    if (
      latestRewatchAt &&
      (!tracking.lastWatchedAt || latestRewatchAt > new Date(tracking.lastWatchedAt))
    ) {
      tracking.lastWatchedAt = latestRewatchAt;
    }

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
