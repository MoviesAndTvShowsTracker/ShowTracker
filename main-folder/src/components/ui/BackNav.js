import { ChevronLeft } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

export default function BackNav({ fallback = '/', label = 'Back', className = '', to }) {
  const navigate = useNavigate();

  const handleBack = () => {
    if (to) {
      navigate(to);
      return;
    }
    if (window.history.state?.idx > 0) {
      navigate(-1);
    } else {
      navigate(fallback);
    }
  };

  return (
    <button
      type="button"
      onClick={handleBack}
      className={`inline-flex min-h-[44px] items-center gap-1.5 text-sm font-medium text-muted transition-colors hover:text-ink-bright cursor-pointer ${className}`}
    >
      <ChevronLeft className="h-4 w-4 shrink-0" aria-hidden="true" />
      {label}
    </button>
  );
}
