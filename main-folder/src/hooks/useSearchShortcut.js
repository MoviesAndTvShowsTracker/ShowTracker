import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

const FOCUS_SEARCH_EVENT = 'marquee:focus-search';

export function focusSearchInput() {
  window.dispatchEvent(new Event(FOCUS_SEARCH_EVENT));
}

function isTypingTarget(target) {
  if (!target) return false;
  const tag = target.tagName;
  if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return true;
  return Boolean(target.isContentEditable);
}

export default function useSearchShortcut() {
  const navigate = useNavigate();

  useEffect(() => {
    const onKeyDown = (e) => {
      if (e.key !== '/' || e.metaKey || e.ctrlKey || e.altKey) return;
      if (isTypingTarget(e.target)) return;

      e.preventDefault();
      navigate('/search');
      requestAnimationFrame(() => focusSearchInput());
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [navigate]);
}

export { FOCUS_SEARCH_EVENT };
