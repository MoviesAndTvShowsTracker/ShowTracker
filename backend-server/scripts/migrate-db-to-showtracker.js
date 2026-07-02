#!/usr/bin/env node
/**
 * One-time migration: copy collections from "test" → "showtracker".
 * Run from backend-server: node scripts/migrate-db-to-showtracker.js
 */
require('dotenv').config();
const mongoose = require('mongoose');

const COLLECTIONS = [
  'users',
  'favorites',
  'watches',
  'watchlists',
  'favoritetvs',
  'tvwatches',
  'tvwatchlists',
];

function uriForDb(baseUri, dbName) {
  const withoutDb = baseUri.replace(/(mongodb\+srv:\/\/[^/]+)\/[^?]*(\?.*)?$/, '$1$2');
  const query = withoutDb.includes('?') ? withoutDb.split('?')[1] : 'retryWrites=true&w=majority';
  const host = withoutDb.replace(/\?.*$/, '');
  return `${host}/${dbName}?${query}`;
}

async function migrate() {
  const targetUri = process.env.MONGODB_URI;
  if (!targetUri?.includes('/showtracker')) {
    console.error('Set MONGODB_URI with /showtracker in the path first.');
    process.exit(1);
  }

  const sourceUri = uriForDb(targetUri, 'test');
  const destUri = uriForDb(targetUri, 'showtracker');

  const source = mongoose.createConnection(sourceUri);
  const dest = mongoose.createConnection(destUri);

  await source.asPromise();
  await dest.asPromise();

  console.log('Source: test');
  console.log('Target: showtracker\n');

  for (const name of COLLECTIONS) {
    const docs = await source.db.collection(name).find({}).toArray();
    if (!docs.length) {
      console.log(`${name}: (empty, skipped)`);
      continue;
    }

    let copied = 0;
    for (const doc of docs) {
      await dest.db.collection(name).replaceOne({ _id: doc._id }, doc, { upsert: true });
      copied += 1;
    }
    console.log(`${name}: ${copied} document(s) copied`);
  }

  await source.close();
  await dest.close();
  console.log('\nDone. Restart the backend and sign in again.');
}

migrate().catch((err) => {
  console.error(err);
  process.exit(1);
});
