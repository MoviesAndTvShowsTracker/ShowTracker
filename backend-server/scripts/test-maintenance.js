/* Auto-pause runs at most once a day per user instead of on every Home load. No DB. */
const assert = require('assert');
const { maintenanceDue } = require('../services/tvTrackingMaintenance');

const day = 24 * 60 * 60 * 1000;
const t0 = Date.parse('2026-11-25T12:00:00Z');

assert.strictEqual(maintenanceDue('u1', t0), true, 'first visit runs');
assert.strictEqual(maintenanceDue('u1', t0 + 60 * 1000), false, 'a minute later: skipped');
assert.strictEqual(maintenanceDue('u1', t0 + day - 1), false, 'just under a day: skipped');
assert.strictEqual(maintenanceDue('u2', t0 + 60 * 1000), true, 'other users are independent');
assert.strictEqual(maintenanceDue('u1', t0 + day), true, 'a day later: runs again');

console.log('maintenance: all passed');
