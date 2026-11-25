/* Watch dates and notes coming from clients. No DB. */
const assert = require('assert');
const { parseWatchedAt, parseNote, NOTE_MAX } = require('../lib/diaryInput');

const now = new Date('2026-11-26T12:00:00Z');
const rejects = (fn, re) => assert.throws(fn, (e) => e.status === 400 && re.test(e.message));

// Dates: default now; any past date; a little future slack for time zones; nothing silly.
assert.strictEqual(parseWatchedAt(undefined, now).getTime(), now.getTime());
assert.strictEqual(parseWatchedAt(null, now).getTime(), now.getTime());
assert.strictEqual(parseWatchedAt('2026-11-25T20:00:00Z', now).toISOString(), '2026-11-25T20:00:00.000Z');
assert.strictEqual(parseWatchedAt('1999-03-31', now).toISOString(), '1999-03-31T00:00:00.000Z');
assert.ok(parseWatchedAt('2026-11-27T10:00:00Z', now), 'tomorrow in UTC can still be today somewhere');
rejects(() => parseWatchedAt('2026-12-05T00:00:00Z', now), /future/);
rejects(() => parseWatchedAt('1850-01-01', now), /valid date/);
rejects(() => parseWatchedAt('yesterday-ish', now), /valid date/);
rejects(() => parseWatchedAt({ $gt: '' }, now), /valid date/);

// Notes: trimmed; empty clears; capped; text only.
assert.strictEqual(parseNote(undefined), undefined, 'absent = leave unchanged');
assert.strictEqual(parseNote('  Watched with Mom.  '), 'Watched with Mom.');
assert.strictEqual(parseNote(''), '');
assert.strictEqual(parseNote(null), '');
assert.strictEqual(parseNote('line one\nline two'), 'line one\nline two', 'keeps line breaks');
assert.strictEqual(parseNote('x'.repeat(NOTE_MAX)).length, NOTE_MAX);
rejects(() => parseNote('x'.repeat(NOTE_MAX + 1)), /500/);
rejects(() => parseNote({ text: 'hi' }), /text/);
assert.strictEqual(parseNote('a\u0000b\u0007c'), 'abc', 'control characters are dropped');

// Counted like the app counts: what you see, so 300 emoji (600 UTF-16 units) fit.
assert.strictEqual(parseNote('😀'.repeat(300)).length, 600);
assert.ok(parseNote('👨‍👩‍👧'.repeat(NOTE_MAX)), 'family emoji count as one each');
rejects(() => parseNote('😀'.repeat(NOTE_MAX + 1)), /500/);

console.log('diary input: all passed');
