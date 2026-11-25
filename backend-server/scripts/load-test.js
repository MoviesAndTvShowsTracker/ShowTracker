#!/usr/bin/env node
/**
 * Tiny load test: N virtual users hit the given paths in a loop for D seconds.
 *
 * Start the API with RATE_LIMIT_DISABLED=1 when testing locally: every virtual user shares one IP.
 *
 * Usage:
 *   BASE_URL=http://localhost:5001 TOKEN=<jwt> USERS=10 SECONDS=30 \
 *     node scripts/load-test.js /api/home /api/stats/dashboard
 */
const base = (process.env.BASE_URL || 'http://localhost:5001').replace(/\/$/, '');
const token = process.env.TOKEN || '';
const users = Number(process.env.USERS || 10);
const seconds = Number(process.env.SECONDS || 30);
const paths = process.argv.slice(2);

if (!paths.length) {
  console.error('Pass one or more paths, e.g. /api/home');
  process.exit(1);
}

function pct(sorted, p) {
  if (!sorted.length) return 0;
  return sorted[Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length))];
}

async function user(id, until, times, errors) {
  let i = id;
  while (Date.now() < until) {
    const path = paths[i % paths.length];
    i += 1;
    const started = Date.now();
    try {
      const res = await fetch(base + path, {
        headers: token ? { Authorization: `Bearer ${token}` } : {},
      });
      await res.arrayBuffer();
      if (!res.ok) errors.push(`${res.status} ${path}`);
    } catch (err) {
      errors.push(`${err.message} ${path}`);
    }
    times.push(Date.now() - started);
  }
}

(async () => {
  const until = Date.now() + seconds * 1000;
  const times = [];
  const errors = [];
  await Promise.all(Array.from({ length: users }, (_, id) => user(id, until, times, errors)));
  const sorted = times.slice().sort((a, b) => a - b);
  console.log(`${users} users × ${seconds}s → ${times.length} requests, ${errors.length} errors`);
  console.log(`p50 ${pct(sorted, 50)}ms  p95 ${pct(sorted, 95)}ms  max ${sorted.at(-1) || 0}ms`);
  if (errors.length) console.log('first errors:', errors.slice(0, 5).join(' | '));
  const health = await fetch(base + '/health').then((r) => r.json()).catch(() => null);
  if (health?.loop) console.log('event-loop delay (ms):', JSON.stringify(health.loop));
})();
