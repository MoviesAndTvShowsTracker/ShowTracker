/** Baseline headers for a JSON API served only over HTTPS (Render + Cloudflare). */
function securityHeaders(req, res, next) {
  // Browsers that saw us once refuse plain HTTP for a year.
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  next();
}

module.exports = { securityHeaders };
