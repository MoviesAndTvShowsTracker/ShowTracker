const express = require('express');
const authenticate = require('../authenticate');
const { buildHomeFeed } = require('../services/homeFeed');
const { resolveTimeZone } = require('../services/statsCalendar');

const router = express.Router();

router.get('/', authenticate.verifyUser, async (req, res, next) => {
  try {
    const timeZone = resolveTimeZone(req.query.tz || req.headers['x-timezone']);
    const feed = await buildHomeFeed(req.user._id, { timeZone });
    res.status(200).json({ success: true, ...feed });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
