import { ChevronLeft } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

/**
 * True “back”: pop history when possible so ScrollRestoration can return the
 * user to their previous scroll (search deep in results, profile rails, etc.).
 * `to` / `fallback` are only used when there is no in-app history (cold open).
 */
export default function BackNav({ fallback = '/', label = 'Back', className = '', to }) {
  const navigate = useNavigate();

  const handleBack = () => {
    if (window.history.state?.idx > 0) {
      navigate(-1);
      return;
    }
    navigate(to || fallback);
  };

  return (
    <button
      type="button"
      onClick={handleBack}
      className={`focus-ring pressable group inline-flex min-h-[44px] items-center gap-1.5 text-sm font-medium text-muted transition-colors hover:text-ink-bright cursor-pointer ${className}`}
    >
      <ChevronLeft
        className="h-4 w-4 shrink-0 transition-transform duration-150 group-hover:-translate-x-0.5"
        aria-hidden="true"
      />
      {label}
    </button>
  );
}
