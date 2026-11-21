import React from 'react';
import { AnalysisResult, ContractClause } from '../../types/contract';
import { 
  ShieldAlert, 
  AlertTriangle, 
  CheckCircle2, 
  Sparkles,
  FileText,
  ExternalLink,
  Check,
  Undo2
} from 'lucide-react';

interface DocumentPaperProps {
  analysis: AnalysisResult;
  selectedClauseId: string | null;
  onSelectClause: (clauseId: string) => void;
  appliedFixes: Record<string, string>;
  onApplyFix?: (clauseId: string, fixedText: string) => void;
  onRejectFix?: (clauseId: string) => void;
}

export const DocumentPaper: React.FC<DocumentPaperProps> = ({
  analysis,
  selectedClauseId,
  onSelectClause,
  appliedFixes,
  onApplyFix,
  onRejectFix,
}) => {
  const { document, clauses, findings } = analysis;
  const [showSafeClauses, setShowSafeClauses] = React.useState(false);

  // Xavfli bandlar (Qizil va Sariq)
  const riskyClauses = clauses.filter((clause) => {
    const finding = findings.find(
      (f) => f.clause_number === clause.clause_number || f.clause_id === clause.id
    );
    return finding || clause.risk_level === 'RED' || clause.risk_level === 'YELLOW';
  });

  // Muvozanatli xavfsiz bandlar (Yashil)
  const safeClauses = clauses.filter((clause) => {
    const finding = findings.find(
      (f) => f.clause_number === clause.clause_number || f.clause_id === clause.id
    );
    return !finding && clause.risk_level !== 'RED' && clause.risk_level !== 'YELLOW';
  });

  return (
    <div className="max-w-4xl mx-auto liquid-glass rounded-3xl border border-slate-200 dark:border-white/10 shadow-2xl p-6 sm:p-10 font-sans text-slate-800 dark:text-slate-200 relative">
      {/* Hujjatning Yuqori Rekvizitlari (Liquid Glass Header) */}
      <div className="text-center pb-8 border-b border-slate-200 dark:border-white/10 space-y-2">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full liquid-glass-subtle border border-slate-200 dark:border-white/10 text-xs font-mono text-slate-600 dark:text-slate-300">
          <FileText className="w-3.5 h-3.5 text-sky-500 dark:text-sky-400" />
          <span className="font-semibold text-slate-900 dark:text-white">{document.document_type}</span>
          <span className="text-slate-400 dark:text-slate-500">·</span>
          <span>Sana: {document.contract_date}</span>
        </div>

        <h1 className="text-xl sm:text-2xl font-black text-slate-900 dark:text-white tracking-tight uppercase">
          {document.filename.replace('.docx', '').replace('.pdf', '').replace(/_/g, ' ')}
        </h1>

        <p className="text-xs text-slate-600 dark:text-slate-400 max-w-lg mx-auto flex items-center justify-center gap-1.5">
          <span>Toshkent shahri · O‘zbekiston Respublikasi qonunchiligi (Lex.uz) asosida tahlil qilingan</span>
        </p>
      </div>

      {/* 1. XAVFLI BANDLAR RO'YXATI (Diqqat markazida) */}
      <div className="py-6 space-y-6">
        {riskyClauses.map((clause) => {
          const isSelected = selectedClauseId === clause.id;
          const isFixed = !!appliedFixes[clause.id];
          const finding = findings.find(
            (f) => f.clause_number === clause.clause_number || f.clause_id === clause.id
          );

          const isRed = clause.risk_level === 'RED';
          const isYellow = clause.risk_level === 'YELLOW';

          return (
            <div
              key={clause.id}
              onClick={() => onSelectClause(clause.id)}
              className={`p-5 rounded-2xl border transition-all cursor-pointer relative group ${
                isSelected
                  ? 'liquid-glass-accent ring-2 ring-sky-500 shadow-xl shadow-sky-500/10'
                  : isRed && !isFixed
                  ? 'liquid-glass-danger border-rose-300 dark:border-rose-500/40 hover:border-rose-500'
                  : isYellow && !isFixed
                  ? 'liquid-glass-warning border-amber-300 dark:border-amber-500/40 hover:border-amber-500'
                  : isFixed
                  ? 'liquid-glass-success border-emerald-300 dark:border-emerald-500/40'
                  : 'liquid-glass-subtle border-slate-200 dark:border-white/5 hover:border-slate-300 dark:hover:border-white/20'
              }`}
            >
              {/* Band Nomeri va Holat Yorlig'i */}
              <div className="flex flex-wrap items-center justify-between gap-2 mb-3">
                <div className="flex items-center gap-2">
                  <span className="text-xs font-bold font-mono px-2 py-0.5 rounded-lg bg-slate-200 dark:bg-slate-900/80 border border-slate-300 dark:border-white/10 text-slate-800 dark:text-white">
                    {clause.clause_number}
                  </span>
                  <h3 className="text-sm font-bold text-slate-900 dark:text-white group-hover:text-sky-600 dark:group-hover:text-sky-300 transition-colors">
                    {clause.title}
                  </h3>
                </div>

                <div className="flex items-center gap-1.5">
                  {isFixed ? (
                    <span className="px-2.5 py-1 rounded-full bg-emerald-100 dark:bg-emerald-500/20 text-emerald-800 dark:text-emerald-400 border border-emerald-300 dark:border-emerald-500/30 text-[11px] font-mono font-bold flex items-center gap-1">
                      <CheckCircle2 className="w-3.5 h-3.5" /> TUZATILDI (QABUL QILINDI)
                    </span>
                  ) : isRed ? (
                    <span className="px-2.5 py-1 rounded-full bg-rose-100 dark:bg-rose-500/20 text-rose-800 dark:text-rose-400 border border-rose-300 dark:border-rose-500/30 text-[11px] font-mono font-bold flex items-center gap-1 animate-pulse">
                      <ShieldAlert className="w-3.5 h-3.5" /> 🔴 QONUNGA ZID
                    </span>
                  ) : isYellow ? (
                    <span className="px-2.5 py-1 rounded-full bg-amber-100 dark:bg-amber-500/20 text-amber-800 dark:text-amber-400 border border-amber-300 dark:border-amber-500/30 text-[11px] font-mono font-bold flex items-center gap-1">
                      <AlertTriangle className="w-3.5 h-3.5" /> 🟡 ASIMMETRIK XAVF
                    </span>
                  ) : (
                    <span className="px-2.5 py-1 rounded-full bg-emerald-100 dark:bg-emerald-500/10 text-emerald-800 dark:text-emerald-400 border border-emerald-300 dark:border-emerald-500/20 text-[11px] font-mono font-bold flex items-center gap-1">
                      <CheckCircle2 className="w-3 h-3" /> 🟢 XAVFSIZ
                    </span>
                  )}
                </div>
              </div>

              {/* BOY NATIJA KO'RINISHI: QIZIL (Asl band) va YASHIL (To'g'ri tahrir) */}
              {finding && (
                <div className="space-y-3 mt-2">
                  {/* 1. QIZIL BLOK (Asl xavfli band) */}
                  <div className={`p-3.5 rounded-xl border transition-all ${
                    isFixed 
                      ? 'bg-rose-50/60 dark:bg-rose-950/10 border-rose-200 dark:border-rose-900/20 opacity-60' 
                      : 'bg-rose-50 dark:bg-rose-950/30 border-rose-200 dark:border-rose-500/40 shadow-inner'
                  }`}>
                    <div className="flex items-center justify-between text-[11px] font-mono font-bold text-rose-700 dark:text-rose-400 mb-1.5">
                      <span className="flex items-center gap-1.5">
                        <span className="w-2 h-2 rounded-full bg-rose-500"></span>
                        ASL XAVFLI MATN (Hujjatdagi asl tahrir):
                      </span>
                      <span className="text-[10px] text-rose-600 dark:text-rose-300/80 uppercase">
                        {isRed ? 'Huquqiy ziddiyat' : 'Tijoriy asimmetriya'}
                      </span>
                    </div>
                    <p className={`text-xs sm:text-[13px] leading-relaxed text-rose-950 dark:text-rose-100 ${
                      isFixed ? 'line-through decoration-rose-500/60' : 'font-medium'
                    }`}>
                      "{finding.original_quote || clause.original_text}"
                    </p>
                    <div className="mt-2 text-[11px] text-rose-800 dark:text-rose-300/90 font-medium">
                      ⚠️ <span className="font-semibold">{finding.issue_title}:</span> {finding.issue_explanation}
                    </div>
                  </div>

                  {/* 2. YASHIL BLOK (Darhol tagida tavsiya etilgan to'g'ri tahrir - Redline) */}
                  <div className={`p-3.5 rounded-xl border transition-all ${
                    isFixed 
                      ? 'bg-emerald-50 dark:bg-emerald-950/40 border-emerald-300 dark:border-emerald-500/60 shadow-lg shadow-emerald-500/10' 
                      : 'bg-emerald-50/80 dark:bg-emerald-950/25 border-emerald-200 dark:border-emerald-500/40 shadow-inner'
                  }`}>
                    <div className="flex items-center justify-between text-[11px] font-mono font-bold text-emerald-800 dark:text-emerald-400 mb-1.5">
                      <span className="flex items-center gap-1.5">
                        <Sparkles className="w-3.5 h-3.5 text-emerald-600 dark:text-emerald-400" />
                        TAVSIYA ETILGAN TO‘G‘RI TAHRIR (LexGuard Redline):
                      </span>
                      {isFixed && (
                        <span className="text-[10px] bg-emerald-100 dark:bg-emerald-500/20 px-2 py-0.5 rounded text-emerald-800 dark:text-emerald-300">
                          ✓ Qabul qilindi
                        </span>
                      )}
                    </div>
                    <p className="text-xs sm:text-[13px] leading-relaxed text-emerald-950 dark:text-emerald-200 font-medium bg-emerald-100/60 dark:bg-emerald-950/30 p-2.5 rounded-lg border border-emerald-200 dark:border-emerald-900/40">
                      "{finding.suggested_redline}"
                    </p>

                    {/* Qonuniy asos va Lex.uz giperhavolasi */}
                    <div className="mt-2.5 pt-2 border-t border-emerald-200 dark:border-emerald-900/40 flex flex-wrap items-center justify-between gap-2 text-xs">
                      <div className="flex items-center gap-1.5 text-slate-700 dark:text-slate-300 text-[11px]">
                        <span className="font-semibold text-emerald-700 dark:text-emerald-300">Qonuniy asos:</span>
                        <span>{finding.legal_basis.source_title}, {finding.legal_basis.article}</span>
                        <span className="text-[10px] font-mono px-1.5 py-0.2 rounded bg-sky-100 dark:bg-sky-950 text-sky-800 dark:text-sky-400 border border-sky-300 dark:border-sky-800">
                          {finding.legal_basis.norm_nature}
                        </span>
                      </div>

                      <div className="flex items-center gap-2">
                        <a
                          href={finding.legal_basis.lex_uz_url}
                          target="_blank"
                          rel="noreferrer"
                          onClick={(e) => e.stopPropagation()}
                          className="text-[11px] font-semibold text-sky-600 dark:text-sky-400 hover:text-sky-500 dark:hover:text-sky-300 hover:underline flex items-center gap-1 transition-colors"
                        >
                          <img src="/lex_uz.svg" alt="" aria-hidden="true" className="h-3.5 w-auto object-contain brightness-110" />
                          <span>Lex.uz da ko‘rish</span>
                          <ExternalLink className="w-3 h-3" />
                        </a>

                        {/* Tezkor Qabul qilish / Rad etish tugmasi */}
                        {onApplyFix && !isFixed && (
                          <button
                            type="button"
                            onClick={(e) => {
                              e.stopPropagation();
                              onApplyFix(clause.id, finding.suggested_redline);
                            }}
                            className="px-2.5 py-1 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-[11px] font-bold shadow-md shadow-emerald-600/30 flex items-center gap-1 transition-all cursor-pointer hover:scale-105"
                          >
                            <Check className="w-3 h-3 text-white" />
                            <span>Qabul qilish</span>
                          </button>
                        )}
                        {onRejectFix && isFixed && (
                          <button
                            type="button"
                            onClick={(e) => {
                              e.stopPropagation();
                              onRejectFix(clause.id);
                            }}
                            className="px-2.5 py-1 rounded-lg bg-slate-200 hover:bg-slate-300 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 text-[11px] font-semibold flex items-center gap-1 transition-all cursor-pointer"
                          >
                            <Undo2 className="w-3 h-3" />
                            <span>Bekor qilish</span>
                          </button>
                        )}
                      </div>
                    </div>
                  </div>
                </div>
              )}
            </div>
          );
        })}

        {/* 2. XAVFSIZ BANDLARNI YAGONA KONSOLIDATSIYA KARTASIDA KO'RSATISH */}
        {safeClauses.length > 0 && (
          <div className="rounded-2xl liquid-glass-subtle border border-emerald-500/25 overflow-hidden transition-all shadow-md">
            <div 
              onClick={() => setShowSafeClauses(!showSafeClauses)}
              className="p-4 sm:p-5 flex items-center justify-between cursor-pointer hover:bg-emerald-500/5 transition-colors"
            >
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center shrink-0">
                  <CheckCircle2 className="w-5 h-5 text-emerald-600 dark:text-emerald-400" />
                </div>
                <div>
                  <h4 className="text-xs sm:text-sm font-bold text-slate-900 dark:text-white flex flex-wrap items-center gap-2">
                    <span>Qolgan {safeClauses.length} ta band xavfsiz va qonuniy</span>
                    <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-700 dark:text-emerald-400 border border-emerald-500/20 font-semibold">
                      O‘zbekiston FK normalariga muvofiq
                    </span>
                  </h4>
                  <p className="text-[11px] text-slate-500 dark:text-slate-400 mt-0.5">
                    Ushbu bandlarda asimmetriya, noqonuniy jarima yoki yashirin moddiy xavflar aniqlanmadi.
                  </p>
                </div>
              </div>

              <button
                type="button"
                className="text-xs font-semibold text-sky-600 dark:text-sky-400 hover:text-sky-500 px-3 py-1.5 rounded-lg border border-slate-200 dark:border-white/10 hover:bg-white/10 transition-colors shrink-0"
              >
                {showSafeClauses ? "Yashirish" : `${safeClauses.length} ta bandni ko‘rish`}
              </button>
            </div>

            {showSafeClauses && (
              <div className="p-4 pt-2 border-t border-slate-200 dark:border-white/10 space-y-2.5">
                {safeClauses.map((clause) => (
                  <div 
                    key={clause.id}
                    onClick={() => onSelectClause(clause.id)}
                    className="p-3 rounded-xl bg-slate-100/60 dark:bg-slate-900/40 border border-slate-200 dark:border-white/5 hover:border-emerald-500/30 transition-all cursor-pointer"
                  >
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-[10px] font-mono font-bold px-1.5 py-0.5 rounded bg-slate-200 dark:bg-slate-800 text-slate-700 dark:text-slate-300">
                        {clause.clause_number}
                      </span>
                      <h5 className="text-xs font-semibold text-slate-900 dark:text-white">{clause.title}</h5>
                      <span className="text-[10px] text-emerald-600 dark:text-emerald-400 ml-auto flex items-center gap-1 font-mono font-bold">
                        <CheckCircle2 className="w-3 h-3" /> Xavfsiz
                      </span>
                    </div>
                    <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">{clause.original_text}</p>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </div>

      {/* Hujjatning Imzo Qismi */}
      <div className="pt-8 border-t border-slate-200 dark:border-white/10 grid grid-cols-1 sm:grid-cols-2 gap-6 text-xs text-slate-600 dark:text-slate-400">
        <div className="space-y-1.5 p-4 rounded-xl liquid-glass-subtle border border-slate-200 dark:border-white/5">
          <p className="font-bold text-slate-900 dark:text-white uppercase text-[11px]">BUYURTMACHI / TARAFLAR:</p>
          <p className="text-slate-700 dark:text-slate-300">Smart Legal Solutions MCHJ</p>
          <p className="text-[10px] font-mono text-slate-500 dark:text-slate-400">STIR: 305123456</p>
          <div className="pt-3 text-slate-400 dark:text-slate-500 font-mono text-[10px]">__________________ (Elektron imzo / E-IMZO)</div>
        </div>

        <div className="space-y-1.5 p-4 rounded-xl liquid-glass-subtle border border-slate-200 dark:border-white/5">
          <p className="font-bold text-slate-900 dark:text-white uppercase text-[11px]">IJROCHI / HAMKOR:</p>
          <p className="text-slate-700 dark:text-slate-300">O‘zTex MCHJ</p>
          <p className="text-[10px] font-mono text-slate-500 dark:text-slate-400">STIR: 309876543</p>
          <div className="pt-3 text-slate-400 dark:text-slate-500 font-mono text-[10px]">__________________ (Elektron imzo / E-IMZO)</div>
        </div>
      </div>

      {/* Lex.uz audit muhri */}
      <div className="mt-8 pt-4 border-t border-dashed border-slate-200 dark:border-white/10 flex flex-wrap items-center justify-between gap-2 text-[10px] text-slate-500 dark:text-slate-400 font-mono">
        <div className="flex items-center gap-1.5">
          <span>Qonunchilik bazasi:</span>
          <img src="/lex_uz.svg" alt="" aria-hidden="true" className="h-3.5 w-auto object-contain brightness-110" />
          <span className="text-sky-600 dark:text-sky-400 font-semibold">Rasmiy milliy portal</span>
        </div>
        <span>LexGuard AI Raqamli Huquqiy Audit · O‘RQ-547</span>
      </div>
    </div>
  );
};
