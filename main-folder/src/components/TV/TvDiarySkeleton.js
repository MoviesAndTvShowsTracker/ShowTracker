export default function TvDiarySkeleton() {
  return (
    <div className="mb-5 space-y-3 md:mb-8" aria-hidden="true">
      <div className="ml-auto h-10 w-36 animate-pulse rounded-lg bg-surface-raised" />
      <div className="h-24 animate-pulse rounded-xl bg-surface-raised" />
      <div className="grid grid-cols-2 gap-2">
        <div className="h-[72px] animate-pulse rounded-xl bg-surface-raised md:min-h-[44px]" />
        <div className="h-[72px] animate-pulse rounded-xl bg-surface-raised md:min-h-[44px]" />
      </div>
    </div>
  );
}
