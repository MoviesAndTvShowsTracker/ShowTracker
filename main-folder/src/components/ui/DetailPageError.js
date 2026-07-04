import { Link } from 'react-router-dom';
import BackNav from './BackNav';

export default function DetailPageError({
  fallback = '/',
  backLabel = 'Back',
  message = "Couldn't load this title. Check your connection and try again.",
  onRetry,
}) {
  return (
    <div className="mx-auto max-w-content px-4 py-10 sm:px-6 md:py-16">
      <BackNav fallback={fallback} label={backLabel} className="mb-6 md:hidden" />
      <div className="glass-card mx-auto max-w-md p-6 text-center sm:p-8">
        <p className="font-serif text-lg text-ink-bright">Something went wrong</p>
        <p className="mt-2 text-sm text-muted">{message}</p>
        <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:justify-center">
          {onRetry && (
            <button type="button" onClick={onRetry} className="btn-primary">
              Try again
            </button>
          )}
          <Link to={fallback} className="btn-secondary">
            Go back
          </Link>
        </div>
      </div>
    </div>
  );
}
