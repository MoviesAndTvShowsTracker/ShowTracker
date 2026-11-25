// Local development only. Production must set JWT_SECRET.
const DEV_FALLBACK = '51811-42966-52626-65419';

/** The JWT secret, and a problem string when production runs without one. */
function secretStatus(env = process.env) {
  if (env.JWT_SECRET) return { secret: env.JWT_SECRET, problem: null };
  const problem = env.NODE_ENV === 'production' ? 'JWT_SECRET is not set in production.' : null;
  return { secret: DEV_FALLBACK, problem };
}

module.exports = { secretStatus };
