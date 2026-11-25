/* Diary export: correct CSV escaping, no spreadsheet formulas, newest first. No DB. */
const assert = require('assert');
const { toCsv, csvCell, diaryRows, CSV_COLUMNS } = require('../services/diaryExport');

// Escaping: commas, quotes and line breaks survive a round trip through any spreadsheet.
assert.strictEqual(csvCell('plain'), 'plain');
assert.strictEqual(csvCell('a, b'), '"a, b"');
assert.strictEqual(csvCell('say "hi"'), '"say ""hi"""');
assert.strictEqual(csvCell('line1\nline2'), '"line1\nline2"');
assert.strictEqual(csvCell(null), '');
assert.strictEqual(csvCell(8), '8');

// A note can't become a formula when the file is opened in Excel/Numbers/Sheets.
for (const evil of ['=HYPERLINK("http://x")', '+1+1', '-2+3', '@SUM(A1)', '\t=1', '\r=1']) {
  assert.ok(csvCell(evil).replace(/^"/, '').startsWith("'"), `neutralised: ${JSON.stringify(evil)}`);
}

// Rows: films, episodes and rewatched episodes in one diary, newest first.
const rows = diaryRows({
  films: [{ movieId: '13', movieTitle: 'Forrest Gump', watchedAt: new Date('2024-02-14T20:00:00Z'), rating: 9, isRewatch: false, note: 'With Mom' }],
  episodes: [{ tvId: '1396', seasonNumber: 1, episodeNumber: 1, episodeName: 'Pilot', watchedAt: new Date('2026-11-20T21:00:00Z'), rating: null, note: '' }],
  rewatches: [{ tvId: '1396', seasonNumber: 1, episodeNumber: 1, episodeName: 'Pilot', watchedAt: new Date('2026-11-25T21:00:00Z') }],
  showTitles: { 1396: 'Breaking Bad' },
});
assert.deepStrictEqual(rows.map((r) => [r.type, r.title, r.date, r.rewatch]), [
  ['episode', 'Breaking Bad', '2026-11-25', 'yes'],
  ['episode', 'Breaking Bad', '2026-11-20', 'no'],
  ['film', 'Forrest Gump', '2024-02-14', 'no'],
]);
assert.strictEqual(rows[2].rating, 4.5, 'ratings exported out of 5');
assert.strictEqual(rows[1].episode, 'S1E1 Pilot');

const csv = toCsv(rows, CSV_COLUMNS);
const lines = csv.split('\r\n');
assert.strictEqual(lines[0], CSV_COLUMNS.map((c) => c.label).join(','));
assert.strictEqual(lines.length, 4, 'header + 3 rows, no trailing blank line');
assert.ok(csv.startsWith('﻿') === false, 'no BOM in the string; the route adds it for Excel');

console.log('diary export: all passed');
