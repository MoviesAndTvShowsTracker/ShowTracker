/** Rules for what clients may log: real past dates and short text notes. */

const NOTE_MAX = 500;
const EARLIEST = Date.parse('1900-01-01T00:00:00Z');
// "Today" in the furthest-ahead time zone (UTC+14) can be ~a day and a half past UTC now.
const FUTURE_SLACK_MS = 36 * 60 * 60 * 1000;

function badRequest(message) {
  const err = new Error(message);
  err.status = 400;
  return err;
}

/** The moment a watch happened. Absent → now. Throws a 400 for anything invalid or in the future. */
function parseWatchedAt(raw, now = new Date()) {
  if (raw === undefined || raw === null || raw === '') return new Date(now.getTime());
  if (typeof raw !== 'string' && !(raw instanceof Date)) throw badRequest('Pick a valid date.');
  const at = new Date(raw);
  const t = at.getTime();
  if (!Number.isFinite(t) || t < EARLIEST) throw badRequest('Pick a valid date.');
  if (t > now.getTime() + FUTURE_SLACK_MS) throw badRequest('That date is in the future.');
  return at;
}

/** A note: undefined = leave as is; null/'' = clear; otherwise trimmed text up to 500 characters. */
function parseNote(raw) {
  if (raw === undefined) return undefined;
  if (raw === null) return '';
  if (typeof raw !== 'string') throw badRequest('A note must be text.');
  // Drop control characters except line breaks and tabs.
  const cleaned = raw.replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, '').trim();
  if (cleaned.length > NOTE_MAX) throw badRequest(`Notes can be up to ${NOTE_MAX} characters.`);
  return cleaned;
}

module.exports = { parseWatchedAt, parseNote, NOTE_MAX };
