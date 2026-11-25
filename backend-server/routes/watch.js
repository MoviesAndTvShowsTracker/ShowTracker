var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
const mongoose = require('mongoose');
var Watch = require('../models/watch');
const { parseWatchedAt, parseNote } = require('../lib/diaryInput');
const moviewatchlist = require('../models/moviewatchlist');
var authenticate = require('../authenticate');
const { ensureMovieRuntime } = require('../services/mediaMeta');
const { invalidateUserStats } = require('../services/statsCache');
const { normalizeRating } = require('../services/ratings');
const {
  watchedSummary,
  addFilmPlay,
  removeLatestPlay,
  removeAllPlays,
  rateLatestPlay,
  libraryFilmsFromPlays,
  updatePlay,
} = require('../services/filmWatchService');

router.use(bodyParser.json());

router.get('/', function (req, res) {
  res.send('respond with a resource');
});

router.post('/watched', authenticate.verifyUser, async (req, res, next) => {
  try {
    const summary = await watchedSummary(req.user._id, req.body.movieId);
    res.status(200).json({
      success: true,
      watched: summary.watched,
      watchCount: summary.watchCount,
      watchedAt: summary.watchedAt,
      rating: summary.rating,
      isRewatch: summary.isRewatch,
      latestPlayId: summary.latestPlayId,
      note: summary.note,
      plays: summary.plays,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * Append a dated play. If the film was already watched, this creates a rewatch
 * and leaves every earlier play's watchedAt untouched.
 */
router.post('/addToWatch', authenticate.verifyUser, async (req, res, next) => {
  try {
    await moviewatchlist.findOneAndDelete({
      movieId: req.body.movieId,
      userFrom: req.user._id,
    });

    const runtime = await ensureMovieRuntime(req.body.movieId, req.body.movieRuntime);
    const movieRuntime = runtime > 0 ? String(runtime) : req.body.movieRuntime || '';

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

    const fields = {
      movieId: req.body.movieId,
      movieTitle: req.body.movieTitle,
      movieImage: req.body.movieImage,
      moviePosterImage: req.body.moviePosterImage,
      movieRuntime,
      watchedAt,
      note,
    };
    if (req.body.rating !== undefined) fields.rating = rating;

    const { play, summary } = await addFilmPlay(req.user._id, fields);
    await invalidateUserStats(req.user._id);
    res.status(200).json({
      success: true,
      watchedAt: play.watchedAt || null,
      rating: summary.rating,
      watchCount: summary.watchCount,
      isRewatch: Boolean(play.isRewatch),
      playId: play._id ? String(play._id) : null,
      plays: summary.plays,
    });
  } catch (err) {
    res.status(400).json({ success: false, err });
  }
});

/** Change the date and/or note of one of your film logs. */
router.post('/play/update', authenticate.verifyUser, async (req, res, next) => {
  try {
    if (!mongoose.isValidObjectId(req.body.playId)) {
      return res.status(400).json({ success: false, message: 'Unknown log.' });
    }
    let watchedAt;
    let note;
    try {
      watchedAt = req.body.watchedAt === undefined ? undefined : parseWatchedAt(req.body.watchedAt);
      note = parseNote(req.body.note);
    } catch (err) {
      return res.status(400).json({ success: false, message: err.message });
    }
    const result = await updatePlay(req.user._id, req.body.playId, { watchedAt, note });
    if (!result) return res.status(404).json({ success: false, message: 'Log not found.' });
    await invalidateUserStats(req.user._id);
    const { summary } = result;
    res.status(200).json({
      success: true,
      watched: summary.watched,
      watchCount: summary.watchCount,
      watchedAt: summary.watchedAt,
      rating: summary.rating,
      isRewatch: summary.isRewatch,
      latestPlayId: summary.latestPlayId,
      note: summary.note,
      plays: summary.plays,
    });
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

    const watch = await rateLatestPlay(req.user._id, req.body.movieId, rating);
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

/**
 * Body.mode:
 * - "latest" (default): remove only the newest play — earlier dates stay.
 * - "all": clear every play for this film.
 */
router.post('/removeFromWatched', authenticate.verifyUser, async (req, res, next) => {
  try {
    const mode = req.body.mode === 'all' ? 'all' : 'latest';
    let payload;
    if (mode === 'all') {
      payload = await removeAllPlays(req.user._id, req.body.movieId);
    } else {
      payload = await removeLatestPlay(req.user._id, req.body.movieId);
    }
    await invalidateUserStats(req.user._id);
    res.status(200).json({
      success: true,
      mode,
      deletedCount: payload.deletedCount ?? (payload.removed ? 1 : 0),
      watched: payload.summary.watched,
      watchCount: payload.summary.watchCount,
      watchedAt: payload.summary.watchedAt,
      rating: payload.summary.rating,
      isRewatch: payload.summary.isRewatch,
      doc: payload.removed || null,
    });
  } catch (err) {
    res.status(400).json({ success: false, err });
  }
});

/** Unique films for library rails (one tile per movieId + watchCount). */
async function getWatchMovie(req, res, next) {
  try {
    const plays = await Watch.find({ userFrom: req.user._id })
      .sort({ watchedAt: -1, updatedAt: -1, createdAt: -1 })
      .lean();
    const watch = libraryFilmsFromPlays(plays);
    res.status(200).json({ success: true, watch });
  } catch (err) {
    next(err);
  }
}

// Read with GET (cacheable, safe to retry); POST kept for older app builds.
router.get('/getWatchMovie', authenticate.verifyUser, getWatchMovie);
router.post('/getWatchMovie', authenticate.verifyUser, getWatchMovie);

module.exports = router;
