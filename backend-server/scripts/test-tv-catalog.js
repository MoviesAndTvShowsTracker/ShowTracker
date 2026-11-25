/* Next-episode, totals and completion from TMDB's catalog. No DB, no network. */
const assert = require('assert');
const {
  airedCount,
  decideStatus,
  episodeAfter,
  episodeExists,
  loadCatalog,
  resolveProgress,
} = require('../services/tvCatalog');

function ep(n, name, air = '2026-01-01') {
  return { episode_number: n, name: name || `E${n}`, air_date: air };
}

function fakeTmdb(shows, seasons, { failSeasons = [] } = {}) {
  return {
    getTvShow: async (id) => shows[id] || null,
    getTvSeason: async (id, s) => {
      if (failSeasons.includes(`${id}-${s}`)) return null;
      return seasons[`${id}-${s}`] || null;
    },
  };
}

const range = (n) => Array.from({ length: n }, (_, i) => ep(i + 1));

const tmdb = fakeTmdb(
  {
    // VisionQuest: one season of 8, ended.
    vq: { seasons: [{ season_number: 1, episode_count: 8 }], last_episode_to_air: { season_number: 1, episode_number: 8 } },
    // Specials + two seasons; season 2 still airing (E5–E8 upcoming).
    multi: {
      seasons: [
        { season_number: 0, episode_count: 3 },
        { season_number: 1, episode_count: 10 },
        { season_number: 2, episode_count: 8 },
      ],
      last_episode_to_air: { season_number: 2, episode_number: 4 },
    },
    // Season 2 announced, no episodes listed yet.
    announced: {
      seasons: [{ season_number: 1, episode_count: 6 }, { season_number: 2, episode_count: 0 }],
      last_episode_to_air: { season_number: 1, episode_number: 6 },
    },
    empty: { seasons: [] },
  },
  {
    'vq-1': { episodes: range(8) },
    'multi-0': { episodes: range(3) },
    'multi-1': { episodes: range(10) },
    'multi-2': { episodes: range(8) },
    'announced-1': { episodes: range(6) },
  }
);

(async () => {
  // Catalog totals
  const vq = await loadCatalog('vq', tmdb);
  assert.deepStrictEqual(vq, { seasons: [{ season: 1, count: 8 }], total: 8, aired: 8 });
  const multi = await loadCatalog('multi', tmdb);
  assert.strictEqual(multi.total, 18, 'specials are not counted');
  assert.strictEqual(multi.aired, 14);
  assert.strictEqual(await loadCatalog('missing', tmdb), null);
  assert.strictEqual(await loadCatalog('empty', tmdb), null);
  assert.strictEqual(airedCount([{ season: 1, count: 5 }], null), 0);

  // The bug: after the finale there is no "season 2, episode 1".
  assert.strictEqual(await episodeAfter('vq', vq, { season: 1, episode: 8 }, tmdb), null);
  assert.deepStrictEqual(await episodeAfter('vq', vq, { season: 1, episode: 3 }, tmdb), { season: 1, episode: 4, name: 'E4' });
  // A bogus position past the end never invents more episodes.
  assert.strictEqual(await episodeAfter('vq', vq, { season: 2, episode: 21 }, tmdb), null);

  // Season boundary goes to the next real season; specials are skipped.
  assert.deepStrictEqual(await episodeAfter('multi', multi, { season: 1, episode: 10 }, tmdb), { season: 2, episode: 1, name: 'E1' });
  assert.deepStrictEqual(await episodeAfter('multi', multi, { season: 0, episode: 2 }, tmdb), { season: 1, episode: 1, name: 'E1' });
  assert.deepStrictEqual(await episodeAfter('multi', multi, null, tmdb), { season: 1, episode: 1, name: 'E1' });
  // Upcoming episodes are still "next" (Home shows when it airs).
  assert.deepStrictEqual(await episodeAfter('multi', multi, { season: 2, episode: 4 }, tmdb), { season: 2, episode: 5, name: 'E5' });

  // An announced season with no episodes isn't a next episode.
  const announced = await loadCatalog('announced', tmdb);
  assert.strictEqual(await episodeAfter('announced', announced, { season: 1, episode: 6 }, tmdb), null);

  // Season list unavailable: fall back to TMDB's per-season count, never beyond it.
  const flaky = fakeTmdb({ vq: { seasons: [{ season_number: 1, episode_count: 8 }] } }, {}, { failSeasons: ['vq-1'] });
  const flakyCat = await loadCatalog('vq', flaky);
  assert.deepStrictEqual(await episodeAfter('vq', flakyCat, { season: 1, episode: 7 }, flaky), { season: 1, episode: 8, name: null });
  assert.strictEqual(await episodeAfter('vq', flakyCat, { season: 1, episode: 8 }, flaky), null);
  assert.strictEqual(await episodeExists('vq', flakyCat, 1, 9, flaky), false);

  // Existence checks
  assert.strictEqual(await episodeExists('vq', vq, 1, 8, tmdb), true);
  assert.strictEqual(await episodeExists('vq', vq, 2, 1, tmdb), false);
  assert.strictEqual(await episodeExists('vq', vq, 1, 9, tmdb), false);

  // resolveProgress end to end
  assert.deepStrictEqual(await resolveProgress('vq', { season: 1, episode: 8 }, tmdb), {
    totalEpisodes: 8, airedEpisodeCount: 8, nextSeason: null, nextEpisode: null, nextEpisodeName: null,
  });
  assert.strictEqual(await resolveProgress('missing', null, tmdb), null);

  // Status
  const base = { status: 'watching', resolved: true };
  assert.strictEqual(decideStatus({ ...base, count: 8, total: 8, aired: 8, hasNext: false }), 'completed');
  // Skipped an episode but watched the finale of an ended show: done.
  assert.strictEqual(decideStatus({ ...base, count: 7, total: 8, aired: 8, hasNext: false }), 'completed');
  // Count inflated by specials while episodes remain: not done.
  assert.strictEqual(decideStatus({ ...base, count: 20, total: 18, aired: 18, hasNext: true }), 'watching');
  // Caught up on an airing season: keep watching.
  assert.strictEqual(decideStatus({ ...base, count: 14, total: 18, aired: 14, hasNext: true }), 'watching');
  // Unmarking a finished show reopens it; paused resumes on a mark.
  assert.strictEqual(decideStatus({ ...base, status: 'completed', count: 7, total: 8, aired: 8, hasNext: true }), 'watching');
  assert.strictEqual(decideStatus({ ...base, status: 'paused', count: 3, total: 8, aired: 8, hasNext: true }), 'watching');
  // Without TMDB: fall back to counts; an unknown total never completes.
  assert.strictEqual(decideStatus({ status: 'watching', resolved: false, count: 8, total: 8, aired: 8, hasNext: true }), 'completed');
  assert.strictEqual(decideStatus({ status: 'watching', resolved: false, count: 30, total: 0, aired: 0, hasNext: true }), 'watching');

  console.log('tv catalog: all passed');
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
