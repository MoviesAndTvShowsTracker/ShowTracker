/* In-memory fixed-window rate limiter. No network. */
const assert = require('assert');
const { createRateLimiter, clientKey } = require('../lib/rateLimit');

function fakeRes() {
  return {
    statusCode: 200,
    headers: {},
    body: null,
    setHeader(k, v) { this.headers[k.toLowerCase()] = v; },
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
}

let clock = 0;
const limit = createRateLimiter({ windowMs: 60000, max: 3, now: () => clock, name: 'test' });
const hit = (ip) => {
  const res = fakeRes();
  let passed = false;
  limit({ ip, headers: {} }, res, () => { passed = true; });
  return { passed, res };
};

for (let i = 0; i < 3; i += 1) assert.ok(hit('1.1.1.1').passed, `request ${i + 1} passes`);
const blocked = hit('1.1.1.1');
assert.ok(!blocked.passed, '4th request is blocked');
assert.strictEqual(blocked.res.statusCode, 429);
assert.strictEqual(blocked.res.body.success, false);
assert.strictEqual(blocked.res.headers['retry-after'], '60');
assert.ok(hit('2.2.2.2').passed, 'another client has its own budget');

clock += 60000;
assert.ok(hit('1.1.1.1').passed, 'a new window resets the budget');

// Behind Cloudflare the client address comes from CF-Connecting-IP.
assert.strictEqual(clientKey({ ip: '10.0.0.1', headers: { 'cf-connecting-ip': '203.0.113.9' } }), '203.0.113.9');
assert.strictEqual(clientKey({ ip: '10.0.0.1', headers: {} }), '10.0.0.1');

console.log('rate limit: all passed');
