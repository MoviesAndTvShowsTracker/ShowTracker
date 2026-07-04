const SECTIONS = [
  { id: 'profile-stats', label: 'Stats' },
  { id: 'profile-library', label: 'Library' },
  { id: 'profile-films', label: 'Films' },
  { id: 'profile-tv', label: 'TV' },
];

export default function ProfileJumpNav({ showLists = true }) {
  const scrollTo = (id) => {
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  const items = showLists
    ? SECTIONS
    : SECTIONS.filter((s) => s.id === 'profile-stats' || s.id === 'profile-library');

  return (
    <nav
      className="flex gap-2 overflow-x-auto pb-1 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
      aria-label="Jump to section"
    >
      {items.map(({ id, label }) => (
        <button
          key={id}
          type="button"
          onClick={() => scrollTo(id)}
          className="shrink-0 rounded-full border border-border/70 bg-surface/80 px-4 py-2 text-xs font-semibold text-ink transition-colors hover:border-accent/40 hover:bg-accent/10 active:bg-accent/15 cursor-pointer"
        >
          {label}
        </button>
      ))}
    </nav>
  );
}
