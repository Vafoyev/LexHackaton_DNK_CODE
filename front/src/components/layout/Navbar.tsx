import React, { useState } from 'react';
import { 
  LogIn, 
  LogOut, 
  ChevronDown,
  Zap,
  FolderOpen,
  Scale,
  User,
  Box,
  FileCheck2,
  ExternalLink
} from 'lucide-react';
import { useAuth } from '../../context/AuthContext';

interface NavbarProps {
  onReset: () => void;
  activeView: 'dashboard' | 'diff' | 'visualizer3d';
  setActiveView: (view: 'dashboard' | 'diff' | 'visualizer3d') => void;
  hasAnalysis: boolean;
  onOpenAuth: () => void;
  onOpen3D?: () => void;
}

export const Navbar: React.FC<NavbarProps> = ({
  onReset,
  activeView,
  setActiveView,
  hasAnalysis,
  onOpenAuth,
  onOpen3D,
}) => {
  const { user, isAuthenticated, activeEntityType, switchEntityType, logout } = useAuth();
  const [showDropdown, setShowDropdown] = useState(false);

  const isIndividual = (user?.entity_type || activeEntityType) === 'INDIVIDUAL';

  return (
    <header className="sticky top-0 z-50 liquid-glass border-b border-white/10 transition-all">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <div 
            onClick={onReset}
            className="flex items-center gap-3 cursor-pointer group shrink-0"
          >
            <div className={`relative h-10 px-2.5 rounded-2xl p-[2px] transition-transform duration-300 group-hover:scale-105 shadow-lg flex items-center justify-center ${
              isIndividual
                ? 'bg-gradient-to-tr from-sky-500 via-blue-500 to-cyan-400 shadow-sky-500/25'
                : 'bg-gradient-to-tr from-emerald-500 via-teal-500 to-green-400 shadow-emerald-500/25'
            }`}>
              <div className="w-full h-full bg-slate-950/80 rounded-[14px] px-2 flex items-center justify-center backdrop-blur-md">
                <img src="/lex_uz.svg" alt="Lex.uz" className="h-5 w-auto object-contain brightness-125" />
              </div>
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xl font-black tracking-tight text-white drop-shadow-sm">
                  LexGuard<span className={isIndividual ? "text-sky-400" : "text-emerald-400"}>.AI</span>
                </span>
                <span className={`text-[10px] font-mono font-bold tracking-wider px-2 py-0.5 rounded-full border ${
                  isIndividual
                    ? 'bg-sky-500/15 text-sky-400 border-sky-500/30'
                    : 'bg-emerald-500/15 text-emerald-400 border-emerald-500/30'
                }`}>
                  {isIndividual ? 'B2C' : 'B2B'}
                </span>
              </div>
            </div>
          </div>

          {/* MINIMALIST CHROME MENU: '⚡ Tahlil' • '📂 Hujjatlar' • '⚖️ Qonunlar' • '👤 Profil' */}
          <nav className="flex items-center gap-1.5 p-1 liquid-glass-subtle rounded-2xl border border-white/10">
            {/* 1. ⚡ Tahlil */}
            <button
              onClick={onReset}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                !hasAnalysis
                  ? 'bg-gradient-to-r from-sky-500 to-blue-600 text-white shadow-md shadow-sky-500/25'
                  : 'text-slate-300 hover:text-white hover:liquid-glass-accent'
              }`}
              title="Yangi shartnoma yuklash va tahlil"
            >
              <Zap className="w-3.5 h-3.5 text-amber-400 fill-amber-400" />
              <span>Tahlil</span>
            </button>

            {/* 2. 📂 Hujjatlar */}
            <button
              onClick={() => {
                if (hasAnalysis) {
                  setActiveView('diff');
                } else {
                  onReset();
                }
              }}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                hasAnalysis && activeView === 'diff'
                  ? 'bg-gradient-to-r from-sky-500 to-blue-600 text-white shadow-md shadow-sky-500/25'
                  : 'text-slate-300 hover:text-white hover:liquid-glass-accent'
              }`}
              title="Tahlil qilingan hujjatlar va Redline Diff"
            >
              <FolderOpen className="w-3.5 h-3.5 text-sky-400" />
              <span>Hujjatlar</span>
            </button>

            {/* 3. ⚖️ Qonunlar (Lex.uz Milliy Portali) */}
            <a
              href="https://lex.uz"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold text-slate-300 hover:text-white hover:liquid-glass-accent transition-all cursor-pointer"
              title="O‘zbekiston Qonunchilik ma’lumotlari milliy bazasi (Lex.uz)"
            >
              <Scale className="w-3.5 h-3.5 text-emerald-400" />
              <span>Qonunlar</span>
            </a>

            {/* 3D Sfera tugmasi (mavjud bo'lsa) */}
            {onOpen3D && (
              <button
                type="button"
                onClick={onOpen3D}
                className="hidden sm:flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-sky-300 hover:text-white hover:liquid-glass-accent text-xs font-bold transition-all cursor-pointer border border-sky-500/20"
                title="Three.js 3D Risk Sferasini ochish"
              >
                <Box className="w-3.5 h-3.5 text-sky-400 animate-pulse" />
                <span>3D</span>
              </button>
            )}
          </nav>

          {/* O'NG TOMON: '👤 Profil' & Shaxs turi (B2B / B2C) */}
          <div className="flex items-center gap-2">
            {/* Shaxs turini almashtirish (Fuqaro / Biznes) */}
            <div className="hidden sm:flex items-center p-0.5 liquid-glass-subtle rounded-xl border border-white/10 text-[11px] font-bold">
              <button
                onClick={() => switchEntityType('INDIVIDUAL')}
                className={`px-2.5 py-1 rounded-lg transition-all ${
                  isIndividual ? 'bg-sky-500 text-white shadow-sm' : 'text-slate-400 hover:text-white'
                }`}
              >
                Fuqaro
              </button>
              <button
                onClick={() => switchEntityType('LEGAL_ENTITY')}
                className={`px-2.5 py-1 rounded-lg transition-all ${
                  !isIndividual ? 'bg-emerald-500 text-white shadow-sm' : 'text-slate-400 hover:text-white'
                }`}
              >
                Biznes
              </button>
            </div>

            {/* 4. 👤 Profil (Kirish yoki Profil menyusi) */}
            {!isAuthenticated ? (
              <button
                onClick={onOpenAuth}
                className={`px-3.5 py-1.5 rounded-xl text-white text-xs font-bold shadow-lg flex items-center gap-1.5 transition-all cursor-pointer hover:scale-105 ${
                  isIndividual
                    ? 'bg-gradient-to-r from-sky-500 to-blue-600 shadow-sky-500/25'
                    : 'bg-gradient-to-r from-emerald-500 to-teal-600 shadow-emerald-500/25'
                }`}
              >
                <User className="w-3.5 h-3.5" />
                <span>Profil</span>
              </button>
            ) : (
              <div className="relative">
                <button
                  onClick={() => setShowDropdown(!showDropdown)}
                  className={`flex items-center gap-2 p-1.5 pr-2.5 rounded-2xl liquid-glass border transition-all text-left cursor-pointer ${
                    isIndividual 
                      ? 'border-sky-500/40 hover:border-sky-400' 
                      : 'border-emerald-500/40 hover:border-emerald-400'
                  }`}
                >
                  <div className={`w-7 h-7 rounded-xl flex items-center justify-center font-bold text-xs ${
                    isIndividual 
                      ? 'bg-sky-500/20 text-sky-400 border border-sky-500/30' 
                      : 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                  }`}>
                    <User className="w-3.5 h-3.5" />
                  </div>
                  <span className="text-xs font-bold text-white hidden sm:inline">
                    Profil
                  </span>
                  <ChevronDown className="w-3.5 h-3.5 text-slate-400" />
                </button>

                {/* Dropdown Menu */}
                {showDropdown && (
                  <div className="absolute right-0 mt-2 w-64 rounded-2xl liquid-glass border border-white/10 shadow-2xl p-3 z-50 animate-in fade-in zoom-in-95 duration-150">
                    <div className="p-2 border-b border-white/10 mb-2">
                      <span className="text-xs font-bold text-white block">{user?.full_name}</span>
                      <p className="text-[11px] text-slate-400 truncate">{user?.email}</p>
                      <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-white/5 text-sky-300 mt-1 inline-block">
                        {isIndividual ? 'Fuqaro (B2C)' : 'Tadbirkorlik (B2B)'}
                      </span>
                    </div>

                    <button
                      onClick={() => {
                        logout();
                        setShowDropdown(false);
                      }}
                      className="w-full py-2 px-3 rounded-xl bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 text-xs font-bold flex items-center justify-center gap-2 transition-colors cursor-pointer"
                    >
                      <LogOut className="w-3.5 h-3.5" />
                      <span>Chiqish</span>
                    </button>
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
