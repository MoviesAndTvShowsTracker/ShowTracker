import { createContext, useContext, useEffect, useState } from 'react';

const ThemeContext = createContext(null);
const STORAGE_KEY = 'showtracker-theme';

function getSystemTheme() {
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function applyTheme(resolved) {
  document.documentElement.classList.remove('light', 'dark');
  document.documentElement.classList.add(resolved);
  document.querySelector('meta[name="theme-color"]')?.setAttribute(
    'content',
    resolved === 'dark' ? '#121110' : '#f5f2eb'
  );
}

export function ThemeProvider({ children }) {
  const [theme, setTheme] = useState(() => {
    const stored = localStorage.getItem(STORAGE_KEY);
    return stored === 'light' || stored === 'dark' ? stored : getSystemTheme();
  });

  useEffect(() => {
    applyTheme(theme);
    localStorage.setItem(STORAGE_KEY, theme);
  }, [theme]);

  useEffect(() => {
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const onChange = () => {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (!stored) setTheme(getSystemTheme());
    };
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, []);

  const toggleTheme = () => setTheme((t) => (t === 'dark' ? 'light' : 'dark'));

  return (
    <ThemeContext.Provider value={{ theme, setTheme, toggleTheme, isDark: theme === 'dark' }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be used within ThemeProvider');
  return ctx;
}
