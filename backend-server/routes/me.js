const express = require('express');
const authenticate = require('../authenticate');
const { buildTvState, buildMovieState } = require('../services/userMediaState');

const router = express.Router();

/** The signed-in user's state for one show: favorite, watchlist, tracking, episodes, rewatch. */
router.get('/tv/:tvId', authenticate.verifyUser, async (req, res, next) => {
  try {
    const state = await buildTvState(req.user._id, String(req.params.tvId));
    res.status(200).json({ success: true, ...state });
  } catch (err) {
    next(err);
  }
});

/** The signed-in user's state for one film: favorite, watchlist, watch summary. */
router.get('/movie/:movieId', authenticate.verifyUser, async (req, res, next) => {
  try {
    const state = await buildMovieState(req.user._id, String(req.params.movieId));
    res.status(200).json({ success: true, ...state });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
