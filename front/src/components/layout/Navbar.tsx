import React, { useState } from 'react';
import { 
  LogIn, 
  LogOut, 
  ChevronDown,
  Box,
  ShieldCheck,
  FileText,
  GitCompare,
  User,
  Building2
} from 'lucide-react';
import { useAuth } from '../../context/AuthContext';

export interface NavbarProps {
  onReset: () => void;
  activeView: 'xulosa' | 'diff' | '3D' | 'dashboard';
  setActiveView: (view: 'xulosa' | 'diff' | '3D' | 'dashboard') => void;
  hasAnalysis: boolean;
  onOpenAuth: () => void;
  onOpen3D?: () => void;
  onLoadDemo?: () => void;
}

export const Navbar: React.FC<NavbarProps> = ({
  onReset,
  activeView,
  setActiveView,
  hasAnalysis,
  onOpenAuth,
  onOpen3D,
  onLoadDemo,
}) => {
  const { user, isAuthenticated, activeEntityType, switchEntityType, logout } = useAuth();
  const [showDropdown, setShowDropdown] = useState(false);

  const isIndividual = (user?.entity_type || activeEntityType) === 'INDIVIDUAL';

  const handleSelectView = (view: 'xulosa' | 'diff' | '3D') => {
    if (view === '3D') {
      if (onOpen3D) onOpen3D();
      return;
    }
    if (!hasAnalysis && onLoadDemo) {
      onLoadDemo();
    }
    setActiveView(view);
  };

  return (
    <header className="fixed top-3 sm:top-4 left-1/2 -translate-x-1/2 z-50 w-[95%] max-w-6xl transition-all duration-300">
      {/* Floating Stadium Capsule Navbar */}
      <div className={`liquid-glass-pill rounded-full px-4 sm:px-6 py-2.5 transition-all duration-300 ${
        isIndividual ? 'border-sky-500/25 shadow-sky-950/40' : 'border-emerald-500/25 shadow-emerald-950/40'
      }`}>
        <div className="flex items-center justify-between gap-3">
          {/* 1. Brand Logo */}
          <div 
            onClick={onReset}
            className="flex items-center gap-3 cursor-pointer group shrink-0"
            title="Bosh sahifaga qaytish"
          >
            <div className={`relative h-9 px-2.5 rounded-full p-[1.5px] transition-transform duration-300 group-hover:scale-105 shadow-md flex items-center justify-center ${
              isIndividual
                ? 'bg-gradient-to-tr from-sky-400 via-blue-500 to-cyan-300 shadow-sky-500/30'
                : 'bg-gradient-to-tr from-emerald-400 via-teal-500 to-green-300 shadow-emerald-500/30'
            }`}>
              <div className="w-full h-full bg-slate-950/85 rounded-full px-2 flex items-center justify-center backdrop-blur-md">
                <img src="/lex_uz.svg" alt="Lex.uz" className="h-4.5 w-auto object-contain brightness-125" />
              </div>
            </div>

            <div className="flex items-center gap-2">
              <span className="text-base sm:text-lg font-black tracking-tight text-white">
                LexGuard<span className={isIndividual ? "text-sky-400" : "text-emerald-400"}>.AI</span>
              </span>
            </div>
          </div>

          {/* 2. Center Glass Capsule Menu — Minimalist Single-Word Labels */}
          <nav className="flex items-center gap-1 p-1 rounded-full bg-white/[0.04] border border-white/10 backdrop-blur-xl">
            {/* Fuqaro (B2C Mode) */}
            <button
              onClick={() => switchEntityType('INDIVIDUAL')}
              className={`px-3.5 py-1.5 rounded-full text-xs font-bold transition-all cursor-pointer flex items-center gap-1.5 ${
                isIndividual
                  ? 'bg-gradient-to-r from-sky-500 to-blue-600 text-white shadow-md shadow-sky-500/30'
                  : 'text-slate-300 hover:text-white hover:bg-white/10'
              }`}
              title="Fuqaro (B2C) — Jismoniy shaxs shartnomalari"
            >
              <User className="w-3.5 h-3.5" />
              <span>Fuqaro</span>
            </button>

            {/* Biznes (B2B Mode) */}
            <button
              onClick={() => switchEntityType('LEGAL_ENTITY')}
              className={`px-3.5 py-1.5 rounded-full text-xs font-bold transition-all cursor-pointer flex items-center gap-1.5 ${
                !isIndividual
                  ? 'bg-gradient-to-r from-emerald-500 to-teal-600 text-white shadow-md shadow-emerald-500/30'
                  : 'text-slate-300 hover:text-white hover:bg-white/10'
              }`}
              title="Biznes (B2B) — Korporativ shartnomalar"
            >
              <Building2 className="w-3.5 h-3.5" />
              <span>Biznes</span>
            </button>

            {/* Xulosa */}
            <button
              onClick={() => handleSelectView('xulosa')}
              className={`px-3.5 py-1.5 rounded-full text-xs font-bold transition-all cursor-pointer flex items-center gap-1.5 ${
                activeView === 'xulosa' || (activeView === 'dashboard' && hasAnalysis)
                  ? isIndividual
                    ? 'bg-sky-500/20 text-sky-300 border border-sky-500/30'
                    : 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                  : 'text-slate-300 hover:text-white hover:bg-white/10'
              }`}
              title="Shartnoma Huquqiy Xulosasi"
            >
              <FileText className="w-3.5 h-3.5" />
              <span>Xulosa</span>
            </button>

            {/* Diff */}
            <button
              onClick={() => handleSelectView('diff')}
              className={`px-3.5 py-1.5 rounded-full text-xs font-bold transition-all cursor-pointer flex items-center gap-1.5 ${
                activeView === 'diff'
                  ? isIndividual
                    ? 'bg-sky-500/20 text-sky-300 border border-sky-500/30'
                    : 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                  : 'text-slate-300 hover:text-white hover:bg-white/10'
              }`}
              title="Yonma-yon Qizil / Yashil Redline Diff"
            >
              <GitCompare className="w-3.5 h-3.5" />
              <span>Diff</span>
            </button>

            {/* 3D */}
            <button
              onClick={() => handleSelectView('3D')}
              className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-full text-xs font-bold text-sky-300 hover:text-white bg-sky-500/10 hover:bg-sky-500/20 border border-sky-500/25 transition-all cursor-pointer shadow-sm shadow-sky-500/15"
              title="Three.js 3D Risk Xaritasi"
            >
              <Box className="w-3.5 h-3.5 text-cyan-300 animate-pulse" />
              <span>3D</span>
            </button>
          </nav>

          {/* 3. Right Action: Kirish (Single Word Minimalist) */}
          <div className="flex items-center gap-2 sm:gap-3">
            {isAuthenticated ? (
              <div className="relative">
                <button
                  onClick={() => setShowDropdown(!showDropdown)}
                  className="flex items-center gap-2 py-1 pl-2.5 pr-2 rounded-full bg-white/5 hover:bg-white/10 border border-white/10 text-xs text-white transition-all cursor-pointer"
                >
                  <div className={`w-5 h-5 rounded-full flex items-center justify-center font-bold text-[10px] text-white ${
                    isIndividual ? 'bg-sky-500' : 'bg-emerald-500'
                  }`}>
                    {user?.full_name?.charAt(0) || 'U'}
                  </div>
                  <span className="max-w-[85px] sm:max-w-[110px] truncate font-medium">
                    {user?.full_name?.split(' ')[0]}
                  </span>
                  <ChevronDown className="w-3 h-3 text-slate-400" />
                </button>

                {showDropdown && (
                  <div className="absolute right-0 mt-2 w-64 liquid-glass-card rounded-2xl p-2 z-50 animate-in fade-in slide-in-from-top-2 duration-150">
                    <div className="p-3 border-b border-white/10 mb-1">
                      <p className="text-xs font-bold text-white truncate">{user?.full_name}</p>
                      <p className="text-[11px] text-slate-400 truncate mt-0.5">{user?.email || 'Foydalanuvchi'}</p>
                      <div className="flex items-center gap-1.5 mt-2 text-[10px] font-mono text-emerald-400">
                        <ShieldCheck className="w-3 h-3" />
                        <span>OneID / E-IMZO tasdiqlangan</span>
                      </div>
                    </div>

                    <button
                      onClick={() => {
                        logout();
                        setShowDropdown(false);
                      }}
                      className="w-full flex items-center gap-2 px-3 py-2 text-xs font-medium text-rose-400 hover:bg-rose-500/10 rounded-xl transition-all cursor-pointer"
                    >
                      <LogOut className="w-3.5 h-3.5" />
                      <span>Chiqish</span>
                    </button>
                  </div>
                )}
              </div>
            ) : (
              <button
                onClick={onOpenAuth}
                className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-full text-xs font-bold text-white bg-white/10 hover:bg-white/15 border border-white/15 transition-all cursor-pointer hover:scale-105"
                title="Tizimga kirish yoki ro'yxatdan o'tish"
              >
                <LogIn className="w-3.5 h-3.5 text-sky-400" />
                <span>Kirish</span>
              </button>
            )}
          </div>
        </div>
      </div>
    </header>
  );
};
