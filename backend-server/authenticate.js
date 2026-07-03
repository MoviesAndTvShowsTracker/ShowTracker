var passport = require('passport');
var User = require('./models/user');

var JwtStrategy = require('passport-jwt').Strategy;
var ExtractJwt = require('passport-jwt').ExtractJwt;
var jwt = require('jsonwebtoken');

var config = require('./config/keys');

passport.use(User.createStrategy());
passport.serializeUser(User.serializeUser());
passport.deserializeUser(User.deserializeUser());

exports.getToken = function (user) {
  return jwt.sign(user, config.secret, { expiresIn: '365d' });
};

var opts = {
  jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
  secretOrKey: config.secret,
};

passport.use(
  new JwtStrategy(opts, async (jwt_payload, done) => {
    try {
      const user = await User.findById(jwt_payload._id);
      if (user) {
        return done(null, user);
      }
      return done(null, false);
    } catch (err) {
      return done(err, false);
    }
  })
);

exports.verifyUser = (req, res, next) => {
  passport.authenticate('jwt', { session: false }, (err, user) => {
    if (err) {
      return next(err);
    }
    if (!user) {
      return res.status(401).json({ success: false, message: 'Unauthorized' });
    }
    req.user = user;
    return next();
  })(req, res, next);
};
