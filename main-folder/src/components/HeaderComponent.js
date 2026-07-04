import { useState } from 'react';
import { NavLink, useLocation, useNavigate } from 'react-router-dom';
import { Film, Home, LogIn, LogOut, Moon, Search, Settings, Sun, Tv, User } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import { hideMobileBottomNav } from '../utils/layout';
import Dialog from './ui/Dialog';
import MobileBottomNav from './MobileBottomNav';
import MarqueeLogo from './brand/MarqueeLogo';
import { BRAND_NAME } from '../config/brand';
import { displayName } from '../utils/displayUser';

const desktopLink = ({ isActive }) =>
  `nav-link inline-flex min-h-[44px] items-center gap-2 px-3 py-2 cursor-pointer ${
    isActive ? 'text-accent' : 'text-muted hover:text-ink-bright'
  }`;

export default function Header() {
  const { isAuthenticated, user, logout } = useAuth();
  const { isDark, toggleTheme } = useTheme();
  const navigate = useNavigate();
  const location = useLocation();
  const [showLogout, setShowLogout] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  const homeTo = isAuthenticated ? '/home' : '/';
  const showMobileNav = !hideMobileBottomNav(location.pathname);

  const handleLogout = async () => {
    await logout();
    setShowLogout(false);
    navigate('/');
  };

  return (
    <>
      <header className="app-header">
        <div className="mx-auto flex max-w-content items-center justify-between gap-4 px-4 py-3 sm:px-6">
          <NavLink to={homeTo} end className="inline-flex shrink-0 items-center gap-2 cursor-pointer">
            <MarqueeLogo className="h-8 w-8 shrink-0 text-ink-bright" />
            <span className="font-serif text-xl font-semibold tracking-tight text-ink-bright">{BRAND_NAME}</span>
          </NavLink>

          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={toggleTheme}
              className="theme-toggle md:hidden"
              aria-label={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
            >
              {isDark ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
            </button>

            <nav className="hidden items-center md:flex" aria-label="Main">
              <NavLink to={homeTo} end className={desktopLink}>
                <Home className="h-4 w-4" aria-hidden="true" />
                Home
              </NavLink>
              <NavLink to="/movies" className={desktopLink}>
                <Film className="h-4 w-4" aria-hidden="true" />
                Films
              </NavLink>
              <NavLink to="/tv" className={desktopLink}>
                <Tv className="h-4 w-4" aria-hidden="true" />
                TV
              </NavLink>
              <NavLink to="/search" className={desktopLink}>
                <Search className="h-4 w-4" aria-hidden="true" />
                Search
              </NavLink>

              {!isAuthenticated ? (
                <>
                  <NavLink to="/login" className={desktopLink}>
                    <LogIn className="h-4 w-4" aria-hidden="true" />
                    Sign in
                  </NavLink>
                  <NavLink to="/signup" className="btn-primary !min-h-[36px] !px-4 !py-2 !text-xs ml-2">
                    Join
                  </NavLink>
                </>
              ) : (
                <div className="relative ml-2">
                  <button
                    type="button"
                    onClick={() => setMenuOpen(!menuOpen)}
                    className="btn-ghost gap-1.5 !text-ink"
                    aria-expanded={menuOpen}
                  >
                    <User className="h-4 w-4" />
                    <span className="max-w-[120px] truncate">{displayName(user)}</span>
                  </button>
                  {menuOpen && (
                    <>
                      <div className="fixed inset-0 z-40" onClick={() => setMenuOpen(false)} aria-hidden="true" />
                      <div className="absolute right-0 z-50 mt-1 w-44 overflow-hidden rounded-xl border border-border bg-surface py-1 shadow-glass backdrop-blur-xl">
                        <NavLink
                          to="/profile"
                          onClick={() => setMenuOpen(false)}
                          className="flex items-center gap-2 px-4 py-2.5 text-sm text-ink hover:bg-surface-raised cursor-pointer"
                        >
                          <User className="h-4 w-4" />
                          Profile
                        </NavLink>
                        <NavLink
                          to="/settings"
                          onClick={() => setMenuOpen(false)}
                          className="flex items-center gap-2 px-4 py-2.5 text-sm text-ink hover:bg-surface-raised cursor-pointer"
                        >
                          <Settings className="h-4 w-4" />
                          Settings
                        </NavLink>
                        <button
                          type="button"
                          onClick={() => {
                            setMenuOpen(false);
                            setShowLogout(true);
                          }}
                          className="flex w-full items-center gap-2 px-4 py-2.5 text-left text-sm text-ink hover:bg-surface-raised cursor-pointer"
                        >
                          <LogOut className="h-4 w-4" />
                          Sign out
                        </button>
                      </div>
                    </>
                  )}
                </div>
              )}
              <button
                type="button"
                onClick={toggleTheme}
                className="theme-toggle ml-2 hidden md:inline-flex"
                aria-label={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
              >
                {isDark ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
              </button>
            </nav>
          </div>
        </div>
      </header>

      {showMobileNav && <MobileBottomNav />}

      <Dialog
        open={showLogout}
        onClose={() => setShowLogout(false)}
        title="Sign out?"
        footer={
          <>
            <button type="button" onClick={() => setShowLogout(false)} className="btn-secondary">
              Cancel
            </button>
            <button type="button" onClick={handleLogout} className="btn-primary">
              Sign out
            </button>
          </>
        }
      >
        <p className="text-sm text-muted">Your lists and history will be here when you return.</p>
      </Dialog>
    </>
  );
}
