/** True when any key, at any depth, starts with "$" (a MongoDB query operator). */
function hasOperatorKey(value, depth = 0) {
  if (!value || typeof value !== 'object' || depth > 20) return false;
  if (Array.isArray(value)) return value.some((v) => hasOperatorKey(v, depth + 1));
  return Object.keys(value).some((k) => k.startsWith('$') || hasOperatorKey(value[k], depth + 1));
}

/**
 * Refuses any request whose body, query or route params carry an operator key, so client input
 * can never turn into a query operator (NoSQL injection). Our clients never send such keys.
 */
function rejectOperators(req, res, next) {
  if (hasOperatorKey(req.body) || hasOperatorKey(req.query) || hasOperatorKey(req.params)) {
    return res.status(400).json({ success: false, message: 'Invalid request.' });
  }
  return next();
}

module.exports = { rejectOperators, hasOperatorKey };
