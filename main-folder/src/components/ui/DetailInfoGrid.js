export default function DetailInfoGrid({ items, providers, providersRegion, imageUrlPrefix }) {
  const rows = items.filter(([, value]) => value);

  return (
    <dl className="grid grid-cols-2 gap-2 md:gap-0 md:overflow-hidden md:rounded-2xl md:border md:border-border md:bg-surface/80 md:shadow-glass md:backdrop-blur-xl md:divide-y md:divide-border">
      {rows.map(([label, value]) => (
        <div
          key={label}
          className="rounded-xl border border-border bg-surface/90 p-3 shadow-glass backdrop-blur-md transition-all duration-300 md:col-span-full md:grid md:grid-cols-3 md:gap-2 md:rounded-none md:border-0 md:bg-transparent md:shadow-none md:backdrop-blur-none md:px-5 md:py-4"
        >
          <dt className="text-[10px] font-bold uppercase tracking-wider text-muted">{label}</dt>
          <dd className="mt-1 text-sm font-medium leading-snug text-ink-bright md:col-span-2 md:mt-0">{value}</dd>
        </div>
      ))}

      {providers?.length > 0 && (
        <div className="col-span-2 rounded-xl border border-border bg-surface/90 p-3 shadow-glass backdrop-blur-md md:col-span-full md:grid md:grid-cols-3 md:gap-2 md:rounded-none md:border-0 md:bg-transparent md:shadow-none md:backdrop-blur-none md:px-5 md:py-4">
          <dt className="text-[10px] font-bold uppercase tracking-wider text-muted">
            Where to watch
            {providersRegion && (
              <span className="mt-0.5 block font-medium normal-case tracking-normal text-muted-dim">
                {providersRegion === 'CA' ? 'Canada' : 'United States'}
              </span>
            )}
          </dt>
          <dd className="mt-2 flex flex-wrap gap-2 md:col-span-2 md:mt-0">
            {providers.map((p) => (
              <img
                key={p.provider_id}
                src={`${imageUrlPrefix}${p.logo_path}`}
                alt={p.provider_name}
                className="h-8 w-8 rounded-lg"
              />
            ))}
          </dd>
        </div>
      )}
    </dl>
  );
}
