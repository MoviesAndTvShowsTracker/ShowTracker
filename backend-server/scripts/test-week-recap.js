/* Week recap: the streak reads distinct day keys from MongoDB, not every play. No DB. */
const assert = require('assert');
const mongoose = require('mongoose');
const { dayKeysPipeline } = require('../services/weekRecap');

const uid = new mongoose.Types.ObjectId();
const pipeline = dayKeysPipeline(uid, 'America/New_York');

// Only this user's dated plays.
assert.deepStrictEqual(pipeline[0], { $match: { userFrom: uid, watchedAt: { $ne: null } } });
// One row per local calendar day, in the user's timezone.
assert.deepStrictEqual(pipeline[1], {
  $group: {
    _id: { $dateToString: { format: '%Y-%m-%d', date: '$watchedAt', timezone: 'America/New_York' } },
  },
});
assert.strictEqual(pipeline.length, 2, 'nothing else is fetched');

console.log('week recap: all passed');
