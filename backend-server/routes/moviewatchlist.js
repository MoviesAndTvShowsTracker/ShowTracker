var express = require('express');
const bodyParser = require('body-parser');
const moviewatchlist = require('../models/moviewatchlist');
var router = express.Router();
var authenticate = require('../authenticate');

router.use(bodyParser.json());

router.get('/', function (req, res) {
  res.send('respond with a resource');
});

router.post('/watchlisted', authenticate.verifyUser, async (req, res, next) => {
  try {
    const watch = await moviewatchlist.find({
      movieId: req.body.movieId,
      userFrom: req.user._id,
    });
    res.status(200).json({ success: true, watchlisted: watch.length !== 0 });
  } catch (err) {
    next(err);
  }
});

router.post('/addToWatchlist', authenticate.verifyUser, async (req, res, next) => {
  try {
    const watchlist = new moviewatchlist({ ...req.body, userFrom: req.user._id });
    await watchlist.save();
    res.status(200).json({ success: true });
  } catch (err) {
    res.status(400).json({ success: false, err });
  }
});

router.post('/removeFromWatchlist', authenticate.verifyUser, async (req, res, next) => {
  try {
    const doc = await moviewatchlist.findOneAndDelete({
      movieId: req.body.movieId,
      userFrom: req.user._id,
    });
    res.status(200).json({ success: true, doc });
  } catch (err) {
    res.status(400).json({ success: false, err });
  }
});

router.post('/getMovieWatchlist', authenticate.verifyUser, async (req, res, next) => {
  try {
    const watchlist = await moviewatchlist.find({ userFrom: req.user._id });
    res.status(200).json({ success: true, watchlist });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
