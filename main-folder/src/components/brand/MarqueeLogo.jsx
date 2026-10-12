/** Marquee mark — geometric M with bulb accents. Uses currentColor + accent. */
export default function MarqueeLogo({ className = 'h-8 w-8', ...props }) {
  return (
    <svg
      viewBox="0 0 64 64"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-hidden="true"
      {...props}
    >
      <path
        d="M20 26v22 M44 26v22 M20 26l12 12 12-12"
        stroke="currentColor"
        strokeWidth="7"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <circle cx="20" cy="17.5" r="2.6" className="fill-accent" />
      <circle cx="44" cy="17.5" r="2.6" className="fill-accent" />
    </svg>
  );
}
