import React, { useState, useEffect } from 'react';
import { AnalysisResult, ContractClause } from '../../types/contract';
import { DocumentPaper } from './DocumentPaper';
import { ClauseInspector } from './ClauseInspector';
import { ThreeDModal } from './ThreeDModal';
import { SideBySideDiffViewer } from '../diff/SideBySideDiffViewer';
import { LiveVoiceAssistant } from '../voice/LiveVoiceAssistant';
import { BalancePanel } from '../dashboard/BalancePanel';
import { ArrowLeft, Mic } from 'lucide-react';
import { Button } from '../ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../ui/tabs';

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
  const [activeView, setActiveView] = useState<'reader' | 'diff' | 'balance'>(initialView);

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
    <Tabs
      value={activeView}
      onValueChange={(v) => setActiveView(v as 'reader' | 'diff' | 'balance')}
      className="flex flex-1 flex-col bg-transparent text-foreground"
    >
      {/* Yuqori panel: orqaga / hujjat nomi / ko'rinish tanlash */}
      <div className="sticky top-16 z-20 border-b bg-background/70 backdrop-blur-md">
        <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-3 px-4 py-2.5 sm:px-6 lg:px-8">
          <div className="flex items-center gap-3">
            <Button variant="ghost" size="sm" onClick={onReset} className="gap-1.5 text-xs font-semibold text-muted-foreground">
              <ArrowLeft className="h-3.5 w-3.5" aria-hidden="true" />
              Boshqaruv paneliga qaytish
            </Button>
            <div className="hidden h-4 w-px bg-border sm:block" aria-hidden="true" />
            <span className="max-w-[260px] truncate text-xs font-bold sm:max-w-md sm:text-sm">
              {analysis.document?.filename || analysis.document?.document_type || "IT xizmat ko'rsatish shartnomasi"}
            </span>
          </div>

          <TabsList>
            <TabsTrigger value="reader" className="text-xs">Hujjat matni</TabsTrigger>
            <TabsTrigger value="diff" className="text-xs">Taqqoslash (Diff)</TabsTrigger>
            <TabsTrigger value="balance" className="text-xs">Balans</TabsTrigger>
          </TabsList>
        </div>
      </div>

      {/* Ish maydoni */}
      <div className="mx-auto w-full max-w-7xl flex-1 px-4 py-4 sm:px-6 sm:py-6 lg:px-8">
        <TabsContent value="reader" className="mt-0 focus-visible:ring-0">
          <div className="grid grid-cols-1 items-start gap-6 lg:grid-cols-12">
            {/* Shartnoma varaqi (qizil/yashil redline) */}
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

            {/* AI yurist inspektori */}
            <div className="sticky top-20 space-y-4 lg:col-span-4">
              <ClauseInspector
                analysis={analysis}
                selectedClause={selectedClause}
                onSelectClause={(id) => setSelectedClauseId(id)}
                onApplyFix={handleApplyFix}
                onRejectFix={handleRejectFix}
                appliedFixes={appliedFixes}
              />

              <Button
                type="button"
                variant="outline"
                onClick={() => setShowVoiceBar(!showVoiceBar)}
                aria-expanded={showVoiceBar}
                className="w-full gap-2 text-xs font-semibold"
              >
                <Mic className="h-4 w-4" aria-hidden="true" />
                {showVoiceBar ? 'Ovozli yordamchini yopish' : 'Ovozli yordamchi'}
              </Button>

              {showVoiceBar && <LiveVoiceAssistant analysis={analysis} onNavigateToClause={(id) => setSelectedClauseId(id)} />}
            </div>
          </div>
        </TabsContent>

        <TabsContent value="diff" className="mt-0 space-y-4 focus-visible:ring-0">
          <SideBySideDiffViewer analysis={analysis} focusedClauseId={selectedClauseId} />
        </TabsContent>

        {/* Tomonlar o'rtasidagi yuk taqsimoti va teng tahrirlar */}
        <TabsContent value="balance" className="mt-0 focus-visible:ring-0">
          <div className="mx-auto max-w-3xl">
            <BalancePanel analysis={analysis} />
          </div>
        </TabsContent>
      </div>

      <ThreeDModal
        isOpen={is3DModalOpen}
        onClose={() => setIs3DModalOpen(false)}
        analysis={analysis}
        selectedClauseId={selectedClauseId}
        onSelectClause={(id) => setSelectedClauseId(id)}
      />
    </Tabs>
  );
};
