var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var User = require('../models/user');
var passport = require('passport');
var authenticate = require('../authenticate');
const { verifyGoogleIdToken, findOrCreateGoogleUser } = require('../lib/googleAuth');
const { uniqueUsername } = require('../lib/userHelpers');

router.use(bodyParser.json());

function signupErrorMessage(err) {
  if (err?.name === 'UserExistsError') {
    return 'That email is already registered.';
  }
  if (err?.code === 11000) {
    if (err.keyPattern?.email) return 'That email is already registered.';
    if (err.keyPattern?.username) return 'That email is already registered.';
  }
  return err?.message || 'Registration failed.';
}

router.get('/', function(req, res, next) {
  res.send('respond with a resource');
});

router.post('/signup', async (req, res, next) => {
  try {
    const { email, password } = req.body;
    if (!email?.trim() || !password) {
      return res.status(400).json({ success: false, message: 'Email and password are required.' });
    }
    if (password.length < 6) {
      return res.status(400).json({ success: false, message: 'Password must be at least 6 characters.' });
    }

    const username = await uniqueUsername(email.trim().split('@')[0]);

    User.register(
      new User({
        email: email.trim(),
        username,
      }),
      password,
      (err, user) => {
        if (err) {
          res.statusCode = 400;
          res.setHeader('Content-Type', 'application/json');
          return res.json({ success: false, err: signupErrorMessage(err) });
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
  } catch (err) {
    next(err);
  }
});

router.post('/google', async (req, res, next) => {
  try {
    const { idToken } = req.body;
    if (!idToken) {
      return res.status(400).json({ success: false, message: 'Missing Google sign-in token.' });
    }

    const payload = await verifyGoogleIdToken(idToken);
    const user = await findOrCreateGoogleUser(payload);
    const token = authenticate.getToken({ _id: user._id });

    return res.status(200).json({
      success: true,
      token,
      userId: user._id,
      email: user.email,
      firstName: user.firstName || '',
      username: user.username,
      message: 'Signed in with Google.',
    });
  } catch (err) {
    if (err.status) {
      return res.status(err.status).json({ success: false, message: err.message });
    }
    return next(err);
  }
});

router.post('/login', (req, res, next) => {
  passport.authenticate('local', { session: false }, (err, user, info) => {
    if (err) {
      return res.status(500).json({ success: false, message: 'Login failed. Please try again.' });
    }
    if (!user) {
      return res.status(401).json({
        success: false,
        message: info?.message || 'Invalid email or password',
      });
    }

    const token = authenticate.getToken({ _id: user._id });
    return res.status(200).json({
      status: 200,
      success: true,
      token,
      userId: user._id,
      email: user.email,
      firstName: user.firstName || '',
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

router.post('/updateProfile', authenticate.verifyUser, async (req, res, next) => {
  try {
    const { firstName, lastName, email, phonenumber } = req.body;
    if (!email?.trim()) {
      return res.status(400).json({ success: false, message: 'Email is required.' });
    }

    const emailTaken = await User.findOne({
      email: email.trim(),
      _id: { $ne: req.user._id },
    });
    if (emailTaken) {
      return res.status(400).json({ success: false, message: 'That email is already in use.' });
    }

    const phone = phonenumber ? String(phonenumber).replace(/\D/g, '') : '';
    if (phone && phone.length !== 10) {
      return res.status(400).json({ success: false, message: 'Phone must be 10 digits.' });
    }

    const updated = await User.findByIdAndUpdate(
      req.user._id,
      {
        firstName: firstName?.trim() || '',
        lastName: lastName?.trim() || '',
        email: email.trim(),
        phonenumber: phone || '',
      },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    return res.status(200).json({ success: true, user: updated });
  } catch (err) {
    next(err);
  }
});

router.post('/changePassword', authenticate.verifyUser, (req, res) => {
  const { currentPassword, newPassword } = req.body;

  if (!currentPassword || !newPassword) {
    return res.status(400).json({ success: false, message: 'Current and new password are required.' });
  }
  if (newPassword.length < 6) {
    return res.status(400).json({ success: false, message: 'New password must be at least 6 characters.' });
  }

  req.user.changePassword(currentPassword, newPassword, (err) => {
    if (err) {
      return res.status(400).json({ success: false, message: 'Current password is incorrect.' });
    }
    return res.status(200).json({ success: true, message: 'Password updated.' });
  });
});

module.exports = router;
