import React from 'react';
import { ExternalLink } from 'lucide-react';

export const Footer: React.FC = () => {
  return (
    <footer className="mt-auto border-t border-slate-200 dark:border-slate-800/80 bg-white/50 dark:bg-slate-950/80 backdrop-blur-md text-slate-500 dark:text-slate-400 text-xs py-6 transition-colors">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex flex-col md:flex-row items-center justify-between gap-4">
          {/* Chap: Brend va rasmiy maqom */}
          <div className="flex items-center gap-3">
            <div className="p-1 px-1.5 rounded-lg bg-slate-900 border border-white/10 flex items-center justify-center shadow-sm">
              <img src="/lex_uz.svg" alt="Lex.uz" className="h-4 w-auto object-contain brightness-125" />
            </div>
            <div>
              <span className="font-bold text-slate-900 dark:text-white text-sm">LexGuard.AI</span>
              <span className="text-slate-400 dark:text-slate-500 text-[11px] ml-2">· O‘zbekiston Respublikasi Lex.uz bazasi integratsiyasi</span>
            </div>
          </div>

          {/* O'ng: Havola va Mualliflik */}
          <div className="flex flex-wrap items-center gap-4 text-[11px]">
            <a 
              href="https://lex.uz" 
              target="_blank" 
              rel="noreferrer" 
              className="text-sky-600 dark:text-sky-400 hover:underline flex items-center gap-1 font-semibold transition-colors"
            >
              <span>Lex.uz Milliy Qonunchilik Portali</span>
              <ExternalLink className="w-3 h-3" />
            </a>
            <span className="text-slate-300 dark:text-slate-700">|</span>
            <p className="text-slate-500">© 2026 LexGuard AI · LexHackathon 2026</p>
          </div>
        </div>

        {/* Yuridik eslatma */}
        <div className="mt-4 pt-3 border-t border-slate-200/60 dark:border-slate-900 text-center text-[10px] text-slate-400 dark:text-slate-500">
          Ogohlantirish: AI huquqiy tahlili konsultatsiya xarakteriga ega bo‘lib, rasmiy advokatlik yoki notarial xulosasi o‘rnini bosmaydi.
        </div>
      </div>
    </footer>
  );
};
