var express = require('express');
var router = express.Router();
var authenticate = require('../authenticate');
const {
  buildUserStatsDashboard,
  STATS_SCHEMA_VERSION,
} = require('../services/userStatsDashboard');
const {
  getCachedUserStats,
  saveCachedUserStats,
} = require('../services/statsCache');
const { buildWeekRecap } = require('../services/weekRecap');
const { resolveTimeZone } = require('../services/statsCalendar');

function requestTimeZone(req) {
  return resolveTimeZone(req.query.tz || req.headers['x-timezone']);
}

router.get('/week-recap', authenticate.verifyUser, async (req, res, next) => {
  try {
    const timeZone = requestTimeZone(req);
    const recap = await buildWeekRecap(req.user._id, { timeZone });
    res.status(200).json({ success: true, recap });
  } catch (err) {
    next(err);
  }
});

router.get('/dashboard', authenticate.verifyUser, async (req, res, next) => {
  try {
    const userId = req.user._id;
    const forceRefresh = req.query.refresh === '1';
    const timeZone = requestTimeZone(req);

    if (!forceRefresh) {
      const cached = await getCachedUserStats(userId);
      // Rebuild when the timezone or payload contract changed
      if (
        cached?.stats &&
        cached.stats.timeZone === timeZone &&
        cached.stats.schemaVersion === STATS_SCHEMA_VERSION
      ) {
        return res.status(200).json({
          success: true,
          stats: cached.stats,
          cached: true,
          builtAt: cached.builtAt,
        });
      }
    }

    const started = Date.now();
    const stats = await buildUserStatsDashboard(userId, { timeZone });
    const builtAt = await saveCachedUserStats(userId, stats);

    if (process.env.NODE_ENV !== 'production') {
      console.log(`[stats] built ${userId} ${Date.now() - started}ms tz=${timeZone}`);
    }

    res.status(200).json({ success: true, stats, cached: false, builtAt });
  } catch (err) {
    console.error('[stats] dashboard error', err.message);
    next(err);
  }
});

module.exports = router;
