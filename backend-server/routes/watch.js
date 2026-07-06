var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var Watch = require('../models/watch');
var Favorite = require('../models/favorite');
const moviewatchlist = require('../models/moviewatchlist');
var authenticate = require('../authenticate');
const { ensureMovieRuntime } = require('../services/mediaMeta');
const { invalidateUserStats } = require('../services/statsCache');

router.use(bodyParser.json());

router.get('/', function (req, res) {
  res.send('respond with a resource');
});

router.post('/watched', authenticate.verifyUser, async (req, res, next) => {
  try {
    const watch = await Watch.findOne({
      movieId: req.body.movieId,
      userFrom: req.user._id,
    });
    res.status(200).json({
      success: true,
      watched: Boolean(watch),
      watchedAt: watch?.watchedAt || null,
    });
  } catch (err) {
    next(err);
  }
});

router.post('/addToWatch', authenticate.verifyUser, async (req, res, next) => {
  try {
    await moviewatchlist.findOneAndDelete({
      movieId: req.body.movieId,
      userFrom: req.user._id,
    });

    const runtime = await ensureMovieRuntime(req.body.movieId, req.body.movieRuntime);

    const watch = new Watch({
      ...req.body,
      userFrom: req.user._id,
      movieRuntime: runtime > 0 ? String(runtime) : req.body.movieRuntime || '',
      watchedAt: req.body.watchedAt || new Date(),
    });
    await watch.save();
    await invalidateUserStats(req.user._id);
    res.status(200).json({ success: true, watchedAt: watch.watchedAt || null });
  } catch (err) {
    res.status(400).json({ success: false, err });
  }
});

router.post('/removeFromWatched', authenticate.verifyUser, async (req, res, next) => {
  try {
    const doc = await Watch.findOneAndDelete({
      movieId: req.body.movieId,
      userFrom: req.user._id,
    });
    await invalidateUserStats(req.user._id);
    res.status(200).json({ success: true, doc });
  } catch (err) {
    res.status(400).json({ success: false, err });
  }
});

router.post('/getWatchMovie', authenticate.verifyUser, async (req, res, next) => {
  try {
    const watch = await Watch.find({ userFrom: req.user._id }).sort({
      watchedAt: -1,
      updatedAt: -1,
      createdAt: -1,
    });
    res.status(200).json({ success: true, watch });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
