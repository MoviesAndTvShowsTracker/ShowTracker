var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var User = require('../models/user');
var passport = require('passport');
var authenticate = require('../authenticate');

router.use(bodyParser.json());

router.get('/', function(req, res, next) {
  res.send('respond with a resource');
});

router.post('/signup', (req, res, next) => {
  User.register(
    new User({
      username: req.body.username,
      firstName: req.body.firstName,
      lastName: req.body.lastName,
      email: req.body.email,
    }),
    req.body.password,
    (err, user) => {
      if (err) {
        res.statusCode = 500;
        res.setHeader('Content-Type', 'application/json');
        return res.json({ err: err });
      }

      passport.authenticate('local')(req, res, () => {
        res.setHeader('Content-Type', 'application/json');
        res.status(200).json({
          status: 200,
          success: true,
          message: 'Registration Successful!',
        });
      });
    }
  );
});

router.post('/login', (req, res, next) => {
  passport.authenticate('local', { session: false }, (err, user, info) => {
    if (err) {
      return res.status(500).json({ success: false, message: 'Login failed. Please try again.' });
    }
    if (!user) {
      return res.status(401).json({
        success: false,
        message: info?.message || 'Invalid username or password',
      });
    }

    const token = authenticate.getToken({ _id: user._id });
    return res.status(200).json({
      status: 200,
      success: true,
      token,
      userId: user._id,
      message: 'You are successfully logged in!',
    });
  })(req, res, next);
});

router.get('/getUser/:id', authenticate.verifyUser, (req, res) => {
  User.findById(req.params.id)
    .then((found) => {
      if (!found) {
        return res.status(404).send();
      }
      return res.status(200).json({ success: true, found });
    })
    .catch((err) => res.status(400).send(err));
});

router.get('/logout', (req, res) => {
  req.logout();
  res.status(200).json({ success: true, message: 'Successfully logged out' });
});

router.post('/updateOrAddPhone', authenticate.verifyUser, async (req, res, next) => {
  try {
    const docs = await User.findByIdAndUpdate(
      req.user._id,
      { phonenumber: req.body.inputValue },
      { new: true }
    );
    if (!docs) {
      return res.status(404).send();
    }
    return res.status(200).json({ success: true, docs });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
