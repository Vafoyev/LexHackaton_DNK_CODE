import React from 'react';

interface LexUzLogoProps {
  className?: string;
  variant?: 'badge' | 'logo-only' | 'partner';
  lightBg?: boolean;
}

export const LexUzLogo: React.FC<LexUzLogoProps> = ({
  className = "h-5 w-auto",
  variant = 'badge',
  lightBg = false,
}) => {
  if (variant === 'logo-only') {
    return (
      <img
        src="/lex_uz.svg"
        alt="Lex.uz"
        className={`${className} object-contain transition-all`}
        title="Lex.uz — O'zbekiston Respublikasi Qonunchilik ma'lumotlari milliy bazasi"
      />
    );
  }

  if (variant === 'partner') {
    return (
      <a
        href="https://lex.uz"
        target="_blank"
        rel="noopener noreferrer"
        className={`inline-flex items-center gap-2 px-2.5 py-1 rounded-xl transition-all border ${
          lightBg
            ? 'bg-white/80 border-slate-200 text-slate-700 hover:bg-white shadow-sm'
            : 'bg-slate-900/80 border-slate-800 text-slate-300 hover:border-zinc-500/40 hover:bg-slate-800/80 shadow-inner'
        }`}
        title="Lex.uz — O'zbekiston Respublikasi Qonunchilik ma'lumotlari milliy bazasi"
      >
        <span className="text-[10px] uppercase font-mono font-bold text-zinc-400">Manba:</span>
        <img
          src="/lex_uz.svg"
          alt="Lex.uz"
          className={`${className} object-contain brightness-110`}
        />
      </a>
    );
  }

  // Default: verified legal source badge
  return (
    <div
      className={`inline-flex items-center gap-2 px-2.5 py-1 rounded-xl border backdrop-blur-sm ${
        lightBg
          ? 'bg-zinc-50 border-zinc-200 text-zinc-950'
          : 'bg-zinc-950/40 border-zinc-500/30 text-zinc-200'
      }`}
    >
      <img
        src="/lex_uz.svg"
        alt="Lex.uz"
        className={`${className} object-contain`}
      />
      <span className="text-[10px] font-mono uppercase font-bold text-zinc-400 tracking-wider">
        Qonuniy Asos
      </span>
    </div>
  );
};
