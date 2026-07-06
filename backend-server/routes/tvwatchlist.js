var express = require('express');
const bodyParser = require('body-parser');
const tvwatchlist = require('../models/tvwatchlist');
const TvShowTracking = require('../models/tvShowTracking');
const {
  TRACKED_STATUSES,
  normTvId,
  getQueuedTvWatchlist,
} = require('../services/tvWatchlistService');
var router = express.Router();
var authenticate = require('../authenticate');

router.use(bodyParser.json());

router.get('/', function (req, res) {
  res.send('respond with a resource');
});

router.post('/watchlisted', authenticate.verifyUser, async (req, res, next) => {
  try {
    const tvId = normTvId(req.body.tvId);
    const tracked = await TvShowTracking.find({
      userFrom: req.user._id,
      status: { $in: TRACKED_STATUSES },
    }).select('tvId');
    if (tracked.some((row) => normTvId(row.tvId) === tvId)) {
      return res.status(200).json({ success: true, watchlisted: false });
    }
    const watch = await tvwatchlist.find({ userFrom: req.user._id }).select('tvId');
    const watchlisted = watch.some((row) => normTvId(row.tvId) === tvId);
    res.status(200).json({ success: true, watchlisted });
  } catch (err) {
    next(err);
  }
});

router.post('/addToWatchlist', authenticate.verifyUser, async (req, res, next) => {
  try {
    const tvId = normTvId(req.body.tvId);
    const tracked = await TvShowTracking.find({
      userFrom: req.user._id,
      status: { $in: TRACKED_STATUSES },
    }).select('tvId');
    if (tracked.some((row) => normTvId(row.tvId) === tvId)) {
      return res.status(400).json({
        success: false,
        message: 'This show is already in your library. Use Watching, Stopped, or Finished instead.',
      });
    }

    const watchlist = new tvwatchlist({ ...req.body, tvId, userFrom: req.user._id });
    await watchlist.save();
    res.status(200).json({ success: true });
  } catch (err) {
    res.status(400).json({ success: false, err });
  }
});

router.post('/removeFromWatchlist', authenticate.verifyUser, async (req, res, next) => {
  try {
    const doc = await tvwatchlist.findOneAndDelete({
      tvId: normTvId(req.body.tvId),
      userFrom: req.user._id,
    });
    res.status(200).json({ success: true, doc });
  } catch (err) {
    res.status(400).json({ success: false, err });
  }
});

router.post('/getTvWatchlist', authenticate.verifyUser, async (req, res, next) => {
  try {
    const watchlist = await getQueuedTvWatchlist(req.user._id);
    res.status(200).json({ success: true, watchlist });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
