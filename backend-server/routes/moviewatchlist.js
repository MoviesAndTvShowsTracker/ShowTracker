var express = require('express');
const bodyParser = require('body-parser');
const moviewatchlist = require('../models/moviewatchlist');
var router = express.Router();
router.use(bodyParser.json());

router.get('/', function(req, res, next) {
    res.send('respond with a resource');
  });

router.post('/watchlisted', (req, res) => {
    moviewatchlist.find({"movieId": req.body.movieId, "userFrom": req.body.userFrom})
    .exec((err, watch) => {
        if(err) return res.status(400).send(err);
        
        let result = false;
        if(watch.length !== 0)
        {
            result = true;
        }
        res.status(200).json({success: true, watchlisted: result })
    })
});

router.post('/addToWatchlist', (req, res) => {
    //save the info of movie
    const watchlist = new moviewatchlist(req.body);
    watchlist.save((err, doc) => {
        if(err) return res.json({success: false, err })
        return res.status(200).json({ success: true })
    })
});

router.post('/removeFromWatchlist', (req, res) => {
    moviewatchlist.findOneAndDelete({ movieId: req.body.movieId, userFrom: req.body.userFrom })
    .exec((err, doc) => {
        if(err) return res.status(400).json({success: false, err })
        res.status(200).json({success: true, doc});
    })
});


module.exports = router;