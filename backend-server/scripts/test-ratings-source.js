/* Ratings come only from TMDB and OMDb's API: never by downloading Rotten Tomatoes pages. No network. */
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { parseOmdbRatings } = require('../routes/ratings');

const parsed = parseOmdbRatings({
  Response: 'True',
  imdbRating: '8.8',
  imdbVotes: '2,669,989',
  Ratings: [
    { Source: 'Internet Movie Database', Value: '8.8/10' },
    { Source: 'Rotten Tomatoes', Value: '81%' },
    { Source: 'Metacritic', Value: '67/100' },
  ],
});
assert.deepStrictEqual(parsed.rottenTomatoes, { value: 81, scale: 100 });
assert.deepStrictEqual(parsed.metacritic, { value: 67, scale: 100 });
assert.strictEqual(parsed.imdb.value, 8.8);
assert.strictEqual(parseOmdbRatings({ Response: 'False' }).rottenTomatoes, null);

const source = fs.readFileSync(path.join(__dirname, '../routes/ratings.js'), 'utf8');
assert.ok(!/tomatoURL|rottentomatoes\.com|parseTomatoMeterFromHtml/.test(source), 'no Rotten Tomatoes page scraping');

console.log('ratings source: all passed');
