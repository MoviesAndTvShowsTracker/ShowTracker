#!/usr/bin/env node
/**
 * Import TV Time GDPR export into Marquee.
 *
 * Usage:
 *   node scripts/import-tvtime.js --dry-run --user admin --data ../gdpr-data
 *   node scripts/import-tvtime.js --user admin --data ../gdpr-data --replace
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const keys = require('../config/keys');
const User = require('../models/user');
const { runTvTimeImport } = require('../services/tvtimeImport');

function parseArgs(argv) {
  const opts = {
    dryRun: false,
    replace: true,
    user: 'admin',
    dataDir: path.resolve(__dirname, '../../gdpr-data'),
    report: null,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--dry-run') opts.dryRun = true;
    else if (arg === '--replace') opts.replace = true;
    else if (arg === '--no-replace') opts.replace = false;
    else if (arg === '--user') opts.user = argv[++i];
    else if (arg === '--data') opts.dataDir = path.resolve(argv[++i]);
    else if (arg === '--report') opts.report = path.resolve(argv[++i]);
    else if (arg === '--help' || arg === '-h') {
      console.log(`Usage: node scripts/import-tvtime.js [options]

Options:
  --dry-run          Map titles and print report without writing to DB
  --user <name>      Marquee username (default: admin)
  --data <dir>       Path to gdpr-data folder (default: ../../gdpr-data)
  --replace          Clear existing progress for user before import (default)
  --no-replace       Keep existing data and skip duplicates
  --report <file>    Write JSON report (default: <data>/import-report.json)
`);
      process.exit(0);
    }
  }

  if (!opts.report) opts.report = path.join(opts.dataDir, 'import-report.json');
  return opts;
}

async function run() {
  const opts = parseArgs(process.argv.slice(2));
  const apiKey = process.env.TMDB_API_KEY;
  if (!apiKey) {
    console.error('Set TMDB_API_KEY in backend-server/.env (see .env.example).');
    process.exit(1);
  }

  if (!fs.existsSync(opts.dataDir)) {
    console.error(`Data folder not found: ${opts.dataDir}`);
    process.exit(1);
  }

  const cachePath = path.join(__dirname, '.tvtime-import-cache.json');

  if (opts.dryRun) {
    console.log(`Loading GDPR data from ${opts.dataDir}...`);
    const report = await runTvTimeImport({
      userId: 'dry-run',
      dataDir: opts.dataDir,
      apiKey,
      cachePath,
      replace: opts.replace,
      dryRun: true,
      onProgress: (phase, d) => console.log(' ', phase, d || ''),
    });
    fs.writeFileSync(opts.report, JSON.stringify(report, null, 2));
    console.log('\n--- Dry run summary ---');
    console.log(`TV episodes ready: ${report.tv.episodesImported}`);
    console.log(`TV shows mapped: ${report.tv.mapped}`);
    console.log(`Movies watched: ${report.movies.watchedMapped}`);
    console.log(`Report: ${opts.report}`);
    return;
  }

  await mongoose.connect(keys.mongoURL);
  const user = await User.findOne({ username: opts.user });
  if (!user) {
    console.error(`User not found: ${opts.user}`);
    process.exit(1);
  }

  console.log(`Importing for ${opts.user}...`);
  const report = await runTvTimeImport({
    userId: user._id,
    dataDir: opts.dataDir,
    apiKey,
    cachePath,
    replace: opts.replace,
    dryRun: false,
    onProgress: (phase, d) => console.log(' ', phase, d || ''),
  });

  fs.writeFileSync(opts.report, JSON.stringify(report, null, 2));
  console.log('\n--- Import complete ---');
  console.log(`TV episodes: ${report.tv.episodesImported}`);
  console.log(`TV shows: ${report.tv.shows}`);
  console.log(`Movies watched: ${report.movies.watchedMapped}`);
  console.log(`Report: ${opts.report}`);

  await mongoose.disconnect();
}

run().catch((err) => {
  console.error(err);
  mongoose.disconnect().finally(() => process.exit(1));
});
