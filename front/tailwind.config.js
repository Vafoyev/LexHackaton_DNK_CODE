import animate from 'tailwindcss-animate';

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
        // Monoxrom dizayn: slate (ko'kimtir kulrang) o'rniga sof neytral kulrang shkala
        slate: {
          50: '#fafafa', 100: '#f5f5f5', 200: '#e5e5e5', 300: '#d4d4d4', 400: '#a3a3a3',
          500: '#737373', 600: '#525252', 700: '#404040', 800: '#262626', 900: '#171717', 950: '#0a0a0a',
        },
        // shadcn/ui semantik tokenlari (qiymatlari src/index.css da; loyiha palitrasiga moslangan)
        border: 'hsl(var(--border))',
        input: 'hsl(var(--input))',
        ring: 'hsl(var(--ring))',
        background: 'hsl(var(--background))',
        foreground: 'hsl(var(--foreground))',
        primary: { DEFAULT: 'hsl(var(--primary))', foreground: 'hsl(var(--primary-foreground))' },
        secondary: { DEFAULT: 'hsl(var(--secondary))', foreground: 'hsl(var(--secondary-foreground))' },
        destructive: { DEFAULT: 'hsl(var(--destructive))', foreground: 'hsl(var(--destructive-foreground))' },
        muted: { DEFAULT: 'hsl(var(--muted))', foreground: 'hsl(var(--muted-foreground))' },
        accent: { DEFAULT: 'hsl(var(--accent))', foreground: 'hsl(var(--accent-foreground))' },
        popover: { DEFAULT: 'hsl(var(--popover))', foreground: 'hsl(var(--popover-foreground))' },
        card: { DEFAULT: 'hsl(var(--card))', foreground: 'hsl(var(--card-foreground))' },
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
      borderRadius: {
        lg: 'var(--radius)',
        md: 'calc(var(--radius) - 2px)',
        sm: 'calc(var(--radius) - 4px)',
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
  plugins: [animate],
}
