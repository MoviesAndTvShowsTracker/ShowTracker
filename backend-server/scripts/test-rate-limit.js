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

// Per-account budgets: guessing one account's password from many addresses still runs out.
const { accountKey } = require('../lib/rateLimit');
let t = 0;
const perAccount = createRateLimiter({ windowMs: 60000, max: 2, now: () => t, keyFn: accountKey('login') });
const tryLogin = (ip, email) => {
  let ok = false;
  const res = fakeRes();
  perAccount({ ip, headers: {}, body: { email } }, res, () => { ok = true; });
  return ok;
};
assert.ok(tryLogin('1.1.1.1', 'Victim@x.com'));
assert.ok(tryLogin('2.2.2.2', 'victim@x.com'));
assert.ok(!tryLogin('3.3.3.3', 'VICTIM@x.com'), 'third attempt on the same account is blocked from any address');
assert.ok(tryLogin('3.3.3.3', 'someone-else@x.com'), 'other accounts are unaffected');
// No email in the body: falls back to the client address.
assert.strictEqual(accountKey('login')({ ip: '9.9.9.9', headers: {}, body: {} }), 'login:ip:9.9.9.9');

console.log('rate limit: all passed');
