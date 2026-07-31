export default function MainImageforDetail({ image, title, text }) {
  return (
    <section
      className="relative h-48 bg-cover bg-center sm:h-56 md:h-64"
      style={{ backgroundImage: `url('${image}')` }}
    >
      <div className="hero-overlay absolute inset-0" aria-hidden />
      <div className="absolute bottom-0 left-0 right-0 px-4 pb-5 sm:px-6">
        <h1 className="text-xl font-bold text-ink-bright sm:text-2xl">{title}</h1>
        <p className={`line-clamp-3 text-sm text-ink ${title ? 'mt-1' : ''}`}>{text}</p>
      </div>
    </section>
  );
}
