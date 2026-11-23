const TvShowTracking = require('../models/tvShowTracking');
const TvRewatchSession = require('../models/tvRewatchSession');
const TvRewatchEpisode = require('../models/tvRewatchEpisode');
const {
  findTracking,
  getWatchedEpisodesForShow,
  deleteWatchedEpisode,
} = require('./tvTrackingService');
const { normTvId } = require('./tvWatchlistService');

function episodeSort(a, b) {
  return a.seasonNumber - b.seasonNumber || a.episodeNumber - b.episodeNumber;
}

function episodeKey(seasonNumber, episodeNumber) {
  return `${seasonNumber}-${episodeNumber}`;
}

/** Full-show finishes only: first completion + completed sessions that covered the whole show. */
async function computeTimesCompleted(userId, tvId, tracking) {
  const id = String(tvId);
  const total =
    tracking?.totalEpisodes ||
    tracking?.airedEpisodeCount ||
    0;
  const firstDone =
    tracking?.status === 'completed' ||
    tracking?.status === 'rewatching' ||
    (total > 0 && (tracking?.watchedEpisodeCount || 0) >= total);

  const sessions = await TvRewatchSession.find({
    userFrom: userId,
    tvId: id,
    status: 'completed',
  })
    .select('watchedEpisodeCount totalEpisodes airedEpisodeCount')
    .lean();

  const fullRewatches = sessions.filter((s) => {
    const need = s.totalEpisodes || s.airedEpisodeCount || total || 0;
    return need > 0 && (s.watchedEpisodeCount || 0) >= need;
  }).length;

  if (!firstDone && fullRewatches === 0) return 0;
  return Math.max(1, (firstDone ? 1 : 0) + fullRewatches);
}

function toIso(value) {
  if (!value) return null;
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString();
}

function pushPlayDate(playDates, key, value) {
  const iso = toIso(value);
  if (!iso) return;
  if (!playDates[key]) playDates[key] = [];
  playDates[key].push(iso);
}

/**
 * plays[S-E] = 1 if first-watched + count of rewatch episode marks.
 * playDates[S-E] = ISO timestamps for each play, oldest → newest.
 */
async function getEpisodePlayCounts(userId, tvId) {
  const id = String(tvId);
  const [canonical, rewatchRows] = await Promise.all([
    getWatchedEpisodesForShow(userId, id),
    TvRewatchEpisode.find({ userFrom: userId, tvId: id })
      .select('seasonNumber episodeNumber watchedAt createdAt')
      .lean(),
  ]);

  const plays = {};
  const playDates = {};
  for (const ep of canonical) {
    const key = episodeKey(ep.seasonNumber, ep.episodeNumber);
    plays[key] = 1;
    pushPlayDate(playDates, key, ep.watchedAt || ep.createdAt);
  }
  for (const ep of rewatchRows) {
    const key = episodeKey(ep.seasonNumber, ep.episodeNumber);
    plays[key] = (plays[key] || 0) + 1;
    pushPlayDate(playDates, key, ep.watchedAt || ep.createdAt);
  }

  for (const key of Object.keys(playDates)) {
    playDates[key].sort();
  }

  const rewatchPlayTotal = rewatchRows.length;
  return { plays, playDates, rewatchPlayTotal };
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
  if (session.status === 'completed' || session.status === 'active') {
    tracking.timesCompleted = await computeTimesCompleted(
      tracking.userFrom,
      tracking.tvId,
      tracking
    );
  }
  await tracking.save();
  return tracking;
}

/**
 * Casual rewatch play(s) without entering structured rewatching / Up Next mode.
 * Each call creates a completed mini-session so the same episode can be logged again later.
 */
async function logEpisodeRewatches(userId, tvId, episodeList, meta = {}) {
  const id = String(tvId);
  const tracking = await findTracking(userId, id);
  if (!tracking) {
    const err = new Error('Show not found in your library.');
    err.status = 404;
    throw err;
  }

  const list = (Array.isArray(episodeList) ? episodeList : [episodeList]).filter(
    (ep) => ep && Number.isFinite(ep.seasonNumber) && Number.isFinite(ep.episodeNumber)
  );
  if (!list.length) {
    const err = new Error('No episodes provided');
    err.status = 400;
    throw err;
  }

  // Structured active run: mark into that session instead.
  if (tracking.status === 'rewatching' && tracking.activeRewatchSessionId) {
    return markEpisodes(userId, id, list, meta);
  }

  const now = new Date();
  const sessionNumber = await nextSessionNumber(userId, id);
  const totalEpisodes = meta.totalEpisodes ?? tracking.totalEpisodes ?? 0;
  const session = await TvRewatchSession.create({
    userFrom: userId,
    tvId: id,
    sessionNumber,
    status: 'completed',
    startedAt: now,
    completedAt: now,
    watchedEpisodeCount: list.length,
    totalEpisodes,
    airedEpisodeCount: meta.airedEpisodeCount ?? tracking.airedEpisodeCount ?? totalEpisodes,
    nextSeason: null,
    nextEpisode: null,
    nextEpisodeName: null,
    lastSeason: list[list.length - 1].seasonNumber,
    lastEpisode: list[list.length - 1].episodeNumber,
    lastWatchedAt: now,
  });

  await TvRewatchEpisode.insertMany(
    list.map((ep) => ({
      userFrom: userId,
      tvId: id,
      sessionId: session._id,
      seasonNumber: ep.seasonNumber,
      episodeNumber: ep.episodeNumber,
      tmdbEpisodeId: ep.tmdbEpisodeId || '',
      episodeName: ep.episodeName || '',
      runtimeMinutes: ep.runtimeMinutes || 0,
      watchedAt: now,
    })),
    { ordered: false }
  ).catch((err) => {
    if (err.code !== 11000) throw err;
  });

  // Do not flip status to rewatching — casual plays only.
  if (tracking.status === 'completed' || (tracking.watchedEpisodeCount || 0) > 0) {
    tracking.lastWatchedAt = now;
  }
  tracking.timesCompleted = await computeTimesCompleted(userId, id, tracking);
  await tracking.save();

  const { plays, playDates, rewatchPlayTotal } = await getEpisodePlayCounts(userId, id);
  return {
    tracking,
    session: sessionPayload(session, list),
    playCounts: plays,
    playDates,
    rewatchPlayTotal,
    completed: false,
  };
}

/**
 * Undo one play for an episode: latest rewatch mark first, then canonical first-watch.
 * Never deletes other shows' data; never clears whole diary.
 */
async function undoEpisodePlay(userId, tvId, episode, meta = {}) {
  const id = String(tvId);
  const tracking = await findTracking(userId, id);
  if (!tracking) {
    const err = new Error('Show not found in your library.');
    err.status = 404;
    throw err;
  }

  const seasonNumber = episode.seasonNumber;
  const episodeNumber = episode.episodeNumber;

  // Active structured rewatch: unmark inside that session only.
  if (tracking.status === 'rewatching' && tracking.activeRewatchSessionId) {
    return unmarkEpisodes(userId, id, [{ seasonNumber, episodeNumber }], meta);
  }

  const latestRewatch = await TvRewatchEpisode.findOne({
    userFrom: userId,
    tvId: id,
    seasonNumber,
    episodeNumber,
  })
    .sort({ watchedAt: -1, createdAt: -1 })
    .lean();

  if (latestRewatch) {
    await TvRewatchEpisode.deleteOne({ _id: latestRewatch._id });
    const leftInSession = await TvRewatchEpisode.countDocuments({
      sessionId: latestRewatch.sessionId,
    });
    if (leftInSession === 0) {
      await TvRewatchSession.deleteOne({
        _id: latestRewatch.sessionId,
        userFrom: userId,
        status: { $in: ['completed', 'cancelled'] },
      });
    } else {
      await TvRewatchSession.updateOne(
        { _id: latestRewatch.sessionId },
        { $set: { watchedEpisodeCount: leftInSession } }
      );
    }
  } else {
    await deleteWatchedEpisode(userId, id, seasonNumber, episodeNumber);
    const remaining = await getWatchedEpisodesForShow(userId, id);
    tracking.watchedEpisodeCount = remaining.length;
    if (remaining.length === 0) {
      // Leave tracking row but clear completion — caller routes often rebuild; keep safe.
      tracking.status = 'watching';
      tracking.timesCompleted = 0;
      tracking.nextSeason = null;
      tracking.nextEpisode = null;
      tracking.nextEpisodeName = null;
    } else {
      const total = tracking.totalEpisodes || 0;
      if (total > 0 && remaining.length < total && tracking.status === 'completed') {
        tracking.status = 'watching';
      }
      tracking.timesCompleted = await computeTimesCompleted(userId, id, tracking);
    }
    await tracking.save();
  }

  if (latestRewatch) {
    tracking.timesCompleted = await computeTimesCompleted(userId, id, tracking);
    await tracking.save();
  }

  const { plays, playDates, rewatchPlayTotal } = await getEpisodePlayCounts(userId, id);
  return {
    tracking,
    playCounts: plays,
    playDates,
    rewatchPlayTotal,
    removedRewatch: Boolean(latestRewatch),
  };
}

async function undoEpisodePlays(userId, tvId, episodeList, meta = {}) {
  const list = Array.isArray(episodeList) ? episodeList : [episodeList];
  let last = null;
  for (const ep of list) {
    last = await undoEpisodePlay(userId, tvId, ep, meta);
  }
  return last;
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
  const { plays, playDates, rewatchPlayTotal } = await getEpisodePlayCounts(userId, id);
  const timesCompleted = tracking
    ? await computeTimesCompleted(userId, id, tracking)
    : 0;
  const fullRewatchSessions = sessions.filter((s) => {
    if (s.status !== 'completed') return false;
    const need = s.totalEpisodes || s.airedEpisodeCount || tracking?.totalEpisodes || 0;
    return need > 0 && (s.watchedEpisodeCount || 0) >= need;
  }).length;
  return {
    tracking,
    activeSession: active ? sessionPayload(active, episodes) : null,
    sessions,
    timesCompleted,
    completedRewatches: fullRewatchSessions,
    playCounts: plays,
    playDates,
    rewatchPlayTotal,
  };
}

/** Safe: only rewrites timesCompleted on tracking docs. Never deletes watches. */
async function repairTimesCompletedForUser(userId) {
  const tracks = await TvShowTracking.find({ userFrom: userId });
  let updated = 0;
  for (const tracking of tracks) {
    const next = await computeTimesCompleted(userId, tracking.tvId, tracking);
    if ((tracking.timesCompleted || 0) !== next) {
      tracking.timesCompleted = next;
      await tracking.save();
      updated += 1;
    }
  }
  return { scanned: tracks.length, updated };
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
  getEpisodePlayCounts,
  computeTimesCompleted,
  logEpisodeRewatches,
  undoEpisodePlay,
  undoEpisodePlays,
  repairTimesCompletedForUser,
  normTvId,
};
