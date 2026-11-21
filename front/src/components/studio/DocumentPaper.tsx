import React from 'react';
import { AnalysisResult, ContractClause } from '../../types/contract';
import { 
  ShieldAlert, 
  AlertTriangle, 
  CheckCircle2, 
  HelpCircle, 
  Sparkles,
  FileText
} from 'lucide-react';

interface DocumentPaperProps {
  analysis: AnalysisResult;
  selectedClauseId: string | null;
  onSelectClause: (clauseId: string) => void;
  appliedFixes: Record<string, string>;
}

export const DocumentPaper: React.FC<DocumentPaperProps> = ({
  analysis,
  selectedClauseId,
  onSelectClause,
  appliedFixes,
}) => {
  const { document, clauses } = analysis;

  return (
    <div className="max-w-3xl mx-auto bg-slate-900/90 rounded-3xl border border-slate-800 shadow-2xl p-6 sm:p-12 font-sans text-slate-200 relative backdrop-blur-xl">
      {/* Hujjatning Yuqori Rekvizitlari (Clean Header) */}
      <div className="text-center pb-8 border-b border-slate-800 space-y-2">
        <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-slate-950 border border-slate-800 text-[11px] font-mono text-slate-400">
          <FileText className="w-3.5 h-3.5 text-sky-400" />
          <span>{document.document_type}</span>
          <span>·</span>
          <span>Sana: {document.contract_date}</span>
        </div>

        <h1 className="text-lg sm:text-2xl font-black text-white tracking-tight uppercase">
          {document.filename.replace('.docx', '').replace('.pdf', '').replace(/_/g, ' ')}
        </h1>

        <p className="text-xs text-slate-400 max-w-lg mx-auto">
          Toshkent shahri · O‘zbekiston Respublikasi qonunlariga muvofiq rasmiylashtirilgan
        </p>
      </div>

      {/* Bandlar Ro'yxati (Interactive Document Clauses) */}
      <div className="py-6 space-y-5">
        {clauses.map((clause) => {
          const isSelected = selectedClauseId === clause.id;
          const isFixed = !!appliedFixes[clause.id];
          const displayedText = appliedFixes[clause.id] || clause.original_text;

          const isRed = !isFixed && clause.risk_level === 'RED';
          const isYellow = !isFixed && clause.risk_level === 'YELLOW';

          let highlightClass = "hover:bg-slate-800/40 border-transparent";
          if (isSelected) {
            highlightClass = "bg-slate-850 border-sky-500 shadow-lg shadow-sky-500/10";
          } else if (isFixed) {
            highlightClass = "bg-emerald-950/20 border-emerald-500/40";
          } else if (isRed) {
            highlightClass = "bg-rose-950/20 border-rose-500/40 hover:border-rose-400";
          } else if (isYellow) {
            highlightClass = "bg-amber-950/20 border-amber-500/40 hover:border-amber-400";
          }

          return (
            <div
              key={clause.id}
              onClick={() => onSelectClause(clause.id)}
              className={`p-4 rounded-2xl border transition-all cursor-pointer relative group ${highlightClass}`}
            >
              {/* Band Nomeri va Holat Yorlig'i */}
              <div className="flex items-center justify-between gap-2 mb-1.5">
                <span className="text-xs font-bold font-mono text-slate-400 group-hover:text-white transition-colors">
                  {clause.clause_number}. {clause.title}
                </span>

                {isFixed ? (
                  <span className="px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 text-[10px] font-mono font-bold flex items-center gap-1">
                    <Sparkles className="w-3 h-3" /> TUZATILGAN VARIANT
                  </span>
                ) : isRed ? (
                  <span className="px-2 py-0.5 rounded-full bg-rose-500/20 text-rose-400 border border-rose-500/30 text-[10px] font-mono font-bold flex items-center gap-1 animate-pulse">
                    <ShieldAlert className="w-3 h-3" /> QONUNGA ZID (FK 707)
                  </span>
                ) : isYellow ? (
                  <span className="px-2 py-0.5 rounded-full bg-amber-500/20 text-amber-400 border border-amber-500/30 text-[10px] font-mono font-bold flex items-center gap-1">
                    <AlertTriangle className="w-3 h-3" /> ASIMMETRIK XAVF
                  </span>
                ) : null}
              </div>

              {/* Matn */}
              <p className={`text-xs sm:text-[13px] leading-relaxed transition-colors ${
                isFixed 
                  ? 'text-emerald-200 font-medium' 
                  : isRed 
                  ? 'text-rose-100 font-medium' 
                  : isYellow 
                  ? 'text-amber-100 font-medium' 
                  : 'text-slate-300'
              }`}>
                {displayedText}
              </p>

              {/* Tanlanmagan xavfli bandlar uchun mini ko'rsatgich */}
              {(isRed || isYellow) && !isSelected && (
                <div className="mt-2 text-[10px] font-mono text-slate-500 group-hover:text-slate-400 flex items-center gap-1">
                  <span>→ AI tahlilini ko‘rish uchun bosing</span>
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Hujjatning Imzo Qismi */}
      <div className="pt-8 border-t border-slate-800 grid grid-cols-2 gap-6 text-xs text-slate-400">
        <div className="space-y-1">
          <p className="font-bold text-white uppercase text-[11px]">BUYURTMACHI:</p>
          <p>Smart Legal Solutions MCHJ</p>
          <p className="text-[10px] font-mono">STIR: 305123456</p>
          <div className="pt-4 text-slate-600 font-mono text-[10px]">__________________ (Imzo / E-IMZO)</div>
        </div>

        <div className="space-y-1">
          <p className="font-bold text-white uppercase text-[11px]">IJROCHI / HAMKOR:</p>
          <p>O‘zTex MCHJ</p>
          <p className="text-[10px] font-mono">STIR: 309876543</p>
          <div className="pt-4 text-slate-600 font-mono text-[10px]">__________________ (Imzo / E-IMZO)</div>
        </div>
      </div>

      {/* Lex.uz audit muhri */}
      <div className="mt-8 pt-4 border-t border-dashed border-slate-800/80 flex items-center justify-between text-[10px] text-slate-500 font-mono">
        <div className="flex items-center gap-1.5">
          <span>Qonunchilik asosi:</span>
          <img src="/lex_uz.svg" alt="Lex.uz" className="h-3 w-auto object-contain brightness-110" />
        </div>
        <span>LexGuard AI Raqamli Audit Tekshiruvi · O‘RQ-547</span>
      </div>
    </div>
  );
};
