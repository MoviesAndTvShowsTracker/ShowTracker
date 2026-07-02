export default function MainImageforDetail({ image, title, text }) {
  return (
    <section
      className="relative h-48 bg-cover bg-center sm:h-56 md:h-64"
      style={{ backgroundImage: `linear-gradient(to bottom, transparent 20%, rgba(20,24,28,0.85) 100%), url('${image}')` }}
    >
      <div className="absolute bottom-0 left-0 right-0 px-4 pb-5 sm:px-6">
        <h1 className="text-xl font-bold text-white sm:text-2xl">{title}</h1>
        <p className="mt-1 line-clamp-3 text-sm text-white/80">{text}</p>
      </div>
    </section>
  );
}
