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
  statsCacheDecision,
} = require('../services/statsCache');
const { singleFlight } = require('../lib/singleFlight');

// Last background rebuild per user, so a stale cache rebuilds at most once a minute.
const lastRebuildAt = new Map();

/** One build per user and timezone at a time; concurrent requests share it. */
function rebuildStats(userId, timeZone) {
  return singleFlight(`stats:${userId}:${timeZone}`, async () => {
    const startedAt = new Date();
    const stats = await buildUserStatsDashboard(userId, { timeZone });
    const builtAt = await saveCachedUserStats(userId, stats, startedAt);
    if (process.env.NODE_ENV !== 'production') {
      console.log(`[stats] built ${userId} ${Date.now() - startedAt}ms tz=${timeZone}`);
    }
    return { stats, builtAt };
  });
}
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
    const key = String(userId);

    const cached = forceRefresh ? null : await getCachedUserStats(userId);
    const decision = statsCacheDecision({
      cached,
      timeZone,
      schemaVersion: STATS_SCHEMA_VERSION,
      forceRefresh,
      now: new Date(),
      lastRebuildAt: lastRebuildAt.get(key) || null,
    });

    if (decision !== 'build') {
      const stale = decision !== 'serve';
      if (decision === 'serve-and-rebuild') {
        lastRebuildAt.set(key, new Date());
        if (lastRebuildAt.size > 5000) lastRebuildAt.delete(lastRebuildAt.keys().next().value);
        rebuildStats(userId, timeZone).catch((err) => console.error('[stats] rebuild failed', err.message));
      }
      return res.status(200).json({
        success: true,
        stats: cached.stats,
        cached: true,
        stale,
        builtAt: cached.builtAt,
      });
    }

    const { stats, builtAt } = await rebuildStats(userId, timeZone);
    res.status(200).json({ success: true, stats, cached: false, builtAt });
  } catch (err) {
    console.error('[stats] dashboard error', err.message);
    next(err);
  }
});

module.exports = router;
