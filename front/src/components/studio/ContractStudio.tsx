import React, { useState, useEffect } from 'react';
import { AnalysisResult, ContractClause } from '../../types/contract';
import { DocumentPaper } from './DocumentPaper';
import { ClauseInspector } from './ClauseInspector';
import { ThreeDModal } from './ThreeDModal';
import { SideBySideDiffViewer } from '../diff/SideBySideDiffViewer';
import { LiveVoiceAssistant } from '../voice/LiveVoiceAssistant';
import { Sparkles, Check } from 'lucide-react';

interface ContractStudioProps {
  analysis: AnalysisResult;
  onReset: () => void;
  initialView?: 'reader' | 'diff';
  onAppliedCountChange?: (count: number) => void;
}

export const ContractStudio: React.FC<ContractStudioProps> = ({
  analysis,
  onReset,
  initialView = 'reader',
  onAppliedCountChange,
}) => {
  const [activeView, setActiveView] = useState<'reader' | 'diff'>(initialView);

  useEffect(() => {
    if (initialView) {
      setActiveView(initialView);
    }
  }, [initialView]);

  const [selectedClauseId, setSelectedClauseId] = useState<string | null>(() => {
    // Dastlab birinchi qizil yoki sariq xavfli bandni avtomatik tanlash
    const firstRisky = analysis.clauses.find((c) => c.risk_level === 'RED' || c.risk_level === 'YELLOW');
    return firstRisky ? firstRisky.id : analysis.clauses[0]?.id || null;
  });

  const [appliedFixes, setAppliedFixes] = useState<Record<string, string>>({});
  const [is3DModalOpen, setIs3DModalOpen] = useState(false);
  const [showVoiceBar, setShowVoiceBar] = useState(false);

  const selectedClause = analysis.clauses.find((c) => c.id === selectedClauseId) || null;

  // 1-Click Fix (Qabul qilish) funksiyasi
  const handleApplyFix = (clauseId: string, fixedText: string) => {
    setAppliedFixes((prev) => ({
      ...prev,
      [clauseId]: fixedText,
    }));
  };

  // Rad etish / Bekor qilish funksiyasi
  const handleRejectFix = (clauseId: string) => {
    setAppliedFixes((prev) => {
      const next = { ...prev };
      delete next[clauseId];
      return next;
    });
  };

  const fixedCount = Object.keys(appliedFixes).length;

  useEffect(() => {
    if (onAppliedCountChange) {
      onAppliedCountChange(fixedCount);
    }
  }, [fixedCount, onAppliedCountChange]);

  return (
    <div className="flex-1 flex flex-col bg-transparent text-slate-900 dark:text-slate-100">
      {/* Asosiy Ish Maydoni (Workspace) */}
      <div className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-4 sm:py-6">
        {/* 1. READER VIEW (Shartnoma Varaqi + AI Inspector Split) */}
        {activeView === 'reader' && (
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
            {/* Chap tomon (65%): Shartnoma Varaqi (Qizil/Yashil boy diff) */}
            <div className="lg:col-span-8">
              <DocumentPaper
                analysis={analysis}
                selectedClauseId={selectedClauseId}
                onSelectClause={(id) => setSelectedClauseId(id)}
                appliedFixes={appliedFixes}
                onApplyFix={handleApplyFix}
                onRejectFix={handleRejectFix}
              />
            </div>

            {/* O'ng tomon (35%): AI Yurist Inspektori (Sticky Liquid Glass) */}
            <div className="lg:col-span-4 sticky top-20 space-y-4">
              <ClauseInspector
                analysis={analysis}
                selectedClause={selectedClause}
                onSelectClause={(id) => setSelectedClauseId(id)}
                onApplyFix={handleApplyFix}
                onRejectFix={handleRejectFix}
                appliedFixes={appliedFixes}
              />

              {/* Ovozli Tahlil Tugmasi */}
              <button
                onClick={() => setShowVoiceBar(!showVoiceBar)}
                className="w-full py-2.5 px-3 rounded-2xl liquid-glass hover:liquid-glass-accent text-xs font-bold text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white flex items-center justify-center gap-2 transition-all cursor-pointer border border-slate-300 dark:border-white/10"
              >
                <span>🎙️ {showVoiceBar ? "Ovozli Yordamchini Yopish" : "Live Sinusoidal Ovozli Yordamchi"}</span>
              </button>

              {showVoiceBar && (
                <LiveVoiceAssistant 
                  analysis={analysis} 
                  onNavigateToClause={(id) => setSelectedClauseId(id)}
                />
              )}
            </div>
          </div>
        )}

        {/* 2. DIFF VIEW (Side-by-Side Redline) */}
        {activeView === 'diff' && (
          <div className="space-y-4">
            <SideBySideDiffViewer
              analysis={analysis}
              focusedClauseId={selectedClauseId}
            />
          </div>
        )}
      </div>

      {/* 3D Visualizer Modali */}
      <ThreeDModal
        isOpen={is3DModalOpen}
        onClose={() => setIs3DModalOpen(false)}
        analysis={analysis}
        selectedClauseId={selectedClauseId}
        onSelectClause={(id) => setSelectedClauseId(id)}
      />
    </div>
  );
};
