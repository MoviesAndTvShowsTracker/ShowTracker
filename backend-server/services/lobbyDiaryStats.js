/**
 * Lobby-diary stats: House Lights rhythm, Lobby Type, season rewatch arcs,
 * biggest night strip, and hot takes. Built for Marquee’s always-on diary —
 * not heatmaps or KPI strips.
 */

const { zonedParts, dateKeyInZone } = require('./statsCalendar');
const { filmRuntimeMinutes } = require('./mediaMeta');

const MAX_NIGHT_MINUTES = 18 * 60;

function emptyHour() {
  return { mins: 0, filmMins: 0, tvMins: 0, playCount: 0 };
}

function buildHourRhythm(episodePlays, films, timeZone, hourOf = null) {
  const byHour = Array.from({ length: 24 }, () => emptyHour());
  const hourFor = (row) =>
    hourOf ? hourOf(row) : zonedParts(new Date(row.watchedAt), timeZone).hour;

  for (const ep of episodePlays) {
    if (!ep.watchedAt) continue;
    const hour = hourFor(ep);
    if (!Number.isFinite(hour) || hour < 0 || hour > 23) continue;
    const mins = ep.runtimeMinutes || 0;
    byHour[hour].tvMins += mins;
    byHour[hour].mins += mins;
    byHour[hour].playCount += 1;
  }
  for (const f of films) {
    if (!f.watchedAt) continue;
    const hour = hourFor(f);
    if (!Number.isFinite(hour) || hour < 0 || hour > 23) continue;
    const mins = filmRuntimeMinutes(f);
    byHour[hour].filmMins += mins;
    byHour[hour].mins += mins;
    byHour[hour].playCount += 1;
  }

  let peakHour = 0;
  let peakMins = -1;
  for (let h = 0; h < 24; h += 1) {
    if (byHour[h].mins > peakMins) {
      peakMins = byHour[h].mins;
      peakHour = h;
    }
  }

  let night = 0;
  let matinee = 0;
  let total = 0;
  for (let h = 0; h < 24; h += 1) {
    const m = byHour[h].mins;
    total += m;
    if (h >= 20 || h <= 3) night += m;
    if (h >= 10 && h <= 16) matinee += m;
  }
  let persona = 'mixed';
  if (total > 0) {
    if (night / total >= 0.45) persona = 'nightHouse';
    else if (matinee / total >= 0.4) persona = 'matinee';
  }

  const captions = {
    nightHouse: 'Your house lights go up after dark',
    matinee: 'You’re a matinee person',
    mixed: 'You wander the lobby at all hours',
  };

  return {
    byHour,
    peakHour,
    peakMins: Math.max(0, peakMins),
    persona,
    caption: captions[persona],
  };
}

function buildLobbyType({
  rhythm,
  library,
  overview,
  episodeCount,
  episodeRewatchPlays,
  completionRate,
}) {
  const nightHouse = rhythm.persona === 'nightHouse';
  const matinee = rhythm.persona === 'matinee';
  const schedule = nightHouse ? 'Night House' : matinee ? 'Matinee' : 'Open House';

  const rewatchRate = episodeCount > 0 ? episodeRewatchPlays / episodeCount : 0;
  const rewatcher = rewatchRate >= 0.12;
  const passLabel = rewatcher ? 'Rewatcher' : 'One-Pass';

  const backlog = library.backlog || 0;
  const caughtUp = library.caughtUp || 0;
  const watching = library.watching || 0;
  const completist =
    (completionRate || 0) >= 40 || (caughtUp > 0 && backlog <= watching);
  const finishLabel = completist ? 'Completist' : 'Sampler';

  const tvLobby = (overview.tvShare || 0) >= 55;
  const filmLobby = (overview.filmShare || 0) >= 55;
  const mediaLabel = tvLobby ? 'TV Lobby' : filmLobby ? 'Film Lobby' : 'Mixed Bill';

  return {
    schedule: nightHouse ? 'nightHouse' : matinee ? 'matinee' : 'mixed',
    scheduleLabel: schedule,
    pass: rewatcher ? 'rewatcher' : 'onePass',
    passLabel,
    finish: completist ? 'completist' : 'sampler',
    finishLabel,
    media: tvLobby ? 'tv' : filmLobby ? 'film' : 'mixed',
    mediaLabel,
    label: `${schedule} · ${passLabel}`,
    blurb: `${finishLabel} energy in a ${mediaLabel === 'Mixed Bill' ? 'mixed bill' : mediaLabel.replace(' Lobby', ' lobby')}.`,
    rewatchRate: Math.round(rewatchRate * 100),
  };
}

function buildSeasonArcs(tracks, episodes, rewatchEpisodes, limit = 5) {
  const byShow = new Map();

  for (const ep of episodes) {
    const id = String(ep.tvId);
    if (!byShow.has(id)) {
      byShow.set(id, { first: [], rewatchBySession: new Map() });
    }
    byShow.get(id).first.push(ep);
  }
  for (const ep of rewatchEpisodes) {
    const id = String(ep.tvId);
    if (!byShow.has(id)) {
      byShow.set(id, { first: [], rewatchBySession: new Map() });
    }
    const sid = String(ep.sessionId || 'unknown');
    const bag = byShow.get(id).rewatchBySession;
    if (!bag.has(sid)) bag.set(sid, []);
    bag.get(sid).push(ep);
  }

  const scored = [];
  for (const [tvId, bag] of byShow.entries()) {
    const firstMins = bag.first.reduce((s, e) => s + (e.runtimeMinutes || 0), 0);
    let rewatchMins = 0;
    let rewatchEps = 0;
    for (const list of bag.rewatchBySession.values()) {
      rewatchMins += list.reduce((s, e) => s + (e.runtimeMinutes || 0), 0);
      rewatchEps += list.length;
    }
    const totalMins = firstMins + rewatchMins;
    const totalPlays = bag.first.length + rewatchEps;
    if (totalPlays < 2 && bag.rewatchBySession.size === 0) continue;
    scored.push({
      tvId,
      bag,
      totalMins,
      totalPlays,
      passes: bag.rewatchBySession.size + (bag.first.length ? 1 : 0),
    });
  }

  scored.sort((a, b) => b.totalMins - a.totalMins || b.totalPlays - a.totalPlays);

  return scored.slice(0, limit).map(({ tvId, bag, totalMins, totalPlays, passes }) => {
    const track = tracks.find((t) => String(t.tvId) === tvId);
    const passList = [];
    if (bag.first.length) {
      const dates = bag.first
        .map((e) => e.watchedAt)
        .filter(Boolean)
        .map((d) => new Date(d));
      passList.push({
        kind: 'first',
        label: 'First watch',
        episodes: bag.first.length,
        mins: bag.first.reduce((s, e) => s + (e.runtimeMinutes || 0), 0),
        start: dates.length ? new Date(Math.min(...dates)).toISOString() : null,
        end: dates.length ? new Date(Math.max(...dates)).toISOString() : null,
      });
    }
    const sessions = [...bag.rewatchBySession.entries()].sort((a, b) => {
      const a0 = a[1][0]?.watchedAt ? new Date(a[1][0].watchedAt).getTime() : 0;
      const b0 = b[1][0]?.watchedAt ? new Date(b[1][0].watchedAt).getTime() : 0;
      return a0 - b0;
    });
    let i = 1;
    for (const [, list] of sessions) {
      const dates = list
        .map((e) => e.watchedAt)
        .filter(Boolean)
        .map((d) => new Date(d));
      passList.push({
        kind: 'rewatch',
        label: `Rewatch ${i}`,
        episodes: list.length,
        mins: list.reduce((s, e) => s + (e.runtimeMinutes || 0), 0),
        start: dates.length ? new Date(Math.min(...dates)).toISOString() : null,
        end: dates.length ? new Date(Math.max(...dates)).toISOString() : null,
      });
      i += 1;
    }
    return {
      tvId,
      tvTitle: track?.tvTitle || null,
      tvPosterImage: track?.tvPosterImage || null,
      passes: passList,
      passCount: passes,
      totalMins,
      totalPlays,
    };
  });
}

function buildBiggestNight(episodePlays, films, timeZone, dayMap, keyOf = null) {
  const dayFor = (row) => (keyOf ? keyOf(row) : dateKeyInZone(row.watchedAt, timeZone));
  let bestDate = null;
  let bestCount = 0;
  let bestMins = 0;
  for (const [date, bucket] of Object.entries(dayMap || {})) {
    const count = (bucket.episodes || 0) + (bucket.films || 0);
    const minutes = (bucket.tvMinutes || 0) + (bucket.filmMinutes || 0);
    // Bulk imports stamp hundreds of plays on one day — not a night anyone lived.
    if (minutes > MAX_NIGHT_MINUTES) continue;
    if (count > bestCount || (count === bestCount && minutes > bestMins)) {
      bestDate = date;
      bestCount = count;
      bestMins = minutes;
    }
  }
  if (!bestDate || bestCount < 2) return null;

  const items = [];
  for (const ep of episodePlays) {
    if (!ep.watchedAt) continue;
    if (dayFor(ep) !== bestDate) continue;
    items.push({
      kind: 'episode',
      id: String(ep.tvId),
      title: ep.episodeName || `S${ep.seasonNumber}E${ep.episodeNumber}`,
      subtitle: null,
      stillOrPoster: null,
      seasonNumber: ep.seasonNumber,
      episodeNumber: ep.episodeNumber,
      watchedAt: ep.watchedAt,
      mins: ep.runtimeMinutes || 0,
    });
  }
  for (const f of films) {
    if (!f.watchedAt) continue;
    if (dayFor(f) !== bestDate) continue;
    items.push({
      kind: 'film',
      id: String(f.movieId),
      title: f.movieTitle || 'Film',
      subtitle: null,
      stillOrPoster: f.moviePosterImage || null,
      watchedAt: f.watchedAt,
      mins: filmRuntimeMinutes(f),
    });
  }
  items.sort((a, b) => new Date(a.watchedAt) - new Date(b.watchedAt));

  return {
    date: bestDate,
    count: bestCount,
    minutes: bestMins,
    items: items.slice(0, 24),
  };
}

function buildHotTakes(films, filmMetaMap, limit = 6) {
  const takes = [];
  for (const f of films) {
    const user = Number(f.rating);
    if (!Number.isFinite(user) || user <= 0) continue;
    const meta = filmMetaMap?.get(String(f.movieId));
    const community = Number(meta?.voteAverage);
    if (!Number.isFinite(community) || community <= 0) continue;
    // Both sides on a 5-star scale (diary ratings are stored 1–10).
    const userStars = user / 2;
    const communityStars = community / 2;
    const delta = userStars - communityStars;
    if (Math.abs(delta) < 0.75) continue;
    takes.push({
      kind: 'film',
      id: String(f.movieId),
      title: f.movieTitle || null,
      poster: f.moviePosterImage || meta?.posterPath || null,
      userRating: Math.round(userStars * 10) / 10,
      communityRating: Math.round(communityStars * 10) / 10,
      delta: Math.round(delta * 10) / 10,
    });
  }
  takes.sort((a, b) => Math.abs(b.delta) - Math.abs(a.delta));
  return takes.slice(0, limit);
}

function attachEpisodePosters(biggestNight, tracks) {
  if (!biggestNight?.items?.length) return biggestNight;
  const byId = new Map(tracks.map((t) => [String(t.tvId), t]));
  return {
    ...biggestNight,
    items: biggestNight.items.map((item) => {
      if (item.kind !== 'episode') return item;
      const track = byId.get(item.id);
      return {
        ...item,
        subtitle: track?.tvTitle || null,
        stillOrPoster: item.stillOrPoster || track?.tvPosterImage || null,
      };
    }),
  };
}

module.exports = {
  buildHourRhythm,
  buildLobbyType,
  buildSeasonArcs,
  buildBiggestNight,
  buildHotTakes,
  attachEpisodePosters,
};
