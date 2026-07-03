export const TV_LIBRARY_TABS = {
  watching: {
    key: 'watching',
    title: 'Watching',
    description: 'Shows you are actively tracking. Mark an episode to keep a show here.',
    empty: 'No shows in progress. Mark an episode on any TV show to start tracking.',
    status: 'watching',
  },
  stopped: {
    key: 'stopped',
    title: 'Stopped',
    description:
      'Shows moved here after 90 days without activity. Caught-up and finished shows stay in their lists.',
    empty: 'No stopped shows. Inactive shows move here automatically after 90 days.',
    status: 'paused',
  },
  finished: {
    key: 'finished',
    title: 'Finished',
    description: 'Every episode logged — your completed series.',
    empty: 'No finished shows yet. Complete a series to see it here.',
    status: 'completed',
  },
};

export const TV_LIBRARY_TAB_ORDER = ['watching', 'stopped', 'finished'];

export function tvLibraryPath(tab = 'watching') {
  return `/tv/library/${tab}`;
}
