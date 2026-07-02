var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var TvShowTracking = require('../models/tvShowTracking');
var authenticate = require('../authenticate');

router.use(bodyParser.json());

router.post('/watched', authenticate.verifyUser, async (req, res, next) => {
  try {
    const tracking = await TvShowTracking.findOne({
      tvId: req.body.tvId,
      userFrom: req.user._id,
      watchedEpisodeCount: { $gt: 0 },
    });
    res.status(200).json({ success: true, watched: Boolean(tracking) });
  } catch (err) {
    next(err);
  }
});

router.post('/getWatchTv', authenticate.verifyUser, async (req, res, next) => {
  try {
    const tracks = await TvShowTracking.find({
      userFrom: req.user._id,
      watchedEpisodeCount: { $gt: 0 },
    }).sort({ lastWatchedAt: -1, updatedAt: -1, createdAt: -1 });

    const watch = tracks.map((t) => ({
      tvId: t.tvId,
      tvTitle: t.tvTitle,
      tvPosterImage: t.tvPosterImage,
      tvImage: t.tvBackdropImage,
      tvRuntime: [],
      lastWatchedAt: t.lastWatchedAt,
      watchedEpisodeCount: t.watchedEpisodeCount,
      totalEpisodes: t.totalEpisodes,
    }));

    res.status(200).json({ success: true, watch });
  } catch (err) {
    next(err);
  }
});

router.post('/removeFromWatched', authenticate.verifyUser, async (req, res, next) => {
  try {
    const userId = req.user._id;
    const tvId = req.body.tvId;

    const TvEpisodeWatch = require('../models/tvEpisodeWatch');
    await TvEpisodeWatch.deleteMany({ userFrom: userId, tvId });
    const doc = await TvShowTracking.findOneAndDelete({ userFrom: userId, tvId });

    res.status(200).json({ success: true, doc });
  } catch (err) {
    res.status(400).json({ success: false, err });
  }
});

module.exports = router;
