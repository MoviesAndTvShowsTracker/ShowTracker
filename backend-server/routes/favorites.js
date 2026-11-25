var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var Favorite = require('../models/favorite');
var Watch = require('../models/watch');
const moviewatchlist = require('../models/moviewatchlist');
var authenticate = require('../authenticate');

router.use(bodyParser.json());

router.get('/', function (req, res) {
  res.send('respond with a resource');
});

router.post('/favoriteNumber', authenticate.verifyUser, async (req, res, next) => {
  try {
    const favorite = await Favorite.find({ movieId: req.body.movieId });
    res.status(200).json({ success: true, favoriteNumber: favorite.length });
  } catch (err) {
    next(err);
  }
});

router.post('/favorited', authenticate.verifyUser, async (req, res, next) => {
  try {
    const favorite = await Favorite.find({ movieId: req.body.movieId, userFrom: req.user._id });
    res.status(200).json({ success: true, favorited: favorite.length !== 0 });
  } catch (err) {
    next(err);
  }
});

router.post('/addToFavorite', authenticate.verifyUser, async (req, res, next) => {
  try {
    const userId = req.user._id;
    const data = { ...req.body, userFrom: userId };

    await moviewatchlist.findOneAndDelete({ movieId: req.body.movieId, userFrom: userId });

    await Favorite.findOneAndUpdate(
      { movieId: req.body.movieId, userFrom: userId },
      { ...data, favoritedAt: data.favoritedAt || new Date() },
      { upsert: true, new: true }
    );

    res.status(200).json({ success: true });
  } catch (err) {
    res.status(400).json({ success: false, err });
  }
});

router.post('/removeFromFavorite', authenticate.verifyUser, async (req, res, next) => {
  try {
    const userId = req.user._id;
    const query = { movieId: req.body.movieId, userFrom: userId };

    const doc = await Favorite.findOneAndDelete(query);

    res.status(200).json({ success: true, doc });
  } catch (err) {
    res.status(400).json({ success: false, err });
  }
});

async function getFavoriteMovie(req, res, next) {
  try {
    const favorites = await Favorite.find({ userFrom: req.user._id })
      .sort({
        favoritedAt: -1,
        updatedAt: -1,
        createdAt: -1,
      })
      .lean();

    const movieIds = favorites.map((f) => f.movieId).filter(Boolean);
    const watches = movieIds.length
      ? await Watch.find({
          userFrom: req.user._id,
          movieId: { $in: movieIds },
        })
          .select('movieId rating watchedAt updatedAt createdAt')
          .lean()
      : [];
    const { ratingByMovieId } = require('../services/filmWatchService');
    const ratingById = ratingByMovieId(watches);

    res.status(200).json({
      success: true,
      favorites: favorites.map((f) => ({
        ...f,
        rating: ratingById.get(String(f.movieId)) ?? null,
      })),
    });
  } catch (err) {
    next(err);
  }
}

// Read with GET (cacheable, safe to retry); POST kept for older app builds.
router.get('/getFavoriteMovie', authenticate.verifyUser, getFavoriteMovie);
router.post('/getFavoriteMovie', authenticate.verifyUser, getFavoriteMovie);

module.exports = router;
