const TvShowTracking = require('../models/tvShowTracking');
const TvEpisodeWatch = require('../models/tvEpisodeWatch');
const { normTvId } = require('./tvWatchlistService');

const TRACKED_STATUSES = ['watching', 'paused', 'completed'];

function findTrackingInList(rows, tvId) {
  const target = normTvId(tvId);
  return rows.find((row) => normTvId(row.tvId) === target) || null;
}

async function findTracking(userId, tvId) {
  const rows = await TvShowTracking.find({ userFrom: userId });
  return findTrackingInList(rows, tvId);
}

async function getWatchedEpisodesForShow(userId, tvId) {
  const target = normTvId(tvId);
  const rows = await TvEpisodeWatch.find({ userFrom: userId });
  return rows
    .filter((row) => normTvId(row.tvId) === target)
    .sort((a, b) => a.seasonNumber - b.seasonNumber || a.episodeNumber - b.episodeNumber);
}

async function deleteWatchedEpisode(userId, tvId, seasonNumber, episodeNumber) {
  const target = normTvId(tvId);
  const rows = await TvEpisodeWatch.find({ userFrom: userId, seasonNumber, episodeNumber });
  const ids = rows.filter((row) => normTvId(row.tvId) === target).map((row) => row._id);
  if (ids.length) await TvEpisodeWatch.deleteMany({ _id: { $in: ids } });
}

async function deleteWatchedEpisodes(userId, tvId, episodes) {
  await Promise.all(
    episodes.map((ep) =>
      deleteWatchedEpisode(userId, tvId, ep.seasonNumber, ep.episodeNumber)
    )
  );
}

/** Return tracking for a show, or null if none / no watched episodes left. */
async function resolveShowTracking(userId, tvId) {
  const watched = await getWatchedEpisodesForShow(userId, tvId);
  const tracking = await findTracking(userId, tvId);

  if (!tracking) return null;

  if (watched.length === 0) {
    await TvShowTracking.deleteOne({ _id: tracking._id });
    return null;
  }

  return tracking;
}

module.exports = {
  TRACKED_STATUSES,
  findTracking,
  getWatchedEpisodesForShow,
  deleteWatchedEpisode,
  deleteWatchedEpisodes,
  resolveShowTracking,
};
