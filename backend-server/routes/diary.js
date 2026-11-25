const express = require('express');
const authenticate = require('../authenticate');
const { buildActivity } = require('../services/diaryActivity');
const { buildDiaryIndex } = require('../services/diaryIndex');
const { sendWithEtag } = require('../lib/etag');
const { buildExport, toCsv } = require('../services/diaryExport');
const { buildNotes } = require('../services/diaryNotes');
const { resolveTimeZone } = require('../services/statsCalendar');

const router = express.Router();

router.get('/activity', authenticate.verifyUser, async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 60, 120);
    const items = await buildActivity(req.user._id, limit);
    res.status(200).json({ success: true, items });
  } catch (err) {
    next(err);
  }
});

/** Catalogue badge data, revalidated with ETag: an unchanged diary costs a 304 and no body. */
router.get('/index', authenticate.verifyUser, async (req, res, next) => {
  try {
    const index = await buildDiaryIndex(req.user._id);
    sendWithEtag(req, res, { success: true, ...index });
  } catch (err) {
    next(err);
  }
});

/** "Your notes": every note, newest first; ?q= filters by note or title text. */
router.get('/notes', authenticate.verifyUser, async (req, res, next) => {
  try {
    const q = typeof req.query.q === 'string' ? req.query.q.slice(0, 100) : '';
    const notes = await buildNotes(req.user._id, { q, limit: req.query.limit });
    res.status(200).json({ success: true, notes });
  } catch (err) {
    next(err);
  }
});

/** Your whole diary as a file: ?format=csv (one row per watch) or json (everything). */
router.get('/export', authenticate.verifyUser, async (req, res, next) => {
  try {
    const format = req.query.format === 'json' ? 'json' : 'csv';
    const timeZone = resolveTimeZone(req.query.tz || req.headers['x-timezone']);
    const { rows, json } = await buildExport(req.user._id, timeZone);
    const stamp = new Date().toISOString().slice(0, 10);
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Content-Disposition', `attachment; filename="marquee-diary-${stamp}.${format}"`);
    if (format === 'json') {
      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      return res.status(200).send(JSON.stringify(json, null, 2));
    }
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    // The byte-order mark makes Excel read accents and emoji as UTF-8.
    return res.status(200).send(`\uFEFF${toCsv(rows)}\r\n`);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
