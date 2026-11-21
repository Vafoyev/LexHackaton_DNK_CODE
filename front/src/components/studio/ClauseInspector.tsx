import React, { useState } from 'react';
import { 
  ShieldAlert, 
  AlertTriangle, 
  CheckCircle2, 
  HelpCircle, 
  ExternalLink, 
  ChevronLeft, 
  ChevronRight,
  Sparkles,
  Check,
  X,
  Undo2,
  GitBranch,
  Volume2,
  VolumeX
} from 'lucide-react';
import { AnalysisResult, ContractClause, Finding } from '../../types/contract';

interface ClauseInspectorProps {
  analysis: AnalysisResult;
  selectedClause: ContractClause | null;
  onSelectClause: (clauseId: string) => void;
  onApplyFix: (clauseId: string, fixedText: string) => void;
  onRejectFix?: (clauseId: string) => void;
  appliedFixes: Record<string, string>; // qaysi bandlar tuzatildi
}

export const ClauseInspector: React.FC<ClauseInspectorProps> = ({
  analysis,
  selectedClause,
  onSelectClause,
  onApplyFix,
  onRejectFix,
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
      <div className="h-full flex flex-col items-center justify-center p-8 text-center liquid-glass rounded-3xl border border-slate-200 dark:border-white/10 text-slate-500 dark:text-slate-400">
        <img src="/lex_uz.svg" alt="" aria-hidden="true" className="h-7 w-auto object-contain opacity-50 mb-3" />
        <h4 className="text-sm font-bold text-slate-900 dark:text-slate-200 mb-1">Band Tanlanmagan</h4>
        <p className="text-xs text-slate-500 dark:text-slate-400 max-w-xs">
          Chap tomondagi shartnoma matnidan istalgan bandni yoki tagiga chizilgan xavfli joyni bosing.
        </p>
      </div>
    );
  }

  const riskLevel = isFixed ? 'GREEN' : selectedClause.risk_level;

  // Knowledge Graph moddalar zanjiri (Spetsifikatsiya 4-bo'lim)
  const getKnowledgeGraphChain = () => {
    if (!finding) return [];
    if (finding.clause_number === '7.3') {
      return [
        { article: 'FK 707-modda', title: 'Bir tomonlama voz kechish sharti', nature: 'IMPERATIVE', url: 'https://lex.uz/docs/111181#111905' },
        { article: 'FK 354-modda', title: 'Shartnoma erkinligi chegarasi', nature: 'DISPOSITIVE', url: 'https://lex.uz/docs/111181#111550' },
        { article: 'FK 324-modda', title: 'Haqiqiy xarajatlarni qoplash majburiyati', nature: 'IMPERATIVE', url: 'https://lex.uz/docs/111181#111516' },
      ];
    }
    if (finding.clause_number === '8.2') {
      return [
        { article: 'FK 324-modda', title: 'Zararni to‘lash majburiyati', nature: 'DISPOSITIVE', url: 'https://lex.uz/docs/111181#111516' },
        { article: 'FK 333-modda', title: 'Javobgarlik asoslari va chegarasi (Cap of Liability)', nature: 'DISPOSITIVE', url: 'https://lex.uz/docs/111181#111530' },
      ];
    }
    if (finding.clause_number === '9.1') {
      return [
        { article: 'FK 326-modda', title: 'Nomutanosib neustoykani kamaytirish', nature: 'DISPOSITIVE', url: 'https://lex.uz/docs/111181#111520' },
        { article: 'FK 260-modda', title: 'Penya va jarima tushunchasi', nature: 'DISPOSITIVE', url: 'https://lex.uz/docs/111181' },
      ];
    }
    return [
      { article: finding.legal_basis.article, title: finding.legal_basis.source_title, nature: finding.legal_basis.norm_nature, url: finding.legal_basis.lex_uz_url }
    ];
  };

  const lawChain = getKnowledgeGraphChain();

  return (
    <div className="h-full flex flex-col liquid-glass rounded-3xl border border-slate-200 dark:border-white/10 shadow-2xl overflow-hidden backdrop-blur-2xl">
      {/* 1. Yuqori Navigatsiya & Xavf Holati */}
      <div className="p-4 border-b border-slate-200 dark:border-white/10 flex items-center justify-between liquid-glass-subtle">
        <div className="flex items-center gap-2">
          {riskLevel === 'RED' && (
            <span className="px-2.5 py-1 rounded-full bg-rose-100 dark:bg-rose-500/20 text-rose-800 dark:text-rose-400 border border-rose-300 dark:border-rose-500/30 text-[10px] font-bold font-mono uppercase tracking-wider flex items-center gap-1">
              <ShieldAlert className="w-3 h-3" /> QONUNGA ZID
            </span>
          )}
          {riskLevel === 'YELLOW' && (
            <span className="px-2.5 py-1 rounded-full bg-amber-100 dark:bg-amber-500/20 text-amber-800 dark:text-amber-400 border border-amber-300 dark:border-amber-500/30 text-[10px] font-bold font-mono uppercase tracking-wider flex items-center gap-1">
              <AlertTriangle className="w-3 h-3" /> ASIMMETRIYA
            </span>
          )}
          {riskLevel === 'GREEN' && (
            <span className="px-2.5 py-1 rounded-full bg-emerald-100 dark:bg-emerald-500/20 text-emerald-800 dark:text-emerald-400 border border-emerald-300 dark:border-emerald-500/30 text-[10px] font-bold font-mono uppercase tracking-wider flex items-center gap-1">
              <CheckCircle2 className="w-3 h-3" /> {isFixed ? 'TUZATILDI' : 'XAVFSIZ'}
            </span>
          )}
          {riskLevel === 'GRAY' && (
            <span className="px-2.5 py-1 rounded-full bg-slate-200 dark:bg-slate-700/40 text-slate-700 dark:text-slate-300 border border-slate-300 dark:border-slate-600/50 text-[10px] font-bold font-mono uppercase tracking-wider flex items-center gap-1">
              <HelpCircle className="w-3 h-3" /> KO‘RIK SHART
            </span>
          )}

          <span className="text-xs font-bold text-slate-900 dark:text-white font-mono">
            {selectedClause.clause_number}-band
          </span>
        </div>

        {/* Xavflar bo'yicha tezkor oldinga / orqaga tugmalari */}
        {riskyClauses.length > 0 && (
          <div className="flex items-center gap-1 text-[11px] text-slate-500 dark:text-slate-400 font-mono">
            <span>{currentRiskIndex >= 0 ? `${currentRiskIndex + 1}/${riskyClauses.length}` : ''}</span>
            <button
              onClick={handlePrevRisk}
              title="Oldingi xavfga o‘tish"
              className="p-1 rounded-lg bg-slate-200 hover:bg-slate-300 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white transition-colors cursor-pointer"
            >
              <ChevronLeft className="w-3.5 h-3.5" />
            </button>
            <button
              onClick={handleNextRisk}
              title="Keyingi xavfga o‘tish"
              className="p-1 rounded-lg bg-slate-200 hover:bg-slate-300 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white transition-colors cursor-pointer"
            >
              <ChevronRight className="w-3.5 h-3.5" />
            </button>
          </div>
        )}
      </div>

      {/* 2. Asosiy Tarkib (Scrollable) */}
      <div className="flex-1 p-5 overflow-y-auto space-y-4 text-xs">
        {/* Sarlavha & Xulosa */}
        <div>
          <h3 className="text-sm font-bold text-slate-900 dark:text-white mb-1.5 flex items-center gap-2">
            <span>{finding ? finding.issue_title : selectedClause.title}</span>
          </h3>
          <p className="text-slate-700 dark:text-slate-300 leading-relaxed text-[11px]">
            {finding 
              ? finding.issue_explanation 
              : "Ushbu band qonuniy me'yorlarga va taraflar muvozanatiga to‘liq mos keladi. Qo‘shimcha yuridik tuzatish talab etilmaydi."}
          </p>
        </div>

        {/* 🧠 Legal Knowledge Graph Moddalar Zanjiri (Multi-Hop) */}
        {finding && lawChain.length > 0 && (
          <div className="p-3.5 rounded-2xl liquid-glass-subtle border border-sky-300 dark:border-sky-500/30 space-y-2">
            <div className="flex items-center justify-between text-[11px] font-mono font-bold text-sky-700 dark:text-sky-400">
              <span className="flex items-center gap-1.5">
                <GitBranch className="w-3.5 h-3.5 text-sky-600 dark:text-sky-400" />
                Lex.uz Knowledge Graph (Moddalar Zanjiri)
              </span>
              <img src="/lex_uz.svg" alt="" aria-hidden="true" className="h-3 w-auto object-contain brightness-110" />
            </div>

            <div className="space-y-1.5 pt-1">
              {lawChain.map((item, idx) => (
                <div key={idx} className="flex items-center justify-between p-2 rounded-xl bg-slate-100 dark:bg-slate-950/60 border border-slate-200 dark:border-white/5 hover:border-sky-400 dark:hover:border-sky-500/40 transition-all">
                  <div className="min-w-0 pr-2">
                    <div className="flex items-center gap-1.5">
                      <span className="text-[10px] font-mono px-1.5 py-0.2 rounded bg-sky-100 dark:bg-sky-500/20 text-sky-800 dark:text-sky-300 font-bold">
                        {item.article}
                      </span>
                      <span className="text-[9px] font-mono uppercase text-slate-500 dark:text-slate-400">
                        ({item.nature})
                      </span>
                    </div>
                    <p className="text-[10px] text-slate-700 dark:text-slate-300 truncate mt-0.5">{item.title}</p>
                  </div>

                  <a
                    href={item.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="p-1 px-2 rounded-lg bg-sky-500/15 hover:bg-sky-500/30 text-sky-700 dark:text-sky-300 text-[10px] font-bold flex items-center gap-1 shrink-0 transition-colors"
                  >
                    <span>Ochish</span>
                    <ExternalLink className="w-2.5 h-2.5" />
                  </a>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Asl xavfli matn vs Tavsiya qilingan Redline */}
        {finding && (
          <div className="space-y-2.5">
            {/* QIZIL */}
            <div className="p-3 rounded-2xl bg-rose-50 dark:bg-rose-950/30 border border-rose-200 dark:border-rose-500/30 space-y-1">
              <span className="text-[10px] font-mono uppercase text-rose-700 dark:text-rose-400 font-bold block">
                🔴 Asl shartnoma bandi:
              </span>
              <p className="text-rose-950 dark:text-rose-100 italic text-[11px] leading-relaxed line-through decoration-rose-500/60">
                "{finding.original_quote}"
              </p>
            </div>

            {/* YASHIL */}
            <div className="p-3 rounded-2xl bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-500/30 space-y-1">
              <span className="text-[10px] font-mono uppercase text-emerald-800 dark:text-emerald-400 font-bold block flex items-center gap-1">
                <Sparkles className="w-3 h-3 text-emerald-600 dark:text-emerald-400" /> 🟢 AI tavsiya etgan qonuniy tahrir:
              </span>
              <p className="text-emerald-950 dark:text-emerald-200 text-[11px] leading-relaxed font-medium">
                "{finding.suggested_redline}"
              </p>
              <p className="text-[10px] text-emerald-700 dark:text-emerald-400/80 mt-1">
                Sabab: {finding.redline_reasoning}
              </p>
            </div>
          </div>
        )}

        {/* Ovozli Yurist Brifingi */}
        <div className="pt-1">
          <button
            onClick={playVoiceExplanation}
            className={`w-full py-2 px-3 rounded-xl border flex items-center justify-center gap-2 text-xs font-semibold transition-all cursor-pointer ${
              isPlayingAudio
                ? 'bg-rose-500/20 text-rose-700 dark:text-rose-300 border-rose-300 dark:border-rose-500/40 animate-pulse'
                : 'liquid-glass-subtle hover:liquid-glass-accent text-slate-700 dark:text-slate-300 border-slate-200 dark:border-white/10'
            }`}
          >
            {isPlayingAudio ? (
              <>
                <VolumeX className="w-3.5 h-3.5 text-rose-500" />
                <span>Ovozli sharhni to‘xtatish</span>
              </>
            ) : (
              <>
                <Volume2 className="w-3.5 h-3.5 text-sky-500 dark:text-sky-400" />
                <span>Advokat ovozli sharhini eshitish (15s)</span>
              </>
            )}
          </button>
        </div>
      </div>

      {/* 3. ASOSIY 1-TUGMALI ACTION: QABUL QILISH / RAD ETISH */}
      {finding && (
        <div className="p-4 border-t border-slate-200 dark:border-white/10 liquid-glass-subtle">
          {!isFixed ? (
            <div className="grid grid-cols-2 gap-2">
              <button
                onClick={() => onApplyFix(selectedClause.id, finding.suggested_redline)}
                className="py-2.5 px-3 rounded-xl bg-gradient-to-r from-emerald-600 to-teal-700 hover:from-emerald-500 hover:to-teal-600 text-white font-bold text-xs shadow-lg shadow-emerald-600/30 flex items-center justify-center gap-1.5 transition-all cursor-pointer hover:scale-[1.02]"
              >
                <Check className="w-3.5 h-3.5" />
                <span>Qabul qilish</span>
              </button>

              <button
                onClick={() => onRejectFix && onRejectFix(selectedClause.id)}
                className="py-2.5 px-3 rounded-xl bg-slate-200 hover:bg-slate-300 dark:bg-slate-800/80 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white font-semibold text-xs border border-slate-300 dark:border-white/10 flex items-center justify-center gap-1.5 transition-all cursor-pointer"
              >
                <X className="w-3.5 h-3.5 text-rose-500 dark:text-rose-400" />
                <span>Rad etish</span>
              </button>
            </div>
          ) : (
            <div className="flex items-center justify-between gap-2 p-2 rounded-xl bg-emerald-100 dark:bg-emerald-500/20 border border-emerald-300 dark:border-emerald-500/40 text-emerald-800 dark:text-emerald-300 font-bold text-xs">
              <div className="flex items-center gap-1.5">
                <CheckCircle2 className="w-4 h-4 text-emerald-600 dark:text-emerald-400" />
                <span>Tahrir qabul qilindi</span>
              </div>
              {onRejectFix && (
                <button
                  onClick={() => onRejectFix(selectedClause.id)}
                  className="px-2 py-1 rounded-lg bg-slate-900/60 hover:bg-slate-900 text-slate-300 hover:text-white text-[11px] font-normal flex items-center gap-1 transition-colors"
                >
                  <Undo2 className="w-3 h-3" />
                  <span>Bekor qilish</span>
                </button>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
};
