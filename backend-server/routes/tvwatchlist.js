var express = require('express');
const bodyParser = require('body-parser');
const tvwatchlist = require('../models/tvwatchlist');
var router = express.Router();
var authenticate = require('../authenticate');

router.use(bodyParser.json());

router.get('/', function (req, res) {
  res.send('respond with a resource');
});

router.post('/watchlisted', authenticate.verifyUser, async (req, res, next) => {
  try {
    const watch = await tvwatchlist.find({ tvId: req.body.tvId, userFrom: req.user._id });
    res.status(200).json({ success: true, watchlisted: watch.length !== 0 });
  } catch (err) {
    next(err);
  }
});

router.post('/addToWatchlist', authenticate.verifyUser, async (req, res, next) => {
  try {
    const watchlist = new tvwatchlist({ ...req.body, userFrom: req.user._id });
    await watchlist.save();
    res.status(200).json({ success: true });
  } catch (err) {
    res.status(400).json({ success: false, err });
  }
});

router.post('/removeFromWatchlist', authenticate.verifyUser, async (req, res, next) => {
  try {
    const doc = await tvwatchlist.findOneAndDelete({
      tvId: req.body.tvId,
      userFrom: req.user._id,
    });
    res.status(200).json({ success: true, doc });
  } catch (err) {
    res.status(400).json({ success: false, err });
  }
});

router.post('/getTvWatchlist', authenticate.verifyUser, async (req, res, next) => {
  try {
    const watchlist = await tvwatchlist.find({ userFrom: req.user._id }).sort({
      updatedAt: -1,
      createdAt: -1,
      _id: -1,
    });
    res.status(200).json({ success: true, watchlist });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
