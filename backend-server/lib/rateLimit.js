/**
 * Small in-memory fixed-window rate limiter (one server process, resets on deploy).
 * Enough to stop password guessing and a scripted client from draining the API.
 */

/** The caller's address: Cloudflare (in front of Render) sets CF-Connecting-IP. */
function clientKey(req) {
  return req.headers['cf-connecting-ip'] || req.ip || 'unknown';
}

/** Keys a budget by the account in the request body (lowercased email), else the client address. */
function accountKey(scope) {
  return (req) => {
    const email = typeof req.body?.email === 'string' ? req.body.email.trim().toLowerCase() : '';
    return email ? `${scope}:${email}` : `${scope}:ip:${clientKey(req)}`;
  };
}

function createRateLimiter({ windowMs, max, name = 'api', now = Date.now, maxClients = 20000, keyFn = clientKey }) {
  const windows = new Map(); // key -> { start, count }

  return function rateLimit(req, res, next) {
    // Local load tests come from one address; never set this in production.
    if (process.env.RATE_LIMIT_DISABLED === '1') return next();
    const key = keyFn(req);
    const t = now();
    let w = windows.get(key);
    if (!w || t - w.start >= windowMs) {
      windows.delete(key);
      w = { start: t, count: 0 };
      windows.set(key, w);
      if (windows.size > maxClients) windows.delete(windows.keys().next().value);
    }
    w.count += 1;
    if (w.count > max) {
      const retry = Math.max(1, Math.ceil((w.start + windowMs - t) / 1000));
      res.setHeader('Retry-After', String(retry));
      return res.status(429).json({ success: false, message: 'Too many requests. Try again shortly.', limit: name });
    }
    return next();
  };
}

module.exports = { createRateLimiter, clientKey, accountKey };
