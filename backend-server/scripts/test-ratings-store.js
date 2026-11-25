/* Ratings: memory → persisted copy → one shared build; memory stays bounded. No DB, no network. */
const assert = require('assert');
const { createRatingsStore } = require('../services/ratingsStore');

function fakePersist() {
  const rows = new Map();
  return {
    rows,
    reads: 0,
    async get(key) { this.reads += 1; return rows.get(key) || null; },
    async set(key, payload) { rows.set(key, payload); },
  };
}

(async () => {
  let builds = 0;
  const build = async (kind, id) => { builds += 1; await new Promise((r) => setTimeout(r, 20)); return { kind, id: Number(id) }; };

  // Concurrent first requests share one build; the result is persisted.
  const persist = fakePersist();
  const store = createRatingsStore({ build, persist, memoryMax: 2 });
  const results = await Promise.all([store.get('movie', '1'), store.get('movie', '1'), store.get('movie', '1')]);
  assert.strictEqual(builds, 1);
  assert.deepStrictEqual(results[0], { kind: 'movie', id: 1 });
  assert.deepStrictEqual(persist.rows.get('v3:movie:1'), { kind: 'movie', id: 1 });

  // Memory hit: no persisted read, no build.
  const reads = persist.reads;
  await store.get('movie', '1');
  assert.strictEqual(persist.reads, reads);
  assert.strictEqual(builds, 1);

  // After a restart (new store, same persisted rows): no rebuild, no OMDb call.
  const restarted = createRatingsStore({ build, persist, memoryMax: 2 });
  assert.deepStrictEqual(await restarted.get('movie', '1'), { kind: 'movie', id: 1 });
  assert.strictEqual(builds, 1, 'persisted copy survives a deploy');

  // Memory is bounded.
  await store.get('tv', '2');
  await store.get('tv', '3');
  assert.ok(store.memorySize() <= 2, `memory ${store.memorySize()}`);

  // A failing persisted store never breaks ratings.
  const broken = createRatingsStore({
    build,
    persist: { get: async () => { throw new Error('db down'); }, set: async () => { throw new Error('db down'); } },
  });
  assert.deepStrictEqual(await broken.get('movie', '9'), { kind: 'movie', id: 9 });

  console.log('ratings store: all passed');
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
