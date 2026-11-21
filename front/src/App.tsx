import React, { useState } from 'react';
import confetti from 'canvas-confetti';
import { Navbar } from './components/layout/Navbar';
import { Footer } from './components/layout/Footer';
import { AuthModal } from './components/auth/AuthModal';
import { ContractUploader } from './components/upload/ContractUploader';
import { ContractStudio } from './components/studio/ContractStudio';
import { ThreeDModal } from './components/studio/ThreeDModal';
import { AnalysisResult, ProgressEvent } from './types/contract';
import { ApiService } from './services/api';
import { SAMPLE_IT_SERVICE_CONTRACT } from './data/mockContract';

export function MainApp() {
  const [analysis, setAnalysis] = useState<AnalysisResult | null>(null);
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
    } finally {
      setIsLoading(false);
    }
  };

  const handleReset = () => {
    setAnalysis(null);
  };

  return (
    <div className="relative min-h-screen flex flex-col bg-[#030712] text-slate-100 selection:bg-sky-500 selection:text-white overflow-x-hidden">
      {/* ============================================================
          AMBIENT LIQUID GLASS LIGHTING BACKDROP (REFRACTION SOURCE)
          ============================================================ */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden z-0" aria-hidden="true">
        {/* Sapphire Blue Top Left Orb */}
        <div className="absolute -top-[10%] left-[10%] w-[580px] h-[580px] rounded-full bg-gradient-to-br from-sky-500/20 via-blue-600/10 to-transparent blur-[110px] liquid-orb-1" />
        
        {/* Deep Emerald Bottom Right Orb */}
        <div className="absolute top-[40%] -right-[5%] w-[620px] h-[620px] rounded-full bg-gradient-to-bl from-emerald-500/15 via-teal-600/10 to-transparent blur-[120px] liquid-orb-2" />
        
        {/* Electric Indigo Center/Bottom Orb */}
        <div className="absolute -bottom-[15%] left-[25%] w-[700px] h-[700px] rounded-full bg-gradient-to-tr from-indigo-500/15 via-violet-600/08 to-transparent blur-[130px] liquid-orb-3" />
        
        {/* Cyan Ambient Accent Spot */}
        <div className="absolute top-[20%] right-[30%] w-[380px] h-[380px] rounded-full bg-cyan-400/10 blur-[90px] liquid-orb-1" />
      </div>

      {analysis ? (
        /* 1. KONTRAKT STUDIYASI (Robin AI / Google Docs uslubidagi haqiqiy ish maydoni) */
        <div className="relative z-10 flex-1 flex flex-col">
          <ContractStudio
            analysis={analysis}
            onReset={handleReset}
          />
        </div>
      ) : (
        /* 2. BOSHLANG'ICH TOPQIR YUKLASH SAHIFASI (Liquid Glass Home) */
        <div className="relative z-10 flex-1 flex flex-col">
          {/* Floating Stadium Capsule Navbar */}
          <Navbar
            onReset={handleReset}
            activeView="dashboard"
            setActiveView={() => {}}
            hasAnalysis={false}
            onOpenAuth={() => setIsAuthModalOpen(true)}
            onOpen3D={() => setIs3DModalOpen(true)}
          />

          <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 pt-28 pb-12 flex flex-col justify-center">
            <ContractUploader
              onAnalyze={handleAnalyze}
              isLoading={isLoading}
              progress={progress}
            />
          </main>

          <Footer />
        </div>
      )}

      {/* Auth Modal (Kirish / Ro'yxatdan o'tish) */}
      <AuthModal
        isOpen={isAuthModalOpen}
        onClose={() => setIsAuthModalOpen(false)}
      />

      {/* Standalone 3D Modal (3D Lex.uz GLTF, Muvozanat Tarozisi, Sfera) */}
      <ThreeDModal
        isOpen={is3DModalOpen}
        onClose={() => setIs3DModalOpen(false)}
        analysis={analysis || SAMPLE_IT_SERVICE_CONTRACT}
        onSelectClause={() => {}}
      />
    </div>
  );
}

export default MainApp;
