import React, { useState } from 'react';
import confetti from 'canvas-confetti';
import { AuthProvider } from './context/AuthContext';
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
    <div className="min-h-screen flex flex-col bg-slate-950 text-slate-100 selection:bg-brand-500 selection:text-white">
      {analysis ? (
        /* 1. KONTRAKT STUDIYASI (Robin AI / Google Docs uslubidagi haqiqiy ish maydoni) */
        <ContractStudio
          analysis={analysis}
          onReset={handleReset}
        />
      ) : (
        /* 2. BOSHLANG'ICH TOPQIR YUKLASH SAHIFASI (Clean & Minimalist Home) */
        <>
          <Navbar
            onReset={handleReset}
            activeView="dashboard"
            setActiveView={() => {}}
            hasAnalysis={false}
            onOpenAuth={() => setIsAuthModalOpen(true)}
            onOpen3D={() => setIs3DModalOpen(true)}
          />

          <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-10 flex flex-col justify-center">
            <ContractUploader
              onAnalyze={handleAnalyze}
              isLoading={isLoading}
              progress={progress}
            />
          </main>

          <Footer />
        </>
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

export default function App() {
  return (
    <AuthProvider>
      <MainApp />
    </AuthProvider>
  );
}
