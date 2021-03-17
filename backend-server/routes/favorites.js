var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var Favorite = require('../models/favorite');
var passport = require('passport');

var authenticate = require('../authenticate');

router.use(bodyParser.json());

router.get('/', function(req, res, next) {
    res.send('respond with a resource');
  });

router.post('/favoriteNumber', (req, res) => {
    Favorite.find({"movieId": req.body.movieId })
    .exec((err, favorite) => {
        if(err) return res.status(400).send(err);
        res.status(200).json({ success: true, favoriteNumber: favorite.length });
    })
});

router.post('/favorited', (req, res) => {
    Favorite.find({"movieId": req.body.movieId, "userFrom": req.body.userFrom})
    .exec((err, favorite) => {
        if(err) return res.status(400).send(err);
        
        let result = false;
        if(favorite.length !== 0)
        {
            result = true;
        }
        res.status(200).json({success: true, favorited: result })
    })
});

router.post('/addToFavorite', (req, res) => {
    //save the info of movie
    const favorite = new Favorite(req.body);
    favorite.save((err, doc) => {
        if(err) return res.json({success: false, err })
        return res.status(200).json({ success: true })
    })
});

router.post('/removeFromFavorite', (req, res) => {
    Favorite.findOneAndDelete({ movieId: req.body.movieId, userFrom: req.body.userFrom })
    .exec((err, doc) => {
        if(err) return res.status(400).json({success: false, err })
        res.status(200).json({success: true, doc});
    })
});

module.exports = router;