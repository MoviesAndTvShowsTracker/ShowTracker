var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var Watch = require('../models/watch');
const moviewatchlist = require('../models/moviewatchlist');
var authenticate = require('../authenticate');

router.use(bodyParser.json());

router.get('/', function (req, res) {
  res.send('respond with a resource');
});

router.post('/watched', authenticate.verifyUser, async (req, res, next) => {
  try {
    const watch = await Watch.find({ movieId: req.body.movieId, userFrom: req.user._id });
    res.status(200).json({ success: true, watched: watch.length !== 0 });
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

    const watch = new Watch({ ...req.body, userFrom: req.user._id });
    await watch.save();
    res.status(200).json({ success: true });
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
    res.status(200).json({ success: true, doc });
  } catch (err) {
    res.status(400).json({ success: false, err });
  }
});

router.post('/getWatchMovie', authenticate.verifyUser, async (req, res, next) => {
  try {
    const watch = await Watch.find({ userFrom: req.user._id });
    res.status(200).json({ success: true, watch });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
