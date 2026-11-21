import React, { useState } from 'react';
import { 
  ShieldCheck, 
  Cpu, 
  Sparkles, 
  Scale, 
  BookOpen, 
  User, 
  LogIn, 
  LogOut, 
  Building, 
  Zap, 
  ChevronDown 
} from 'lucide-react';
import { useAuth } from '../../context/AuthContext';

interface NavbarProps {
  onReset: () => void;
  activeView: 'dashboard' | 'diff' | 'visualizer3d';
  setActiveView: (view: 'dashboard' | 'diff' | 'visualizer3d') => void;
  hasAnalysis: boolean;
  onOpenAuth: () => void;
}

export const Navbar: React.FC<NavbarProps> = ({
  onReset,
  activeView,
  setActiveView,
  hasAnalysis,
  onOpenAuth,
}) => {
  const { user, isAuthenticated, logout } = useAuth();
  const [showDropdown, setShowDropdown] = useState(false);

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
            <nav className="hidden md:flex items-center gap-1.5 p-1 bg-slate-900/90 rounded-xl border border-slate-800 shadow-inner">
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

          {/* Status Badges & Auth Section */}
          <div className="flex items-center gap-3">
            {/* Yangi shartnoma yuklash tugmasi */}
            {hasAnalysis && (
              <button
                onClick={onReset}
                className="hidden sm:flex px-3 py-1.5 rounded-xl text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 transition-all items-center gap-1.5 cursor-pointer"
              >
                <Sparkles className="w-3.5 h-3.5 text-sky-400" />
                <span>Yangi</span>
              </button>
            )}

            {/* LOGIN / USER PROFILI */}
            {!isAuthenticated ? (
              <button
                onClick={onOpenAuth}
                className="px-4 py-2 rounded-xl bg-gradient-to-r from-sky-500 to-brand-600 hover:from-sky-400 hover:to-brand-500 text-white text-xs font-bold shadow-lg shadow-sky-500/20 flex items-center gap-1.5 transition-all cursor-pointer hover:scale-105"
              >
                <LogIn className="w-3.5 h-3.5" />
                <span>Kirish / OneID</span>
              </button>
            ) : (
              <div className="relative">
                <button
                  onClick={() => setShowDropdown(!showDropdown)}
                  className="flex items-center gap-2.5 p-1.5 pr-3 rounded-2xl bg-slate-900 border border-slate-800 hover:border-sky-500/40 transition-all text-left cursor-pointer"
                >
                  <div className="w-8 h-8 rounded-xl bg-sky-500/20 border border-sky-500/30 flex items-center justify-center text-sky-400 font-bold text-xs">
                    {user?.full_name?.charAt(0) || 'U'}
                  </div>
                  <div className="hidden sm:block">
                    <div className="flex items-center gap-1.5">
                      <span className="text-xs font-bold text-white leading-tight">
                        {user?.full_name?.split(' ')[0]}
                      </span>
                      <span className="text-[9px] font-mono px-1.5 py-0.2 rounded bg-sky-500/20 text-sky-300 border border-sky-500/30">
                        {user?.role === 'lawyer_reviewer' ? 'YURIST' : 'BIZNES'}
                      </span>
                    </div>
                    <span className="text-[10px] text-slate-400 block truncate max-w-[110px]">
                      {user?.org_name}
                    </span>
                  </div>
                  <ChevronDown className="w-3.5 h-3.5 text-slate-400" />
                </button>

                {/* Dropdown Menu */}
                {showDropdown && (
                  <div className="absolute right-0 mt-2 w-64 rounded-2xl bg-slate-900 border border-slate-800 shadow-2xl p-3 z-50 animate-in fade-in zoom-in-95 duration-150">
                    <div className="p-2 border-b border-slate-800 mb-2">
                      <p className="text-xs font-bold text-white">{user?.full_name}</p>
                      <p className="text-[11px] text-slate-400 truncate">{user?.email}</p>
                      <div className="mt-2 flex items-center justify-between text-[10px] font-mono p-1.5 rounded-lg bg-slate-950 border border-slate-800/80">
                        <span className="text-slate-400">B2B Kvota:</span>
                        <span className="text-emerald-400 font-bold">18/20 ta qoldi</span>
                      </div>
                    </div>

                    <div className="space-y-1 text-xs">
                      <div className="px-2 py-1.5 rounded-lg text-slate-300 flex items-center gap-2">
                        <Building className="w-3.5 h-3.5 text-sky-400" />
                        <span className="truncate">{user?.org_name}</span>
                      </div>
                      <div className="px-2 py-1.5 rounded-lg text-slate-300 flex items-center gap-2">
                        <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" />
                        <span>O‘RQ-547 Tasdiqlangan</span>
                      </div>
                    </div>

                    <div className="pt-2 border-t border-slate-800 mt-2">
                      <button
                        onClick={() => {
                          logout();
                          setShowDropdown(false);
                        }}
                        className="w-full py-2 px-3 rounded-xl bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 text-xs font-bold flex items-center gap-2 transition-colors cursor-pointer"
                      >
                        <LogOut className="w-3.5 h-3.5" />
                        <span>Chiqish (Logout)</span>
                      </button>
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  );
};
