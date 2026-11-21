import React from 'react';
import { ArrowLeft, Sun, Moon } from 'lucide-react';
import { AnalysisResult } from '../../types/contract';
import { exportToDocx, exportToPDF } from '../../utils/export';
import { useAuth } from '../../context/AuthContext';
import { useTheme } from '../../context/ThemeContext';

interface StudioHeaderProps {
  analysis: AnalysisResult;
  activeView: 'reader' | 'diff';
  setActiveView: (view: 'reader' | 'diff') => void;
  onOpen3D: () => void;
  onReset: () => void;
  appliedCount: number;
}

export const StudioHeader: React.FC<StudioHeaderProps> = ({
  analysis,
  activeView,
  setActiveView,
  onOpen3D,
  onReset,
  appliedCount,
}) => {
  const { user, activeEntityType } = useAuth();
  const { isDark, toggleTheme } = useTheme();
  const isIndividual = (user?.entity_type || activeEntityType) === 'INDIVIDUAL';

  const initialScore = 100 - analysis.summary.risk_score;
  // Har bir qabul qilingan fix uchun ball oshadi
  const dynamicScore = Math.min(100, initialScore + appliedCount * 12);

  return (
    <header className="sticky top-0 z-40 bg-white/90 dark:bg-slate-950/90 border-b border-slate-200 dark:border-slate-800 backdrop-blur-xl px-4 sm:px-8 py-3 transition-colors duration-300">
      <div className="max-w-7xl mx-auto flex flex-col md:flex-row items-center justify-between gap-3">
        {/* Chap tomon: Qaytish tugmasi va Hujjat nomi */}
        <div className="flex items-center gap-3 w-full md:w-auto justify-between md:justify-start">
          <button
            onClick={onReset}
            className="p-2 px-3 rounded-xl bg-slate-100 hover:bg-slate-200 dark:bg-slate-900 dark:hover:bg-slate-800 text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white border border-slate-200 dark:border-slate-800 transition-colors cursor-pointer flex items-center gap-1.5 text-xs font-semibold"
            title="Boshqa shartnoma yuklash"
          >
            <ArrowLeft className="w-4 h-4" />
            <span>Yangi Shartnoma</span>
          </button>

          <div>
            <div className="flex items-center gap-2">
              <span className={`text-[10px] font-mono font-bold px-2 py-0.5 rounded-full border ${
                isIndividual 
                  ? 'bg-sky-500/10 text-sky-600 dark:text-sky-400 border-sky-500/30' 
                  : 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-500/30'
              }`}>
                {isIndividual ? 'JISMONIY SHAXS' : 'YURIDIK B2B'}
              </span>

              <h2 className="text-xs sm:text-sm font-bold text-slate-900 dark:text-white truncate max-w-[200px] sm:max-w-xs">
                {analysis.document.filename}
              </h2>
            </div>
          </div>

          {/* Dinamik Xavfsizlik ko'rsatkichi */}
          <div className="flex items-center gap-1.5 px-3 py-1 rounded-xl bg-slate-100 dark:bg-slate-900 border border-slate-200 dark:border-slate-800">
            <span className={`text-xs font-black font-mono ${
              dynamicScore >= 80 ? 'text-emerald-500 dark:text-emerald-400' : dynamicScore >= 50 ? 'text-amber-500 dark:text-amber-400' : 'text-rose-500 dark:text-rose-400'
            }`}>
              {dynamicScore}%
            </span>
            <span className="text-[10px] text-slate-500 dark:text-slate-400 uppercase font-mono">Xavfsiz</span>
          </div>

          {/* Lex.uz Moslik nishoni */}
          <a
            href="https://lex.uz"
            target="_blank"
            rel="noopener noreferrer"
            className="hidden xl:flex items-center gap-1.5 px-2.5 py-1 rounded-xl bg-slate-100 dark:bg-slate-900 border border-slate-200 dark:border-slate-800 hover:border-sky-500/40 transition-all text-[10px] text-slate-600 dark:text-slate-300"
            title="Lex.uz qonunchilik bazasi bilan sinxronlangan"
          >
            <img src="/lex_uz.svg" alt="Lex.uz" className="h-3.5 w-auto object-contain brightness-110" />
            <span className="font-mono text-sky-600 dark:text-sky-400 font-bold">Moslashtirilgan</span>
          </a>
        </div>

        {/* O'rta: Asosiy Ko'rinish Almashtirgich (Reader vs Diff vs 3D) */}
        <div className="flex items-center gap-1 p-1 bg-slate-100 dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-inner">
          <button
            onClick={() => setActiveView('reader')}
            className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
              activeView === 'reader'
                ? 'bg-white dark:bg-slate-800 text-slate-900 dark:text-white shadow-sm'
                : 'text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
            }`}
          >
            Shartnoma Varaqi
          </button>

          <button
            onClick={() => setActiveView('diff')}
            className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
              activeView === 'diff'
                ? 'bg-white dark:bg-slate-800 text-slate-900 dark:text-white shadow-sm'
                : 'text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
            }`}
          >
            Redline Diff
          </button>

          <button
            onClick={onOpen3D}
            className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl text-xs font-bold text-sky-600 dark:text-sky-400 hover:text-sky-700 dark:hover:text-sky-300 hover:bg-slate-200/50 dark:hover:bg-slate-800/60 transition-all cursor-pointer"
          >
            <img src="/lex_uz.svg" alt="3D" className="h-3 w-auto object-contain brightness-125" />
            <span>3D Xarita</span>
          </button>
        </div>

        {/* O'ng tomon: Rejim Toggle va Eksport Tugmalari */}
        <div className="flex items-center gap-2">
          {/* Tungi / Kunduzgi Rejim Tugmasi */}
          <button
            onClick={toggleTheme}
            className="p-1.5 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-100 hover:bg-slate-200 dark:bg-slate-900 dark:hover:bg-slate-800 text-slate-700 dark:text-amber-400 transition-all cursor-pointer hover:scale-105"
            title={isDark ? "Kunduzgi rejim (Light Mode)" : "Tungi rejim (Dark Mode)"}
          >
            {isDark ? (
              <Sun className="w-4 h-4 text-amber-400" />
            ) : (
              <Moon className="w-4 h-4 text-indigo-600" />
            )}
          </button>

          <button
            onClick={() => exportToDocx(analysis)}
            className="px-3 py-1.5 rounded-xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-sky-600 dark:text-sky-300 text-xs font-semibold border border-slate-200 dark:border-slate-700 hover:border-sky-500/40 transition-all cursor-pointer"
            title="Word (.docx) yuklab olish"
          >
            DOCX
          </button>

          <button
            onClick={() => exportToPDF(analysis)}
            className="px-3 py-1.5 rounded-xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-emerald-600 dark:text-emerald-300 text-xs font-semibold border border-slate-200 dark:border-slate-700 hover:border-emerald-500/40 transition-all cursor-pointer"
            title="Audit PDF yuklab olish"
          >
            PDF
          </button>
        </div>
      </div>
    </header>
  );
};
