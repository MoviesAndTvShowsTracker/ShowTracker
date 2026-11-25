/* /api/me: one response per detail page, its lookups run in parallel. No DB. */
const assert = require('assert');
const { buildTvState, buildMovieState } = require('../services/userMediaState');

const tick = (ms, v) => new Promise((r) => setTimeout(() => r(v), ms));

(async () => {
  const started = Date.now();
  const tv = await buildTvState('u', '1396', {
    favorited: () => tick(40, true),
    watchlisted: () => tick(40, false),
    tracking: () => tick(40, { tvId: '1396', status: 'watching' }),
    episodes: () => tick(40, [{ seasonNumber: 1, episodeNumber: 1 }]),
    rewatch: () => tick(40, { playCounts: { '1-1': 1 } }),
  });
  assert.ok(Date.now() - started < 120, 'lookups run in parallel');
  assert.deepStrictEqual(tv, {
    favorited: true,
    watchlisted: false,
    tracking: { tvId: '1396', status: 'watching' },
    episodes: [{ seasonNumber: 1, episodeNumber: 1 }],
    rewatch: { playCounts: { '1-1': 1 } },
  });

  const movie = await buildMovieState('u', '550', {
    favorited: async () => false,
    watchlisted: async () => true,
    watched: async () => ({ watched: true, watchCount: 2 }),
  });
  assert.deepStrictEqual(movie, { favorited: false, watchlisted: true, watched: { watched: true, watchCount: 2 } });

  // A failing part fails the whole answer (the app then falls back to the old calls).
  await assert.rejects(buildMovieState('u', '550', {
    favorited: async () => { throw new Error('db down'); },
    watchlisted: async () => true,
    watched: async () => ({}),
  }), /db down/);

  console.log('me shape: all passed');
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
