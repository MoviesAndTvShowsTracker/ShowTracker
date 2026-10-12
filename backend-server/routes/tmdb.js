const express = require('express');

const router = express.Router();

const TMDB_BASE = 'https://api.themoviedb.org/3/';

// Only prefixes the UI actually needs. Prevents the proxy from acting as an open relay.
const ALLOWED_PREFIXES = [
  'trending/',
  'movie/',
  'tv/',
  'search/',
  'discover/',
  'genre/',
  'find/',
];

function isAllowed(tmdbPath) {
  if (!tmdbPath) return false;
  if (tmdbPath.includes('..')) return false;
  if (/^https?:/i.test(tmdbPath)) return false;
  return ALLOWED_PREFIXES.some((prefix) => tmdbPath.startsWith(prefix));
}

router.get(/^\/(.+)$/, async (req, res) => {
  const apiKey = process.env.TMDB_API_KEY;
  if (!apiKey) {
    return res
      .status(503)
      .json({ success: false, message: 'TMDB is not configured on the server.' });
  }

  const tmdbPath = req.params[0];
  if (!isAllowed(tmdbPath)) {
    return res.status(400).json({ success: false, message: 'Path not allowed.' });
  }

  let url;
  try {
    url = new URL(TMDB_BASE + tmdbPath);
  } catch {
    return res.status(400).json({ success: false, message: 'Invalid path.' });
  }
  if (!url.href.startsWith(TMDB_BASE)) {
    return res.status(400).json({ success: false, message: 'Path not allowed.' });
  }

  Object.entries(req.query || {}).forEach(([key, value]) => {
    if (key === 'api_key') return;
    if (value == null) return;
    url.searchParams.set(key, Array.isArray(value) ? value[0] : String(value));
  });
  if (!url.searchParams.has('language')) {
    url.searchParams.set('language', 'en-US');
  }
  url.searchParams.set('api_key', apiKey);

  try {
    const upstream = await fetch(url);
    const body = await upstream.text();
    const contentType = upstream.headers.get('content-type');
    if (contentType) res.setHeader('Content-Type', contentType);
    res.status(upstream.status).send(body);
  } catch {
    res.status(502).json({ success: false, message: 'Upstream TMDB request failed.' });
  }
});

module.exports = router;
