import { useLayoutEffect, useRef, useState } from 'react';
import { NavLink } from 'react-router-dom';
import { Film, Home, Search, Tv, User } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { useActiveMobileTab } from '../utils/mobileTabs';

const TABS = [
  { id: 'home', end: true, icon: Home, label: 'Home' },
  { id: 'movies', icon: Film, label: 'Films' },
  { id: 'tv', icon: Tv, label: 'TV' },
  { id: 'search', icon: Search, label: 'Search' },
  { id: 'you', icon: User, label: 'You', altLabel: 'Sign in' },
];

const mobileLink = ({ isActive }) =>
  `relative z-[1] flex w-full flex-col items-center justify-center gap-0.5 rounded-full py-2 text-[10px] font-bold uppercase tracking-wide transition-colors duration-200 cursor-pointer min-h-[44px] ${
    isActive ? 'text-accent' : 'text-muted active:text-ink'
  }`;

export default function MobileBottomNav() {
  const { isAuthenticated } = useAuth();
  const navRef = useRef(null);
  const itemRefs = useRef({});
  const [indicator, setIndicator] = useState({ x: 0, width: 0, ready: false });

  const activeId = useActiveMobileTab(isAuthenticated);
  const homeTo = isAuthenticated ? '/home' : '/';
  const youTo = isAuthenticated ? '/profile' : '/login';

  const tabTargets = {
    home: homeTo,
    movies: '/movies',
    tv: '/tv',
    search: '/search',
    you: youTo,
  };

  useLayoutEffect(() => {
    if (!activeId) {
      setIndicator({ x: 0, width: 0, ready: false });
      return undefined;
    }

    const measure = () => {
      const nav = navRef.current;
      const item = itemRefs.current[activeId];
      if (!nav || !item) return;

      const navRect = nav.getBoundingClientRect();
      const itemRect = item.getBoundingClientRect();
      setIndicator({
        x: itemRect.left - navRect.left,
        width: itemRect.width,
        ready: true,
      });
    };

    measure();
    const raf = requestAnimationFrame(measure);

    const nav = navRef.current;
    const observer = typeof ResizeObserver !== 'undefined' && nav
      ? new ResizeObserver(measure)
      : null;
    observer?.observe(nav);

    window.addEventListener('resize', measure);
    return () => {
      cancelAnimationFrame(raf);
      observer?.disconnect();
      window.removeEventListener('resize', measure);
    };
  }, [activeId, isAuthenticated]);

  return (
    <div className="mobile-nav-shell" aria-hidden={false}>
      <nav ref={navRef} className="mobile-nav-pill" aria-label="Mobile">
        <div
          className="mobile-nav-indicator"
          aria-hidden
          style={{
            width: indicator.width,
            transform: `translate3d(${indicator.x}px, 0, 0)`,
            opacity: indicator.ready ? 1 : 0,
          }}
        />
        {TABS.map((tab) => {
          const Icon = tab.icon;
          const label = tab.id === 'you' && !isAuthenticated ? tab.altLabel : tab.label;
          return (
            <div
              key={tab.id}
              ref={(el) => {
                if (el) itemRefs.current[tab.id] = el;
                else delete itemRefs.current[tab.id];
              }}
              className="flex min-w-0 flex-1"
            >
              <NavLink
                to={tabTargets[tab.id]}
                end={tab.end}
                className={mobileLink}
              >
                <Icon className="h-[18px] w-[18px]" aria-hidden="true" />
                {label}
              </NavLink>
            </div>
          );
        })}
      </nav>
    </div>
  );
}
