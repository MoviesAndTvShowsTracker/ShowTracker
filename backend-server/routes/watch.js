var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var Watch = require('../models/watch');
const moviewatchlist = require('../models/moviewatchlist');

router.use(bodyParser.json());

router.get('/', function(req, res, next) {
    res.send('respond with a resource');
  });

router.post('/watched', (req, res) => {
    Watch.find({"movieId": req.body.movieId, "userFrom": req.body.userFrom})
    .exec((err, watch) => {
        if(err) return res.status(400).send(err);
        
        let result = false;
        if(watch.length !== 0)
        {
            result = true;
        }
        res.status(200).json({success: true, watched: result })
    })
});

router.post('/addToWatch', (req, res) => {
    //we can't have watchlist of watched movies, so it'll find the movie in watchlist if it exist, we delete and add movie to watched.
    moviewatchlist.findOneAndDelete({ movieId: req.body.movieId, userFrom: req.body.userFrom }, function (err, docs) {
        if (err){
            console.log(err)
        }
        else{
            console.log("Deleted movie from watchlist if found : ", docs);
        }
    })

    const watch = new Watch(req.body);
    watch.save((err, doc) => {
        if(err) return res.json({success: false, err })
        return res.status(200).json({ success: true })
    })
});

router.post('/removeFromWatched', (req, res) => {
    Watch.findOneAndDelete({ movieId: req.body.movieId, userFrom: req.body.userFrom })
    .exec((err, doc) => {
        if(err) return res.status(400).json({success: false, err })
        res.status(200).json({success: true, doc});
    })
});

router.post('/getWatchMovie', (req, res) => {
    Watch.find({'userFrom': req.body.userFrom})
    .exec((err, watch) => {
        if(err) return res.status(400).send(err);
        return res.status(200).json({ success: true, watch });
    })
});

module.exports = router;