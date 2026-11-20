import React from 'react';
import { AnalysisResult } from '../../types/contract';
import { 
  ShieldAlert, 
  AlertTriangle, 
  CheckCircle2, 
  HelpCircle, 
  Download, 
  FileText, 
  Scale, 
  ShieldCheck, 
  ExternalLink,
  Cpu
} from 'lucide-react';
import { exportToDocx, exportToPDF } from '../../utils/export';

interface ExecutiveSummaryProps {
  analysis: AnalysisResult;
  onOpen3D: () => void;
  onOpenDiff: () => void;
}

export const ExecutiveSummary: React.FC<ExecutiveSummaryProps> = ({
  analysis,
  onOpen3D,
  onOpenDiff,
}) => {
  const { summary, document } = analysis;

  return (
    <div className="space-y-6">
      {/* Yuqori Banner: Hujjat Rekvizitlari & Tezkor Amallar */}
      <div className="p-6 rounded-3xl bg-gradient-to-r from-slate-900 via-slate-850 to-slate-900 border border-slate-800 shadow-xl flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="text-[10px] font-mono uppercase px-2 py-0.5 rounded bg-sky-500/20 text-sky-400 border border-sky-500/30">
              {document.document_type}
            </span>
            <span className="text-xs text-slate-400">
              Sana: {document.contract_date}
            </span>
          </div>
          <h2 className="text-xl sm:text-2xl font-bold text-white tracking-tight">
            {document.filename}
          </h2>
          <p className="text-xs text-slate-400 font-mono mt-1">
            SHA256: <span className="text-slate-300">{document.sha256.substring(0, 24)}...</span>
          </p>
        </div>

        {/* Eksport Tugmalari */}
        <div className="flex items-center gap-2 self-stretch sm:self-auto">
          <button
            onClick={() => exportToDocx(analysis)}
            className="flex-1 sm:flex-initial px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-sky-300 text-xs font-semibold border border-slate-700 hover:border-sky-500/50 shadow-sm transition-all flex items-center justify-center gap-1.5"
            title="Kelishmovchiliklar bayonnomasi va redline takliflar bilan Word (.docx) yuklab olish"
          >
            <Download className="w-3.5 h-3.5" />
            <span>Word Redline (.docx)</span>
          </button>

          <button
            onClick={() => exportToPDF(analysis)}
            className="flex-1 sm:flex-initial px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-emerald-300 text-xs font-semibold border border-slate-700 hover:border-emerald-500/50 shadow-sm transition-all flex items-center justify-center gap-1.5"
            title="Audit hisobotini PDF formatida yuklab olish"
          >
            <FileText className="w-3.5 h-3.5" />
            <span>Audit PDF</span>
          </button>
        </div>
      </div>

      {/* 4-Rangli Risk Matritsasi Kartalari */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {/* QIZIL */}
        <div className="p-5 rounded-2xl bg-gradient-to-br from-red-950/40 via-slate-900 to-slate-950 border border-red-900/60 shadow-lg shadow-red-950/20 space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-red-400">
              Qizil (Huquqiy)
            </span>
            <ShieldAlert className="w-4 h-4 text-red-400" />
          </div>
          <div className="text-3xl font-black text-white">
            {summary.red_count}
          </div>
          <p className="text-[11px] text-red-300/80 leading-relaxed">
            Qonunga zid, bitimning haqiqiy emasligi xavfi mavjud bandlar.
          </p>
        </div>

        {/* SARIQ */}
        <div className="p-5 rounded-2xl bg-gradient-to-br from-amber-950/40 via-slate-900 to-slate-950 border border-amber-900/60 shadow-lg shadow-amber-950/20 space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-amber-400">
              Sariq (Tijoriy)
            </span>
            <AlertTriangle className="w-4 h-4 text-amber-400" />
          </div>
          <div className="text-3xl font-black text-white">
            {summary.yellow_count}
          </div>
          <p className="text-[11px] text-amber-300/80 leading-relaxed">
            Tijoriy asimmetriya, yuqori penya yoki cheksiz javobgarlik.
          </p>
        </div>

        {/* YASHIL */}
        <div className="p-5 rounded-2xl bg-gradient-to-br from-emerald-950/40 via-slate-900 to-slate-950 border border-emerald-900/60 shadow-lg shadow-emerald-950/20 space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-emerald-400">
              Yashil (Muvozanatli)
            </span>
            <CheckCircle2 className="w-4 h-4 text-emerald-400" />
          </div>
          <div className="text-3xl font-black text-white">
            {summary.green_count}
          </div>
          <p className="text-[11px] text-emerald-300/80 leading-relaxed">
            Qonuniy va ikki tomon manfaatlariga mos keluvchi bandlar.
          </p>
        </div>

        {/* KULRANG */}
        <div className="p-5 rounded-2xl bg-gradient-to-br from-gray-900/40 via-slate-900 to-slate-950 border border-gray-800 shadow-lg space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-gray-400">
              Kulrang (Inson Ko'rigi)
            </span>
            <HelpCircle className="w-4 h-4 text-gray-400" />
          </div>
          <div className="text-3xl font-black text-white">
            {summary.gray_count}
          </div>
          <p className="text-[11px] text-gray-400 leading-relaxed">
            Noaniq shartlar, advokat ko'rigi talab etiladigan bandlar.
          </p>
        </div>
      </div>

      {/* O'rta Blok: Taraflar Balansi & 3D Visualizer Reklama Barchasi */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Balans & Metrika */}
        <div className="p-6 rounded-3xl bg-slate-900/80 border border-slate-800 space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-bold text-white flex items-center gap-2">
              <Scale className="w-4 h-4 text-sky-400" />
              <span>Taraflar Manfaati Balansi</span>
            </h3>
            <span className="text-xs font-bold px-2.5 py-1 rounded-full bg-red-500/20 text-red-400 border border-red-500/30">
              {summary.balance_label}
            </span>
          </div>

          <div className="space-y-2">
            <div className="flex items-center justify-between text-xs text-slate-400">
              <span>Umumiy Xavf Indeksi:</span>
              <span className="font-bold text-white">{summary.risk_score}/100</span>
            </div>
            <div className="w-full bg-slate-800 rounded-full h-3 overflow-hidden">
              <div 
                className={`h-3 rounded-full transition-all ${
                  summary.risk_score > 60 ? 'bg-red-500' : summary.risk_score > 30 ? 'bg-amber-500' : 'bg-emerald-500'
                }`}
                style={{ width: `${summary.risk_score}%` }}
              />
            </div>
          </div>

          <div className="p-3 bg-slate-950/60 rounded-xl border border-slate-800/80 text-xs text-slate-400 leading-relaxed">
            💡 Shartnomada buyurtmachi manfaati ustun qo'yilgan. Xususan, 7.3 va 8.2 bandlar ijrochi uchun jiddiy moliyaviy asimmetriyani keltirib chiqarmoqda.
          </div>
        </div>

        {/* 3D Visualizerga Tezkor Kirish Kartasi */}
        <div 
          onClick={onOpen3D}
          className="p-6 rounded-3xl bg-gradient-to-tr from-sky-950/60 via-slate-900 to-brand-950/40 border border-sky-500/40 hover:border-sky-400 cursor-pointer group transition-all shadow-xl shadow-sky-950/30 flex flex-col justify-between"
        >
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <span className="p-2 rounded-xl bg-sky-500/20 text-sky-400 border border-sky-500/30">
                <Cpu className="w-5 h-5 group-hover:rotate-12 transition-transform" />
              </span>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                WebGL 3D
              </span>
            </div>
            <h3 className="text-base font-bold text-white group-hover:text-sky-300 transition-colors">
              Interaktiv 3D Risk Visualizer
            </h3>
            <p className="text-xs text-slate-300 leading-relaxed">
              Shartnomani 3D sfera va tugunlar ko'rinishida aylantiring, xavflar klasterini fazoda tahlil qiling.
            </p>
          </div>

          <div className="pt-4 flex items-center justify-between text-xs font-bold text-sky-400">
            <span>3D Rejimga O'tish</span>
            <span className="group-hover:translate-x-1 transition-transform">→</span>
          </div>
        </div>

        {/* Side-by-Side Diff ga Tezkor Kirish */}
        <div 
          onClick={onOpenDiff}
          className="p-6 rounded-3xl bg-slate-900/80 border border-slate-800 hover:border-slate-700 cursor-pointer group transition-all flex flex-col justify-between"
        >
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <span className="p-2 rounded-xl bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                <FileText className="w-5 h-5 group-hover:scale-105 transition-transform" />
              </span>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-slate-800 text-slate-300">
                Side-by-Side
              </span>
            </div>
            <h3 className="text-base font-bold text-white group-hover:text-emerald-300 transition-colors">
              Yonma-yon Legal Diff Viewer
            </h3>
            <p className="text-xs text-slate-300 leading-relaxed">
              Asl band matni va tavsiya qilingan qonuniy redline tuzatishlarni Lex.uz moddalari bilan taqqoslang.
            </p>
          </div>

          <div className="pt-4 flex items-center justify-between text-xs font-bold text-emerald-400">
            <span>Diff Ko'rinishiga O'tish</span>
            <span className="group-hover:translate-x-1 transition-transform">→</span>
          </div>
        </div>
      </div>

      {/* Top 3 Xavflar va Yuridik Ogohlantirish */}
      <div className="p-6 rounded-3xl bg-slate-900/80 border border-slate-800 space-y-4">
        <h3 className="text-sm font-bold text-white flex items-center gap-2">
          <ShieldAlert className="w-4 h-4 text-red-400" />
          <span>Eng Muhim Topilmalar va Huquqiy Xatarlar</span>
        </h3>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          {summary.top_risks.map((risk, idx) => (
            <div key={idx} className="p-3.5 rounded-xl bg-slate-950/70 border border-slate-800 flex items-start gap-3">
              <span className="w-5 h-5 rounded-full bg-red-500/20 text-red-400 flex items-center justify-center font-bold text-xs shrink-0 mt-0.5">
                {idx + 1}
              </span>
              <p className="text-xs text-slate-300 leading-relaxed">
                {risk}
              </p>
            </div>
          ))}
        </div>

        {/* Disclaimer */}
        <div className="pt-2 text-[11px] text-slate-500 italic border-t border-slate-800/80">
          ⚖️ {analysis.disclaimer}
        </div>
      </div>
    </div>
  );
};
