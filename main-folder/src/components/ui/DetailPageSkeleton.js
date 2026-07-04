import BackNav from './BackNav';

export default function DetailPageSkeleton({ fallback = '/', backLabel = 'Back' }) {
  return (
    <>
      <div className="h-40 animate-pulse bg-surface-raised sm:h-48 md:h-56" aria-hidden />
      <div className="mx-auto max-w-content px-4 py-5 sm:px-6 md:py-8">
        <BackNav fallback={fallback} label={backLabel} className="mb-4 md:hidden" />
        <div className="animate-pulse space-y-6" aria-busy="true" aria-label="Loading">
          <div className="flex gap-3 md:hidden">
            <div className="h-28 w-[4.5rem] shrink-0 rounded-xl bg-surface-raised" />
            <div className="flex min-w-0 flex-1 flex-col justify-center gap-2">
              <div className="h-6 w-[80%] rounded-lg bg-surface-raised" />
              <div className="h-4 w-1/2 rounded-lg bg-surface-raised" />
              <div className="h-3 w-1/3 rounded-lg bg-surface-raised" />
            </div>
          </div>
          <div className="h-20 rounded-xl bg-surface-raised md:h-24" />
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
            {Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="h-14 rounded-xl bg-surface-raised" />
            ))}
          </div>
        </div>
      </div>
    </>
  );
}
