var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var User = require('../models/user');
var passport = require('passport');
var authenticate = require('../authenticate');
const { deleteAccountData } = require('../services/accountDeletion');
const { requestPasswordReset } = require('../services/passwordResetFlow');
const { verifyGoogleIdToken, findOrCreateGoogleUser } = require('../lib/googleAuth');
const { verifyAppleIdentityToken, findOrCreateAppleUser } = require('../lib/appleAuth');
const {
  uniqueUsername,
  normalizeEmail,
  findUserByEmail,
  emailTakenFilter,
  profileEmailUpdate,
  canReadProfile,
  publicProfile,
} = require('../lib/userHelpers');
const { hashResetToken, setPassword } = require('../lib/passwordReset');

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
    const normalizedEmail = normalizeEmail(email);
    if (!normalizedEmail || !password) {
      return res.status(400).json({ success: false, message: 'Email and password are required.' });
    }
    if (password.length < 6) {
      return res.status(400).json({ success: false, message: 'Password must be at least 6 characters.' });
    }

    const username = await uniqueUsername(normalizedEmail.split('@')[0]);

    User.register(
      new User({
        email: normalizedEmail,
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
    const message = String(err.message || '');
    if (/audience|wrong recipient/i.test(message)) {
      return res.status(401).json({ success: false, message: 'Google sign-in could not be verified.' });
    }
    return next(err);
  }
});

router.post('/apple', async (req, res, next) => {
  try {
    const { identityToken, nonce, fullName } = req.body;
    if (!identityToken) {
      return res.status(400).json({ success: false, message: 'Missing Apple sign-in token.' });
    }
    if (!nonce) {
      return res.status(400).json({ success: false, message: 'Missing Apple sign-in nonce.' });
    }

    const payload = await verifyAppleIdentityToken(identityToken, nonce);
    const name =
      fullName && (fullName.givenName || fullName.familyName)
        ? {
            givenName: fullName.givenName || '',
            familyName: fullName.familyName || '',
          }
        : null;
    const user = await findOrCreateAppleUser(payload, name);
    const token = authenticate.getToken({ _id: user._id });

    return res.status(200).json({
      success: true,
      token,
      userId: user._id,
      email: user.email,
      firstName: user.firstName || '',
      username: user.username,
      message: 'Signed in with Apple.',
    });
  } catch (err) {
    if (err.status) {
      return res.status(err.status).json({ success: false, message: err.message });
    }
    return next(err);
  }
});

router.post('/login', async (req, res, next) => {
  try {
    const user = await findUserByEmail(req.body.email);
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password',
      });
    }

    req.body.email = user.email;

    passport.authenticate('local', { session: false }, (err, authedUser, info) => {
      if (err) {
        return res.status(500).json({ success: false, message: 'Login failed. Please try again.' });
      }
      if (!authedUser) {
        return res.status(401).json({
          success: false,
          message: info?.message || 'Invalid email or password',
        });
      }

      const token = authenticate.getToken({ _id: authedUser._id });
      return res.status(200).json({
        status: 200,
        success: true,
        token,
        userId: authedUser._id,
        email: authedUser.email,
        firstName: authedUser.firstName || '',
        message: 'You are successfully logged in!',
      });
    })(req, res, next);
  } catch (err) {
    next(err);
  }
});

// Your own profile only: someone else's id answers 404, like an id that doesn't exist.
router.get('/getUser/:id', authenticate.verifyUser, (req, res) => {
  if (!canReadProfile(req.user._id, req.params.id)) {
    return res.status(404).json({ success: false, message: 'Not found.' });
  }
  return res.status(200).json({ success: true, found: publicProfile(req.user) });
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
    return res.status(200).json({ success: true, docs: publicProfile(docs) });
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

    // Unique regardless of case, so nobody can hold "Victim@x.com" beside "victim@x.com".
    const emailTaken = await User.findOne(emailTakenFilter(email, req.user._id));
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
        firstName: String(firstName ?? '').trim(),
        lastName: String(lastName ?? '').trim(),
        // Stored lowercase; a new address is unproven until a reset link or a provider confirms it.
        ...profileEmailUpdate(req.user, email),
        phonenumber: phone || '',
      },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    return res.status(200).json({ success: true, user: publicProfile(updated) });
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

  req.user.changePassword(currentPassword, newPassword, async (err) => {
    if (err) {
      return res.status(400).json({ success: false, message: 'Current password is incorrect.' });
    }
    // Sessions on other devices end; this device gets a fresh token.
    req.user.passwordChangedAt = new Date();
    await req.user.save();
    const token = authenticate.getToken({ _id: req.user._id });
    return res.status(200).json({ success: true, message: 'Password updated.', token });
  });
});

// Same answer for every address, sent before any lookup, so it never reveals who has an account.
router.post('/forgot-password', async (req, res, next) => {
  try {
    const body = await requestPasswordReset(req.body.email);
    return res.status(200).json(body);
  } catch (err) {
    next(err);
  }
});

router.delete('/me', authenticate.verifyUser, async (req, res, next) => {
  try {
    // Every collection with a userFrom field (found from the models), then the account itself.
    await deleteAccountData(req.user._id);
    return res.status(200).json({ success: true, message: 'Account deleted.' });
  } catch (err) {
    next(err);
  }
});

router.post('/reset-password', async (req, res, next) => {
  try {
    const { token, newPassword } = req.body;
    if (!token?.trim()) {
      return res.status(400).json({ success: false, message: 'Reset token is required.' });
    }
    if (!newPassword || newPassword.length < 6) {
      return res.status(400).json({ success: false, message: 'Password must be at least 6 characters.' });
    }

    const tokenHash = hashResetToken(token.trim());
    const user = await User.findOne({
      resetPasswordToken: tokenHash,
      resetPasswordExpires: { $gt: new Date() },
    }).select('+resetPasswordToken +resetPasswordExpires');

    if (!user) {
      return res.status(400).json({
        success: false,
        message: 'This reset link is invalid or has expired. Request a new one.',
      });
    }

    await setPassword(user, newPassword);
    user.resetPasswordToken = undefined;
    user.resetPasswordExpires = undefined;
    // The emailed link proves the address; every older session ends.
    user.emailVerified = true;
    user.passwordChangedAt = new Date();
    await user.save();

    return res.status(200).json({ success: true, message: 'Password updated. You can sign in now.' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
