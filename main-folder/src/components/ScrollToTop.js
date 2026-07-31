import { useEffect, useState } from 'react';
import { ArrowUp } from 'lucide-react';
import useAnimatedPresence from '../hooks/useAnimatedPresence';

export default function ScrollToTop() {
  const [isVisible, setIsVisible] = useState(false);
  const presence = useAnimatedPresence(isVisible);

  useEffect(() => {
    const toggle = () => setIsVisible(window.pageYOffset > 300);
    window.addEventListener('scroll', toggle);
    return () => window.removeEventListener('scroll', toggle);
  }, []);

  if (!presence.rendered) return null;

  return (
    <button
      type="button"
      onClick={() =>
        window.scrollTo({
          top: 0,
          behavior: window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth',
        })
      }
      aria-label="Scroll to top"
      className={`focus-ring scroll-fab fixed bottom-[calc(5.5rem+env(safe-area-inset-bottom))] right-4 z-40 flex h-10 w-10 items-center justify-center rounded-full border border-border bg-surface text-ink shadow-glass transition-colors hover:border-accent hover:text-accent active:scale-90 md:bottom-8 cursor-pointer ${
        presence.exiting ? 'is-exiting' : ''
      }`}
    >
      <ArrowUp className="h-4 w-4" />
    </button>
  );
}
