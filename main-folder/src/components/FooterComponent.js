import { Link } from 'react-router-dom';

export default function Footer() {
  return (
    <footer className="hidden border-t border-border bg-canvas md:block">
      <div className="mx-auto flex max-w-content flex-col items-center justify-between gap-4 px-4 py-8 text-center sm:flex-row sm:px-6 sm:text-left">
        <p className="text-xs uppercase tracking-widest text-muted">
          &copy; {new Date().getFullYear()} ShowTracker — track films &amp; TV
        </p>
        <nav className="flex flex-wrap justify-center gap-5 text-xs font-bold uppercase tracking-widest text-muted">
          <Link to="/" className="transition-colors hover:text-ink-bright cursor-pointer">Home</Link>
          <Link to="/movies" className="transition-colors hover:text-ink-bright cursor-pointer">Films</Link>
          <Link to="/tv" className="transition-colors hover:text-ink-bright cursor-pointer">TV</Link>
          <Link to="/search" className="transition-colors hover:text-ink-bright cursor-pointer">Search</Link>
          <Link to="/login" className="transition-colors hover:text-ink-bright cursor-pointer">Sign in</Link>
        </nav>
      </div>
    </footer>
  );
}
