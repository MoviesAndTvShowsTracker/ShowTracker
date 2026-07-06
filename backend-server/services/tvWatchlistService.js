const tvwatchlist = require('../models/tvwatchlist');
const TvShowTracking = require('../models/tvShowTracking');

const TRACKED_STATUSES = ['watching', 'paused', 'completed'];

function normTvId(id) {
  return String(id ?? '').trim();
}

/** Remove watchlist row(s) for a show — scans by string match so type/format never blocks delete. */
async function clearWatchlistForShow(userId, tvId) {
  const target = normTvId(tvId);
  if (!target) return;

  const rows = await tvwatchlist.find({ userFrom: userId }).select('_id tvId');
  const staleIds = rows.filter((row) => normTvId(row.tvId) === target).map((row) => row._id);
  if (staleIds.length) {
    await tvwatchlist.deleteMany({ _id: { $in: staleIds } });
  }
}

/** tvIds for shows already in Watching / Stopped / Finished (not watchlist). */
async function getInLibraryTvIds(userId) {
  const tracked = await TvShowTracking.find({
    userFrom: userId,
    status: { $in: TRACKED_STATUSES },
  }).select('tvId');

  return [...new Set(tracked.map((row) => normTvId(row.tvId)).filter(Boolean))];
}

/** Watchlist = queued only. Purges rows that belong in the TV library. */
async function getQueuedTvWatchlist(userId) {
  const [watchlist, inLibrary] = await Promise.all([
    tvwatchlist.find({ userFrom: userId }).sort({ updatedAt: -1, createdAt: -1, _id: -1 }),
    getInLibraryTvIds(userId),
  ]);

  const inLibrarySet = new Set(inLibrary);
  const kept = [];
  const staleIds = [];

  for (const row of watchlist) {
    if (inLibrarySet.has(normTvId(row.tvId))) {
      staleIds.push(row._id);
    } else {
      kept.push(row);
    }
  }

  if (staleIds.length) {
    await tvwatchlist.deleteMany({ _id: { $in: staleIds } });
  }

  return kept;
}

module.exports = {
  TRACKED_STATUSES,
  normTvId,
  clearWatchlistForShow,
  getInLibraryTvIds,
  getQueuedTvWatchlist,
};
