var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var TvWatch = require('../models/tvwatch');
var FavoriteTv = require('../models/favoritefortv');
var authenticate = require('../authenticate');

router.use(bodyParser.json());

router.post('/watched', authenticate.verifyUser, async (req, res, next) => {
  try {
    const watch = await TvWatch.find({ tvId: req.body.tvId, userFrom: req.user._id });
    res.status(200).json({ success: true, watched: watch.length !== 0 });
  } catch (err) {
    next(err);
  }
});

router.post('/getWatchTv', authenticate.verifyUser, async (req, res, next) => {
  try {
    const userId = req.user._id;
    const favorites = await FavoriteTv.find({ userFrom: userId });

    await Promise.all(
      favorites.map((fav) =>
        TvWatch.findOneAndUpdate(
          { tvId: fav.tvId, userFrom: userId },
          {
            userFrom: userId,
            tvId: fav.tvId,
            tvTitle: fav.tvTitle,
            tvImage: fav.tvImage,
            tvPosterImage: fav.tvPosterImage,
            tvRuntime: fav.tvRuntime,
          },
          { upsert: true }
        )
      )
    );

    const watch = await TvWatch.find({ userFrom: userId });
    res.status(200).json({ success: true, watch });
  } catch (err) {
    next(err);
  }
});

router.post('/removeFromWatched', authenticate.verifyUser, async (req, res, next) => {
  try {
    const doc = await TvWatch.findOneAndDelete({
      tvId: req.body.tvId,
      userFrom: req.user._id,
    });
    res.status(200).json({ success: true, doc });
  } catch (err) {
    res.status(400).json({ success: false, err });
  }
});

module.exports = router;
