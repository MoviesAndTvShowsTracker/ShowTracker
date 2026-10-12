/**
 * Rating normalization.
 *
 * UI uses half-star steps (0.5–5). Storage is an integer 1–10 (half-steps),
 * matching Letterboxd-style conventions. `null` always means "unrated".
 *
 * Accepts:
 *   - null / '' / undefined -> null (clear rating)
 *   - integer 1..10 -> as-is
 *   - decimal 0.5..5 (half-star) -> int * 2
 */
function normalizeRating(value) {
  if (value === null || value === undefined || value === '') return null;

  const num = Number(value);
  if (!Number.isFinite(num)) {
    const err = new Error('Rating must be a number between 0.5 and 5 (half-star steps).');
    err.code = 'BAD_RATING';
    throw err;
  }

  // Half-star UI value (0.5..5)
  if (num > 0 && num <= 5 && Math.round(num * 2) === num * 2) {
    return Math.round(num * 2);
  }

  // Already stored form (1..10 integer)
  if (Number.isInteger(num) && num >= 1 && num <= 10) {
    return num;
  }

  const err = new Error('Rating must be a half-star value from 0.5 to 5.');
  err.code = 'BAD_RATING';
  throw err;
}

module.exports = { normalizeRating };
