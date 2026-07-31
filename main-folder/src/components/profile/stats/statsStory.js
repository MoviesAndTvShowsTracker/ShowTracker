import {
  formatCount,
  formatDuration,
  formatMonthLabel,
  formatShortDate,
} from '../../../utils/statsFormat';

/** Continuous-screen-time framing for big watch totals. */
export function screenDaysLine(totalMins) {
  if (!totalMins || totalMins < 60) return null;
  const days = totalMins / (60 * 24);
  if (days < 1) {
    const hours = Math.round(totalMins / 60);
    return `About ${hours} hour${hours === 1 ? '' : 's'} of continuous watching`;
  }
  const rounded = days < 10 ? Math.round(days * 10) / 10 : Math.round(days);
  return `About ${rounded} day${rounded === 1 ? '' : 's'} of continuous watching`;
}

function weekdayQuirk(day) {
  const map = {
    Monday: 'Mondays — you ease into the week on the couch',
    Tuesday: 'Tuesdays are when you actually press play',
    Wednesday: 'Midweek is your sweet spot',
    Thursday: 'Thursdays — almost weekend energy',
    Friday: 'Friday nights belong to your queue',
    Saturday: 'Saturdays are for settling in',
    Sunday: 'Sundays are your screening day',
  };
  return map[day] || `${day}s show up most in your diary`;
}

/**
 * Personality tickets for the stats page — quirky, specific, never generic KPIs.
 * Returns up to 4 cards from whatever the payload can support.
 */
export function buildQuirkTickets(stats) {
  if (!stats) return [];
  const act = stats.activity;
  const facts = stats.funFacts;
  const o = stats.overview;
  const taste = stats.taste;
  const tickets = [];

  if (act?.busiestDay?.day) {
    tickets.push({
      key: 'weekday',
      kicker: 'Habit',
      headline: act.busiestDay.day,
      line: weekdayQuirk(act.busiestDay.day),
      meta: act.busiestDay.count ? `${formatCount(act.busiestDay.count)} lifetime logs` : null,
    });
  }

  if (facts?.biggestBinge?.count > 1) {
    tickets.push({
      key: 'binge',
      kicker: 'Biggest day',
      headline: `${facts.biggestBinge.count}`,
      line: 'Titles logged in a single day',
      meta: facts.biggestBinge.date ? formatShortDate(facts.biggestBinge.date) : null,
    });
  }

  if (act?.streak > 1) {
    tickets.push({
      key: 'streak',
      kicker: 'On a run',
      headline: `${act.streak}d`,
      line: 'Consecutive days with something logged',
      meta: act.longestStreak > act.streak ? `Best ever: ${act.longestStreak}d` : 'Personal best so far',
    });
  } else if (act?.longestStreak > 1) {
    tickets.push({
      key: 'best-streak',
      kicker: 'Personal best',
      headline: `${act.longestStreak}d`,
      line: 'Longest stretch of daily logging',
      meta: null,
    });
  }

  const topGenre =
    taste?.tv?.genreByEpisodes?.[0] || taste?.films?.genreByCount?.[0] || null;
  if (topGenre?.name) {
    tickets.push({
      key: 'genre',
      kicker: 'House style',
      headline: topGenre.name,
      line: `${topGenre.pct}% of your logged sample leans here`,
      meta: null,
    });
  }

  if (o?.filmShare >= 60) {
    tickets.push({
      key: 'lean-film',
      kicker: 'Screen split',
      headline: 'Film-first',
      line: `${o.filmShare}% of estimated time goes to movies`,
      meta: formatDuration(o.filmMins),
    });
  } else if (o?.tvShare >= 60) {
    tickets.push({
      key: 'lean-tv',
      kicker: 'Screen split',
      headline: 'Series-first',
      line: `${o.tvShare}% of estimated time goes to TV`,
      meta: formatDuration(o.tvMins),
    });
  }

  if (act?.busiestMonth?.count > 0 && tickets.length < 4) {
    tickets.push({
      key: 'month',
      kicker: 'Peak month',
      headline: formatMonthLabel(act.busiestMonth.month),
      line: `${formatCount(act.busiestMonth.count)} things logged`,
      meta: act.busiestMonth.minutes ? formatDuration(act.busiestMonth.minutes) : null,
    });
  }

  if (facts?.avgPerActiveDay && tickets.length < 4) {
    tickets.push({
      key: 'pace',
      kicker: 'Pace',
      headline: `${facts.avgPerActiveDay}`,
      line: 'Average logs on days you show up',
      meta: facts.avgMinsPerActiveDay
        ? `${formatDuration(facts.avgMinsPerActiveDay)} typical`
        : null,
    });
  }

  // Prefer variety — drop later duplicates of similar shape by keeping first 4
  return tickets.slice(0, 4);
}

export function storyInsight(stats) {
  if (stats?.insight?.text) return stats.insight.text;
  const year = stats?.year;
  if (year?.filmCount || year?.episodeCount) {
    const parts = [];
    if (year.filmCount) parts.push(`${formatCount(year.filmCount)} films`);
    if (year.episodeCount) parts.push(`${formatCount(year.episodeCount)} episodes`);
    return `This year you’ve logged ${parts.join(' and ')}.`;
  }
  return 'Log a film or episode to start your viewing story.';
}
