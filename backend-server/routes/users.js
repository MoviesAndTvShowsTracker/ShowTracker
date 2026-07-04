var express = require('express');
const bodyParser = require('body-parser');
var router = express.Router();
var User = require('../models/user');
var passport = require('passport');
var authenticate = require('../authenticate');
const { verifyGoogleIdToken, findOrCreateGoogleUser } = require('../lib/googleAuth');
const { uniqueUsername, normalizeEmail, findUserByEmail } = require('../lib/userHelpers');
const { sendPasswordResetEmail } = require('../lib/mail');
const {
  RESET_GENERIC_MESSAGE,
  generateResetToken,
  hashResetToken,
  buildResetUrl,
  setPassword,
} = require('../lib/passwordReset');

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

router.post('/forgot-password', async (req, res, next) => {
  try {
    const normalizedEmail = normalizeEmail(req.body.email);
    if (!normalizedEmail) {
      return res.status(400).json({ success: false, message: 'Email is required.' });
    }

    const user = await findUserByEmail(normalizedEmail);
    let emailDispatched = false;

    if (user) {
      const { raw, hash, expires } = generateResetToken();
      user.resetPasswordToken = hash;
      user.resetPasswordExpires = expires;
      await user.save();

      try {
        await sendPasswordResetEmail({
          to: user.email,
          resetUrl: buildResetUrl(raw),
        });
        emailDispatched = true;
      } catch (mailErr) {
        user.resetPasswordToken = undefined;
        user.resetPasswordExpires = undefined;
        await user.save();
        console.error('[forgot-password] email failed:', mailErr.message);
        return res.status(mailErr.status || 502).json({
          success: false,
          message: 'Could not send reset email. Try again later.',
        });
      }
    }

    return res.status(200).json({
      success: true,
      emailDispatched,
      message: emailDispatched
        ? 'Check your inbox for a password reset link. It expires in 1 hour.'
        : RESET_GENERIC_MESSAGE,
    });
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
    await user.save();

    return res.status(200).json({ success: true, message: 'Password updated. You can sign in now.' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
