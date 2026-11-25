/* Lookups with different lifetimes never share a cache entry (show detail 6 h vs metadata 24 h). */
const assert = require('assert');
const { libCacheKey } = require('../lib/tmdb');

assert.notStrictEqual(libCacheKey('tv/1396', 6 * 3600), libCacheKey('tv/1396', 24 * 3600));
assert.strictEqual(libCacheKey('/tv/1396', 3600), libCacheKey('tv/1396', 3600));
console.log('tmdb keys: all passed');
