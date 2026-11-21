import React, { useState } from 'react';
import confetti from 'canvas-confetti';
import { AuthProvider, useAuth } from './context/AuthContext';
import { ThemeProvider } from './context/ThemeContext';
import { Navbar, MainNavTab } from './components/layout/Navbar';
import { Footer } from './components/layout/Footer';
import { AuthModal } from './components/auth/AuthModal';
import { LandingView } from './components/landing/LandingView';
import { HomeDashboard } from './components/dashboard/HomeDashboard';
import { ContractStudio } from './components/studio/ContractStudio';
import { ThreeDModal } from './components/studio/ThreeDModal';
import { DocumentsView } from './components/documents/DocumentsView';
import { LawsView } from './components/laws/LawsView';
import { AIChatView } from './components/ai/AIChatView';
import { ProfileView } from './components/profile/ProfileView';
import { ScanUploadModal } from './components/upload/ScanUploadModal';
import { AnalysisResult, ProgressEvent } from './types/contract';
import { ApiService } from './services/api';
import { SAMPLE_IT_SERVICE_CONTRACT } from './data/mockContract';
import { SampleContract } from './data/sampleContracts';
import { Alert, AlertDescription } from './components/ui/alert';
import { Button } from './components/ui/button';

function MainApp() {
  const { isAuthenticated, user } = useAuth();
  const [analysis, setAnalysis] = useState<AnalysisResult | null>(null);
  const [activeTab, setActiveTab] = useState<MainNavTab>('home');
  const [studioSubView, setStudioSubView] = useState<'xulosa' | 'diff'>('xulosa');
  const [segment, setSegment] = useState<'b2c' | 'b2b'>('b2b');
  const [isLoading, setIsLoading] = useState(false);
  const [progress, setProgress] = useState<ProgressEvent | null>(null);
  const [isAuthModalOpen, setIsAuthModalOpen] = useState(false);
  const [isScanModalOpen, setIsScanModalOpen] = useState(false);
  const [is3DModalOpen, setIs3DModalOpen] = useState(false);
  const [appliedCount, setAppliedCount] = useState(0);
  const [analyzeError, setAnalyzeError] = useState<string | null>(null);

  const handleAnalyze = async (file: File | null, isDemo: boolean, sampleId?: SampleContract['id']): Promise<boolean> => {
    setIsLoading(true);
    setProgress(null);
    setAnalyzeError(null);

    try {
      const result = await ApiService.analyzeDocument(
        file,
        (event) => setProgress(event),
        isDemo,
        sampleId
      );
      setAnalysis(result);
      setActiveTab('home');

      confetti({
        particleCount: 80,
        spread: 60,
        origin: { y: 0.7 },
        colors: ['#FAFAFA', '#A3A3A3', '#22C55E'],
      });
      return true;
    } catch (err) {
      console.error(err);
      setAnalyzeError(err instanceof Error ? err.message : 'Tahlil bajarilmadi. Qayta urinib ko‘ring.');
      return false;
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
    <div className="relative min-h-screen flex flex-col text-foreground selection:bg-foreground selection:text-background overflow-x-hidden transition-colors duration-300">
      {/* Sokin Ambient Orblar */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden z-0 opacity-20 dark:opacity-30 transition-opacity duration-300" aria-hidden="true">
        <div className="absolute -top-[10%] left-[15%] w-[600px] h-[600px] rounded-full bg-foreground/10 blur-[140px]" />
        <div className="absolute top-[40%] -right-[5%] w-[500px] h-[500px] rounded-full bg-foreground/5 blur-[140px]" />
      </div>

      {/* Floating Shadcn Navbar (Mehmon holatida Landing links + Kirish; Kirilganda Asosiy, Hujjatlar, Qonunlar, Profil) */}
      <Navbar
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        onOpenScan={() => setIsScanModalOpen(true)}
        onOpenAuth={() => setIsAuthModalOpen(true)}
        segment={segment}
        onSegmentChange={setSegment}
        hasAnalysis={!!analysis}
      />

      {analyzeError && !isScanModalOpen && (
        <div className="fixed inset-x-0 top-20 z-40 mx-auto w-[calc(100%-2rem)] max-w-xl">
          <Alert variant="destructive" role="alert" className="bg-background shadow-lg">
            <AlertDescription className="flex items-center justify-between gap-3">
              <span>{analyzeError}</span>
              <Button type="button" size="sm" variant="outline" onClick={() => setAnalyzeError(null)}>
                Yopish
              </Button>
            </AlertDescription>
          </Alert>
        </div>
      )}

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
          ) : isAuthenticated ? (
            <div className="flex-1 flex flex-col">
              <main className="flex-1 w-full pb-12">
                <HomeDashboard
                  currentAnalysis={currentAnalysis}
                  onOpenContract={(c) => {
                    setAnalysis(c);
                    setActiveTab('home');
                  }}
                  onOpenScan={() => setIsScanModalOpen(true)}
                  onAnalyzeDemo={() => handleAnalyze(null, true)}
                  onAnalyzeFile={(file) => handleAnalyze(file, false)}
                  isLoading={isLoading}
                  progress={progress}
                  onGoToDocuments={() => setActiveTab('documents')}
                  onGoToLaws={() => setActiveTab('laws')}
                />
              </main>
              <Footer />
            </div>
          ) : (
            <div className="flex-1 flex flex-col">
              <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-4 sm:py-8 flex flex-col justify-center">
                <LandingView
                  onAnalyze={handleAnalyze}
                  isLoading={isLoading}
                  progress={progress}
                  onOpenAuth={() => setIsAuthModalOpen(true)}
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

        {activeTab === 'ai' && (
          <AIChatView onRequireAuth={() => setIsAuthModalOpen(true)} />
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
        error={analyzeError}
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
