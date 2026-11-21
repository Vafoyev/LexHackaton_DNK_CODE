import React, { useState } from 'react';
import confetti from 'canvas-confetti';
import { AuthProvider } from './context/AuthContext';
import { ThemeProvider } from './context/ThemeContext';
import { Navbar, MainNavTab } from './components/layout/Navbar';
import { Footer } from './components/layout/Footer';
import { AuthModal } from './components/auth/AuthModal';
import { ContractUploader } from './components/upload/ContractUploader';
import { ContractStudio } from './components/studio/ContractStudio';
import { ThreeDModal } from './components/studio/ThreeDModal';
import { DocumentsView } from './components/documents/DocumentsView';
import { LawsView } from './components/laws/LawsView';
import { ProfileView } from './components/profile/ProfileView';
import { ScanUploadModal } from './components/upload/ScanUploadModal';
import { AnalysisResult, ProgressEvent } from './types/contract';
import { ApiService } from './services/api';
import { SAMPLE_IT_SERVICE_CONTRACT } from './data/mockContract';

function MainApp() {
  const [analysis, setAnalysis] = useState<AnalysisResult | null>(SAMPLE_IT_SERVICE_CONTRACT);
  const [activeTab, setActiveTab] = useState<MainNavTab>('home');
  const [studioSubView, setStudioSubView] = useState<'xulosa' | 'diff'>('xulosa');
  const [segment, setSegment] = useState<'b2c' | 'b2b'>('b2b');
  const [isLoading, setIsLoading] = useState(false);
  const [progress, setProgress] = useState<ProgressEvent | null>(null);
  const [isAuthModalOpen, setIsAuthModalOpen] = useState(false);
  const [isScanModalOpen, setIsScanModalOpen] = useState(false);
  const [is3DModalOpen, setIs3DModalOpen] = useState(false);
  const [appliedCount, setAppliedCount] = useState(0);

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
      setActiveTab('home');

      confetti({
        particleCount: 80,
        spread: 60,
        origin: { y: 0.7 },
        colors: ['#38BDF8', '#0284C7', '#22C55E'],
      });
    } catch (err) {
      console.error(err);
      setAnalysis(SAMPLE_IT_SERVICE_CONTRACT);
      setActiveTab('home');
    } finally {
      setIsLoading(false);
    }
  };

  const handleReset = () => {
    setAnalysis(null);
    setActiveTab('home');
  };

  const currentAnalysis = analysis || SAMPLE_IT_SERVICE_CONTRACT;

  return (
    <div className="relative min-h-screen flex flex-col bg-[#F8FAFC] dark:bg-[#030712] text-slate-900 dark:text-slate-100 selection:bg-sky-500 selection:text-white overflow-x-hidden transition-colors duration-300">
      {/* Sokin Ambient Orblar */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden z-0 opacity-20 dark:opacity-30 transition-opacity duration-300" aria-hidden="true">
        <div className="absolute -top-[10%] left-[15%] w-[600px] h-[600px] rounded-full bg-sky-500/10 blur-[140px]" />
        <div className="absolute top-[40%] -right-[5%] w-[500px] h-[500px] rounded-full bg-teal-500/10 blur-[140px]" />
      </div>

      {/* Floating Shadcn Navbar (Mobildagidek: Asosiy, Hujjatlar, Qonunlar, Profil, Skanerlash) */}
      <Navbar
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        onOpenScan={() => setIsScanModalOpen(true)}
        onOpenAuth={() => setIsAuthModalOpen(true)}
        segment={segment}
        onSegmentChange={setSegment}
      />

      {/* Main Content Area */}
      <div className="relative z-10 flex-1 flex flex-col pt-20">
        {activeTab === 'home' && (
          analysis ? (
            <div className="flex-1 flex flex-col">
              <ContractStudio
                analysis={currentAnalysis}
                onReset={handleReset}
                initialView={studioSubView === 'diff' ? 'diff' : 'reader'}
                onAppliedCountChange={setAppliedCount}
              />
            </div>
          ) : (
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
          )
        )}

        {activeTab === 'documents' && (
          <DocumentsView
            currentAnalysis={currentAnalysis}
            onOpenContract={(c) => {
              setAnalysis(c);
              setActiveTab('home');
            }}
            onOpenScan={() => setIsScanModalOpen(true)}
          />
        )}

        {activeTab === 'laws' && (
          <LawsView />
        )}

        {activeTab === 'profile' && (
          <ProfileView
            segment={segment}
            onSegmentChange={setSegment}
            onOpenScan={() => setIsScanModalOpen(true)}
          />
        )}
      </div>

      {/* Global Skanerlash Modal */}
      <ScanUploadModal
        isOpen={isScanModalOpen}
        onClose={() => setIsScanModalOpen(false)}
        onAnalyze={handleAnalyze}
        isLoading={isLoading}
        progress={progress}
      />

      {/* Auth Modal (ONE ID / Kirish) */}
      <AuthModal
        isOpen={isAuthModalOpen}
        onClose={() => setIsAuthModalOpen(false)}
      />

      {/* Standalone 3D Modal */}
      <ThreeDModal
        isOpen={is3DModalOpen}
        onClose={() => setIs3DModalOpen(false)}
        analysis={currentAnalysis}
        onSelectClause={() => {}}
      />
    </div>
  );
}

export default function App() {
  return (
    <ThemeProvider>
      <AuthProvider>
        <MainApp />
      </AuthProvider>
    </ThemeProvider>
  );
}
