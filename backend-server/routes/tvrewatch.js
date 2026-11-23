const express = require('express');
const bodyParser = require('body-parser');
const authenticate = require('../authenticate');
const { invalidateUserStats } = require('../services/statsCache');
const {
  startRewatch,
  markEpisodes,
  unmarkEpisodes,
  cancelRewatch,
  getRewatchState,
  logEpisodeRewatches,
  undoEpisodePlay,
  undoEpisodePlays,
} = require('../services/tvRewatchService');

const router = express.Router();
router.use(bodyParser.json());

function handleServiceError(err, res, next) {
  if (err.status) {
    return res.status(err.status).json({ success: false, message: err.message });
  }
  return next(err);
}

router.get('/:tvId', authenticate.verifyUser, async (req, res, next) => {
  try {
    const state = await getRewatchState(req.user._id, req.params.tvId);
    res.status(200).json({ success: true, ...state });
  } catch (err) {
    handleServiceError(err, res, next);
  }
});

router.post('/start', authenticate.verifyUser, async (req, res, next) => {
  try {
    const result = await startRewatch(req.user._id, req.body.tvId, {
      totalEpisodes: req.body.totalEpisodes,
      airedEpisodeCount: req.body.airedEpisodeCount,
      nextSeason: req.body.nextSeason,
      nextEpisode: req.body.nextEpisode,
      nextEpisodeName: req.body.nextEpisodeName,
    });
    await invalidateUserStats(req.user._id);
    res.status(200).json({ success: true, ...result });
  } catch (err) {
    handleServiceError(err, res, next);
  }
});

router.post('/cancel', authenticate.verifyUser, async (req, res, next) => {
  try {
    const result = await cancelRewatch(req.user._id, req.body.tvId);
    await invalidateUserStats(req.user._id);
    res.status(200).json({ success: true, ...result });
  } catch (err) {
    handleServiceError(err, res, next);
  }
});

router.post('/mark', authenticate.verifyUser, async (req, res, next) => {
  try {
    const ep = {
      seasonNumber: req.body.seasonNumber,
      episodeNumber: req.body.episodeNumber,
      tmdbEpisodeId: req.body.tmdbEpisodeId,
      episodeName: req.body.episodeName,
      runtimeMinutes: req.body.runtimeMinutes,
    };
    const result = await markEpisodes(req.user._id, req.body.tvId, [ep], {
      totalEpisodes: req.body.totalEpisodes,
      airedEpisodeCount: req.body.airedEpisodeCount,
      nextSeason: req.body.nextSeason,
      nextEpisode: req.body.nextEpisode,
      nextEpisodeName: req.body.nextEpisodeName,
    });
    await invalidateUserStats(req.user._id);
    res.status(200).json({ success: true, ...result });
  } catch (err) {
    handleServiceError(err, res, next);
  }
});

router.post('/unmark', authenticate.verifyUser, async (req, res, next) => {
  try {
    const ep = {
      seasonNumber: req.body.seasonNumber,
      episodeNumber: req.body.episodeNumber,
    };
    const result = await unmarkEpisodes(req.user._id, req.body.tvId, [ep], {
      totalEpisodes: req.body.totalEpisodes,
      airedEpisodeCount: req.body.airedEpisodeCount,
      nextSeason: req.body.nextSeason,
      nextEpisode: req.body.nextEpisode,
      nextEpisodeName: req.body.nextEpisodeName,
    });
    await invalidateUserStats(req.user._id);
    res.status(200).json({ success: true, ...result });
  } catch (err) {
    handleServiceError(err, res, next);
  }
});

router.post('/mark-batch', authenticate.verifyUser, async (req, res, next) => {
  try {
    const result = await markEpisodes(req.user._id, req.body.tvId, req.body.episodes || [], {
      totalEpisodes: req.body.totalEpisodes,
      airedEpisodeCount: req.body.airedEpisodeCount,
      nextSeason: req.body.nextSeason,
      nextEpisode: req.body.nextEpisode,
      nextEpisodeName: req.body.nextEpisodeName,
    });
    await invalidateUserStats(req.user._id);
    res.status(200).json({ success: true, ...result });
  } catch (err) {
    handleServiceError(err, res, next);
  }
});

router.post('/unmark-batch', authenticate.verifyUser, async (req, res, next) => {
  try {
    const result = await unmarkEpisodes(req.user._id, req.body.tvId, req.body.episodes || [], {
      totalEpisodes: req.body.totalEpisodes,
      airedEpisodeCount: req.body.airedEpisodeCount,
      nextSeason: req.body.nextSeason,
      nextEpisode: req.body.nextEpisode,
      nextEpisodeName: req.body.nextEpisodeName,
    });
    await invalidateUserStats(req.user._id);
    res.status(200).json({ success: true, ...result });
  } catch (err) {
    handleServiceError(err, res, next);
  }
});

/** Casual rewatch play (does not enter structured rewatching). */
router.post('/log', authenticate.verifyUser, async (req, res, next) => {
  try {
    const ep = {
      seasonNumber: req.body.seasonNumber,
      episodeNumber: req.body.episodeNumber,
      tmdbEpisodeId: req.body.tmdbEpisodeId,
      episodeName: req.body.episodeName,
      runtimeMinutes: req.body.runtimeMinutes,
    };
    const result = await logEpisodeRewatches(req.user._id, req.body.tvId, [ep], {
      totalEpisodes: req.body.totalEpisodes,
      airedEpisodeCount: req.body.airedEpisodeCount,
    });
    await invalidateUserStats(req.user._id);
    res.status(200).json({ success: true, ...result });
  } catch (err) {
    handleServiceError(err, res, next);
  }
});

router.post('/log-batch', authenticate.verifyUser, async (req, res, next) => {
  try {
    const result = await logEpisodeRewatches(
      req.user._id,
      req.body.tvId,
      req.body.episodes || [],
      {
        totalEpisodes: req.body.totalEpisodes,
        airedEpisodeCount: req.body.airedEpisodeCount,
      }
    );
    await invalidateUserStats(req.user._id);
    res.status(200).json({ success: true, ...result });
  } catch (err) {
    handleServiceError(err, res, next);
  }
});

/** Undo latest rewatch play, then canonical first-watch. */
router.post('/undo-play', authenticate.verifyUser, async (req, res, next) => {
  try {
    const result = await undoEpisodePlay(
      req.user._id,
      req.body.tvId,
      {
        seasonNumber: req.body.seasonNumber,
        episodeNumber: req.body.episodeNumber,
      },
      {
        totalEpisodes: req.body.totalEpisodes,
        airedEpisodeCount: req.body.airedEpisodeCount,
      }
    );
    await invalidateUserStats(req.user._id);
    res.status(200).json({ success: true, ...result });
  } catch (err) {
    handleServiceError(err, res, next);
  }
});

router.post('/undo-play-batch', authenticate.verifyUser, async (req, res, next) => {
  try {
    const result = await undoEpisodePlays(
      req.user._id,
      req.body.tvId,
      req.body.episodes || [],
      {
        totalEpisodes: req.body.totalEpisodes,
        airedEpisodeCount: req.body.airedEpisodeCount,
      }
    );
    await invalidateUserStats(req.user._id);
    res.status(200).json({ success: true, ...result });
  } catch (err) {
    handleServiceError(err, res, next);
  }
});

module.exports = router;
