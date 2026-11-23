const TvShowTracking = require('../models/tvShowTracking');
const TvRewatchSession = require('../models/tvRewatchSession');
const TvRewatchEpisode = require('../models/tvRewatchEpisode');
const { findTracking, getWatchedEpisodesForShow } = require('./tvTrackingService');
const { normTvId } = require('./tvWatchlistService');

function episodeSort(a, b) {
  return a.seasonNumber - b.seasonNumber || a.episodeNumber - b.episodeNumber;
}

function sessionPayload(session, episodes = []) {
  if (!session) return null;
  const doc = session.toObject ? session.toObject() : session;
  return {
    ...doc,
    id: String(doc._id),
    _id: String(doc._id),
    episodeCount: episodes.length || doc.watchedEpisodeCount || 0,
    episodes,
  };
}

async function listSessions(userId, tvId) {
  return TvRewatchSession.find({ userFrom: userId, tvId: String(tvId) })
    .sort({ sessionNumber: -1 })
    .lean();
}

async function getActiveSession(userId, tvId) {
  return TvRewatchSession.findOne({
    userFrom: userId,
    tvId: String(tvId),
    status: 'active',
  });
}

async function getSessionEpisodes(userId, sessionId) {
  return TvRewatchEpisode.find({ userFrom: userId, sessionId })
    .sort({ seasonNumber: 1, episodeNumber: 1 })
    .lean();
}

async function nextSessionNumber(userId, tvId) {
  const last = await TvRewatchSession.findOne({ userFrom: userId, tvId: String(tvId) })
    .sort({ sessionNumber: -1 })
    .select('sessionNumber')
    .lean();
  return (last?.sessionNumber || 0) + 1;
}

/**
 * Start a rewatch for a completed show. Canonical episode rows are never cleared.
 */
async function startRewatch(userId, tvId, meta = {}) {
  const id = String(tvId);
  const tracking = await findTracking(userId, id);
  if (!tracking) {
    const err = new Error('Show not found in your library.');
    err.status = 404;
    throw err;
  }
  if (tracking.status === 'rewatching' && tracking.activeRewatchSessionId) {
    const existing = await TvRewatchSession.findById(tracking.activeRewatchSessionId);
    if (existing && existing.status === 'active') {
      const episodes = await getSessionEpisodes(userId, existing._id);
      return { tracking, session: sessionPayload(existing, episodes), resumed: true };
    }
  }
  if (tracking.status !== 'completed' && tracking.status !== 'rewatching') {
    const err = new Error('Finish the show once before starting a rewatch.');
    err.status = 400;
    throw err;
  }

  const active = await getActiveSession(userId, id);
  if (active) {
    const episodes = await getSessionEpisodes(userId, active._id);
    tracking.status = 'rewatching';
    tracking.activeRewatchSessionId = active._id;
    await tracking.save();
    return { tracking, session: sessionPayload(active, episodes), resumed: true };
  }

  const sessionNumber = await nextSessionNumber(userId, id);
  const session = await TvRewatchSession.create({
    userFrom: userId,
    tvId: id,
    sessionNumber,
    status: 'active',
    startedAt: new Date(),
    totalEpisodes: meta.totalEpisodes ?? tracking.totalEpisodes ?? 0,
    airedEpisodeCount: meta.airedEpisodeCount ?? tracking.airedEpisodeCount ?? 0,
    nextSeason: meta.nextSeason ?? 1,
    nextEpisode: meta.nextEpisode ?? 1,
    nextEpisodeName: meta.nextEpisodeName || null,
    watchedEpisodeCount: 0,
  });

  if (!tracking.timesCompleted || tracking.timesCompleted < 1) {
    tracking.timesCompleted = 1;
  }
  tracking.status = 'rewatching';
  tracking.activeRewatchSessionId = session._id;
  // Up Next for Lobby comes from session next — mirror onto tracking for continue rails.
  tracking.nextSeason = session.nextSeason;
  tracking.nextEpisode = session.nextEpisode;
  tracking.nextEpisodeName = session.nextEpisodeName;
  await tracking.save();

  return { tracking, session: sessionPayload(session, []), resumed: false };
}

async function syncSessionProgress(userId, session, extra = {}) {
  const episodes = await getSessionEpisodes(userId, session._id);
  const last = episodes[episodes.length - 1];
  const count = episodes.length;
  const aired =
    extra.airedEpisodeCount ?? session.airedEpisodeCount ?? session.totalEpisodes ?? 0;
  const total = extra.totalEpisodes ?? session.totalEpisodes ?? 0;

  session.watchedEpisodeCount = count;
  if (extra.airedEpisodeCount != null) session.airedEpisodeCount = extra.airedEpisodeCount;
  if (extra.totalEpisodes != null) session.totalEpisodes = extra.totalEpisodes;
  if (last) {
    session.lastSeason = last.seasonNumber;
    session.lastEpisode = last.episodeNumber;
    session.lastWatchedAt = last.watchedAt || new Date();
  }

  const progressTotal = aired || total;
  const done = progressTotal > 0 && count >= progressTotal;

  if ('nextSeason' in extra || 'nextEpisode' in extra || 'nextEpisodeName' in extra) {
    session.nextSeason = extra.nextSeason;
    session.nextEpisode = extra.nextEpisode;
    session.nextEpisodeName = extra.nextEpisodeName;
  } else if (done) {
    session.nextSeason = null;
    session.nextEpisode = null;
    session.nextEpisodeName = null;
  }

  if (done && session.status === 'active') {
    session.status = 'completed';
    session.completedAt = new Date();
  }

  await session.save();
  return { session, episodes, done };
}

async function mirrorSessionOntoTracking(tracking, session) {
  tracking.status = session.status === 'active' ? 'rewatching' : 'completed';
  tracking.activeRewatchSessionId =
    session.status === 'active' ? session._id : null;
  tracking.nextSeason = session.nextSeason;
  tracking.nextEpisode = session.nextEpisode;
  tracking.nextEpisodeName = session.nextEpisodeName;
  if (session.lastWatchedAt) tracking.lastWatchedAt = session.lastWatchedAt;
  if (session.status === 'completed') {
    const completedSessions = await TvRewatchSession.countDocuments({
      userFrom: tracking.userFrom,
      tvId: tracking.tvId,
      status: 'completed',
    });
    // First finish + completed rewatch sessions.
    tracking.timesCompleted = Math.max(1, completedSessions + 1);
  }
  await tracking.save();
  return tracking;
}

async function markEpisodes(userId, tvId, episodeList, meta = {}) {
  const id = String(tvId);
  const tracking = await findTracking(userId, id);
  if (!tracking || tracking.status !== 'rewatching' || !tracking.activeRewatchSessionId) {
    const err = new Error('No active rewatch for this show.');
    err.status = 400;
    throw err;
  }
  const session = await TvRewatchSession.findOne({
    _id: tracking.activeRewatchSessionId,
    userFrom: userId,
    status: 'active',
  });
  if (!session) {
    const err = new Error('No active rewatch for this show.');
    err.status = 400;
    throw err;
  }

  const list = Array.isArray(episodeList) ? episodeList : [episodeList];
  if (!list.length) {
    const err = new Error('No episodes provided');
    err.status = 400;
    throw err;
  }

  await Promise.all(
    list.map((ep) =>
      TvRewatchEpisode.findOneAndUpdate(
        {
          userFrom: userId,
          sessionId: session._id,
          seasonNumber: ep.seasonNumber,
          episodeNumber: ep.episodeNumber,
        },
        {
          $set: {
            userFrom: userId,
            tvId: id,
            sessionId: session._id,
            seasonNumber: ep.seasonNumber,
            episodeNumber: ep.episodeNumber,
            tmdbEpisodeId: ep.tmdbEpisodeId,
            episodeName: ep.episodeName,
            runtimeMinutes: ep.runtimeMinutes || 0,
          },
          $setOnInsert: { watchedAt: new Date() },
        },
        { upsert: true, new: true }
      )
    )
  );

  const { session: synced, episodes, done } = await syncSessionProgress(userId, session, {
    totalEpisodes: meta.totalEpisodes,
    airedEpisodeCount: meta.airedEpisodeCount,
    nextSeason: meta.nextSeason,
    nextEpisode: meta.nextEpisode,
    nextEpisodeName: meta.nextEpisodeName,
  });
  await mirrorSessionOntoTracking(tracking, synced);

  return {
    tracking,
    session: sessionPayload(synced, episodes),
    episodes,
    completed: done,
  };
}

async function unmarkEpisodes(userId, tvId, episodeList, meta = {}) {
  const id = String(tvId);
  const tracking = await findTracking(userId, id);
  if (!tracking || !tracking.activeRewatchSessionId) {
    const err = new Error('No active rewatch for this show.');
    err.status = 400;
    throw err;
  }
  const session = await TvRewatchSession.findOne({
    _id: tracking.activeRewatchSessionId,
    userFrom: userId,
    status: 'active',
  });
  if (!session) {
    const err = new Error('No active rewatch for this show.');
    err.status = 400;
    throw err;
  }

  const list = Array.isArray(episodeList) ? episodeList : [episodeList];
  await Promise.all(
    list.map((ep) =>
      TvRewatchEpisode.deleteOne({
        userFrom: userId,
        sessionId: session._id,
        seasonNumber: ep.seasonNumber,
        episodeNumber: ep.episodeNumber,
      })
    )
  );

  const { session: synced, episodes } = await syncSessionProgress(userId, session, {
    totalEpisodes: meta.totalEpisodes,
    airedEpisodeCount: meta.airedEpisodeCount,
    nextSeason: meta.nextSeason,
    nextEpisode: meta.nextEpisode,
    nextEpisodeName: meta.nextEpisodeName,
  });
  await mirrorSessionOntoTracking(tracking, synced);

  return {
    tracking,
    session: sessionPayload(synced, episodes),
    episodes,
    completed: false,
  };
}

/**
 * Cancel active rewatch. Deletes session episode marks; canonical history stays.
 */
async function cancelRewatch(userId, tvId) {
  const id = String(tvId);
  const tracking = await findTracking(userId, id);
  if (!tracking) {
    const err = new Error('Show not found in your library.');
    err.status = 404;
    throw err;
  }

  const session =
    (tracking.activeRewatchSessionId &&
      (await TvRewatchSession.findOne({
        _id: tracking.activeRewatchSessionId,
        userFrom: userId,
      }))) ||
    (await getActiveSession(userId, id));

  if (session && session.status === 'active') {
    await TvRewatchEpisode.deleteMany({ userFrom: userId, sessionId: session._id });
    session.status = 'cancelled';
    session.cancelledAt = new Date();
    session.watchedEpisodeCount = 0;
    session.nextSeason = null;
    session.nextEpisode = null;
    session.nextEpisodeName = null;
    await session.save();
  }

  tracking.status = 'completed';
  tracking.activeRewatchSessionId = null;
  tracking.nextSeason = null;
  tracking.nextEpisode = null;
  tracking.nextEpisodeName = null;
  if (!tracking.timesCompleted || tracking.timesCompleted < 1) {
    tracking.timesCompleted = 1;
  }
  await tracking.save();

  return { tracking, session: session ? sessionPayload(session, []) : null };
}

async function getRewatchState(userId, tvId) {
  const id = String(tvId);
  const tracking = await findTracking(userId, id);
  const sessions = await listSessions(userId, id);
  const active = sessions.find((s) => s.status === 'active') || null;
  let episodes = [];
  if (active) {
    episodes = await getSessionEpisodes(userId, active._id);
  }
  const completedCount = sessions.filter((s) => s.status === 'completed').length;
  return {
    tracking,
    activeSession: active ? sessionPayload(active, episodes) : null,
    sessions,
    timesCompleted: tracking?.timesCompleted || (tracking?.status === 'completed' ? 1 : 0),
    completedRewatches: completedCount,
  };
}

/** Recent rewatch episode activity for diary. */
async function recentRewatchActivity(userId, limit = 60) {
  const rows = await TvRewatchEpisode.find({ userFrom: userId })
    .sort({ watchedAt: -1, updatedAt: -1 })
    .limit(limit)
    .lean();
  return rows;
}

module.exports = {
  episodeSort,
  sessionPayload,
  listSessions,
  getActiveSession,
  getSessionEpisodes,
  startRewatch,
  markEpisodes,
  unmarkEpisodes,
  cancelRewatch,
  getRewatchState,
  recentRewatchActivity,
  syncSessionProgress,
  getWatchedEpisodesForShow,
  normTvId,
};
