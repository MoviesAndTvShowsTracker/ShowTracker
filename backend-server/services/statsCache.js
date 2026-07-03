const UserStatsCache = require('../models/userStatsCache');

async function getCachedUserStats(userId) {
  const row = await UserStatsCache.findOne({ userFrom: userId }).lean();
  if (!row?.stats) return null;
  return { stats: row.stats, builtAt: row.builtAt };
}

async function saveCachedUserStats(userId, stats) {
  const builtAt = new Date();
  await UserStatsCache.findOneAndUpdate(
    { userFrom: userId },
    { stats, builtAt },
    { upsert: true, new: true }
  );
  return builtAt;
}

async function invalidateUserStats(userId) {
  await UserStatsCache.deleteOne({ userFrom: userId });
}

module.exports = {
  getCachedUserStats,
  saveCachedUserStats,
  invalidateUserStats,
};
