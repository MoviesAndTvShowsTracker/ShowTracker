/* Shared TMDB client: coalescing, byte-bounded TTL cache, concurrency cap, 429 retry, timeout. No network. */
const assert = require('assert');
const { createTmdbClient } = require('../lib/tmdbClient');

function response(status, body, headers = {}) {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: { get: (k) => headers[k.toLowerCase()] ?? null },
    text: async () => body,
  };
}

const tick = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  // Coalescing: five callers, one upstream request.
  let calls = 0;
  let clock = 0;
  const slow = async () => { calls += 1; await tick(20); return response(200, '{"a":1}', { 'content-type': 'application/json' }); };
  const c1 = createTmdbClient({ fetchImpl: slow, now: () => clock });
  const many = await Promise.all(Array.from({ length: 5 }, () => c1.getText('u1', { cacheKey: 'k1', ttlSeconds: 60 })));
  assert.strictEqual(calls, 1, 'one upstream call for concurrent callers');
  assert.ok(many.every((r) => r.status === 200 && r.body === '{"a":1}'));

  // Cached until the TTL ends.
  const hit = await c1.getText('u1', { cacheKey: 'k1', ttlSeconds: 60 });
  assert.strictEqual(hit.cache, 'HIT');
  assert.strictEqual(calls, 1);
  clock += 61 * 1000;
  const miss = await c1.getText('u1', { cacheKey: 'k1', ttlSeconds: 60 });
  assert.strictEqual(miss.cache, 'MISS');
  assert.strictEqual(calls, 2, 'refetched after expiry');

  // JSON helper parses, and returns null for failures.
  assert.deepStrictEqual(await c1.getJson('u1', { cacheKey: 'k1', ttlSeconds: 60 }), { a: 1 });

  // Errors are not cached.
  let n404 = 0;
  const c2 = createTmdbClient({ fetchImpl: async () => { n404 += 1; return response(404, '{}'); } });
  assert.strictEqual((await c2.getText('x', { cacheKey: 'x', ttlSeconds: 60 })).status, 404);
  await c2.getText('x', { cacheKey: 'x', ttlSeconds: 60 });
  assert.strictEqual(n404, 2, 'a 404 is not cached');
  assert.strictEqual(await c2.getJson('x', { cacheKey: 'x', ttlSeconds: 60 }), null);

  // Byte cap evicts the least recently used entry.
  const body40 = 'x'.repeat(40);
  const c3 = createTmdbClient({ fetchImpl: async () => response(200, body40), maxBytes: 100 });
  for (const k of ['a', 'b', 'c']) await c3.getText(k, { cacheKey: k, ttlSeconds: 60 });
  assert.ok(c3.stats().bytes <= 100, `bytes ${c3.stats().bytes}`);
  assert.strictEqual(c3.stats().entries, 2);
  assert.strictEqual((await c3.getText('a', { cacheKey: 'a', ttlSeconds: 60 })).cache, 'MISS', 'oldest evicted');

  // Concurrency cap: never more than 2 upstream at once.
  let live = 0;
  let peak = 0;
  const c4 = createTmdbClient({
    maxConcurrent: 2,
    fetchImpl: async () => { live += 1; peak = Math.max(peak, live); await tick(15); live -= 1; return response(200, '{}'); },
  });
  await Promise.all(['1', '2', '3', '4', '5'].map((k) => c4.getText(k, { cacheKey: k, ttlSeconds: 60 })));
  assert.strictEqual(peak, 2, `peak ${peak}`);

  // 429: wait Retry-After, retry once.
  let tries = 0;
  const waited = [];
  const c5 = createTmdbClient({
    fetchImpl: async () => { tries += 1; return tries === 1 ? response(429, '', { 'retry-after': '2' }) : response(200, '{}'); },
    sleep: async (ms) => { waited.push(ms); },
  });
  assert.strictEqual((await c5.getText('r', { cacheKey: 'r', ttlSeconds: 60 })).status, 200);
  assert.strictEqual(tries, 2);
  assert.deepStrictEqual(waited, [2000]);

  // Every upstream request carries an abort signal (the timeout).
  let signal;
  const c6 = createTmdbClient({ fetchImpl: async (url, opts) => { signal = opts && opts.signal; return response(200, '{}'); }, timeoutMs: 8000 });
  await c6.getText('t', { cacheKey: 't', ttlSeconds: 60 });
  assert.ok(signal && typeof signal.aborted === 'boolean', 'fetch receives a signal');

  // A transport failure throws from getText and is null from getJson; nothing is cached.
  const c7 = createTmdbClient({ fetchImpl: async () => { throw new Error('timeout'); } });
  await assert.rejects(c7.getText('f', { cacheKey: 'f', ttlSeconds: 60 }), /timeout/);
  assert.strictEqual(await c7.getJson('f', { cacheKey: 'f', ttlSeconds: 60 }), null);

  console.log('tmdb client: all passed');
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
