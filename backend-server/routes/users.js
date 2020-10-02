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

  //console.log("From front-end : " + req.body.username);

  User.register(new User({ username: req.body.username, firstName: req.body.firstName, lastName: req.body.lastName, email: req.body.email }),
   req.body.password, (err, user) => {
    if(err) {
      res.statusCode = 500;
      res.setHeader('Content-Type', 'application/json');
      res.json({err: err});
    }
    else {
        passport.authenticate('local')(req, res, () => {
        res.setHeader('Content-Type', 'application/json');
 
        res.json({
          status: 200,
          message: 'Registration Successful!'
        })


        res.send();

      });
    }
  });
});

router.post('/login', passport.authenticate('local'), (req, res) => {
  var token = authenticate.getToken({_id: req.user._id});
  res.setHeader('Content-Type', 'application/json');
  res.json({status: 200, token: token, message: 'You are successfully logged in!'});

  res.send();

});

router.get('/logout', (req, res) => {
  req.logout();
  localStorage.removeItem("user");
  res.redirect('/');
  
});

module.exports = router;
