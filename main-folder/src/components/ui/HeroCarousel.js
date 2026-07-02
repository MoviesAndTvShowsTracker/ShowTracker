import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { ChevronLeft, ChevronRight } from 'lucide-react';

export default function HeroCarousel({ slides = [] }) {
  const valid = slides.filter((s) => s?.id && s?.image);
  const [index, setIndex] = useState(0);

  useEffect(() => {
    if (valid.length <= 1) return undefined;
    const timer = setInterval(() => setIndex((c) => (c + 1) % valid.length), 7000);
    return () => clearInterval(timer);
  }, [valid.length]);

  if (!valid.length) return null;

  const slide = valid[index] || valid[0];

  return (
    <section className="relative h-52 overflow-hidden sm:h-64 md:h-80">
      <Link to={slide.to} className="block h-full cursor-pointer">
        <div className="absolute inset-0 bg-cover bg-center" style={{ backgroundImage: `url('${slide.image}')` }} />
        <div className="absolute inset-0 bg-gradient-to-t from-black/85 via-black/35 to-black/10" />
        <div className="relative flex h-full flex-col justify-end px-4 pb-6 sm:px-6">
          {slide.badge && (
            <span className="mb-2 inline-flex w-fit rounded-full bg-accent px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider text-on-accent backdrop-blur-sm">
              {slide.badge}
            </span>
          )}
          <h2 className="font-serif text-xl text-white sm:text-3xl">{slide.title}</h2>
          <p className="mt-1 line-clamp-2 max-w-xl text-xs text-white/75 sm:text-sm">{slide.text}</p>
        </div>
      </Link>
      {valid.length > 1 && (
        <>
          <button
            type="button"
            onClick={() => setIndex((c) => (c - 1 + valid.length) % valid.length)}
            aria-label="Previous"
            className="absolute left-2 top-1/2 -translate-y-1/2 rounded-full border border-border bg-surface/90 p-1.5 shadow cursor-pointer"
          >
            <ChevronLeft className="h-4 w-4 text-ink" />
          </button>
          <button
            type="button"
            onClick={() => setIndex((c) => (c + 1) % valid.length)}
            aria-label="Next"
            className="absolute right-2 top-1/2 -translate-y-1/2 rounded-full border border-border bg-surface/90 p-1.5 shadow cursor-pointer"
          >
            <ChevronRight className="h-4 w-4 text-ink" />
          </button>
          <div className="absolute bottom-2 left-1/2 flex -translate-x-1/2 gap-1.5">
            {valid.map((_, i) => (
              <button
                key={i}
                type="button"
                aria-label={`Slide ${i + 1}`}
                onClick={() => setIndex(i)}
                className={`h-1 rounded-full transition-all cursor-pointer ${i === index ? 'w-4 bg-accent' : 'w-1 bg-muted/60'}`}
              />
            ))}
          </div>
        </>
      )}
    </section>
  );
}
