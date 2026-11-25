#!/usr/bin/env node
/* Read-only: the aggregated streak days equal the old whole-history day set, for every user. */
require('dotenv').config({ path: require('path').join(__dirname, '../.env'), quiet: true });
const mongoose = require('mongoose');
const keys = require('../config/keys');
const User = require('../models/user');
const TvEpisodeWatch = require('../models/tvEpisodeWatch');
const TvRewatchEpisode = require('../models/tvRewatchEpisode');
const Watch = require('../models/watch');
const { activeDayKeys } = require('../services/weekRecap');
const { dateKeyInZone } = require('../services/statsCalendar');

(async () => {
  await mongoose.connect(keys.mongoURL);
  let mismatches = 0;
  for (const tz of ['America/New_York', 'Asia/Kolkata', 'Pacific/Auckland']) {
    for (const user of await User.find({}).select('_id').lean()) {
      const [eps, rws, films] = await Promise.all([
        TvEpisodeWatch.find({ userFrom: user._id }).select('watchedAt').lean(),
        TvRewatchEpisode.find({ userFrom: user._id }).select('watchedAt').lean(),
        Watch.find({ userFrom: user._id }).select('watchedAt').lean(),
      ]);
      const old = new Set([...eps, ...rws, ...films].filter((r) => r.watchedAt).map((r) => dateKeyInZone(r.watchedAt, tz)));
      const next = await activeDayKeys(user._id, tz);
      const same = old.size === next.size && [...old].every((k) => next.has(k));
      if (!same) {
        mismatches += 1;
        console.log('mismatch', String(user._id), tz, old.size, next.size);
      }
    }
  }
  console.log(`${mismatches} mismatches`);
  await mongoose.disconnect();
  process.exit(mismatches ? 1 : 0);
})();
