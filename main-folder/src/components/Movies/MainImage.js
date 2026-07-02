import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { ChevronLeft, ChevronRight } from 'lucide-react';

export default function MainImage(props) {
  const slides = [
    { id: props.movieid, image: props.image, title: props.title, text: props.text },
    { id: props.movieid1, image: props.image1, title: props.title1, text: props.text1 },
    { id: props.movieid2, image: props.image2, title: props.title2, text: props.text2 },
  ].filter((slide) => slide.id);

  const [index, setIndex] = useState(0);

  useEffect(() => {
    if (slides.length <= 1) return undefined;
    const timer = setInterval(() => setIndex((c) => (c + 1) % slides.length), 7000);
    return () => clearInterval(timer);
  }, [slides.length]);

  const slide = slides[index] || slides[0];
  if (!slide) return null;

  return (
    <section className="relative h-52 overflow-hidden sm:h-64 md:h-80">
      <Link to={`/movies/${slide.id}`} className="block h-full cursor-pointer">
        <div className="absolute inset-0 bg-cover bg-center" style={{ backgroundImage: `url('${slide.image}')` }} />
        <div className="absolute inset-0 bg-gradient-to-t from-ink/90 via-ink/30 to-transparent" />
        <div className="relative flex h-full flex-col justify-end px-4 pb-5 sm:px-6">
          <h2 className="text-lg font-bold text-white sm:text-2xl">{slide.title}</h2>
          <p className="mt-1 line-clamp-2 text-xs text-white/80 sm:text-sm">{slide.text}</p>
        </div>
      </Link>
      {slides.length > 1 && (
        <>
          <button type="button" onClick={() => setIndex((c) => (c - 1 + slides.length) % slides.length)} aria-label="Previous" className="absolute left-2 top-1/2 -translate-y-1/2 rounded-full bg-surface/90 p-1.5 shadow cursor-pointer">
            <ChevronLeft className="h-4 w-4 text-ink" />
          </button>
          <button type="button" onClick={() => setIndex((c) => (c + 1) % slides.length)} aria-label="Next" className="absolute right-2 top-1/2 -translate-y-1/2 rounded-full bg-surface/90 p-1.5 shadow cursor-pointer">
            <ChevronRight className="h-4 w-4 text-ink" />
          </button>
          <div className="absolute bottom-2 left-1/2 flex -translate-x-1/2 gap-1.5">
            {slides.map((_, i) => (
              <button key={i} type="button" aria-label={`Slide ${i + 1}`} onClick={() => setIndex(i)} className={`h-1 rounded-full transition-all cursor-pointer ${i === index ? 'w-4 bg-accent' : 'w-1 bg-white/50'}`} />
            ))}
          </div>
        </>
      )}
    </section>
  );
}
