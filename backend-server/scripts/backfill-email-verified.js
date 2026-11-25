#!/usr/bin/env node
/**
 * Marks accounts already linked to Google or Apple as emailVerified (their address came from
 * the provider). Previews by default; pass --apply to write.
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env'), quiet: true });
const mongoose = require('mongoose');
const keys = require('../config/keys');
const User = require('../models/user');

(async () => {
  const apply = process.argv.includes('--apply');
  await mongoose.connect(keys.mongoURL);
  const filter = {
    emailVerified: { $ne: true },
    $or: [{ googleId: { $nin: [null, ''] } }, { appleId: { $nin: [null, ''] } }],
  };
  const count = await User.countDocuments(filter);
  const total = await User.countDocuments({});
  console.log(`${count} of ${total} accounts are provider-linked and not yet marked verified.`);
  if (apply && count) {
    const res = await User.updateMany(filter, { $set: { emailVerified: true } });
    console.log(`updated ${res.modifiedCount}`);
  } else if (count) {
    console.log('Run again with --apply to write.');
  }
  await mongoose.disconnect();
})().catch(async (err) => {
  console.error(err);
  await mongoose.disconnect();
  process.exit(1);
});
