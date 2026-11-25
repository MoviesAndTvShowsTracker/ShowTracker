const express = require('express');

const { ttlFor } = require('../services/tmdbCache');
const { tmdbClient } = require('../lib/tmdbClient');

const router = express.Router();

const TMDB_BASE = 'https://api.themoviedb.org/3/';

// Only prefixes the UI actually needs. Prevents the proxy from acting as an open relay.
const ALLOWED_PREFIXES = [
  'trending/',
  'movie/',
  'tv/',
  'person/',
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

  const ttl = ttlFor(tmdbPath);
  // Cache key never includes the API key.
  const cacheKey = url.href.replace(/([?&])api_key=[^&]*/, '$1');
  try {
    const result = await tmdbClient().getText(url.href, { cacheKey: `proxy:${cacheKey}`, ttlSeconds: ttl });
    res.setHeader('Content-Type', result.contentType);
    if (result.status >= 200 && result.status < 300) {
      res.setHeader('Cache-Control', `private, max-age=${ttl}`);
    }
    res.setHeader('X-Cache', result.cache);
    res.status(result.status).send(result.body);
  } catch {
    res.status(502).json({ success: false, message: 'Upstream TMDB request failed.' });
  }
});

module.exports = router;
