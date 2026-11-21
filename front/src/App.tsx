import React, { useState } from 'react';
import confetti from 'canvas-confetti';
import { Navbar } from './components/layout/Navbar';
import { Footer } from './components/layout/Footer';
import { ContractUploader } from './components/upload/ContractUploader';
import { ExecutiveSummary } from './components/dashboard/ExecutiveSummary';
import { Contract3DVisualizer } from './components/visualizer/Contract3DVisualizer';
import { SideBySideDiffViewer } from './components/diff/SideBySideDiffViewer';
import { AnalysisResult, ProgressEvent } from './types/contract';
import { ApiService } from './services/api';
import { SAMPLE_IT_SERVICE_CONTRACT } from './data/mockContract';

export default function App() {
  const [analysis, setAnalysis] = useState<AnalysisResult | null>(null);
  const [activeView, setActiveView] = useState<'dashboard' | 'diff' | 'visualizer3d'>('dashboard');
  const [isLoading, setIsLoading] = useState(false);
  const [progress, setProgress] = useState<ProgressEvent | null>(null);
  const [focusedClauseId, setFocusedClauseId] = useState<string | null>(null);

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
      setActiveView('dashboard');

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
    setActiveView('dashboard');
    setFocusedClauseId(null);
  };

  const handleSelectClauseFrom3D = (clauseId: string) => {
    setFocusedClauseId(clauseId);
    setActiveView('diff');
  };

  return (
    <div className="min-h-screen flex flex-col bg-slate-950 text-slate-100">
      <Navbar
        onReset={handleReset}
        activeView={activeView}
        setActiveView={setActiveView}
        hasAnalysis={!!analysis}
      />

      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {!analysis ? (
          <ContractUploader
            onAnalyze={handleAnalyze}
            isLoading={isLoading}
            progress={progress}
          />
        ) : (
          <div className="space-y-8 animate-in fade-in duration-300">
            {activeView === 'dashboard' && (
              <ExecutiveSummary
                analysis={analysis}
                onOpen3D={() => setActiveView('visualizer3d')}
                onOpenDiff={() => setActiveView('diff')}
                onSelectClause={handleSelectClauseFrom3D}
              />
            )}

            {activeView === 'visualizer3d' && (
              <div className="space-y-4">
                <Contract3DVisualizer
                  analysis={analysis}
                  selectedClauseId={focusedClauseId}
                  onSelectClause={handleSelectClauseFrom3D}
                />
              </div>
            )}

            {activeView === 'diff' && (
              <SideBySideDiffViewer
                analysis={analysis}
                focusedClauseId={focusedClauseId}
              />
            )}
          </div>
        )}
      </main>

      <Footer />
    </div>
  );
}
