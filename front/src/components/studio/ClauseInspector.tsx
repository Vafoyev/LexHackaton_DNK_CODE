import React, { useState } from 'react';
import { 
  ShieldAlert, 
  AlertTriangle, 
  CheckCircle2, 
  HelpCircle, 
  ExternalLink, 
  Wand2, 
  Volume2, 
  VolumeX, 
  ArrowRight, 
  ChevronLeft, 
  ChevronRight,
  BookOpen,
  Scale,
  Sparkles
} from 'lucide-react';
import { AnalysisResult, ContractClause, Finding } from '../../types/contract';

interface ClauseInspectorProps {
  analysis: AnalysisResult;
  selectedClause: ContractClause | null;
  onSelectClause: (clauseId: string) => void;
  onApplyFix: (clauseId: string, fixedText: string) => void;
  appliedFixes: Record<string, string>; // qaysi bandlar tuzatildi
}

export const ClauseInspector: React.FC<ClauseInspectorProps> = ({
  analysis,
  selectedClause,
  onSelectClause,
  onApplyFix,
  appliedFixes,
}) => {
  const [isPlayingAudio, setIsPlayingAudio] = useState(false);

  // Tanlangan bandga tegishli finding (topilma)
  const finding: Finding | undefined = analysis.findings.find(
    (f) => f.clause_number === selectedClause?.clause_number || f.clause_id === selectedClause?.id
  );

  const isFixed = selectedClause ? !!appliedFixes[selectedClause.id] : false;

  // Xavfli bandlar bo'yicha navigatsiya indekslari
  const riskyClauses = analysis.clauses.filter(
    (c) => c.risk_level === 'RED' || c.risk_level === 'YELLOW'
  );
  const currentRiskIndex = riskyClauses.findIndex((c) => c.id === selectedClause?.id);

  const handlePrevRisk = () => {
    if (riskyClauses.length === 0) return;
    const prevIdx = currentRiskIndex <= 0 ? riskyClauses.length - 1 : currentRiskIndex - 1;
    onSelectClause(riskyClauses[prevIdx].id);
  };

  const handleNextRisk = () => {
    if (riskyClauses.length === 0) return;
    const nextIdx = currentRiskIndex >= riskyClauses.length - 1 ? 0 : currentRiskIndex + 1;
    onSelectClause(riskyClauses[nextIdx].id);
  };

  // Ovozli sharhni gapirtirish
  const playVoiceExplanation = () => {
    if (!('speechSynthesis' in window)) return;

    if (isPlayingAudio) {
      window.speechSynthesis.cancel();
      setIsPlayingAudio(false);
      return;
    }

    const text = finding 
      ? `${selectedClause?.clause_number}-band bo‘yicha AI xulosasi: ${finding.issue_title}. ${finding.issue_explanation}. Tavsiya: tuzatish tugmasini bosing.`
      : `${selectedClause?.clause_number}-band qonuniy va ikki tomon manfaatlariga mos keladi.`;

    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = 1.05;
    utterance.onend = () => setIsPlayingAudio(false);
    utterance.onerror = () => setIsPlayingAudio(false);

    window.speechSynthesis.speak(utterance);
    setIsPlayingAudio(true);
  };

  if (!selectedClause) {
    return (
      <div className="h-full flex flex-col items-center justify-center p-8 text-center bg-slate-900/60 rounded-3xl border border-slate-800 text-slate-400">
        <Scale className="w-12 h-12 text-slate-600 mb-3 animate-pulse" />
        <h4 className="text-sm font-bold text-slate-300 mb-1">Band Tanlanmagan</h4>
        <p className="text-xs text-slate-500 max-w-xs">
          Chap tomondagi shartnoma matnidan istalgan bandni yoki tagiga chizilgan xavfli joyni bosing.
        </p>
      </div>
    );
  }

  const riskLevel = isFixed ? 'GREEN' : selectedClause.risk_level;

  return (
    <div className="h-full flex flex-col bg-slate-900/90 rounded-3xl border border-slate-800 shadow-xl overflow-hidden backdrop-blur-md">
      {/* 1. Yuqori Navigatsiya & Xavf Holati */}
      <div className="p-4 border-b border-slate-800 flex items-center justify-between bg-slate-950/60">
        <div className="flex items-center gap-2">
          {riskLevel === 'RED' && (
            <span className="px-2.5 py-1 rounded-full bg-rose-500/20 text-rose-400 border border-rose-500/30 text-[10px] font-bold font-mono uppercase tracking-wider flex items-center gap-1">
              <ShieldAlert className="w-3 h-3" /> QONUNGA ZID
            </span>
          )}
          {riskLevel === 'YELLOW' && (
            <span className="px-2.5 py-1 rounded-full bg-amber-500/20 text-amber-400 border border-amber-500/30 text-[10px] font-bold font-mono uppercase tracking-wider flex items-center gap-1">
              <AlertTriangle className="w-3 h-3" /> ASIMMETRIYA
            </span>
          )}
          {riskLevel === 'GREEN' && (
            <span className="px-2.5 py-1 rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 text-[10px] font-bold font-mono uppercase tracking-wider flex items-center gap-1">
              <CheckCircle2 className="w-3 h-3" /> {isFixed ? 'TUZATILDI' : 'XAVFSIZ'}
            </span>
          )}
          {riskLevel === 'GRAY' && (
            <span className="px-2.5 py-1 rounded-full bg-slate-700/40 text-slate-300 border border-slate-600/50 text-[10px] font-bold font-mono uppercase tracking-wider flex items-center gap-1">
              <HelpCircle className="w-3 h-3" /> KO‘RIK SHART
            </span>
          )}

          <span className="text-xs font-bold text-white font-mono">
            {selectedClause.clause_number}-band
          </span>
        </div>

        {/* Xavflar bo'yicha tezkor oldinga / orqaga tugmalari */}
        {riskyClauses.length > 0 && (
          <div className="flex items-center gap-1 text-[11px] text-slate-400 font-mono">
            <span>{currentRiskIndex >= 0 ? `${currentRiskIndex + 1}/${riskyClauses.length}` : ''}</span>
            <button
              onClick={handlePrevRisk}
              title="Oldingi xavfga o‘tish"
              className="p-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors cursor-pointer"
            >
              <ChevronLeft className="w-3.5 h-3.5" />
            </button>
            <button
              onClick={handleNextRisk}
              title="Keyingi xavfga o‘tish"
              className="p-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors cursor-pointer"
            >
              <ChevronRight className="w-3.5 h-3.5" />
            </button>
          </div>
        )}
      </div>

      {/* 2. Asosiy Tarkib (Scrollable) */}
      <div className="flex-1 p-5 overflow-y-auto space-y-4 text-xs">
        {/* Sarlavha */}
        <div>
          <h3 className="text-sm font-bold text-white mb-1">
            {finding ? finding.issue_title : selectedClause.title}
          </h3>
          <p className="text-slate-400 leading-relaxed text-[11px]">
            {finding 
              ? finding.issue_explanation 
              : "Ushbu band qonuniy me'yorlarga va taraflar muvozanatiga to‘liq mos keladi. Qo‘shimcha yuridik tuzatish talab etilmaydi."}
          </p>
        </div>

        {/* Lex.uz Qonun Havolasi */}
        {finding?.legal_basis && (
          <div className="p-3 rounded-2xl bg-slate-950/70 border border-slate-800 flex items-start justify-between gap-3">
            <div className="space-y-0.5">
              <span className="text-[10px] font-mono uppercase text-sky-400 font-bold block flex items-center gap-1">
                <BookOpen className="w-3 h-3" /> Qonuniy Manba:
              </span>
              <p className="text-slate-200 font-semibold text-xs">
                {finding.legal_basis.article}
              </p>
              <span className="text-[10px] text-slate-400">
                {finding.legal_basis.source_title} ({finding.legal_basis.norm_nature})
              </span>
            </div>

            <a
              href={finding.legal_basis.lex_uz_url}
              target="_blank"
              rel="noopener noreferrer"
              className="p-2 rounded-xl bg-sky-500/10 hover:bg-sky-500/20 text-sky-400 border border-sky-500/30 shrink-0 transition-colors cursor-pointer"
              title="Lex.uz rasmiy bazasida ochish"
            >
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          </div>
        )}

        {/* Asl matn vs Qonuniy Redline */}
        {finding && (
          <div className="space-y-2.5">
            <div className="p-3 rounded-2xl bg-rose-950/20 border border-rose-900/40 space-y-1">
              <span className="text-[10px] font-mono uppercase text-rose-400 font-bold block">
                Asl xavfli matn:
              </span>
              <p className="text-slate-300 italic text-[11px] leading-relaxed line-through decoration-rose-500/60">
                "{finding.original_quote}"
              </p>
            </div>

            <div className="p-3 rounded-2xl bg-emerald-950/20 border border-emerald-900/40 space-y-1">
              <span className="text-[10px] font-mono uppercase text-emerald-400 font-bold block flex items-center gap-1">
                <Sparkles className="w-3 h-3" /> AI tavsiya qilgan qonuniy redline:
              </span>
              <p className="text-emerald-200 text-[11px] leading-relaxed font-medium">
                "{finding.suggested_redline}"
              </p>
            </div>
          </div>
        )}

        {/* Ovozli Yurist Brifingi */}
        <div className="pt-2">
          <button
            onClick={playVoiceExplanation}
            className={`w-full py-2 px-3 rounded-xl border flex items-center justify-center gap-2 text-xs font-semibold transition-all cursor-pointer ${
              isPlayingAudio
                ? 'bg-rose-500/20 text-rose-300 border-rose-500/40 animate-pulse'
                : 'bg-slate-800/80 hover:bg-slate-800 text-slate-300 border-slate-700'
            }`}
          >
            {isPlayingAudio ? (
              <>
                <VolumeX className="w-3.5 h-3.5 text-rose-400" />
                <span>Ovozli tushuntirishni to‘xtatish</span>
              </>
            ) : (
              <>
                <Volume2 className="w-3.5 h-3.5 text-sky-400" />
                <span>Advokat ovozli sharhini eshitish (15s)</span>
              </>
            )}
          </button>
        </div>
      </div>

      {/* 3. ASOSIY ACTION: 1-Click Fix Tugmasi */}
      {finding && (
        <div className="p-4 border-t border-slate-800 bg-slate-950/80">
          {!isFixed ? (
            <button
              onClick={() => onApplyFix(selectedClause.id, finding.suggested_redline)}
              className="w-full py-3 px-4 rounded-2xl bg-gradient-to-r from-emerald-600 via-teal-600 to-emerald-500 hover:from-emerald-500 hover:to-teal-500 text-white font-bold text-xs shadow-lg shadow-emerald-600/30 flex items-center justify-center gap-2 transition-all cursor-pointer hover:scale-[1.02]"
            >
              <Wand2 className="w-4 h-4" />
              <span>Shartnomaga Qo‘llash (1-Click Fix)</span>
            </button>
          ) : (
            <div className="py-2.5 px-3 rounded-2xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-300 font-bold text-xs flex items-center justify-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-400" />
              <span>Qonuniy tahrir shartnomaga kiritildi</span>
            </div>
          )}
        </div>
      )}
    </div>
  );
};
