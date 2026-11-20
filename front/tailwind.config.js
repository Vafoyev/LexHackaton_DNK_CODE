/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // LegalTech 4-Color Standard (Kelishuv 3.2 & CONTRACTS.md)
        risk: {
          red: {
            DEFAULT: '#DC2626',
            light: '#FEE2E2',
            dark: '#991B1B',
            border: '#F87171',
            glow: 'rgba(220, 38, 38, 0.4)',
          },
          yellow: {
            DEFAULT: '#D97706',
            light: '#FEF3C7',
            dark: '#92400E',
            border: '#FBBF24',
            glow: 'rgba(217, 119, 6, 0.4)',
          },
          green: {
            DEFAULT: '#16A34A',
            light: '#DCFCE7',
            dark: '#166534',
            border: '#4ADE80',
            glow: 'rgba(22, 163, 74, 0.4)',
          },
          gray: {
            DEFAULT: '#4B5563',
            light: '#F3F4F6',
            dark: '#1F2937',
            border: '#9CA3AF',
            glow: 'rgba(75, 85, 99, 0.3)',
          },
        },
        brand: {
          50: '#F0F7FF',
          100: '#E0EFFE',
          500: '#0284C7',
          600: '#0369A1',
          700: '#075985',
          800: '#0C4A6E',
          900: '#082F49',
          950: '#041B2D',
        },
        slate: {
          850: '#131D31',
          900: '#0B132B',
          950: '#060B18',
        }
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
        mono: ['JetBrains Mono', 'Fira Code', 'monospace'],
      },
      animation: {
        'pulse-subtle': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'spin-slow': 'spin 12s linear infinite',
      }
    },
  },
  plugins: [],
}
