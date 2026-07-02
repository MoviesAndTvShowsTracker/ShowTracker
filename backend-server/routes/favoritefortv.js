var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var FavoriteTv = require('../models/favoritefortv');
var authenticate = require('../authenticate');

router.use(bodyParser.json());

router.get('/', function (req, res) {
  res.send('respond with a resource');
});

router.post('/favoriteNumber', authenticate.verifyUser, async (req, res, next) => {
  try {
    const favorite = await FavoriteTv.find({ tvId: req.body.tvId });
    res.status(200).json({ success: true, favoriteNumber: favorite.length });
  } catch (err) {
    next(err);
  }
});

router.post('/favorited', authenticate.verifyUser, async (req, res, next) => {
  try {
    const favorite = await FavoriteTv.find({ tvId: req.body.tvId, userFrom: req.user._id });
    res.status(200).json({ success: true, favorited: favorite.length !== 0 });
  } catch (err) {
    next(err);
  }
});

router.post('/addToFavorite', authenticate.verifyUser, async (req, res, next) => {
  try {
    const favoritetv = new FavoriteTv({ ...req.body, userFrom: req.user._id });
    await favoritetv.save();
    res.status(200).json({ success: true });
  } catch (err) {
    res.status(400).json({ success: false, err });
  }
});

router.post('/removeFromFavorite', authenticate.verifyUser, async (req, res, next) => {
  try {
    const doc = await FavoriteTv.findOneAndDelete({
      tvId: req.body.tvId,
      userFrom: req.user._id,
    });
    res.status(200).json({ success: true, doc });
  } catch (err) {
    res.status(400).json({ success: false, err });
  }
});

router.post('/getFavoriteMovie', authenticate.verifyUser, async (req, res, next) => {
  try {
    const favorites = await FavoriteTv.find({ userFrom: req.user._id });
    res.status(200).json({ success: true, favorites });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
