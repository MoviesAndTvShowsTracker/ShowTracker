/* "Rewatch" follows the dates: the earliest play is the first watch, even if logged later. No DB. */
const assert = require('assert');
const { rewatchFlags } = require('../services/filmWatchService');

const plays = [
  { _id: 'today', watchedAt: new Date('2026-11-26'), isRewatch: false },
  { _id: 'backdated', watchedAt: new Date('2025-02-14'), isRewatch: true },
  { _id: 'middle', watchedAt: new Date('2026-01-10'), isRewatch: true },
];
assert.deepStrictEqual(rewatchFlags(plays), [
  { id: 'backdated', isRewatch: false },
  { id: 'middle', isRewatch: true },
  { id: 'today', isRewatch: true },
]);
assert.deepStrictEqual(rewatchFlags([]), []);
assert.deepStrictEqual(rewatchFlags([{ _id: 'only', watchedAt: new Date() }]), [{ id: 'only', isRewatch: false }]);

console.log('rewatch flags: all passed');
