import React, { useState } from 'react';
import confetti from 'canvas-confetti';
import { AuthProvider } from './context/AuthContext';
import { ThemeProvider } from './context/ThemeContext';
import { Navbar } from './components/layout/Navbar';
import { Footer } from './components/layout/Footer';
import { AuthModal } from './components/auth/AuthModal';
import { ContractUploader } from './components/upload/ContractUploader';
import { ContractStudio } from './components/studio/ContractStudio';
import { ThreeDModal } from './components/studio/ThreeDModal';
import { AnalysisResult, ProgressEvent } from './types/contract';
import { ApiService } from './services/api';
import { SAMPLE_IT_SERVICE_CONTRACT } from './data/mockContract';

function MainApp() {
  const [analysis, setAnalysis] = useState<AnalysisResult | null>(SAMPLE_IT_SERVICE_CONTRACT);
  const [activeView, setActiveView] = useState<'xulosa' | 'diff' | '3D' | 'dashboard'>('xulosa');
  const [isLoading, setIsLoading] = useState(false);
  const [progress, setProgress] = useState<ProgressEvent | null>(null);
  const [isAuthModalOpen, setIsAuthModalOpen] = useState(false);
  const [is3DModalOpen, setIs3DModalOpen] = useState(false);

  const handleAnalyze = async (file: File | null, isDemo: boolean) => {
    setIsLoading(true);
    setProgress(null);

    try {
      const result = await ApiService.analyzeDocument(
        file,
        (event) => setProgress(event),
        isDemo
      );
      setAnalysis(result);
      setActiveView('xulosa');

      // Tahlil muvaffaqiyatli tugagach bayramona animatsiya
      confetti({
        particleCount: 80,
        spread: 60,
        origin: { y: 0.7 },
        colors: ['#38BDF8', '#0284C7', '#22C55E'],
      });
    } catch (err) {
      console.error(err);
      // Fallback
      setAnalysis(SAMPLE_IT_SERVICE_CONTRACT);
      setActiveView('xulosa');
    } finally {
      setIsLoading(false);
    }
  };

  const handleLoadDemo = () => {
    setAnalysis(SAMPLE_IT_SERVICE_CONTRACT);
  };

  const handleReset = () => {
    setAnalysis(null);
    setActiveView('dashboard');
  };

  const currentAnalysis = analysis || SAMPLE_IT_SERVICE_CONTRACT;

  return (
    <div className="relative min-h-screen flex flex-col bg-[#F8FAFC] dark:bg-[#030712] text-slate-900 dark:text-slate-100 selection:bg-sky-500 selection:text-white overflow-x-hidden transition-colors duration-300">
      {/* ============================================================
          AMBIENT LIQUID GLASS LIGHTING BACKDROP (REFRACTION SOURCE)
          ============================================================ */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden z-0 opacity-70 dark:opacity-100 transition-opacity duration-300" aria-hidden="true">
        {/* Sapphire Blue Top Left Orb */}
        <div className="absolute -top-[10%] left-[10%] w-[580px] h-[580px] rounded-full bg-gradient-to-br from-sky-400/25 dark:from-sky-500/20 via-blue-500/15 dark:via-blue-600/10 to-transparent blur-[110px] liquid-orb-1" />
        
        {/* Deep Emerald Bottom Right Orb */}
        <div className="absolute top-[40%] -right-[5%] w-[620px] h-[620px] rounded-full bg-gradient-to-bl from-emerald-400/20 dark:from-emerald-500/15 via-teal-500/15 dark:via-teal-600/10 to-transparent blur-[120px] liquid-orb-2" />
        
        {/* Electric Indigo Center/Bottom Orb */}
        <div className="absolute -bottom-[15%] left-[25%] w-[700px] h-[700px] rounded-full bg-gradient-to-tr from-indigo-400/20 dark:from-indigo-500/15 via-violet-500/10 dark:via-violet-600/08 to-transparent blur-[130px] liquid-orb-3" />
        
        {/* Cyan Ambient Accent Spot */}
        <div className="absolute top-[20%] right-[30%] w-[380px] h-[380px] rounded-full bg-cyan-400/15 dark:bg-cyan-400/10 blur-[90px] liquid-orb-1" />
      </div>

      {/* Floating Stadium Capsule Navbar (Minimalist Single-Word Labels: Fuqaro, Biznes, Xulosa, 3D, Diff, Kirish) */}
      <Navbar
        onReset={handleReset}
        activeView={activeView}
        setActiveView={(view) => {
          if (view === '3D') {
            setIs3DModalOpen(true);
            return;
          }
          if (!analysis) {
            setAnalysis(SAMPLE_IT_SERVICE_CONTRACT);
          }
          setActiveView(view);
        }}
        hasAnalysis={!!analysis}
        onOpenAuth={() => setIsAuthModalOpen(true)}
        onOpen3D={() => setIs3DModalOpen(true)}
        onLoadDemo={handleLoadDemo}
      />

      {/* Main Content Area */}
      <div className="relative z-10 flex-1 flex flex-col pt-20">
        {analysis || activeView === 'xulosa' || activeView === 'diff' ? (
          /* 1. KONTRAKT STUDIYASI (Robin AI / Google Docs uslubidagi haqiqiy ish maydoni) */
          <div className="flex-1 flex flex-col">
            <ContractStudio
              analysis={currentAnalysis}
              onReset={handleReset}
              initialView={activeView === 'diff' ? 'diff' : 'reader'}
            />
          </div>
        ) : (
          /* 2. BOSHLANG'ICH TOPQIR YUKLASH SAHIFASI (Liquid Glass Home) */
          <div className="flex-1 flex flex-col">
            <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-8 flex flex-col justify-center">
              <ContractUploader
                onAnalyze={handleAnalyze}
                isLoading={isLoading}
                progress={progress}
              />
            </main>

            <Footer />
          </div>
        )}
      </div>

      {/* Auth Modal (Kirish / Ro'yxatdan o'tish) */}
      <AuthModal
        isOpen={isAuthModalOpen}
        onClose={() => setIsAuthModalOpen(false)}
      />

      {/* Standalone 3D Modal (3D Lex.uz GLTF, Muvozanat Tarozisi, Sfera) */}
      <ThreeDModal
        isOpen={is3DModalOpen}
        onClose={() => setIs3DModalOpen(false)}
        analysis={currentAnalysis}
        onSelectClause={() => {}}
      />
    </div>
  );
}

export function App() {
  return (
    <ThemeProvider>
      <AuthProvider>
        <MainApp />
      </AuthProvider>
    </ThemeProvider>
  );
}

export default App;
