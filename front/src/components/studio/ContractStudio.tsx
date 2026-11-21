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
  initialView?: 'reader' | 'diff';
}

export const ContractStudio: React.FC<ContractStudioProps> = ({
  analysis,
  onReset,
  initialView = 'reader',
}) => {
  const [activeView, setActiveView] = useState<'reader' | 'diff'>(initialView);

  React.useEffect(() => {
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
      {/* Studio Header (Minimalist Chrome) */}
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
          <div className="mb-6 p-4 rounded-2xl liquid-glass border border-sky-500/30 flex flex-col sm:flex-row items-center justify-between gap-3 shadow-xl">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-xl liquid-glass-subtle border border-white/10 flex items-center justify-center shrink-0">
                <img src="/lex_uz.svg" alt="Lex.uz" className="h-5 w-auto object-contain brightness-125" />
              </div>
              <div>
                <p className="text-xs font-bold text-white flex items-center gap-2">
                  <span>Shartnomada {riskyCount} ta noqonuniy va asimmetrik band aniqlandi ({fixedCount} tasi qabul qilindi)</span>
                  <span className="text-[10px] font-mono px-2 py-0.2 rounded-full bg-rose-500/20 text-rose-300 border border-rose-500/30">
                    Boy Redline Tahrir
                  </span>
                </p>
                <p className="text-[11px] text-slate-300">
                  O‘zR Fuqarolik Kodeksi va Lex.uz milliy qonunchilik bazasi talablari asosida barcha bandlarni 1-bosishda avto-tuzating.
                </p>
              </div>
            </div>

            <button
              onClick={handleAutoFixAll}
              className="w-full sm:w-auto px-5 py-2.5 rounded-xl bg-gradient-to-r from-sky-500 to-blue-600 hover:from-sky-400 hover:to-blue-500 text-white text-xs font-bold shadow-lg shadow-sky-500/25 flex items-center justify-center gap-1.5 transition-all cursor-pointer hover:scale-105 shrink-0"
            >
              <Wand2 className="w-3.5 h-3.5" />
              <span>Barcha Xavflarni Qabul Qilish</span>
            </button>
          </div>
        )}

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
                className="w-full py-2.5 px-3 rounded-2xl liquid-glass hover:liquid-glass-accent text-xs font-bold text-slate-300 hover:text-white flex items-center justify-center gap-2 transition-all cursor-pointer border border-white/10"
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
