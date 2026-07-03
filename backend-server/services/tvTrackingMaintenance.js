const TvShowTracking = require('../models/tvShowTracking');

const STALE_DAYS = 90;
const STALE_MS = STALE_DAYS * 24 * 60 * 60 * 1000;

function isCaughtUpWaiting(track) {
  const aired = track.airedEpisodeCount || 0;
  const total = track.totalEpisodes || 0;
  const watched = track.watchedEpisodeCount || 0;
  return aired > 0 && watched >= aired && total > aired;
}

function isFullyFinished(track) {
  const total = track.totalEpisodes || 0;
  return track.status === 'completed' || (total > 0 && track.watchedEpisodeCount >= total);
}

/** Move inactive shows to paused (stopped) unless caught up or finished. */
async function autoPauseStaleTracks(userId) {
  const cutoff = new Date(Date.now() - STALE_MS);
  const stale = await TvShowTracking.find({
    userFrom: userId,
    status: 'watching',
    $or: [
      { lastWatchedAt: { $ne: null, $lt: cutoff } },
      { lastWatchedAt: null, updatedAt: { $lt: cutoff } },
    ],
  });

  let paused = 0;
  for (const track of stale) {
    if (isCaughtUpWaiting(track) || isFullyFinished(track)) continue;
    track.status = 'paused';
    await track.save();
    paused += 1;
  }
  return paused;
}

async function getLibraryCounts(userId) {
  const [watching, paused, completed] = await Promise.all([
    TvShowTracking.countDocuments({ userFrom: userId, status: 'watching' }),
    TvShowTracking.countDocuments({ userFrom: userId, status: 'paused' }),
    TvShowTracking.countDocuments({ userFrom: userId, status: 'completed' }),
  ]);
  return { watching, paused, completed };
}

function mapTabToStatus(tab) {
  if (tab === 'stopped') return 'paused';
  if (tab === 'finished') return 'completed';
  return 'watching';
}

module.exports = {
  STALE_DAYS,
  isCaughtUpWaiting,
  isFullyFinished,
  autoPauseStaleTracks,
  getLibraryCounts,
  mapTabToStatus,
};
