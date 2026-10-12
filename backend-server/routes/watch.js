var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var Watch = require('../models/watch');
var Favorite = require('../models/favorite');
const moviewatchlist = require('../models/moviewatchlist');
var authenticate = require('../authenticate');
const { ensureMovieRuntime } = require('../services/mediaMeta');
const { invalidateUserStats } = require('../services/statsCache');
const { normalizeRating } = require('../services/ratings');

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
      rating: watch?.rating ?? null,
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
    const watchedAt = req.body.watchedAt || new Date();
    const movieRuntime = runtime > 0 ? String(runtime) : req.body.movieRuntime || '';

    let rating;
    try {
      rating = normalizeRating(req.body.rating);
    } catch (err) {
      return res.status(400).json({ success: false, message: err.message });
    }

    const set = {
      movieId: req.body.movieId,
      movieTitle: req.body.movieTitle,
      movieImage: req.body.movieImage,
      moviePosterImage: req.body.moviePosterImage,
      movieRuntime,
      watchedAt,
      userFrom: req.user._id,
    };
    // Only touch rating when the client explicitly sent one; otherwise preserve.
    if (req.body.rating !== undefined) set.rating = rating;

    const watch = await Watch.findOneAndUpdate(
      { movieId: req.body.movieId, userFrom: req.user._id },
      { $set: set },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );
    await invalidateUserStats(req.user._id);
    res.status(200).json({
      success: true,
      watchedAt: watch.watchedAt || null,
      rating: watch.rating ?? null,
    });
  } catch (err) {
    res.status(400).json({ success: false, err });
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

    const watch = await Watch.findOneAndUpdate(
      { movieId: req.body.movieId, userFrom: req.user._id },
      { $set: { rating } },
      { new: true }
    );
    if (!watch) {
      return res
        .status(404)
        .json({ success: false, message: 'Mark this film watched before rating it.' });
    }
    await invalidateUserStats(req.user._id);
    res.status(200).json({ success: true, rating: watch.rating ?? null });
  } catch (err) {
    next(err);
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
