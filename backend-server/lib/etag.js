const crypto = require('crypto');

/** Weak ETag for a JSON body: same data, same tag. */
function etagFor(body) {
  const hash = crypto.createHash('sha1').update(JSON.stringify(body)).digest('hex').slice(0, 27);
  return `W/"${hash}"`;
}

/**
 * Sends `body` as JSON with an ETag. A client that already holds this exact data
 * (If-None-Match) gets an empty 304 instead. `no-cache` = keep it, but ask before reuse.
 */
function sendWithEtag(req, res, body) {
  const tag = etagFor(body);
  res.setHeader('ETag', tag);
  res.setHeader('Cache-Control', 'private, no-cache');
  if (req.headers['if-none-match'] === tag) {
    return res.status(304).end();
  }
  return res.status(200).json(body);
}

module.exports = { etagFor, sendWithEtag };
