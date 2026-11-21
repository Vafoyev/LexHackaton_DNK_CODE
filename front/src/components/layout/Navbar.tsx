import React from 'react';
import { 
  LogIn, 
  LogOut, 
  Sun, 
  Moon, 
  FileText, 
  BookOpen, 
  User, 
  Home, 
  QrCode,
  Sparkles,
  ShieldCheck,
  ChevronRight
} from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { useTheme } from '../../context/ThemeContext';
import { Button } from '../ui/button';

export type MainNavTab = 'home' | 'documents' | 'laws' | 'profile';

export interface NavbarProps {
  activeTab: MainNavTab;
  setActiveTab: (tab: MainNavTab) => void;
  onOpenScan: () => void;
  onOpenAuth: () => void;
  segment: 'b2c' | 'b2b';
  onSegmentChange: (segment: 'b2c' | 'b2b') => void;
  onScrollToSection?: (sectionId: string) => void;
  hasAnalysis?: boolean;
}

export const Navbar: React.FC<NavbarProps> = ({
  activeTab,
  setActiveTab,
  onOpenScan,
  onOpenAuth,
  segment,
  onSegmentChange,
  hasAnalysis = false,
}) => {
  const { user, isAuthenticated, logout } = useAuth();
  const { isDark, toggleTheme } = useTheme();

  const isB2B = segment === 'b2b';

  const scrollTo = (id: string) => {
    setActiveTab('home');
    setTimeout(() => {
      const el = document.getElementById(id);
      if (el) {
        el.scrollIntoView({ behavior: 'smooth' });
      }
    }, 50);
  };

  return (
    <header className="fixed top-2 sm:top-3 left-1/2 -translate-x-1/2 z-50 w-[96%] max-w-7xl transition-all duration-300">
      <div className="rounded-2xl border border-slate-200/80 dark:border-slate-800/80 bg-white/95 dark:bg-slate-900/95 shadow-lg backdrop-blur-xl px-3 sm:px-6 py-2 transition-all duration-300">
        <div className="flex items-center justify-between gap-2 sm:gap-4">
          
          {/* 1. Brand Logo + Segment Switcher */}
          <div className="flex items-center gap-3 sm:gap-4 shrink-0">
            <button 
              onClick={() => setActiveTab('home')}
              className="flex items-center gap-2 group text-left cursor-pointer"
              title="Bosh sahifa"
            >
              <div className="h-8 sm:h-9 px-1.5 rounded-lg bg-slate-950 flex items-center justify-center border border-slate-800 shadow-sm">
                <img src="/lex_uz.svg" alt="" aria-hidden="true" className="h-4 sm:h-4.5 w-auto object-contain brightness-125" />
              </div>
              <div className="flex flex-col">
                <span className="text-base sm:text-lg font-bold tracking-tight text-slate-900 dark:text-white leading-none">
                  LexGuard<span className={isB2B ? "text-emerald-500" : "text-sky-500"}>.AI</span>
                </span>
                <span className="text-[10px] text-slate-400 font-medium">Lex.uz Sinxron</span>
              </div>
            </button>

            {/* B2C / B2B Segment Pill */}
            <div className="hidden md:flex items-center rounded-lg bg-slate-100 dark:bg-slate-800/80 p-0.5 border border-slate-200 dark:border-slate-700/60 text-xs font-semibold">
              <button
                type="button"
                onClick={() => onSegmentChange('b2c')}
                className={`px-3 py-1 rounded-md transition-all cursor-pointer ${
                  !isB2B
                    ? 'bg-white dark:bg-slate-900 text-sky-600 dark:text-sky-400 shadow-xs'
                    : 'text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
                }`}
              >
                Fuqaro
              </button>
              <button
                type="button"
                onClick={() => onSegmentChange('b2b')}
                className={`px-3 py-1 rounded-md transition-all cursor-pointer ${
                  isB2B
                    ? 'bg-white dark:bg-slate-900 text-emerald-600 dark:text-emerald-400 shadow-xs'
                    : 'text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
                }`}
              >
                Biznes
              </button>
            </div>
          </div>

          {/* 2. CENTER NAVIGATION: 
              A) Agar foydalanuvchi tizimga kirgan bo'lsa yoki shartnoma ochilgan bo'lsa -> Ish maydoni tablari (Asosiy, Hujjatlar, Qonunlar, Profil)
              B) Agar LOGIN QILMAGAN bo'lsa -> Faqat Landing bo'limlari (Loyiha haqida, Yengilliklari, Sinash)
          */}
          {isAuthenticated || hasAnalysis ? (
            /* ================= AUTENTIFIKATSIYADAN O'TGAN REJIM ================= */
            <nav className="flex items-center gap-1 sm:gap-1.5 p-1 rounded-xl bg-slate-100/80 dark:bg-slate-800/60 border border-slate-200/60 dark:border-slate-700/40">
              <button
                onClick={() => setActiveTab('home')}
                className={`flex items-center gap-1.5 px-3 sm:px-4 py-1.5 rounded-lg text-xs sm:text-sm font-semibold transition-all cursor-pointer ${
                  activeTab === 'home'
                    ? 'bg-white dark:bg-slate-900 text-slate-900 dark:text-white shadow-xs'
                    : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'
                }`}
              >
                <Home className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-sky-500" />
                <span>Asosiy</span>
              </button>

              <button
                onClick={() => setActiveTab('documents')}
                className={`flex items-center gap-1.5 px-3 sm:px-4 py-1.5 rounded-lg text-xs sm:text-sm font-semibold transition-all cursor-pointer ${
                  activeTab === 'documents'
                    ? 'bg-white dark:bg-slate-900 text-slate-900 dark:text-white shadow-xs'
                    : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'
                }`}
              >
                <FileText className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-blue-500" />
                <span>Hujjatlar</span>
              </button>

              <button
                onClick={() => setActiveTab('laws')}
                className={`flex items-center gap-1.5 px-3 sm:px-4 py-1.5 rounded-lg text-xs sm:text-sm font-semibold transition-all cursor-pointer ${
                  activeTab === 'laws'
                    ? 'bg-white dark:bg-slate-900 text-slate-900 dark:text-white shadow-xs'
                    : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'
                }`}
              >
                <BookOpen className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-emerald-500" />
                <span>Qonunlar</span>
              </button>

              <button
                onClick={() => setActiveTab('profile')}
                className={`flex items-center gap-1.5 px-3 sm:px-4 py-1.5 rounded-lg text-xs sm:text-sm font-semibold transition-all cursor-pointer ${
                  activeTab === 'profile'
                    ? 'bg-white dark:bg-slate-900 text-slate-900 dark:text-white shadow-xs'
                    : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'
                }`}
              >
                <User className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-indigo-500" />
                <span>Profil</span>
              </button>
            </nav>
          ) : (
            /* ================= LOGIN QILMAGAN / MEHMON REJIMI (LANDING NAV) ================= */
            <nav className="hidden lg:flex items-center gap-1 sm:gap-2">
              <button
                onClick={() => scrollTo('muammolar')}
                className="px-3.5 py-1.5 rounded-lg text-xs sm:text-sm font-medium text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800 transition-all cursor-pointer"
              >
                Loyiha Nima Uchun?
              </button>
              <button
                onClick={() => scrollTo('afzalliklar')}
                className="px-3.5 py-1.5 rounded-lg text-xs sm:text-sm font-medium text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800 transition-all cursor-pointer"
              >
                Yengilliklari
              </button>
              <button
                onClick={() => scrollTo('sinash')}
                className="px-3.5 py-1.5 rounded-lg text-xs sm:text-sm font-medium text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800 transition-all cursor-pointer"
              >
                Qanday Ishlaydi?
              </button>
            </nav>
          )}

          {/* 3. Action Area */}
          <div className="flex items-center gap-2 sm:gap-3">
            {isAuthenticated || hasAnalysis ? (
              /* Kirilgan holatda -> Skanerlash */
              <Button
                onClick={onOpenScan}
                size="sm"
                className={`gap-1.5 font-bold shadow-xs cursor-pointer ${
                  isB2B
                    ? 'bg-emerald-600 hover:bg-emerald-700 text-white'
                    : 'bg-sky-600 hover:bg-sky-700 text-white'
                }`}
              >
                <QrCode className="w-4 h-4" />
                <span>Skanerlash</span>
              </Button>
            ) : (
              /* Login qilinmagan holatda -> Bosh Kirish (OneID / E-IMZO) Tugmasi */
              <Button
                onClick={onOpenAuth}
                size="sm"
                className={`gap-1.5 font-bold shadow-sm transition-all cursor-pointer ${
                  isB2B
                    ? 'bg-emerald-600 hover:bg-emerald-700 text-white'
                    : 'bg-sky-600 hover:bg-sky-700 text-white'
                }`}
              >
                <LogIn className="w-4 h-4" />
                <span>Kirish (OneID / E-IMZO)</span>
              </Button>
            )}

            {/* Theme Toggle (Sun/Moon) */}
            <Button
              variant="outline"
              size="icon"
              onClick={toggleTheme}
              className="h-8 w-8 rounded-lg cursor-pointer"
              title={isDark ? "Kunduzgi rejim" : "Tungi rejim"}
            >
              {isDark ? (
                <Sun className="h-4 w-4 text-amber-400" />
              ) : (
                <Moon className="h-4 w-4 text-slate-700" />
              )}
            </Button>

            {/* Profil / Chiqish (Faqat tizimga kirilgan bo'lsa) */}
            {isAuthenticated && (
              <Button
                variant="ghost"
                size="sm"
                onClick={logout}
                className="gap-1.5 text-xs text-red-600 dark:text-red-400 cursor-pointer"
                title="Tizimdan chiqish"
              >
                <LogOut className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">Chiqish</span>
              </Button>
            )}
          </div>

        </div>
      </div>
    </header>
  );
};
