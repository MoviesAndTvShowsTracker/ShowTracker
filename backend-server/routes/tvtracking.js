var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var TvShowTracking = require('../models/tvShowTracking');
var TvEpisodeWatch = require('../models/tvEpisodeWatch');
const { clearWatchlistForShow, normTvId } = require('../services/tvWatchlistService');
const {
  findTracking,
  getWatchedEpisodesForShow,
  resolveShowTracking,
} = require('../services/tvTrackingService');
var authenticate = require('../authenticate');
const {
  autoPauseStaleTracks,
  getLibraryCounts,
  mapTabToStatus,
  STALE_DAYS,
} = require('../services/tvTrackingMaintenance');
const { normalizeRating } = require('../services/ratings');
const { decideStatus, resolveProgress } = require('../services/tvCatalog');
const { invalidateUserStats } = require('../services/statsCache');

router.use(bodyParser.json());

async function syncTrackingCounts(userId, tvId, extra = {}) {
  const watched = await getWatchedEpisodesForShow(userId, tvId);
  const last = watched[watched.length - 1];
  const count = watched.length;

  const tracking = await findTracking(userId, tvId);
  if (!tracking) {
    return null;
  }

  if (count === 0) {
    await TvShowTracking.deleteOne({ _id: tracking._id });
    return null;
  }

  // Never rewrite next / status while a rewatch session owns Up Next / episode checks.
  const rewatching = tracking.status === 'rewatching';

  // TMDB's catalog decides the next episode and totals; client values are only a fallback.
  const furthest = last ? { season: last.seasonNumber, episode: last.episodeNumber } : null;
  const truth = rewatching ? null : await resolveProgress(tvId, furthest);
  const facts = truth ? { ...extra, ...truth } : extra;

  const patch = {
    watchedEpisodeCount: count,
    lastWatchedAt: new Date(),
    ...facts,
  };

  if (last) {
    patch.lastSeason = last.seasonNumber;
    patch.lastEpisode = last.episodeNumber;
  }

  if (!rewatching) {
    const total = positive(facts.totalEpisodes) || positive(tracking.totalEpisodes);
    const aired = positive(facts.airedEpisodeCount) || positive(tracking.airedEpisodeCount) || total;
    const hasNext = facts.nextSeason != null ? facts.nextSeason > 0 : tracking.nextSeason > 0;
    patch.status = decideStatus({
      status: tracking.status,
      count,
      total,
      aired,
      hasNext,
      resolved: Boolean(truth),
    });
    if (patch.status === 'completed') {
      patch.nextSeason = null;
      patch.nextEpisode = null;
      patch.nextEpisodeName = null;
      if (!tracking.timesCompleted || tracking.timesCompleted < 1) {
        patch.timesCompleted = 1;
      }
    }
  }

  Object.assign(tracking, patch);
  await tracking.save();
  return tracking;
}

function positive(n) {
  const v = Number(n);
  return Number.isFinite(v) && v > 0 ? v : 0;
}

router.post('/start', authenticate.verifyUser, async (req, res, next) => {
  try {
    const userId = req.user._id;
    const tvId = String(req.body.tvId);
    const data = {
      userFrom: userId,
      tvId,
      tvTitle: req.body.tvTitle,
      tvPosterImage: req.body.tvPosterImage,
      tvBackdropImage: req.body.tvBackdropImage,
      totalEpisodes: req.body.totalEpisodes || 0,
      status: 'watching',
    };

    const tracking = await TvShowTracking.findOneAndUpdate(
      { userFrom: userId, tvId },
      data,
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    await clearWatchlistForShow(userId, tvId);

    res.status(200).json({ success: true, tracking });
  } catch (err) {
    next(err);
  }
});

router.get('/continue', authenticate.verifyUser, async (req, res, next) => {
  try {
    await autoPauseStaleTracks(req.user._id);

    const tracks = await TvShowTracking.find({
      userFrom: req.user._id,
      status: { $in: ['watching', 'rewatching'] },
      watchedEpisodeCount: { $gt: 0 },
    })
      .sort({ lastWatchedAt: -1, updatedAt: -1 })
      .limit(24);

    res.status(200).json({ success: true, tracks });
  } catch (err) {
    next(err);
  }
});

router.get('/library/summary', authenticate.verifyUser, async (req, res, next) => {
  try {
    await autoPauseStaleTracks(req.user._id);
    const counts = await getLibraryCounts(req.user._id);
    res.status(200).json({ success: true, counts, staleAfterDays: STALE_DAYS });
  } catch (err) {
    next(err);
  }
});

router.get('/library/:tab', authenticate.verifyUser, async (req, res, next) => {
  try {
    await autoPauseStaleTracks(req.user._id);
    const status = mapTabToStatus(req.params.tab);
    if (!['watching', 'paused', 'completed'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid library tab.' });
    }

    const statusFilter =
      status === 'watching' ? { $in: ['watching', 'rewatching'] } : status;

    const tracks = await TvShowTracking.find({
      userFrom: req.user._id,
      status: statusFilter,
    }).sort({ lastWatchedAt: -1, updatedAt: -1 });

    const counts = await getLibraryCounts(req.user._id);

    res.status(200).json({
      success: true,
      tab: req.params.tab,
      status,
      tracks,
      counts,
      staleAfterDays: STALE_DAYS,
    });
  } catch (err) {
    next(err);
  }
});

router.post('/resume', authenticate.verifyUser, async (req, res, next) => {
  try {
    const existing = await TvShowTracking.findOne({
      userFrom: req.user._id,
      tvId: req.body.tvId,
    });
    if (!existing) {
      return res.status(404).json({ success: false, message: 'Show not found in your library.' });
    }
    // Do not clobber an in-progress rewatch session.
    if (existing.status === 'rewatching') {
      return res.status(200).json({ success: true, tracking: existing });
    }
    existing.status = 'watching';
    await existing.save();
    res.status(200).json({ success: true, tracking: existing });
  } catch (err) {
    next(err);
  }
});

router.get('/show/:tvId', authenticate.verifyUser, async (req, res, next) => {
  try {
    const tracking = await resolveShowTracking(req.user._id, req.params.tvId);
    res.status(200).json({ success: true, tracking });
  } catch (err) {
    next(err);
  }
});

router.post('/stop', authenticate.verifyUser, async (req, res, next) => {
  try {
    const status = req.body.status || 'paused';
    const tracking = await TvShowTracking.findOneAndUpdate(
      { userFrom: req.user._id, tvId: req.body.tvId },
      { status },
      { new: true }
    );
    if (!tracking) {
      return res.status(404).json({ success: false, message: 'Not tracking this show' });
    }
    res.status(200).json({ success: true, tracking });
  } catch (err) {
    next(err);
  }
});

router.post('/rate', authenticate.verifyUser, async (req, res, next) => {
  try {
    let rating;
    try {
      rating = normalizeRating(req.body.rating);
    } catch (err) {
      return res.status(400).json({ success: false, message: err.message });
    }

    const tracking = await findTracking(req.user._id, req.body.tvId);
    if (!tracking || (tracking.watchedEpisodeCount || 0) < 1) {
      return res
        .status(404)
        .json({ success: false, message: 'Mark at least one episode before rating this show.' });
    }

    tracking.rating = rating;
    await tracking.save();
    await invalidateUserStats(req.user._id);
    res.status(200).json({ success: true, rating: tracking.rating ?? null, tracking });
  } catch (err) {
    next(err);
  }
});

router.post('/update-next', authenticate.verifyUser, async (req, res, next) => {
  try {
    const tracking = await TvShowTracking.findOneAndUpdate(
      { userFrom: req.user._id, tvId: req.body.tvId },
      {
        nextSeason: req.body.nextSeason,
        nextEpisode: req.body.nextEpisode,
        nextEpisodeName: req.body.nextEpisodeName,
        totalEpisodes: req.body.totalEpisodes,
      },
      { new: true }
    );
    res.status(200).json({ success: true, tracking });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
module.exports.syncTrackingCounts = syncTrackingCounts;
module.exports.clearWatchlistForShow = clearWatchlistForShow;
