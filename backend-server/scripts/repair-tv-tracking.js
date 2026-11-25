#!/usr/bin/env node
/**
 * Repair TV tracking against TMDB's real catalog:
 *  - removes logged episodes TMDB doesn't list (e.g. S2E1–S2E22 of a one-season show)
 *  - recomputes next episode, totals and status for every tracked show
 *
 * Shows mid-rewatch are skipped. Previews by default; pass --apply to write.
 *
 * Usage:
 *   node scripts/repair-tv-tracking.js --user <username or email>
 *   node scripts/repair-tv-tracking.js --user <username or email> --apply
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env'), quiet: true });

const mongoose = require('mongoose');
const keys = require('../config/keys');
const User = require('../models/user');
const TvShowTracking = require('../models/tvShowTracking');
const TvEpisodeWatch = require('../models/tvEpisodeWatch');
const { episodeExists, loadCatalog, resolveProgress } = require('../services/tvCatalog');
const { syncTrackingCounts } = require('../routes/tvtracking');
const { invalidateUserStats } = require('../services/statsCache');

function parseArgs(argv) {
  const opts = { user: null, apply: false };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--user') opts.user = argv[++i];
    else if (argv[i] === '--apply') opts.apply = true;
  }
  return opts;
}

function code(s, e) {
  return s == null || e == null ? '—' : `S${s}E${e}`;
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (!opts.user) {
    console.error('Pass --user <username or email>.');
    process.exit(1);
  }
  if (!process.env.TMDB_API_KEY) {
    console.error('Set TMDB_API_KEY in backend-server/.env.');
    process.exit(1);
  }

  await mongoose.connect(keys.mongoURL);
  const user = await User.findOne({ $or: [{ username: opts.user }, { email: opts.user.toLowerCase() }] });
  if (!user) {
    console.error(`User not found: ${opts.user}`);
    process.exit(1);
  }
  const userId = user._id;
  console.log(`${opts.apply ? 'Repairing' : 'Previewing'} TV tracking for ${opts.user}\n`);

  const tracks = await TvShowTracking.find({ userFrom: userId });
  let phantomTotal = 0;
  let changedShows = 0;
  let skipped = 0;

  for (const track of tracks) {
    const tvId = String(track.tvId).trim();
    const title = track.tvTitle || tvId;
    if (track.status === 'rewatching') {
      skipped += 1;
      continue;
    }
    const catalog = await loadCatalog(tvId);
    if (!catalog) {
      console.log(`? ${title}: TMDB unavailable, left as is`);
      skipped += 1;
      continue;
    }

    const watched = await TvEpisodeWatch.find({ userFrom: userId, tvId });
    const phantoms = [];
    for (const ep of watched) {
      if (ep.seasonNumber === 0) continue;
      if (!(await episodeExists(tvId, catalog, ep.seasonNumber, ep.episodeNumber))) phantoms.push(ep);
    }

    const real = watched
      .filter((ep) => !phantoms.includes(ep))
      .sort((a, b) => a.seasonNumber - b.seasonNumber || a.episodeNumber - b.episodeNumber);
    const furthest = real.length ? real[real.length - 1] : null;
    const truth = await resolveProgress(
      tvId,
      furthest ? { season: furthest.seasonNumber, episode: furthest.episodeNumber } : null
    );

    const before = `${track.status} · next ${code(track.nextSeason, track.nextEpisode)} · total ${track.totalEpisodes || 0}`;
    const after = truth
      ? `next ${code(truth.nextSeason, truth.nextEpisode)} · total ${truth.totalEpisodes}`
      : 'unchanged';
    const nextChanged = truth && (
      (track.nextSeason || null) !== truth.nextSeason
      || (track.nextEpisode || null) !== truth.nextEpisode
      || (track.totalEpisodes || 0) !== truth.totalEpisodes
    );
    if (!phantoms.length && !nextChanged) continue;

    changedShows += 1;
    phantomTotal += phantoms.length;
    console.log(`• ${title}`);
    console.log(`    now:   ${before}`);
    console.log(`    fixed: ${after}`);
    if (phantoms.length) {
      console.log(`    remove ${phantoms.length} unlisted: ${phantoms.map((p) => code(p.seasonNumber, p.episodeNumber)).join(', ')}`);
    }

    if (opts.apply) {
      if (phantoms.length) {
        await TvEpisodeWatch.deleteMany({ _id: { $in: phantoms.map((p) => p._id) } });
      }
      const synced = await syncTrackingCounts(userId, tvId);
      console.log(`    saved: ${synced ? `${synced.status} · next ${code(synced.nextSeason, synced.nextEpisode)}` : 'removed (no episodes left)'}`);
    }
  }

  if (opts.apply && changedShows) await invalidateUserStats(userId);

  console.log(`\n${changedShows} of ${tracks.length} shows ${opts.apply ? 'repaired' : 'need repair'}; ${phantomTotal} unlisted episodes; ${skipped} skipped.`);
  if (!opts.apply && changedShows) console.log('Run again with --apply to write these changes.');
  await mongoose.disconnect();
}

main().catch(async (err) => {
  console.error(err);
  await mongoose.disconnect();
  process.exit(1);
});
