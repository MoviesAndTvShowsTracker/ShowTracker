var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var TvShowTracking = require('../models/tvShowTracking');
var TvEpisodeWatch = require('../models/tvEpisodeWatch');
var authenticate = require('../authenticate');
const { syncTrackingCounts, clearWatchlistForShow } = require('./tvtracking');
const {
  deleteWatchedEpisode,
  deleteWatchedEpisodes,
} = require('../services/tvTrackingService');
const { invalidateUserStats } = require('../services/statsCache');

router.use(bodyParser.json());

router.get('/stats', authenticate.verifyUser, async (req, res, next) => {
  try {
    const userId = req.user._id;
    const episodes = await TvEpisodeWatch.find({ userFrom: userId });
    const tvMins = episodes.reduce((sum, ep) => sum + (ep.runtimeMinutes || 0), 0);
    const tvShowIds = await TvEpisodeWatch.distinct('tvId', { userFrom: userId });
    res.status(200).json({
      success: true,
      episodeCount: episodes.length,
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

    await TvEpisodeWatch.findOneAndUpdate(
      { userFrom: userId, tvId, seasonNumber, episodeNumber },
      {
        userFrom: userId,
        tvId,
        seasonNumber,
        episodeNumber,
        tmdbEpisodeId,
        episodeName,
        runtimeMinutes: runtimeMinutes || 0,
        watchedAt: new Date(),
      },
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

    await clearWatchlistForShow(userId, tvId);

    const tracking = await syncTrackingCounts(userId, tvId, {
      nextSeason,
      nextEpisode,
      nextEpisodeName,
      totalEpisodes,
      airedEpisodeCount,
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
