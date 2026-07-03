var express = require('express');
var router = express.Router();
var authenticate = require('../authenticate');
const { buildUserStatsDashboard } = require('../services/userStatsDashboard');
const {
  getCachedUserStats,
  saveCachedUserStats,
} = require('../services/statsCache');

router.get('/dashboard', authenticate.verifyUser, async (req, res, next) => {
  try {
    const userId = req.user._id;
    const forceRefresh = req.query.refresh === '1';

    if (!forceRefresh) {
      const cached = await getCachedUserStats(userId);
      if (cached) {
        return res.status(200).json({
          success: true,
          stats: cached.stats,
          cached: true,
          builtAt: cached.builtAt,
        });
      }
    }

    const started = Date.now();
    const stats = await buildUserStatsDashboard(userId);
    const builtAt = await saveCachedUserStats(userId, stats);

    if (process.env.NODE_ENV !== 'production') {
      console.log(`[stats] built ${userId} ${Date.now() - started}ms`);
    }

    res.status(200).json({ success: true, stats, cached: false, builtAt });
  } catch (err) {
    console.error('[stats] dashboard error', err.message);
    next(err);
  }
});

module.exports = router;
