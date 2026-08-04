/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      keyframes: {
        scroll: {
          from: { transform: 'translateX(0)' },
          to: { transform: 'translateX(-50%)' },
        },
        'progress-fill': {
          from: { width: '0%' },
          to: { width: '100%' },
        },
      },
      animation: {
        scroll: 'scroll var(--duration, 30s) linear infinite',
        'progress-fill': 'progress-fill 1s ease-out forwards',
      },
    },
  },
  plugins: [],
};
