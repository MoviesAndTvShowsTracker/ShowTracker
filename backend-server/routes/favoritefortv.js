var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var  FavoriteTv = require('../models/favoritefortv');
var passport = require('passport');

var authenticate = require('../authenticate');

router.use(bodyParser.json());

router.get('/', function(req, res, next) {
    res.send('respond with a resource');
});

router.post('/favoriteNumber', (req, res) => {
    FavoriteTv.find({"tvId": req.body.tvId })
    .exec((err, favorite) => {
        if(err) return res.status(400).send(err);
        res.status(200).json({ success: true, favoriteNumber: favorite.length });
    })
});

router.post('/favorited', (req, res) => {
    FavoriteTv.find({"tvId": req.body.tvId, "userFrom": req.body.userFrom})
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
    //save the info of tv
    const favoritetv = new FavoriteTv(req.body);
    favoritetv.save((err, doc) => {
        if(err) return res.json({success: false, err })
        return res.status(200).json({ success: true })
    })
});

router.post('/removeFromFavorite', (req, res) => {
    FavoriteTv.findOneAndDelete({ tvId: req.body.tvId, userFrom: req.body.userFrom })
    .exec((err, doc) => {
        if(err) return res.status(400).json({success: false, err })
        res.status(200).json({success: true, doc});
    })
});

router.post('/getFavoriteMovie', (req, res) => {
    FavoriteTv.find({'userFrom': req.body.userFrom})
    .exec((err, favorites) => {
        if(err) return res.status(400).send(err);
        return res.status(200).json({ success: true, favorites });
    })
});

module.exports = router;