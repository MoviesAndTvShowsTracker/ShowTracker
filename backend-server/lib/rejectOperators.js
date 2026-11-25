/** True when any key, at any depth, starts with "$" (a MongoDB query operator). */
function hasOperatorKey(value, depth = 0) {
  if (!value || typeof value !== 'object') return false;
  if (depth > 20) return true; // implausibly deep input is refused, not waved through
  if (Array.isArray(value)) return value.some((v) => hasOperatorKey(v, depth + 1));
  return Object.keys(value).some((k) => k.startsWith('$') || hasOperatorKey(value[k], depth + 1));
}

/**
 * Refuses any request whose JSON/urlencoded body or query string carries an operator key, so client
 * input can never turn into a query operator (NoSQL injection). Our clients never send such keys.
 * Route params are always plain strings; multipart bodies (the zip upload) carry no query fields.
 */
function rejectOperators(req, res, next) {
  if (hasOperatorKey(req.body) || hasOperatorKey(req.query)) {
    return res.status(400).json({ success: false, message: 'Invalid request.' });
  }
  return next();
}

module.exports = { rejectOperators, hasOperatorKey };
