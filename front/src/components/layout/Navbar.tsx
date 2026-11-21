import React from 'react';
import { BookOpen, FileText, Home, LogIn, LogOut, Moon, QrCode, Sparkles, Sun, User } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { useTheme } from '../../context/ThemeContext';
import { Button } from '../ui/button';
import { Tabs, TabsList, TabsTrigger } from '../ui/tabs';
import { Tooltip, TooltipContent, TooltipTrigger } from '../ui/tooltip';

export type MainNavTab = 'home' | 'documents' | 'laws' | 'ai' | 'profile';

const TABS: { id: MainNavTab; label: string; icon: React.ElementType; color: string; hint?: string }[] = [
  { id: 'home', label: 'Asosiy', icon: Home, color: 'text-zinc-500' },
  { id: 'documents', label: 'Hujjatlar', icon: FileText, color: 'text-zinc-500' },
  { id: 'laws', label: 'Qonunlar', icon: BookOpen, color: 'text-emerald-500' },
  { id: 'ai', label: 'AI', icon: Sparkles, color: 'text-zinc-500', hint: 'AI yordamchi (chat va ovozli)' },
  { id: 'profile', label: 'Profil', icon: User, color: 'text-zinc-500' },
];

const LANDING_LINKS = [
  { id: 'muammolar', label: 'Loyiha nima uchun?' },
  { id: 'afzalliklar', label: 'Yengilliklari' },
  { id: 'sinash', label: 'Qanday ishlaydi?' },
];

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

export const Navbar: React.FC<NavbarProps> = ({ activeTab, setActiveTab, onOpenScan, onOpenAuth, hasAnalysis = false }) => {
  const { isAuthenticated, logout } = useAuth();
  const { isDark, toggleTheme } = useTheme();

  const scrollTo = (id: string) => {
    setActiveTab('home');
    setTimeout(() => document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' }), 50);
  };

  const signedIn = isAuthenticated || hasAnalysis;

  return (
    <header className="fixed left-1/2 top-2 z-50 w-[96%] max-w-7xl -translate-x-1/2 sm:top-3">
      <div className="glass rounded-2xl px-3 py-2 sm:px-6">
        <div className="flex items-center justify-between gap-2 sm:gap-4">
          {/* Brend */}
          <Button
            variant="ghost"
            onClick={() => setActiveTab('home')}
            className="hidden h-auto shrink-0 gap-2 p-1 text-left hover:bg-transparent sm:flex"
            aria-label="Bosh sahifa"
          >
            <span className="flex h-9 items-center justify-center rounded-lg border border-slate-800 bg-slate-950 px-1.5 shadow-sm">
              <img src="/lex_uz.svg" alt="" aria-hidden="true" className="h-4 w-auto object-contain brightness-125" />
            </span>
            <span className="flex flex-col">
              <span className="text-lg font-bold leading-none tracking-tight">
                LexGuard<span className="text-zinc-500">.AI</span>
              </span>
              <span className="text-[10px] font-medium text-muted-foreground">Lex.uz sinxron</span>
            </span>
          </Button>

          {/* Markaziy navigatsiya */}
          {signedIn ? (
            <nav aria-label="Asosiy navigatsiya" className="min-w-0">
              <Tabs value={activeTab} onValueChange={(v) => setActiveTab(v as MainNavTab)}>
                <TabsList className="h-auto max-w-full overflow-x-auto p-1 [scrollbar-width:none]">
                  {TABS.map(({ id, label, icon: Icon, color, hint }) => (
                    <Tooltip key={id}>
                      <TooltipTrigger asChild>
                        <TabsTrigger value={id} aria-label={label} className="shrink-0 gap-1.5 px-2 text-xs sm:px-4 sm:text-sm">
                          <Icon className={`h-4 w-4 ${color}`} aria-hidden="true" />
                          {/* Mobilda (<640px) faqat ikonka: 5 ta tab 375px ga sig'ishi uchun */}
                          <span className="hidden sm:inline">{label}</span>
                        </TabsTrigger>
                      </TooltipTrigger>
                      <TooltipContent className="sm:hidden">{hint || label}</TooltipContent>
                    </Tooltip>
                  ))}
                </TabsList>
              </Tabs>
            </nav>
          ) : (
            <nav aria-label="Sahifa bo‘limlari" className="hidden items-center gap-1 lg:flex">
              {LANDING_LINKS.map((l) => (
                <Button key={l.id} variant="ghost" size="sm" onClick={() => scrollTo(l.id)} className="text-muted-foreground">
                  {l.label}
                </Button>
              ))}
            </nav>
          )}

          {/* Amallar */}
          <div className="flex items-center gap-2 sm:gap-3">
            {signedIn ? (
              <Button onClick={onOpenScan} size="sm" className="gap-1.5 font-semibold" aria-label="Skanerlash">
                <QrCode className="h-4 w-4" aria-hidden="true" />
                <span className="hidden sm:inline">Skanerlash</span>
              </Button>
            ) : (
              <Button onClick={onOpenAuth} size="sm" className="gap-1.5 font-semibold">
                <LogIn className="h-4 w-4" aria-hidden="true" />
                <span>Kirish (OneID / E-IMZO)</span>
              </Button>
            )}

            <Button
              variant="outline"
              size="icon"
              onClick={toggleTheme}
              className="h-8 w-8"
              aria-label={isDark ? 'Kunduzgi rejim' : 'Tungi rejim'}
              title={isDark ? 'Kunduzgi rejim' : 'Tungi rejim'}
            >
              {isDark ? <Sun className="h-4 w-4 text-amber-400" aria-hidden="true" /> : <Moon className="h-4 w-4" aria-hidden="true" />}
            </Button>

            {isAuthenticated && (
              <Button variant="ghost" size="sm" onClick={logout} className="gap-1.5 text-xs text-destructive hover:text-destructive" aria-label="Chiqish">
                <LogOut className="h-3.5 w-3.5" aria-hidden="true" />
                <span className="hidden sm:inline">Chiqish</span>
              </Button>
            )}
          </div>
        </div>
      </div>
    </header>
  );
};
