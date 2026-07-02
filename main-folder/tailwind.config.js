/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/**/*.{js,jsx,ts,tsx}'],
  theme: {
    extend: {
      colors: {
        canvas: '#14181C',
        surface: '#202830',
        'surface-raised': '#2C3440',
        border: '#2C3440',
        ink: '#C8D4E0',
        'ink-bright': '#FFFFFF',
        muted: '#8899AA',
        'muted-dim': '#667788',
        accent: '#00E054',
        'accent-hover': '#00C030',
        link: '#40BCF4',
      },
      fontFamily: {
        sans: ['DM Sans', 'system-ui', 'sans-serif'],
        serif: ['Source Serif 4', 'Georgia', 'serif'],
      },
      maxWidth: {
        content: '75rem',
      },
      spacing: {
        'poster-sm': '5.5rem',
        'poster-md': '7rem',
        'poster-lg': '9.5rem',
      },
      boxShadow: {
        poster: '0 2px 12px rgba(0, 0, 0, 0.45)',
        'poster-hover': '0 8px 24px rgba(0, 0, 0, 0.55)',
        bento: '0 4px 20px rgba(0, 0, 0, 0.35)',
      },
      animation: {
        'fade-up': 'fadeUp 0.55s ease-out forwards',
      },
      keyframes: {
        fadeUp: {
          '0%': { opacity: '0', transform: 'translateY(14px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
      },
    },
  },
  plugins: [],
};
