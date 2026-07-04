import { useMatch } from 'react-router-dom';

export function useActiveMobileTab(isAuthenticated) {
  const homeTo = isAuthenticated ? '/home' : '/';
  const home = useMatch({ path: homeTo, end: true });
  const movies = useMatch('/movies/*');
  const tv = useMatch('/tv/*');
  const search = useMatch('/search/*');
  const profile = useMatch('/profile/*');
  const settings = useMatch('/settings/*');
  const login = useMatch('/login');

  if (home) return 'home';
  if (movies) return 'movies';
  if (tv) return 'tv';
  if (search) return 'search';
  if (profile || settings) return 'you';
  if (!isAuthenticated && login) return 'you';
  return null;
}

export function getMobileTabId(pathname, isAuthenticated) {
  if (pathname === '/' || pathname === '/home') return 'home';
  if (pathname.startsWith('/movies')) return 'movies';
  if (pathname.startsWith('/tv')) return 'tv';
  if (pathname.startsWith('/search')) return 'search';
  if (pathname.startsWith('/profile') || pathname.startsWith('/settings')) return 'you';
  if (!isAuthenticated && pathname === '/login') return 'you';
  return null;
}

export function isMobileTabRoute(pathname, isAuthenticated) {
  return getMobileTabId(pathname, isAuthenticated) !== null;
}
