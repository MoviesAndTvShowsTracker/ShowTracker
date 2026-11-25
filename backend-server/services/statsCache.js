const UserStatsCache = require('../models/userStatsCache');

const REBUILD_EVERY_MS = 60 * 1000;

async function getCachedUserStats(userId) {
  const row = await UserStatsCache.findOne({ userFrom: userId }).lean();
  if (!row?.stats) return null;
  return { stats: row.stats, builtAt: row.builtAt, staleAt: row.staleAt || null };
}

/** `builtAt` = when the build STARTED, so a write during the build still leaves it stale. */
async function saveCachedUserStats(userId, stats, builtAt = new Date()) {
  await UserStatsCache.findOneAndUpdate(
    { userFrom: userId },
    { stats, builtAt },
    { upsert: true, new: true }
  );
  return builtAt;
}

function isStale(cached) {
  return Boolean(cached?.staleAt && cached.builtAt && new Date(cached.staleAt) > new Date(cached.builtAt));
}

/**
 * 'serve' (fresh) · 'serve-and-rebuild' (stale: answer now, rebuild behind, at most once a minute)
 * · 'serve-stale' (stale, a rebuild started under a minute ago: answer now, flagged stale)
 * · 'build' (missing, other timezone or payload version, or a forced refresh).
 */
function statsCacheDecision({ cached, timeZone, schemaVersion, forceRefresh, now = new Date(), lastRebuildAt = null }) {
  if (forceRefresh) return 'build';
  if (!cached?.stats) return 'build';
  if (cached.stats.timeZone !== timeZone || cached.stats.schemaVersion !== schemaVersion) return 'build';
  if (!isStale(cached)) return 'serve';
  if (lastRebuildAt && now - lastRebuildAt < REBUILD_EVERY_MS) return 'serve-stale';
  return 'serve-and-rebuild';
}

/** Marks the cache stale instead of deleting it, so Stats can still answer instantly. */
async function invalidateUserStats(userId) {
  await UserStatsCache.updateOne({ userFrom: userId }, { $set: { staleAt: new Date() } });
}

module.exports = {
  isStale,
  statsCacheDecision,
  getCachedUserStats,
  saveCachedUserStats,
  invalidateUserStats,
};
