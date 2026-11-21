import React, { useState } from 'react';
import { AnalysisResult, ContractClause } from '../../types/contract';
import { StudioHeader } from './StudioHeader';
import { DocumentPaper } from './DocumentPaper';
import { ClauseInspector } from './ClauseInspector';
import { ThreeDModal } from './ThreeDModal';
import { SideBySideDiffViewer } from '../diff/SideBySideDiffViewer';
import { LiveVoiceAssistant } from '../voice/LiveVoiceAssistant';
import { Sparkles, Check, Wand2 } from 'lucide-react';

interface ContractStudioProps {
  analysis: AnalysisResult;
  onReset: () => void;
}

export const ContractStudio: React.FC<ContractStudioProps> = ({
  analysis,
  onReset,
}) => {
  const [activeView, setActiveView] = useState<'reader' | 'diff'>('reader');
  const [selectedClauseId, setSelectedClauseId] = useState<string | null>(() => {
    // Dastlab birinchi qizil yoki sariq xavfli bandni avtomatik tanlash
    const firstRisky = analysis.clauses.find((c) => c.risk_level === 'RED' || c.risk_level === 'YELLOW');
    return firstRisky ? firstRisky.id : analysis.clauses[0]?.id || null;
  });

  const [appliedFixes, setAppliedFixes] = useState<Record<string, string>>({});
  const [is3DModalOpen, setIs3DModalOpen] = useState(false);
  const [showVoiceBar, setShowVoiceBar] = useState(false);

  const selectedClause = analysis.clauses.find((c) => c.id === selectedClauseId) || null;

  // 1-Click Fix funksiyasi
  const handleApplyFix = (clauseId: string, fixedText: string) => {
    setAppliedFixes((prev) => ({
      ...prev,
      [clauseId]: fixedText,
    }));
  };

  // Barcha xavflarni bir vaqtda avto-tuzatish (Auto-fix all)
  const handleAutoFixAll = () => {
    const newFixes: Record<string, string> = { ...appliedFixes };
    analysis.findings.forEach((f) => {
      const matchClause = analysis.clauses.find(
        (c) => c.clause_number === f.clause_number || c.id === f.clause_id
      );
      if (matchClause && f.suggested_redline) {
        newFixes[matchClause.id] = f.suggested_redline;
      }
    });
    setAppliedFixes(newFixes);
  };

  const riskyCount = analysis.clauses.filter(
    (c) => c.risk_level === 'RED' || c.risk_level === 'YELLOW'
  ).length;
  const fixedCount = Object.keys(appliedFixes).length;

  return (
    <div className="min-h-screen flex flex-col bg-slate-950 text-slate-100">
      {/* Studio Header */}
      <StudioHeader
        analysis={analysis}
        activeView={activeView}
        setActiveView={setActiveView}
        onOpen3D={() => setIs3DModalOpen(true)}
        onReset={onReset}
        appliedCount={fixedCount}
      />

      {/* Asosiy Ish Maydoni (Workspace) */}
      <div className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-6">
        {/* Avto-tuzatish Taklif Banneri (agar hali tuzatilmagan xavflar bo'lsa) */}
        {fixedCount < riskyCount && (
          <div className="mb-6 p-4 rounded-2xl bg-gradient-to-r from-slate-900 via-sky-950/40 to-slate-900 border border-sky-500/30 flex flex-col sm:flex-row items-center justify-between gap-3 shadow-lg">
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 rounded-xl bg-sky-500/20 text-sky-400 flex items-center justify-center font-bold">
                <Sparkles className="w-4 h-4" />
              </div>
              <div>
                <p className="text-xs font-bold text-white">
                  Shartnomada {riskyCount} ta noqonuniy va asimmetrik band aniqlandi ({fixedCount} tasi tuzatildi)
                </p>
                <p className="text-[11px] text-slate-400">
                  O‘zbekiston Fuqarolik Kodeksi talablari asosida barcha bandlarni bitta bosishda tuzatishingiz mumkin.
                </p>
              </div>
            </div>

            <button
              onClick={handleAutoFixAll}
              className="w-full sm:w-auto px-4 py-2 rounded-xl bg-sky-500 hover:bg-sky-400 text-white text-xs font-bold shadow-md shadow-sky-500/20 flex items-center justify-center gap-1.5 transition-all cursor-pointer hover:scale-105 shrink-0"
            >
              <Wand2 className="w-3.5 h-3.5" />
              <span>Barcha Xavflarni Avto-Tuzatish</span>
            </button>
          </div>
        )}

        {/* 1. READER VIEW (Shartnoma Varaqi + AI Inspector Split) */}
        {activeView === 'reader' && (
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
            {/* Chap tomon (65%): Shartnoma Varaqi */}
            <div className="lg:col-span-8">
              <DocumentPaper
                analysis={analysis}
                selectedClauseId={selectedClauseId}
                onSelectClause={(id) => setSelectedClauseId(id)}
                appliedFixes={appliedFixes}
              />
            </div>

            {/* O'ng tomon (35%): AI Yurist Inspektori (Sticky) */}
            <div className="lg:col-span-4 sticky top-20 space-y-4">
              <ClauseInspector
                analysis={analysis}
                selectedClause={selectedClause}
                onSelectClause={(id) => setSelectedClauseId(id)}
                onApplyFix={handleApplyFix}
                appliedFixes={appliedFixes}
              />

              {/* Ovozli Tahlil Tugmasi */}
              <button
                onClick={() => setShowVoiceBar(!showVoiceBar)}
                className="w-full py-2.5 px-3 rounded-2xl bg-slate-900 hover:bg-slate-850 border border-slate-800 text-xs font-bold text-slate-300 hover:text-white flex items-center justify-center gap-2 transition-all cursor-pointer"
              >
                <span>🎙️ {showVoiceBar ? "Ovozli Yuristni Yopish" : "AI Live Ovozli Yuristni Ochish"}</span>
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
