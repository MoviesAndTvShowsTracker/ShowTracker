export default function MediaScroller({ title, icon: Icon, emptyMessage, emptyLink, emptyLinkText, children }) {
  return (
    <section className="space-y-4">
      <div className="flex items-center gap-2">
        {Icon && <Icon className="h-5 w-5 text-accent" aria-hidden="true" />}
        <h2 className="font-heading text-xl font-bold md:text-2xl">{title}</h2>
      </div>
      {children ? (
        <div className="media-scroll">{children}</div>
      ) : (
        <p className="text-text-muted">
          {emptyMessage}{' '}
          {emptyLink && (
            <a href={emptyLink} className="text-accent underline-offset-4 hover:underline">
              {emptyLinkText}
            </a>
          )}
        </p>
      )}
    </section>
  );
}
