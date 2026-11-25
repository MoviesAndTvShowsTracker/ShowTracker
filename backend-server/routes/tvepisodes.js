var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var TvShowTracking = require('../models/tvShowTracking');
var TvEpisodeWatch = require('../models/tvEpisodeWatch');
var TvRewatchEpisode = require('../models/tvRewatchEpisode');
var authenticate = require('../authenticate');
const { syncTrackingCounts, clearWatchlistForShow } = require('./tvtracking');
const {
  deleteWatchedEpisode,
  deleteWatchedEpisodes,
} = require('../services/tvTrackingService');
const { invalidateUserStats } = require('../services/statsCache');
const { normalizeRating } = require('../services/ratings');
const { parseWatchedAt, parseNote } = require('../lib/diaryInput');
const { mergeEpisodePlaysForTime } = require('../services/userStatsDashboard');
const { episodeExists, loadCatalog } = require('../services/tvCatalog');

/** Episodes TMDB doesn't list (e.g. a season that doesn't exist). Specials and an unreachable TMDB pass. */
async function unknownEpisodes(tvId, episodes) {
  const catalog = await loadCatalog(tvId);
  if (!catalog) return [];
  const checks = await Promise.all(
    episodes.map(async (ep) => {
      if (Number(ep.seasonNumber) === 0) return null;
      const ok = await episodeExists(tvId, catalog, ep.seasonNumber, ep.episodeNumber);
      return ok ? null : ep;
    })
  );
  return checks.filter(Boolean);
}

function notListed(res, ep) {
  return res.status(400).json({
    success: false,
    message: `S${ep.seasonNumber}E${ep.episodeNumber} isn't listed for this show.`,
  });
}

router.use(bodyParser.json());

router.get('/stats', authenticate.verifyUser, async (req, res, next) => {
  try {
    const userId = req.user._id;
    const [episodes, rewatches] = await Promise.all([
      TvEpisodeWatch.find({ userFrom: userId }).lean(),
      TvRewatchEpisode.find({ userFrom: userId }).lean(),
    ]);
    const plays = mergeEpisodePlaysForTime(episodes, rewatches);
    const tvMins = plays.reduce((sum, ep) => sum + (ep.runtimeMinutes || 0), 0);
    const tvShowIds = await TvEpisodeWatch.distinct('tvId', { userFrom: userId });
    res.status(200).json({
      success: true,
      episodeCount: episodes.length,
      episodePlayCount: plays.length,
      episodeRewatchPlays: rewatches.length,
      tvMins,
      tvShowCount: tvShowIds.length,
    });
  } catch (err) {
    next(err);
  }
});

router.get('/:tvId', authenticate.verifyUser, async (req, res, next) => {
  try {
    const episodes = await TvEpisodeWatch.find({
      userFrom: req.user._id,
      tvId: req.params.tvId,
    }).sort({ seasonNumber: 1, episodeNumber: 1 });

    res.status(200).json({ success: true, episodes });
  } catch (err) {
    next(err);
  }
});

router.post('/mark', authenticate.verifyUser, async (req, res, next) => {
  try {
    const userId = req.user._id;
    const tvId = String(req.body.tvId);
    const {
      seasonNumber,
      episodeNumber,
      tmdbEpisodeId,
      episodeName,
      runtimeMinutes,
      tvTitle,
      tvPosterImage,
      tvBackdropImage,
      totalEpisodes,
      airedEpisodeCount,
      nextSeason,
      nextEpisode,
      nextEpisodeName,
    } = req.body;

    let rating;
    let watchedAt;
    let note;
    try {
      rating = normalizeRating(req.body.rating);
      watchedAt = parseWatchedAt(req.body.watchedAt);
      note = parseNote(req.body.note);
    } catch (err) {
      return res.status(400).json({ success: false, message: err.message });
    }

    const epSet = {
      userFrom: userId,
      tvId,
      seasonNumber,
      episodeNumber,
      tmdbEpisodeId,
      episodeName,
      runtimeMinutes: runtimeMinutes || 0,
      watchedAt,
    };
    if (req.body.rating !== undefined) epSet.rating = rating;
    if (note !== undefined) epSet.note = note;

    const [missing] = await unknownEpisodes(tvId, [{ seasonNumber, episodeNumber }]);
    if (missing) return notListed(res, missing);

    await TvEpisodeWatch.findOneAndUpdate(
      { userFrom: userId, tvId, seasonNumber, episodeNumber },
      epSet,
      { upsert: true, new: true }
    );

    await TvShowTracking.findOneAndUpdate(
      { userFrom: userId, tvId },
      {
        userFrom: userId,
        tvId,
        tvTitle,
        tvPosterImage,
        tvBackdropImage,
        totalEpisodes: totalEpisodes || 0,
        airedEpisodeCount: airedEpisodeCount || 0,
        status: 'watching',
        nextSeason,
        nextEpisode,
        nextEpisodeName,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    const [tracking] = await Promise.all([
      syncTrackingCounts(userId, tvId, {
        nextSeason,
        nextEpisode,
        nextEpisodeName,
        totalEpisodes,
        airedEpisodeCount,
      }),
      clearWatchlistForShow(userId, tvId),
      invalidateUserStats(userId),
    ]);

    const episodes = await TvEpisodeWatch.find({ userFrom: userId, tvId }).sort({
      seasonNumber: 1,
      episodeNumber: 1,
    });

    res.status(200).json({ success: true, tracking, episodes });
  } catch (err) {
    next(err);
  }
});

router.post('/mark-batch', authenticate.verifyUser, async (req, res, next) => {
  try {
    const userId = req.user._id;
    const tvId = String(req.body.tvId);
    const {
      episodes,
      tvTitle,
      tvPosterImage,
      tvBackdropImage,
      totalEpisodes,
      airedEpisodeCount,
      nextSeason,
      nextEpisode,
      nextEpisodeName,
    } = req.body;

    if (!Array.isArray(episodes) || !episodes.length) {
      return res.status(400).json({ success: false, message: 'No episodes provided' });
    }

    const missing = await unknownEpisodes(tvId, episodes);
    if (missing.length) return notListed(res, missing[0]);

    await Promise.all(
      episodes.map((ep) =>
        TvEpisodeWatch.findOneAndUpdate(
          {
            userFrom: userId,
            tvId,
            seasonNumber: ep.seasonNumber,
            episodeNumber: ep.episodeNumber,
          },
          {
            $set: {
              userFrom: userId,
              tvId,
              seasonNumber: ep.seasonNumber,
              episodeNumber: ep.episodeNumber,
              tmdbEpisodeId: ep.tmdbEpisodeId,
              episodeName: ep.episodeName,
              runtimeMinutes: ep.runtimeMinutes || 0,
            },
            $setOnInsert: { watchedAt: new Date() },
          },
          { upsert: true, new: true }
        )
      )
    );

    await TvShowTracking.findOneAndUpdate(
      { userFrom: userId, tvId },
      {
        userFrom: userId,
        tvId,
        tvTitle,
        tvPosterImage,
        tvBackdropImage,
        totalEpisodes: totalEpisodes || 0,
        airedEpisodeCount: airedEpisodeCount || 0,
        status: 'watching',
        nextSeason,
        nextEpisode,
        nextEpisodeName,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    await clearWatchlistForShow(userId, tvId);

    const tracking = await syncTrackingCounts(userId, tvId, {
      nextSeason,
      nextEpisode,
      nextEpisodeName,
      totalEpisodes,
      airedEpisodeCount,
    });

    const allEpisodes = await TvEpisodeWatch.find({ userFrom: userId, tvId }).sort({
      seasonNumber: 1,
      episodeNumber: 1,
    });

    await invalidateUserStats(userId);
    res.status(200).json({ success: true, tracking, episodes: allEpisodes });
  } catch (err) {
    next(err);
  }
});

router.post('/unmark-batch', authenticate.verifyUser, async (req, res, next) => {
  try {
    const userId = req.user._id;
    const tvId = String(req.body.tvId);
    const { episodes, nextSeason, nextEpisode, nextEpisodeName } = req.body;

    if (!Array.isArray(episodes) || !episodes.length) {
      return res.status(400).json({ success: false, message: 'No episodes provided' });
    }

    await deleteWatchedEpisodes(userId, tvId, episodes);

    const tracking = await syncTrackingCounts(userId, tvId, {
      nextSeason,
      nextEpisode,
      nextEpisodeName,
    });

    const allEpisodes = await TvEpisodeWatch.find({ userFrom: userId, tvId }).sort({
      seasonNumber: 1,
      episodeNumber: 1,
    });

    await invalidateUserStats(userId);
    res.status(200).json({ success: true, tracking, episodes: allEpisodes });
  } catch (err) {
    next(err);
  }
});

/** Change the date and/or note of an episode you logged. */
router.post('/update', authenticate.verifyUser, async (req, res, next) => {
  try {
    const userId = req.user._id;
    const tvId = String(req.body.tvId);
    const seasonNumber = Number(req.body.seasonNumber);
    const episodeNumber = Number(req.body.episodeNumber);
    if (!Number.isInteger(seasonNumber) || !Number.isInteger(episodeNumber)) {
      return res.status(400).json({ success: false, message: 'Unknown episode.' });
    }
    const set = {};
    try {
      if (req.body.watchedAt !== undefined) set.watchedAt = parseWatchedAt(req.body.watchedAt);
      const note = parseNote(req.body.note);
      if (note !== undefined) set.note = note;
    } catch (err) {
      return res.status(400).json({ success: false, message: err.message });
    }
    const episode = await TvEpisodeWatch.findOneAndUpdate(
      { userFrom: userId, tvId, seasonNumber, episodeNumber },
      { $set: set },
      { new: true }
    );
    if (!episode) {
      return res.status(404).json({ success: false, message: 'Log this episode first.' });
    }
    await invalidateUserStats(userId);
    res.status(200).json({ success: true, episode });
  } catch (err) {
    next(err);
  }
});

router.post('/rate-episode', authenticate.verifyUser, async (req, res, next) => {
  try {
    const userId = req.user._id;
    const tvId = String(req.body.tvId);
    const { seasonNumber, episodeNumber } = req.body;

    let rating;
    try {
      rating = normalizeRating(req.body.rating);
    } catch (err) {
      return res.status(400).json({ success: false, message: err.message });
    }

    const episode = await TvEpisodeWatch.findOneAndUpdate(
      { userFrom: userId, tvId, seasonNumber, episodeNumber },
      { $set: { rating } },
      { new: true }
    );

    if (!episode) {
      return res
        .status(404)
        .json({ success: false, message: 'Mark this episode watched before rating it.' });
    }

    await invalidateUserStats(userId);
    res.status(200).json({ success: true, rating: episode.rating ?? null, episode });
  } catch (err) {
    next(err);
  }
});

router.post('/unmark', authenticate.verifyUser, async (req, res, next) => {
  try {
    const userId = req.user._id;
    const tvId = String(req.body.tvId);
    const { seasonNumber, episodeNumber, nextSeason, nextEpisode, nextEpisodeName } =
      req.body;

    await deleteWatchedEpisode(userId, tvId, seasonNumber, episodeNumber);

    const tracking = await syncTrackingCounts(userId, tvId, {
      nextSeason,
      nextEpisode,
      nextEpisodeName,
    });

    const episodes = await TvEpisodeWatch.find({ userFrom: userId, tvId }).sort({
      seasonNumber: 1,
      episodeNumber: 1,
    });

    await invalidateUserStats(userId);
    res.status(200).json({ success: true, tracking, episodes });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
