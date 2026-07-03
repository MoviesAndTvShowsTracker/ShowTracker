var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var TvShowTracking = require('../models/tvShowTracking');
var TvEpisodeWatch = require('../models/tvEpisodeWatch');
var authenticate = require('../authenticate');
const {
  autoPauseStaleTracks,
  getLibraryCounts,
  mapTabToStatus,
  STALE_DAYS,
} = require('../services/tvTrackingMaintenance');

router.use(bodyParser.json());

async function syncTrackingCounts(userId, tvId, extra = {}) {
  const watched = await TvEpisodeWatch.find({ userFrom: userId, tvId }).sort({
    seasonNumber: 1,
    episodeNumber: 1,
  });
  const last = watched[watched.length - 1];
  const count = watched.length;

  const patch = {
    watchedEpisodeCount: count,
    lastWatchedAt: count ? new Date() : null,
    ...extra,
  };

  if (last) {
    patch.lastSeason = last.seasonNumber;
    patch.lastEpisode = last.episodeNumber;
  }

  const tracking = await TvShowTracking.findOne({ userFrom: userId, tvId });
  if (tracking) {
    const progressTotal =
      extra.airedEpisodeCount ?? tracking.airedEpisodeCount ?? tracking.totalEpisodes;
    const hasUnreleased =
      tracking.totalEpisodes > 0 && progressTotal < tracking.totalEpisodes;

    if (progressTotal > 0 && count >= progressTotal) {
      if (hasUnreleased && count < tracking.totalEpisodes) {
        patch.status = 'watching';
        if (!extra.nextSeason && !('nextSeason' in extra)) {
          patch.nextSeason = null;
          patch.nextEpisode = null;
          patch.nextEpisodeName = null;
        }
      } else if (tracking.totalEpisodes > 0 && count >= tracking.totalEpisodes) {
        patch.status = 'completed';
        patch.nextSeason = null;
        patch.nextEpisode = null;
        patch.nextEpisodeName = null;
      }
    } else if (tracking.status === 'completed' && progressTotal > 0 && count < progressTotal) {
      patch.status = 'watching';
    } else if (tracking.totalEpisodes > 0 && count >= tracking.totalEpisodes) {
      patch.status = 'completed';
      patch.nextSeason = null;
      patch.nextEpisode = null;
      patch.nextEpisodeName = null;
    } else if (tracking.status === 'completed' && count < tracking.totalEpisodes) {
      patch.status = 'watching';
    }

    if (extra.airedEpisodeCount != null) {
      patch.airedEpisodeCount = extra.airedEpisodeCount;
    }

    if (tracking.status === 'paused' && count > 0) {
      patch.status = 'watching';
    }

    Object.assign(tracking, patch);
    await tracking.save();
    return tracking;
  }

  return null;
}

router.post('/start', authenticate.verifyUser, async (req, res, next) => {
  try {
    const userId = req.user._id;
    const data = {
      userFrom: userId,
      tvId: req.body.tvId,
      tvTitle: req.body.tvTitle,
      tvPosterImage: req.body.tvPosterImage,
      tvBackdropImage: req.body.tvBackdropImage,
      totalEpisodes: req.body.totalEpisodes || 0,
      status: 'watching',
    };

    const tracking = await TvShowTracking.findOneAndUpdate(
      { userFrom: userId, tvId: req.body.tvId },
      data,
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

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
      status: 'watching',
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

    const tracks = await TvShowTracking.find({
      userFrom: req.user._id,
      status,
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
    const tracking = await TvShowTracking.findOneAndUpdate(
      { userFrom: req.user._id, tvId: req.body.tvId },
      { status: 'watching' },
      { new: true }
    );
    if (!tracking) {
      return res.status(404).json({ success: false, message: 'Show not found in your library.' });
    }
    res.status(200).json({ success: true, tracking });
  } catch (err) {
    next(err);
  }
});

router.get('/show/:tvId', authenticate.verifyUser, async (req, res, next) => {
  try {
    const tracking = await TvShowTracking.findOne({
      userFrom: req.user._id,
      tvId: req.params.tvId,
    });
    res.status(200).json({ success: true, tracking: tracking || null });
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
