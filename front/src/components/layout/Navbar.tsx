import React from 'react';
import { ShieldCheck, Cpu, Sparkles, Scale, BookOpen, AlertCircle } from 'lucide-react';

interface NavbarProps {
  onReset: () => void;
  activeView: 'dashboard' | 'diff' | 'visualizer3d';
  setActiveView: (view: 'dashboard' | 'diff' | 'visualizer3d') => void;
  hasAnalysis: boolean;
}

export const Navbar: React.FC<NavbarProps> = ({
  onReset,
  activeView,
  setActiveView,
  hasAnalysis,
}) => {
  return (
    <header className="sticky top-0 z-50 backdrop-blur-xl bg-slate-950/80 border-b border-slate-800/80 transition-all">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <div 
            onClick={onReset}
            className="flex items-center gap-3 cursor-pointer group"
          >
            <div className="relative w-10 h-10 rounded-xl bg-gradient-to-tr from-brand-600 via-sky-500 to-emerald-400 p-[2px] transition-transform duration-300 group-hover:scale-105 shadow-lg shadow-sky-500/20">
              <div className="w-full h-full bg-slate-900 rounded-[10px] flex items-center justify-center">
                <ShieldCheck className="w-6 h-6 text-sky-400" />
              </div>
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xl font-bold tracking-tight bg-gradient-to-r from-white via-slate-100 to-sky-400 bg-clip-text text-transparent">
                  LexGuard<span className="text-sky-400">.AI</span>
                </span>
                <span className="text-[10px] uppercase font-semibold tracking-wider px-2 py-0.5 rounded-full bg-sky-500/10 text-sky-400 border border-sky-500/20">
                  B2B v3.2
                </span>
              </div>
              <p className="text-[11px] text-slate-400 font-medium">
                Lex.uz Qonuniy Shartnoma Audit & 3D Risk Visualizer
              </p>
            </div>
          </div>

          {/* Navigation Tabs (agar tahlil yuklangan bo'lsa) */}
          {hasAnalysis && (
            <nav className="flex items-center gap-1.5 p-1 bg-slate-900/90 rounded-xl border border-slate-800 shadow-inner">
              <button
                onClick={() => setActiveView('dashboard')}
                className={`flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                  activeView === 'dashboard'
                    ? 'bg-gradient-to-r from-sky-600 to-brand-600 text-white shadow-md shadow-sky-600/30'
                    : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
                }`}
              >
                <Scale className="w-3.5 h-3.5" />
                <span>Executive Xulosa</span>
              </button>

              <button
                onClick={() => setActiveView('visualizer3d')}
                className={`flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                  activeView === 'visualizer3d'
                    ? 'bg-gradient-to-r from-sky-600 to-brand-600 text-white shadow-md shadow-sky-600/30'
                    : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
                }`}
              >
                <Cpu className="w-3.5 h-3.5 text-sky-400" />
                <span>3D Risk Visualizer</span>
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping"></span>
              </button>

              <button
                onClick={() => setActiveView('diff')}
                className={`flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                  activeView === 'diff'
                    ? 'bg-gradient-to-r from-sky-600 to-brand-600 text-white shadow-md shadow-sky-600/30'
                    : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
                }`}
              >
                <BookOpen className="w-3.5 h-3.5" />
                <span>Side-by-Side Diff</span>
              </button>
            </nav>
          )}

          {/* Status Badges */}
          <div className="flex items-center gap-3">
            <div className="hidden sm:flex items-center gap-2 px-3 py-1.5 rounded-full bg-slate-900 border border-slate-800 text-xs">
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
              <span className="text-slate-300 font-medium">Lex.uz FK 1997–2026</span>
            </div>

            <button
              onClick={onReset}
              className="px-3.5 py-1.5 rounded-lg text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 transition-all flex items-center gap-1.5"
            >
              <Sparkles className="w-3.5 h-3.5 text-sky-400" />
              <span>Yangi Shartnoma</span>
            </button>
          </div>
        </div>
      </div>
    </header>
  );
};
