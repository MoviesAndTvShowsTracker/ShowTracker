export default function MarqueeLogo({ className = 'h-8 w-8', ...props }) {
  return (
    <svg
      viewBox="0 0 32 32"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-hidden="true"
      {...props}
    >
      <path
        d="M6 15c0-4.8 4.2-8.5 10-8.5s10 3.7 10 8.5v8.5c0 0-4.2-1.8-10-1.8S6 23.5 6 23.5V15z"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinejoin="round"
      />
      <path
        d="M7 15c3.5-3 7-4 9-4s5.5 1 9 4"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinecap="round"
      />
      <circle cx="11" cy="13" r="1.2" className="fill-accent" />
      <circle cx="16" cy="10.5" r="1.2" className="fill-accent" />
      <circle cx="21" cy="13" r="1.2" className="fill-accent" />
    </svg>
  );
}
