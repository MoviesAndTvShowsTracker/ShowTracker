export function favoriteRemoveConfirm(title) {
  return {
    title: 'Remove from favorites?',
    body: `Remove "${title}" from your favorites?`,
    confirmLabel: 'Remove',
  };
}

export function watchlistRemoveConfirm(title) {
  return {
    title: 'Remove from watchlist?',
    body: `Remove "${title}" from your watchlist?`,
    confirmLabel: 'Remove',
  };
}

export function watchedFilmRemoveConfirm(title) {
  return {
    title: 'Unmark as watched?',
    body: `Remove "${title}" from your watched films?`,
    confirmLabel: 'Remove',
  };
}

/** Multi-action sheet when a film already has one or more dated plays. */
export function watchedFilmManageConfirm(title, watchCount) {
  const count = Math.max(1, Number(watchCount) || 1);
  if (count > 1) {
    return {
      title: `Watched ×${count}`,
      body: `Log again adds a new date and keeps older watches. Remove last log only drops the newest entry for "${title}".`,
    };
  }
  return {
    title: 'Watched',
    body: `Log again keeps this watch and adds a new dated entry for "${title}". Or remove it from your watched films.`,
  };
}

export function watchedTvRemoveConfirm(title) {
  return {
    title: 'Remove from watched?',
    body: `Remove "${title}" from your watched shows?`,
    confirmLabel: 'Remove',
  };
}

export function episodeUnmarkConfirm(season, episodeNumber, episodeName) {
  const label = `S${season} E${episodeNumber}${episodeName ? ` — ${episodeName}` : ''}`;
  return {
    title: 'Unmark episode?',
    body: `Unmark ${label} as watched?`,
    confirmLabel: 'Unmark',
  };
}

export function seasonUnmarkConfirm(season, count) {
  return {
    title: `Unmark Season ${season}?`,
    body: `This will unmark ${count} episode${count === 1 ? '' : 's'} in this season.`,
    confirmLabel: 'Unmark season',
  };
}

export function markWholeShowConfirm(count) {
  return {
    title: 'Mark whole show?',
    body: `Every released episode will be marked as watched (${count} episode${count === 1 ? '' : 's'} across all seasons).`,
    confirmLabel: 'Mark watched',
  };
}

export function markSeasonConfirm(season, count) {
  return {
    title: `Mark Season ${season}?`,
    body: `Every released episode in this season will be marked as watched (${count} episode${count === 1 ? '' : 's'}).`,
    confirmLabel: 'Mark watched',
  };
}

export function profileListRemoveConfirm(listKey, title) {
  switch (listKey) {
    case 'favorite-films':
    case 'favorite-tv':
      return favoriteRemoveConfirm(title);
    case 'film-watchlist':
    case 'tv-watchlist':
      return watchlistRemoveConfirm(title);
    case 'watched-films':
      return watchedFilmRemoveConfirm(title);
    case 'watched-tv':
      return watchedTvRemoveConfirm(title);
    default:
      return {
        title: 'Remove?',
        body: `Remove "${title}" from this list?`,
        confirmLabel: 'Remove',
      };
  }
}
