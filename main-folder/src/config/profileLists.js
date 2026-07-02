export const PROFILE_LISTS = {
  'favorite-films': {
    title: 'Favorite films',
    kind: 'movie',
    empty: 'No favorite films yet.',
  },
  'favorite-tv': {
    title: 'Favorite TV',
    kind: 'tv',
    empty: 'No favorite shows yet.',
  },
  'watched-films': {
    title: 'Watched films',
    kind: 'movie',
    empty: 'No watched films yet.',
  },
  'watched-tv': {
    title: 'Watched TV',
    kind: 'tv',
    empty: 'No watched TV yet.',
  },
  'film-watchlist': {
    title: 'Film watchlist',
    kind: 'movie',
    empty: 'Your film watchlist is empty.',
  },
  'tv-watchlist': {
    title: 'TV watchlist',
    kind: 'tv',
    empty: 'Your TV watchlist is empty.',
  },
};

export function profileListPath(listKey) {
  return `/profile/lists/${listKey}`;
}
