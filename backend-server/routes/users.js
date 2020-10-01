var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var User = require('../models/user');
var passport = require('passport');

var authenticate = require('../authenticate');

router.use(bodyParser.json());

/* GET users listing. */
router.get('/', function(req, res, next) {
  res.send('respond with a resource');
});

router.post('/signup', (req, res, next) => {

  User.register(new User({ username: req.body.username, firstName: req.body.firstName, lastName: req.body.lastName, email: req.body.email }),
   req.body.password, (err, user) => {
    if(err) {
      res.statusCode = 500;
      res.setHeader('Content-Type', 'application/json');
      res.json({err: err});
    }
    else {
        passport.authenticate('local')(req, res, () => {
        res.statusCode = 200;
        res.setHeader('Content-Type', 'application/json');
        //res.json({success: true, status: 'Registration Successful!'});

        var data = {
          success: true, 
          status: 'Registration Successful!'
        }
        res.send(JSON.stringify(data));

      });
    }
  });
});

router.post('/login', passport.authenticate('local'), (req, res) => {
  var token = authenticate.getToken({_id: req.user._id});
  res.statusCode = 200;
  res.setHeader('Content-Type', 'application/json');
  res.json({success: true, token: token, status: 'You are successfully logged in!'});
});

router.get('/logout', (req, res) => {
  req.logout();
  res.redirect('/');
  
});

module.exports = router;
