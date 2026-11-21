import React from 'react';
import { ExternalLink } from 'lucide-react';

export const Footer: React.FC = () => {
  return (
    <footer className="mt-auto border-t border-slate-200/80 dark:border-slate-800/80 bg-white/60 dark:bg-slate-950/80 backdrop-blur-md text-slate-500 dark:text-slate-400 text-xs py-5 transition-colors">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex flex-col sm:flex-row items-center justify-between gap-3">
          {/* Chap: Brend va rasmiy maqom */}
          <div className="flex items-center gap-2.5">
            <span className="font-bold text-slate-900 dark:text-white text-sm">
              LexGuard<span className="text-sky-500">.AI</span>
            </span>
            <span className="text-slate-400 dark:text-slate-600 text-xs">·</span>
            <span className="text-slate-500 dark:text-slate-400 text-xs">
              O‘zbekiston Respublikasi Qonunchiligi Huquqiy Auditi
            </span>
          </div>

          {/* O'ng: Havola va Mualliflik */}
          <div className="flex items-center gap-4 text-xs">
            <a 
              href="https://lex.uz" 
              target="_blank" 
              rel="noreferrer" 
              className="text-sky-600 dark:text-sky-400 hover:underline flex items-center gap-1.5 font-medium transition-colors"
            >
              <img src="/lex_uz.svg" alt="" aria-hidden="true" className="h-3.5 w-auto object-contain brightness-110" />
              <span>Lex.uz Milliy Qonunchilik Portali</span>
              <ExternalLink className="w-3 h-3" />
            </a>
            <span className="text-slate-300 dark:text-slate-700">|</span>
            <span className="text-slate-500">© 2026 LexHackathon</span>
          </div>
        </div>

        {/* Yuridik eslatma */}
        <div className="mt-3 pt-3 border-t border-slate-200/60 dark:border-slate-900 text-center text-[11px] text-slate-400 dark:text-slate-500">
          Ogohlantirish: AI huquqiy tahlili konsultatsiya xarakteriga ega bo‘lib, rasmiy advokatlik yoki notarial xulosasi o‘rnini bosmaydi.
        </div>
      </div>
    </footer>
  );
};
