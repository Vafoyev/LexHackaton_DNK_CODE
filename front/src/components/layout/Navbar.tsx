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
  ChevronDown,
  CreditCard,
  FileBadge
} from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { EntityType } from '../../types/auth';

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
  const { user, isAuthenticated, activeEntityType, switchEntityType, logout } = useAuth();
  const [showDropdown, setShowDropdown] = useState(false);

  const isIndividual = (user?.entity_type || activeEntityType) === 'INDIVIDUAL';

  return (
    <header className="sticky top-0 z-50 backdrop-blur-xl bg-slate-950/85 border-b border-slate-800/80 transition-all">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <div 
            onClick={onReset}
            className="flex items-center gap-3 cursor-pointer group shrink-0"
          >
            <div className={`relative w-10 h-10 rounded-xl p-[2px] transition-transform duration-300 group-hover:scale-105 shadow-lg ${
              isIndividual
                ? 'bg-gradient-to-tr from-sky-600 via-blue-500 to-cyan-400 shadow-sky-500/20'
                : 'bg-gradient-to-tr from-emerald-600 via-teal-500 to-green-400 shadow-emerald-500/20'
            }`}>
              <div className="w-full h-full bg-slate-900 rounded-[10px] flex items-center justify-center">
                <ShieldCheck className={`w-6 h-6 ${isIndividual ? 'text-sky-400' : 'text-emerald-400'}`} />
              </div>
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xl font-black tracking-tight bg-gradient-to-r from-white via-slate-100 to-slate-300 bg-clip-text text-transparent">
                  LexGuard<span className={isIndividual ? "text-sky-400" : "text-emerald-400"}>.AI</span>
                </span>
                <span className={`text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded-full border ${
                  isIndividual
                    ? 'bg-sky-500/10 text-sky-400 border-sky-500/30'
                    : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                }`}>
                  {isIndividual ? 'FUQARO' : 'B2B'}
                </span>
              </div>
              <p className="text-[10px] text-slate-400 font-medium hidden sm:block">
                Lex.uz Qonuniy Audit & 3D Risk Visualizer
              </p>
            </div>
          </div>

          {/* MARKAZIY SHAXS TURINI ALMASHTIRGICH (JISMONIY / YURIDIK) */}
          <div className="flex items-center p-1 bg-slate-900/90 rounded-2xl border border-slate-800 shadow-inner">
            <button
              onClick={() => switchEntityType('INDIVIDUAL')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                isIndividual
                  ? 'bg-gradient-to-r from-sky-600 to-brand-600 text-white shadow-md shadow-sky-600/30'
                  : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              <User className="w-3.5 h-3.5" />
              <span>Jismoniy shaxs</span>
            </button>

            <button
              onClick={() => switchEntityType('LEGAL_ENTITY')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                !isIndividual
                  ? 'bg-gradient-to-r from-emerald-600 to-teal-700 text-white shadow-md shadow-emerald-600/30'
                  : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              <Building className="w-3.5 h-3.5" />
              <span>Yuridik shaxs</span>
            </button>
          </div>

          {/* Navigation Tabs (agar tahlil yuklangan bo'lsa) */}
          {hasAnalysis && (
            <nav className="hidden lg:flex items-center gap-1.5 p-1 bg-slate-900/90 rounded-xl border border-slate-800 shadow-inner">
              <button
                onClick={() => setActiveView('dashboard')}
                className={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                  activeView === 'dashboard'
                    ? 'bg-slate-800 text-white shadow-sm'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                <Scale className="w-3.5 h-3.5" />
                <span>Executive Xulosa</span>
              </button>

              <button
                onClick={() => setActiveView('visualizer3d')}
                className={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                  activeView === 'visualizer3d'
                    ? 'bg-slate-800 text-white shadow-sm'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                <Cpu className="w-3.5 h-3.5 text-sky-400" />
                <span>3D Sfera</span>
              </button>

              <button
                onClick={() => setActiveView('diff')}
                className={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                  activeView === 'diff'
                    ? 'bg-slate-800 text-white shadow-sm'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                <BookOpen className="w-3.5 h-3.5" />
                <span>Diff</span>
              </button>
            </nav>
          )}

          {/* O'ng tomon: Login / Foydalanuvchi Profili */}
          <div className="flex items-center gap-3">
            {!isAuthenticated ? (
              <button
                onClick={onOpenAuth}
                className={`px-4 py-2 rounded-xl text-white text-xs font-bold shadow-lg flex items-center gap-1.5 transition-all cursor-pointer hover:scale-105 ${
                  isIndividual
                    ? 'bg-gradient-to-r from-sky-500 to-brand-600 shadow-sky-500/20'
                    : 'bg-gradient-to-r from-emerald-500 to-teal-600 shadow-emerald-500/20'
                }`}
              >
                <LogIn className="w-3.5 h-3.5" />
                <span>Kirish / OneID</span>
              </button>
            ) : (
              <div className="relative">
                <button
                  onClick={() => setShowDropdown(!showDropdown)}
                  className={`flex items-center gap-2.5 p-1.5 pr-3 rounded-2xl bg-slate-900 border transition-all text-left cursor-pointer ${
                    isIndividual 
                      ? 'border-sky-500/40 hover:border-sky-400' 
                      : 'border-emerald-500/40 hover:border-emerald-400'
                  }`}
                >
                  <div className={`w-8 h-8 rounded-xl flex items-center justify-center font-bold text-xs ${
                    isIndividual 
                      ? 'bg-sky-500/20 text-sky-400 border border-sky-500/30' 
                      : 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                  }`}>
                    {isIndividual ? <User className="w-4 h-4" /> : <Building className="w-4 h-4" />}
                  </div>
                  <div className="hidden sm:block">
                    <div className="flex items-center gap-1.5">
                      <span className="text-xs font-bold text-white leading-tight">
                        {user?.full_name?.split(' ')[0]}
                      </span>
                      <span className={`text-[9px] font-mono px-1.5 py-0.2 rounded font-bold uppercase ${
                        isIndividual 
                          ? 'bg-sky-500/20 text-sky-300 border border-sky-500/30' 
                          : 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                      }`}>
                        {isIndividual ? 'JISMONIY' : 'YURIDIK'}
                      </span>
                    </div>
                    <span className="text-[10px] text-slate-400 block truncate max-w-[120px] font-mono">
                      {isIndividual ? `JShShIR: ${user?.jshshir || '301019...'}` : `STIR: ${user?.tin || '305123...'}`}
                    </span>
                  </div>
                  <ChevronDown className="w-3.5 h-3.5 text-slate-400" />
                </button>

                {/* Dropdown Menu */}
                {showDropdown && (
                  <div className="absolute right-0 mt-2 w-72 rounded-2xl bg-slate-900 border border-slate-800 shadow-2xl p-3.5 z-50 animate-in fade-in zoom-in-95 duration-150">
                    <div className="p-2.5 border-b border-slate-800 mb-2">
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-xs font-bold text-white">{user?.full_name}</span>
                        <span className={`text-[9px] font-mono font-bold px-1.5 py-0.5 rounded ${
                          isIndividual ? 'bg-sky-500/20 text-sky-400' : 'bg-emerald-500/20 text-emerald-400'
                        }`}>
                          {isIndividual ? 'FUQARO' : 'KORPORATIV'}
                        </span>
                      </div>
                      <p className="text-[11px] text-slate-400 truncate">{user?.email}</p>

                      <div className="mt-2.5 p-2 rounded-xl bg-slate-950 border border-slate-800 space-y-1">
                        {isIndividual ? (
                          <div className="flex items-center justify-between text-[11px]">
                            <span className="text-slate-400 flex items-center gap-1">
                              <CreditCard className="w-3 h-3 text-sky-400" /> JShShIR:
                            </span>
                            <span className="text-sky-300 font-mono font-bold">{user?.jshshir || '30101901234567'}</span>
                          </div>
                        ) : (
                          <>
                            <div className="flex items-center justify-between text-[11px]">
                              <span className="text-slate-400 flex items-center gap-1">
                                <FileBadge className="w-3 h-3 text-emerald-400" /> STIR (INN):
                              </span>
                              <span className="text-emerald-300 font-mono font-bold">{user?.tin || '305123456'}</span>
                            </div>
                            <div className="flex items-center justify-between text-[11px]">
                              <span className="text-slate-400 flex items-center gap-1">
                                <Building className="w-3 h-3 text-emerald-400" /> Tashkilot:
                              </span>
                              <span className="text-slate-200 font-semibold truncate max-w-[120px]">{user?.org_name || 'MCHJ'}</span>
                            </div>
                          </>
                        )}
                        <div className="flex items-center justify-between text-[11px] pt-1 border-t border-slate-900">
                          <span className="text-slate-400">Tahlil Limiti:</span>
                          <span className="text-emerald-400 font-bold">
                            {user?.quota?.remaining ?? (isIndividual ? 9 : 46)} ta qoldi
                          </span>
                        </div>
                      </div>
                    </div>

                    {/* Shaxs turini almashtirish imkoniyati */}
                    <div className="mb-2 p-1.5 rounded-xl bg-slate-950/60 border border-slate-800 flex items-center justify-between text-xs">
                      <span className="text-slate-400 text-[11px]">Rejim:</span>
                      <div className="flex gap-1">
                        <button
                          onClick={() => switchEntityType('INDIVIDUAL')}
                          className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                            isIndividual ? 'bg-sky-500 text-white' : 'text-slate-400 hover:text-white'
                          }`}
                        >
                          Jismoniy
                        </button>
                        <button
                          onClick={() => switchEntityType('LEGAL_ENTITY')}
                          className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                            !isIndividual ? 'bg-emerald-500 text-white' : 'text-slate-400 hover:text-white'
                          }`}
                        >
                          Yuridik
                        </button>
                      </div>
                    </div>

                    <div className="pt-2 border-t border-slate-800">
                      <button
                        onClick={() => {
                          logout();
                          setShowDropdown(false);
                        }}
                        className="w-full py-2 px-3 rounded-xl bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 text-xs font-bold flex items-center justify-center gap-2 transition-colors cursor-pointer"
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
