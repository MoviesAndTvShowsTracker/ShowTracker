const fs = require('fs');
const path = require('path');

const TMDB_BASE = 'https://api.themoviedb.org/3/';
const REQUEST_DELAY_MS = 260;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function parseCsv(content) {
  const rows = [];
  let row = [];
  let field = '';
  let inQuotes = false;

  for (let i = 0; i < content.length; i += 1) {
    const c = content[i];
    const next = content[i + 1];

    if (inQuotes) {
      if (c === '"' && next === '"') {
        field += '"';
        i += 1;
      } else if (c === '"') {
        inQuotes = false;
      } else {
        field += c;
      }
      continue;
    }

    if (c === '"') {
      inQuotes = true;
    } else if (c === ',') {
      row.push(field);
      field = '';
    } else if (c === '\n' || (c === '\r' && next === '\n')) {
      row.push(field);
      if (row.length > 1 || row[0] !== '') rows.push(row);
      row = [];
      field = '';
      if (c === '\r') i += 1;
    } else if (c !== '\r') {
      field += c;
    }
  }

  if (field.length || row.length) {
    row.push(field);
    rows.push(row);
  }

  if (!rows.length) return [];

  const headers = rows[0];
  return rows.slice(1).map((cells) => {
    const obj = {};
    headers.forEach((h, idx) => {
      obj[h] = cells[idx] ?? '';
    });
    return obj;
  });
}

function readCsv(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  return parseCsv(content);
}

function normalizeTitle(title) {
  return (title || '')
    .toLowerCase()
    .replace(/\([^)]*\)/g, ' ')
    .replace(/[^\w\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function yearFromDate(dateStr) {
  if (!dateStr || dateStr.startsWith('0001')) return null;
  const y = parseInt(String(dateStr).slice(0, 4), 10);
  return Number.isFinite(y) && y > 1880 ? y : null;
}

function episodeKey(season, episode) {
  return `${season}-${episode}`;
}

function parseListUuids(dataDir, listKey) {
  const filePath = path.join(dataDir, 'lists-prod-lists.csv');
  if (!fs.existsSync(filePath)) return [];
  const lines = fs.readFileSync(filePath, 'utf8').split('\n');
  const line =
    lines.find((row) => row.includes(`s_key:${listKey}`) && row.includes('uuid:')) ||
    lines.find((row) => row.includes(listKey) && row.includes('uuid:'));
  if (!line) return [];
  return [...line.matchAll(/uuid:([0-9a-f-]{36})/gi)].map((m) => m[1]);
}

function loadGdprData(dataDir) {
  const trackingV2 = readCsv(path.join(dataDir, 'tracking-prod-records-v2.csv'));
  const trackingV1 = readCsv(path.join(dataDir, 'tracking-prod-records.csv'));
  const userTvShow = readCsv(path.join(dataDir, 'user_tv_show_data.csv'));

  const seriesUuidToTvdb = new Map();
  for (const row of trackingV1) {
    if (row.series_id && row.uuid) seriesUuidToTvdb.set(row.uuid, String(row.series_id).trim());
  }
  for (const row of trackingV2) {
    if (row.key?.startsWith('user-series-') && row.s_id && row.uuid) {
      seriesUuidToTvdb.set(row.uuid, String(row.s_id).trim());
    }
  }

  const movieFollowDates = new Map();
  for (const row of trackingV1) {
    if (row.entity_type === 'movie' && row.uuid && row.type === 'follow' && row.created_at) {
      movieFollowDates.set(row.uuid, new Date(row.created_at));
    }
  }

  const tvEpisodes = new Map();
  for (const row of trackingV2) {
    if (!row.key?.startsWith('watch-episode')) continue;
    const season = parseInt(row.season_number || row.s_no, 10);
    const episode = parseInt(row.episode_number || row.ep_no, 10);
    if (!row.series_name || !Number.isFinite(season) || !Number.isFinite(episode)) continue;
    if (season <= 0) continue;

    const key = `${row.series_name}\0${season}\0${episode}`;
    const watchedAt = row.created_at ? new Date(row.created_at) : new Date();
    const existing = tvEpisodes.get(key);
    if (!existing || watchedAt < existing.watchedAt) {
      tvEpisodes.set(key, {
        seriesName: row.series_name,
        tvdbId: String(row.s_id || '').trim(),
        seasonNumber: season,
        episodeNumber: episode,
        tvtimeEpisodeId: row.episode_id || row.ep_id || '',
        watchedAt,
      });
    }
  }

  const movieMetaByUuid = new Map();
  for (const row of trackingV1) {
    if (row.entity_type !== 'movie' || !row.uuid) continue;
    const name = (row.movie_name || '').trim();
    if (!name) continue;
    const year = yearFromDate(row.release_date);
    const prev = movieMetaByUuid.get(row.uuid);
    if (!prev || (year && !prev.year)) {
      movieMetaByUuid.set(row.uuid, { name, year, runtime: row.runtime ? Math.round(Number(row.runtime) / 60) : null });
    }
  }

  const moviesWatched = new Map();
  const moviesTowatch = new Map();

  for (const row of trackingV1) {
    if (row.entity_type !== 'movie' || !row.uuid) continue;
    const meta = movieMetaByUuid.get(row.uuid) || { name: (row.movie_name || '').trim() };
    if (!meta.name && row.type !== 'watch') continue;

    if (row.type === 'watch') {
      const watchedAt = row.created_at ? new Date(row.created_at) : new Date();
      const existing = moviesWatched.get(row.uuid);
      if (!existing || watchedAt < existing.watchedAt) {
        moviesWatched.set(row.uuid, { uuid: row.uuid, ...meta, watchedAt });
      }
    } else if (row.type === 'towatch') {
      moviesTowatch.set(row.uuid, { uuid: row.uuid, ...meta });
    }
  }

  const tvFavorites = [];
  const tvFavoriteKeys = new Set();
  const tvWatchlist = [];
  const tvShowMeta = new Map();

  const addTvFavorite = (tvdbId, name, favoritedAt) => {
    if (!tvdbId || !name || tvFavoriteKeys.has(tvdbId)) return;
    tvFavoriteKeys.add(tvdbId);
    tvFavorites.push({ tvdbId, name, favoritedAt: favoritedAt || null });
  };

  for (const row of userTvShow) {
    const tvdbId = String(row.tv_show_id || '').trim();
    const name = (row.tv_show_name || '').trim();
    if (!tvdbId || !name) continue;

    tvShowMeta.set(tvdbId, {
      tvdbId,
      name,
      episodesSeen: parseInt(row.nb_episodes_seen || '0', 10) || 0,
      isFollowed: row.is_followed === '1',
      isFavorited: row.is_favorited === '1',
    });

    if (row.is_favorited === '1') {
      addTvFavorite(tvdbId, name, null);
    }
    if (row.is_followed === '1' && (parseInt(row.nb_episodes_seen || '0', 10) || 0) === 0) {
      tvWatchlist.push({ tvdbId, name });
    }
  }

  for (const row of trackingV2) {
    if (!row.key?.startsWith('user-series-')) continue;
    const tvdbId = String(row.s_id || '').trim();
    const name = (row.series_name || '').trim();
    if (!tvdbId || !name) continue;
    if (row.is_for_later === 'true' && (parseInt(row.ep_watch_count || '0', 10) || 0) === 0) {
      if (!tvWatchlist.some((s) => s.tvdbId === tvdbId)) {
        tvWatchlist.push({ tvdbId, name });
      }
    }
  }

  for (const uuid of parseListUuids(dataDir, 'favorite-series')) {
    const tvdbId = seriesUuidToTvdb.get(uuid);
    const row = trackingV1.find((r) => r.uuid === uuid && r.series_name);
    addTvFavorite(tvdbId, row?.series_name || '', null);
  }

  const movieFavoriteUuids = parseListUuids(dataDir, 'favorite-movies');
  const movieFavorites = movieFavoriteUuids
    .map((uuid) => {
      const meta = movieMetaByUuid.get(uuid);
      if (!meta?.name) return null;
      return {
        uuid,
        ...meta,
        favoritedAt: movieFollowDates.get(uuid) || null,
      };
    })
    .filter(Boolean);

  const showsWithEpisodes = new Set(
    [...tvEpisodes.values()].map((ep) => ep.tvdbId).filter(Boolean)
  );

  return {
    tvEpisodes: [...tvEpisodes.values()],
    moviesWatched: [...moviesWatched.values()],
    moviesTowatch: [...moviesTowatch.values()],
    movieFavorites,
    tvFavorites,
    tvWatchlist: tvWatchlist.filter((s) => !showsWithEpisodes.has(s.tvdbId)),
    tvShowMeta,
    stats: {
      tvEpisodeRows: tvEpisodes.size,
      moviesWatched: moviesWatched.size,
      moviesTowatch: moviesTowatch.size,
      movieFavorites: movieFavorites.length,
      tvFavorites: tvFavorites.length,
      tvWatchlist: tvWatchlist.length,
    },
  };
}

class TmdbMapper {
  constructor(apiKey, cachePath) {
    this.apiKey = apiKey;
    this.cachePath = cachePath;
    this.cache = { tvdb: {}, movieUuid: {}, movieTitle: {}, episodeIndex: {} };
    this.lastRequestAt = 0;
    if (cachePath && fs.existsSync(cachePath)) {
      try {
        this.cache = JSON.parse(fs.readFileSync(cachePath, 'utf8'));
      } catch {
        /* fresh cache */
      }
    }
  }

  saveCache() {
    if (!this.cachePath) return;
    fs.writeFileSync(this.cachePath, JSON.stringify(this.cache, null, 2));
  }

  async fetch(endpoint, params = {}) {
    const gap = Date.now() - this.lastRequestAt;
    if (gap < REQUEST_DELAY_MS) await sleep(REQUEST_DELAY_MS - gap);

    const url = new URL(endpoint.startsWith('http') ? endpoint : `${TMDB_BASE}${endpoint.replace(/^\//, '')}`);
    url.searchParams.set('api_key', this.apiKey);
    Object.entries(params).forEach(([k, v]) => {
      if (v != null && v !== '') url.searchParams.set(k, v);
    });

    this.lastRequestAt = Date.now();
    const res = await fetch(url);
    if (!res.ok) {
      const text = await res.text();
      throw new Error(`TMDB ${res.status} ${endpoint}: ${text.slice(0, 120)}`);
    }
    return res.json();
  }

  async mapTvdbToTmdb(tvdbId, fallbackName) {
    if (this.cache.tvdb[tvdbId]) return this.cache.tvdb[tvdbId];

    let result = null;
    try {
      const byId = await this.fetch('/find/' + tvdbId, {
        external_source: 'tvdb_id',
      });
      const show = byId.tv_results?.[0];
      if (show) {
        result = {
          tmdbId: String(show.id),
          name: show.name || show.original_name,
          poster_path: show.poster_path || '',
          backdrop_path: show.backdrop_path || '',
          source: 'tvdb_id',
        };
      }
    } catch {
      /* fall through to search */
    }

    if (!result && fallbackName) {
      try {
        const search = await this.fetch('/search/tv', { query: fallbackName });
        const hit = search.results?.[0];
        if (hit) {
          result = {
            tmdbId: String(hit.id),
            name: hit.name || hit.original_name,
            poster_path: hit.poster_path || '',
            backdrop_path: hit.backdrop_path || '',
            source: 'search',
          };
        }
      } catch {
        /* unmatched */
      }
    }

    if (result) this.cache.tvdb[tvdbId] = result;
    return result;
  }

  async mapMovie(uuid, name, year) {
    if (this.cache.movieUuid[uuid]) return this.cache.movieUuid[uuid];
    const titleKey = `${normalizeTitle(name)}|${year || ''}`;
    if (this.cache.movieTitle[titleKey]) {
      this.cache.movieUuid[uuid] = this.cache.movieTitle[titleKey];
      return this.cache.movieUuid[uuid];
    }

    let result = null;
    try {
      const search = await this.fetch('/search/movie', { query: name, year: year || undefined });
      let hit = search.results?.[0];
      if (year && search.results?.length > 1) {
        const exact = search.results.find((m) => (m.release_date || '').startsWith(String(year)));
        if (exact) hit = exact;
      }
      if (hit) {
        result = {
          tmdbId: String(hit.id),
          title: hit.title || hit.original_title,
          poster_path: hit.poster_path || '',
          backdrop_path: hit.backdrop_path || '',
          runtime: hit.runtime || null,
          source: 'search',
        };
      }
    } catch {
      /* unmatched */
    }

    if (result) {
      this.cache.movieUuid[uuid] = result;
      this.cache.movieTitle[titleKey] = result;
    }
    return result;
  }

  async getShowMeta(tmdbId) {
    if (!this.cache.showMeta) this.cache.showMeta = {};
    if (this.cache.showMeta[tmdbId]) return this.cache.showMeta[tmdbId];

    const show = await this.fetch(`/tv/${tmdbId}`);
    const meta = {
      id: show.id,
      name: show.name,
      poster_path: show.poster_path,
      backdrop_path: show.backdrop_path,
      number_of_episodes: show.number_of_episodes,
      seasons: (show.seasons || []).filter((s) => s.season_number > 0),
    };
    this.cache.showMeta[tmdbId] = meta;
    return meta;
  }

  async getSeasonEpisodes(tmdbId, seasonNumber) {
    const cacheKey = `${tmdbId}:s${seasonNumber}`;
    if (!this.cache.seasonEpisodes) this.cache.seasonEpisodes = {};
    if (this.cache.seasonEpisodes[cacheKey]) return this.cache.seasonEpisodes[cacheKey];

    let detail = { episodes: [] };
    try {
      detail = await this.fetch(`/tv/${tmdbId}/season/${seasonNumber}`);
    } catch {
      /* skip */
    }

    const episodes = (detail.episodes || []).map((ep) => ({
      seasonNumber,
      episodeNumber: ep.episode_number,
      tmdbEpisodeId: String(ep.id),
      episodeName: ep.name,
      runtimeMinutes: ep.runtime || 0,
    }));

    this.cache.seasonEpisodes[cacheKey] = episodes;
    return episodes;
  }

  async resolveShowProgress(tmdbId, watchedEps) {
    const show = await this.getShowMeta(tmdbId);
    const watchedKeys = new Set(
      watchedEps.map((w) => episodeKey(w.seasonNumber, w.episodeNumber))
    );

    const episodeIndex = [];
    const watchedSeasons = [...new Set(watchedEps.map((w) => w.seasonNumber))].sort((a, b) => a - b);
    for (const seasonNumber of watchedSeasons) {
      episodeIndex.push(...(await this.getSeasonEpisodes(tmdbId, seasonNumber)));
    }

    let next = null;
    const orderedSeasons = [...show.seasons].sort((a, b) => a.season_number - b.season_number);
    for (const season of orderedSeasons) {
      const seasonEps = await this.getSeasonEpisodes(tmdbId, season.season_number);
      const unwatched = seasonEps.find(
        (ep) => !watchedKeys.has(episodeKey(ep.seasonNumber, ep.episodeNumber))
      );
      if (unwatched) {
        next = unwatched;
        break;
      }
    }

    return {
      show,
      episodes: episodeIndex,
      totalEpisodes: show.number_of_episodes || episodeIndex.length,
      next,
    };
  }

  async getEpisodeIndex(tmdbId) {
    if (this.cache.episodeIndex[tmdbId]?.episodes?.length) return this.cache.episodeIndex[tmdbId];

    const show = await this.getShowMeta(tmdbId);
    const episodes = [];
    for (const season of show.seasons) {
      episodes.push(...(await this.getSeasonEpisodes(tmdbId, season.season_number)));
    }

    const payload = {
      show: {
        id: show.id,
        name: show.name,
        poster_path: show.poster_path,
        backdrop_path: show.backdrop_path,
        number_of_episodes: show.number_of_episodes,
      },
      episodes,
      totalEpisodes: show.number_of_episodes || episodes.length,
    };
    this.cache.episodeIndex[tmdbId] = payload;
    return payload;
  }
}

function buildEpisodeDocs(userId, tmdbId, showMeta, episodeIndex, watchedForShow) {
  const indexByKey = new Map(
    episodeIndex.map((ep) => [episodeKey(ep.seasonNumber, ep.episodeNumber), ep])
  );

  return watchedForShow.map((w) => {
    const meta = indexByKey.get(episodeKey(w.seasonNumber, w.episodeNumber));
    return {
      userFrom: userId,
      tvId: tmdbId,
      seasonNumber: w.seasonNumber,
      episodeNumber: w.episodeNumber,
      tmdbEpisodeId: meta?.tmdbEpisodeId || '',
      episodeName: meta?.episodeName || '',
      runtimeMinutes: meta?.runtimeMinutes || 0,
      watchedAt: w.watchedAt,
    };
  });
}

function buildTrackingDoc(userId, tmdbId, showMeta, episodeIndex, watchedForShow, nextEp) {
  const watchedKeys = new Set(
    watchedForShow.map((w) => episodeKey(w.seasonNumber, w.episodeNumber))
  );
  const next =
    nextEp ||
    episodeIndex.find((ep) => !watchedKeys.has(episodeKey(ep.seasonNumber, ep.episodeNumber)));
  const lastByOrder = [...watchedForShow].sort(
    (a, b) => a.seasonNumber - b.seasonNumber || a.episodeNumber - b.episodeNumber
  ).pop();
  const lastByDate = [...watchedForShow].sort(
    (a, b) => new Date(b.watchedAt || 0) - new Date(a.watchedAt || 0)
  )[0];
  const totalEpisodes = showMeta.number_of_episodes || episodeIndex.length;
  const count = watchedForShow.length;
  const completed = totalEpisodes > 0 && count >= totalEpisodes;

  return {
    userFrom: userId,
    tvId: tmdbId,
    tvTitle: showMeta.name,
    tvPosterImage: showMeta.poster_path || '',
    tvBackdropImage: showMeta.backdrop_path || '',
    totalEpisodes,
    watchedEpisodeCount: count,
    status: completed ? 'completed' : 'watching',
    nextSeason: completed ? null : next?.seasonNumber ?? null,
    nextEpisode: completed ? null : next?.episodeNumber ?? null,
    nextEpisodeName: completed ? null : next?.episodeName ?? null,
    lastSeason: lastByOrder?.seasonNumber ?? null,
    lastEpisode: lastByOrder?.episodeNumber ?? null,
    lastWatchedAt: lastByDate?.watchedAt ?? null,
  };
}

module.exports = {
  loadGdprData,
  TmdbMapper,
  buildEpisodeDocs,
  buildTrackingDoc,
  normalizeTitle,
  readCsv,
};
