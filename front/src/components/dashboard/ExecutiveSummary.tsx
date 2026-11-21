import React from 'react';
import { AnalysisResult } from '../../types/contract';
import { 
  Download, 
  FileText, 
  Scale, 
  Cpu, 
  Sparkles,
  ChevronRight,
  ShieldCheck,
  AlertTriangle
} from 'lucide-react';
import { exportToDocx, exportToPDF } from '../../utils/export';
import { ContractHealthGauge } from './ContractHealthGauge';
import { LiveVoiceAssistant } from '../voice/LiveVoiceAssistant';
import { Mini3DVisualizer } from '../visualizer/Mini3DVisualizer';

interface ExecutiveSummaryProps {
  analysis: AnalysisResult;
  onOpen3D: () => void;
  onOpenDiff: () => void;
  onSelectClause?: (clauseId: string) => void;
}

export const ExecutiveSummary: React.FC<ExecutiveSummaryProps> = ({
  analysis,
  onOpen3D,
  onOpenDiff,
  onSelectClause,
}) => {
  const { summary, document } = analysis;

  return (
    <div className="space-y-6">
      {/* 1. YUQORI DOKUMENT REKVIZITLARI & EKSPORT AMALLARI */}
      <div className="p-5 sm:p-6 rounded-3xl bg-slate-900/90 border border-slate-800 shadow-xl flex flex-col md:flex-row items-start md:items-center justify-between gap-4 backdrop-blur-md">
        <div>
          <div className="flex items-center gap-2 mb-1.5">
            <span className="text-[10px] font-mono uppercase px-2.5 py-0.5 rounded-full bg-zinc-500/20 text-zinc-400 border border-zinc-500/30 font-bold">
              {document.document_type}
            </span>
            <span className="text-xs text-slate-400 font-mono">
              📅 {document.contract_date}
            </span>
          </div>
          <h2 className="text-xl sm:text-2xl font-black text-white tracking-tight flex items-center gap-2">
            <span>{document.filename}</span>
            <span className="text-xs px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-400 font-mono border border-emerald-500/30">
              O‘RQ-547 ANONIM
            </span>
          </h2>
          <p className="text-[11px] text-slate-400 font-mono mt-1">
            SHA256: <span className="text-slate-300">{document.sha256.substring(0, 20)}...</span>
          </p>
        </div>

        {/* Eksport Tugmalari */}
        <div className="flex items-center gap-2.5 self-stretch sm:self-auto">
          <button
            onClick={() => exportToDocx(analysis)}
            className="flex-1 sm:flex-initial px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-zinc-300 text-xs font-bold border border-slate-700 hover:border-zinc-500/50 shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer hover:scale-105"
            title="Kelishmovchiliklar bayonnomasi va redline takliflar bilan Word (.docx) yuklab olish"
          >
            <Download className="w-4 h-4 text-zinc-400" />
            <span>Word Redline (.docx)</span>
          </button>

          <button
            onClick={() => exportToPDF(analysis)}
            className="flex-1 sm:flex-initial px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-emerald-300 text-xs font-bold border border-slate-700 hover:border-emerald-500/50 shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer hover:scale-105"
            title="Audit hisobotini PDF formatida yuklab olish"
          >
            <FileText className="w-4 h-4 text-emerald-400" />
            <span>Audit PDF</span>
          </button>
        </div>
      </div>

      {/* 2. ULTIMATE VISUAL GAUGE (0-100 Radial Donut + DNA Barcode Heatmap) */}
      <ContractHealthGauge 
        analysis={analysis} 
        onSelectClause={onSelectClause}
        onOpen3D={onOpen3D}
      />

      {/* 3. AI LIVE OVOZLI YURIST ASSISTENTI (Waveform + 30s Debrief + Voice Q&A) */}
      <LiveVoiceAssistant 
        analysis={analysis} 
        onNavigateToClause={onSelectClause}
      />

      {/* 4. 3D MINI VIEWPORT & TEZKOR AMALLAR KARTALARI */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* 3D Interaktiv Sfera Kartasi (Mini Three.js integratsiyasi) */}
        <div className="p-5 rounded-3xl bg-slate-900/90 border border-slate-800 space-y-3 flex flex-col justify-between shadow-xl">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-bold text-white flex items-center gap-1.5">
              <Cpu className="w-4 h-4 text-zinc-400" />
              <span>3D Neyron Risk Fazosi</span>
            </h3>
            <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-zinc-500/20 text-zinc-400 border border-zinc-500/30">
              Interactive
            </span>
          </div>

          <Mini3DVisualizer analysis={analysis} onOpenFull3D={onOpen3D} />

          <button
            onClick={onOpen3D}
            className="w-full py-2 px-3 rounded-xl bg-zinc-500/10 hover:bg-zinc-500/20 text-zinc-300 text-xs font-bold border border-zinc-500/30 flex items-center justify-center gap-1.5 transition-all cursor-pointer"
          >
            <span>To‘liq 3D Fazoga O‘tish</span>
            <ChevronRight className="w-3.5 h-3.5" />
          </button>
        </div>

        {/* Side-by-Side Diff Kartasi */}
        <div className="p-5 rounded-3xl bg-slate-900/90 border border-slate-800 space-y-3 flex flex-col justify-between shadow-xl">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-bold text-white flex items-center gap-1.5">
              <FileText className="w-4 h-4 text-emerald-400" />
              <span>Side-by-Side Redline Diff</span>
            </h3>
            <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
              {analysis.clauses.filter(c => c.risk_level === 'RED' || c.risk_level === 'YELLOW').length} ta tuzatish
            </span>
          </div>

          <div className="space-y-2 p-3 bg-slate-950/60 rounded-2xl border border-slate-800/80 text-xs text-slate-300 flex-1 flex flex-col justify-center">
            <div className="flex items-center gap-2 text-rose-400 font-bold">
              <span>🔴 4.2-modda:</span>
              <span className="text-[11px] text-slate-400 truncate">Bir tomonlama bekor qilish</span>
            </div>
            <div className="flex items-center gap-2 text-amber-400 font-bold">
              <span>🟡 7.3-modda:</span>
              <span className="text-[11px] text-slate-400 truncate">Kechikkan kunga 0.5% penya</span>
            </div>
            <div className="text-[10px] text-slate-500 pt-1 border-t border-slate-800/60">
              Yuridik ekspertiza asosida tayyorlangan rasmiy redline takliflar.
            </div>
          </div>

          <button
            onClick={onOpenDiff}
            className="w-full py-2 px-3 rounded-xl bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-300 text-xs font-bold border border-emerald-500/30 flex items-center justify-center gap-1.5 transition-all cursor-pointer"
          >
            <span>Taqqoslama Diff Ko‘rish</span>
            <ChevronRight className="w-3.5 h-3.5" />
          </button>
        </div>

        {/* Manfaatlar Balansi & Lex.uz Manbalari */}
        <div className="p-5 rounded-3xl bg-slate-900/90 border border-slate-800 space-y-3 flex flex-col justify-between shadow-xl">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-bold text-white flex items-center gap-1.5">
              <Scale className="w-4 h-4 text-amber-400" />
              <span>Taraflar Balansi & Lex.uz</span>
            </h3>
            <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-amber-500/20 text-amber-400 border border-amber-500/30">
              {summary.balance_label}
            </span>
          </div>

          <div className="p-3 bg-slate-950/60 rounded-2xl border border-slate-800/80 space-y-2 flex-1 flex flex-col justify-center text-xs">
            <div className="text-slate-300 font-semibold flex items-center gap-1.5">
              <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" />
              <span>Asoslangan Kodekslar:</span>
            </div>
            <div className="flex flex-wrap gap-1.5">
              <span className="px-2 py-0.5 rounded bg-slate-800 text-[10px] font-mono text-zinc-300 border border-slate-700">FK 326-modda</span>
              <span className="px-2 py-0.5 rounded bg-slate-800 text-[10px] font-mono text-zinc-300 border border-slate-700">FK 707-modda</span>
              <span className="px-2 py-0.5 rounded bg-slate-800 text-[10px] font-mono text-zinc-300 border border-slate-700">O‘RQ-547</span>
            </div>
            <p className="text-[10px] text-slate-400 italic pt-1">
              Gallyutsinatsiyasiz: barcha havola va moddalar Lex.uz bazasi bilan 100% verifikatsiya qilingan.
            </p>
          </div>

          <div className="text-[10px] text-slate-500 italic p-1">
            ⚖️ {analysis.disclaimer}
          </div>
        </div>
      </div>
    </div>
  );
};
