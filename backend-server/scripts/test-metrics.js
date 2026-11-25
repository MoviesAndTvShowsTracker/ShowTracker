/* Request timing middleware and event-loop monitor. No DB, no network. */
const assert = require('assert');
const { requestTimer, startLoopMonitor } = require('../lib/metrics');

function fakeRes() {
  const headers = {};
  const listeners = {};
  return {
    statusCode: 200,
    headers,
    setHeader(k, v) { headers[k.toLowerCase()] = v; },
    getHeader(k) { return headers[k.toLowerCase()]; },
    on(evt, fn) { listeners[evt] = fn; },
    once(evt, fn) { listeners[evt] = fn; },
    emit(evt) { if (listeners[evt]) listeners[evt](); },
    writeHead() {},
  };
}

(async () => {
  // Fast request: Server-Timing set, nothing logged.
  const logs = [];
  let clock = 1000;
  const mw = requestTimer({ slowMs: 500, log: (line) => logs.push(line), now: () => clock });
  const req = { method: 'GET', originalUrl: '/api/home?tz=America/New_York&token=secret' };
  const res = fakeRes();
  let nextCalled = false;
  mw(req, res, () => { nextCalled = true; });
  assert.ok(nextCalled, 'calls next');
  clock += 120;
  res.emit('finish');
  assert.strictEqual(logs.length, 0, 'fast request is not logged');

  // Slow request: logged once, without the query string.
  const slowRes = fakeRes();
  slowRes.statusCode = 201;
  mw({ method: 'POST', originalUrl: '/api/tv/episodes/mark?x=1' }, slowRes, () => {});
  clock += 750;
  slowRes.emit('finish');
  assert.strictEqual(logs.length, 1);
  assert.strictEqual(logs[0], '[slow] POST /api/tv/episodes/mark 201 750ms');

  // Server-Timing is added before headers go out.
  const timed = fakeRes();
  mw({ method: 'GET', originalUrl: '/health' }, timed, () => {});
  clock += 42;
  timed.writeHead(200);
  assert.strictEqual(timed.getHeader('server-timing'), 'app;dur=42');

  // Loop monitor reports numbers in ms.
  const mon = startLoopMonitor({ resolution: 10 });
  await new Promise((r) => setTimeout(r, 60));
  const snap = mon.snapshot();
  mon.stop();
  for (const k of ['p50', 'p99', 'max']) assert.ok(Number.isFinite(snap[k]) && snap[k] >= 0, k);

  console.log('metrics: all passed');
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
