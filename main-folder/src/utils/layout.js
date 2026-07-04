const AUTH_ROUTES = ['/login', '/signup', '/forgot-password', '/reset-password'];

export function isAuthRoute(pathname) {
  return AUTH_ROUTES.some((route) => pathname === route);
}

export function hideMobileBottomNav(pathname) {
  return isAuthRoute(pathname);
}
