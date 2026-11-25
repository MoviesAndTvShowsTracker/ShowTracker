/* Per-user lists are indexed by user (and item), so a lookup never scans every user's rows. No DB. */
const assert = require('assert');

const cases = [
  ['../models/favorite', { userFrom: 1, movieId: 1 }],
  ['../models/favoritefortv', { userFrom: 1, tvId: 1 }],
  ['../models/moviewatchlist', { userFrom: 1, movieId: 1 }],
  ['../models/tvwatchlist', { userFrom: 1, tvId: 1 }],
];

for (const [path, key] of cases) {
  const model = require(path);
  const keys = model.schema.indexes().map(([fields]) => JSON.stringify(fields));
  assert.ok(keys.includes(JSON.stringify(key)), `${model.modelName} has ${JSON.stringify(key)}; has ${keys.join(' ')}`);
}

console.log('indexes: all passed');
