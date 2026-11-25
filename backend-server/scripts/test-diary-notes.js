/* "Your notes": every film and episode note, newest first, searchable. No DB. */
const assert = require('assert');
const { notesFromRows, matchesQuery } = require('../services/diaryNotes');

const notes = notesFromRows({
  films: [
    { _id: 'f1', movieId: '13', movieTitle: 'Forrest Gump', moviePosterImage: '/f.jpg', watchedAt: new Date('2024-02-14'), note: 'With Mom.', rating: 9 },
    { _id: 'f2', movieId: '14', movieTitle: 'No note', watchedAt: new Date('2026-01-01'), note: '' },
  ],
  episodes: [
    { _id: 'e1', tvId: '1396', seasonNumber: 1, episodeNumber: 1, episodeName: 'Pilot', watchedAt: new Date('2026-11-20'), note: 'Hooked.' },
  ],
  shows: { 1396: { title: 'Breaking Bad', posterPath: '/b.jpg' } },
});

assert.deepStrictEqual(notes.map((n) => n.id), ['episode-e1', 'film-f1'], 'newest first, only rows with notes');
assert.deepStrictEqual(notes[0], {
  id: 'episode-e1', kind: 'episode', mediaId: '1396', title: 'Breaking Bad', posterPath: '/b.jpg',
  subtitle: 'S1 · E1  Pilot', seasonNumber: 1, episodeNumber: 1, watchedAt: new Date('2026-11-20'), note: 'Hooked.', rating: null,
});
assert.strictEqual(notes[1].rating, 9);

// Search matches the note or the title, ignoring case and accents-free regex specials.
assert.ok(matchesQuery(notes[1], 'mom'));
assert.ok(matchesQuery(notes[0], 'BREAKING'));
assert.ok(!matchesQuery(notes[0], 'gump'));
assert.ok(matchesQuery(notes[0], ''), 'empty query matches all');
assert.ok(!matchesQuery(notes[0], '.*'), 'query is literal text, not a pattern');

console.log('diary notes: all passed');
