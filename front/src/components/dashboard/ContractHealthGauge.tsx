import React from 'react';
import { AnalysisResult, RiskLevel } from '../../types/contract';
import { 
  ShieldCheck, 
  AlertOctagon, 
  Coins, 
  Activity, 
  Layers, 
  ArrowRight
} from 'lucide-react';

interface ContractHealthGaugeProps {
  analysis: AnalysisResult;
  onSelectClause?: (clauseId: string) => void;
  onOpen3D?: () => void;
}

export const ContractHealthGauge: React.FC<ContractHealthGaugeProps> = ({
  analysis,
  onSelectClause,
  onOpen3D,
}) => {
  const { summary, clauses } = analysis;
  const score = Math.max(0, Math.min(100, 100 - summary.risk_score)); // 100 = mukammal xavfsiz, 0 = xavfli

  // Rang hisoblash
  const getScoreColor = () => {
    if (score >= 75) return { stroke: '#10B981', text: 'text-emerald-400', bg: 'bg-emerald-500/10', border: 'border-emerald-500/30', label: 'YUQORI XAVFSIZLIK' };
    if (score >= 45) return { stroke: '#F59E0B', text: 'text-amber-400', bg: 'bg-amber-500/10', border: 'border-amber-500/30', label: 'O‘RTACHA XAVF' };
    return { stroke: '#EF4444', text: 'text-rose-400', bg: 'bg-rose-500/10', border: 'border-rose-500/30', label: 'KRITIK XAVF' };
  };

  const status = getScoreColor();
  const radius = 68;
  const circumference = 2 * Math.PI * radius;
  const strokeDashoffset = circumference - (score / 100) * circumference;

  return (
    <div className="rounded-3xl bg-slate-900/90 border border-slate-800 p-6 shadow-2xl relative overflow-hidden backdrop-blur-xl">
      {/* Orqa fon nur effekti */}
      <div 
        className="absolute -top-24 -right-24 w-72 h-72 rounded-full opacity-20 blur-3xl pointer-events-none"
        style={{ backgroundColor: status.stroke }}
      />

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-center">
        {/* 1. KATTA VISUAL GAUGE (0-100 Radiali) */}
        <div className="lg:col-span-4 flex flex-col items-center justify-center p-4 rounded-2xl bg-slate-950/60 border border-slate-800/80 relative">
          <div className="relative w-44 h-44 flex items-center justify-center">
            <svg className="w-full h-full transform -rotate-90" viewBox="0 0 160 160">
              {/* Asosiy kulrang aylanasi */}
              <circle
                cx="80"
                cy="80"
                r={radius}
                stroke="#1E293B"
                strokeWidth="12"
                fill="none"
              />
              {/* Progress aylanasi */}
              <circle
                cx="80"
                cy="80"
                r={radius}
                stroke={status.stroke}
                strokeWidth="12"
                strokeDasharray={circumference}
                strokeDashoffset={strokeDashoffset}
                strokeLinecap="round"
                fill="none"
                style={{ transition: 'stroke-dashoffset 1.2s cubic-bezier(0.16, 1, 0.3, 1)' }}
              />
            </svg>

            {/* Markaziy raqam */}
            <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
              <span className={`text-4xl font-black tracking-tight ${status.text}`}>
                {score}
              </span>
              <span className="text-[10px] uppercase font-mono tracking-widest text-slate-400 mt-0.5">
                / 100 INDEKS
              </span>
            </div>
          </div>

          <div className={`mt-3 px-3 py-1 rounded-full text-[11px] font-bold border tracking-wider uppercase ${status.bg} ${status.text} ${status.border}`}>
            {status.label}
          </div>
        </div>

        {/* 2. GLANCEABLE METRIKALAR & MOLIYAVIY XAVF (Yozuvsiz, ko'rgandayoq tushunarli) */}
        <div className="lg:col-span-8 space-y-5">
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            {/* Qizil Bandlar */}
            <div className="p-3.5 rounded-2xl bg-rose-950/30 border border-rose-900/50 flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-rose-500/20 border border-rose-500/40 flex items-center justify-center text-rose-400 font-bold shrink-0">
                🔴 {summary.red_count}
              </div>
              <div className="min-w-0">
                <div className="text-[11px] text-rose-300 font-bold uppercase tracking-wider">Qonunga zid</div>
                <div className="text-[10px] text-slate-400 truncate">Haqiqiy emas</div>
              </div>
            </div>

            {/* Sariq Bandlar */}
            <div className="p-3.5 rounded-2xl bg-amber-950/30 border border-amber-900/50 flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-amber-500/20 border border-amber-500/40 flex items-center justify-center text-amber-400 font-bold shrink-0">
                🟡 {summary.yellow_count}
              </div>
              <div className="min-w-0">
                <div className="text-[11px] text-amber-300 font-bold uppercase tracking-wider">Asimmetriya</div>
                <div className="text-[10px] text-slate-400 truncate">Yuqori penya</div>
              </div>
            </div>

            {/* Yashil Bandlar */}
            <div className="p-3.5 rounded-2xl bg-emerald-950/30 border border-emerald-900/50 flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-emerald-500/20 border border-emerald-500/40 flex items-center justify-center text-emerald-400 font-bold shrink-0">
                🟢 {summary.green_count}
              </div>
              <div className="min-w-0">
                <div className="text-[11px] text-emerald-300 font-bold uppercase tracking-wider">Muvozanatli</div>
                <div className="text-[10px] text-slate-400 truncate">Qonuniy himoya</div>
              </div>
            </div>

            {/* Kulrang Bandlar */}
            <div className="p-3.5 rounded-2xl bg-slate-800/40 border border-slate-700/50 flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-slate-700/30 border border-slate-600/40 flex items-center justify-center text-slate-300 font-bold shrink-0">
                ⚪ {summary.gray_count}
              </div>
              <div className="min-w-0">
                <div className="text-[11px] text-slate-300 font-bold uppercase tracking-wider">Ko‘rik shart</div>
                <div className="text-[10px] text-slate-400 truncate">Advokat nazorati</div>
              </div>
            </div>
          </div>

          {/* 3. DNA SHARTNOMA ISSIQLIK XARITASI (HEATMAP STRIP) */}
          <div className="p-4 rounded-2xl bg-slate-950/50 border border-slate-800/80 space-y-2.5">
            <div className="flex items-center justify-between text-xs">
              <span className="font-semibold text-slate-300 flex items-center gap-1.5">
                <Activity className="w-3.5 h-3.5 text-sky-400" />
                <span>Shartnoma Moddalari Xaritasi (DNA Barcode):</span>
              </span>
              <span className="text-[10px] font-mono text-slate-500">
                Ustiga bosing → Moddaga o‘tish
              </span>
            </div>

            {/* Segmentli DNA lentasi */}
            <div className="flex items-center gap-1.5 h-7 w-full overflow-hidden p-1 bg-slate-900 rounded-xl border border-slate-800">
              {clauses.map((clause) => {
                let bg = 'bg-slate-600 hover:bg-slate-500';
                let ring = 'hover:ring-slate-400';
                if (clause.risk_level === 'RED') {
                  bg = 'bg-rose-500 hover:bg-rose-400 shadow-sm shadow-rose-500/50 animate-pulse';
                  ring = 'hover:ring-rose-400';
                } else if (clause.risk_level === 'YELLOW') {
                  bg = 'bg-amber-500 hover:bg-amber-400';
                  ring = 'hover:ring-amber-400';
                } else if (clause.risk_level === 'GREEN') {
                  bg = 'bg-emerald-500 hover:bg-emerald-400';
                  ring = 'hover:ring-emerald-400';
                }

                return (
                  <button
                    key={clause.id}
                    onClick={() => onSelectClause && onSelectClause(clause.id)}
                    title={`${clause.clause_number}: ${clause.title} (${clause.risk_level})`}
                    className={`flex-1 h-full rounded-md transition-all cursor-pointer hover:scale-110 hover:ring-2 ${ring} ${bg}`}
                  />
                );
              })}
            </div>

            {/* Moliyaviy Xavf Barometri */}
            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 pt-1 text-xs">
              <div className="flex items-center gap-2 text-rose-400 font-bold">
                <Coins className="w-4 h-4 shrink-0 text-amber-400" />
                <span>Moliyaviy Asimmetriya: Kechikkan har kun uchun 0.5% (Max: 50% jami qiymat)</span>
              </div>

              {onOpen3D && (
                <button
                  onClick={onOpen3D}
                  className="px-3 py-1.5 rounded-xl bg-sky-500/20 hover:bg-sky-500/30 text-sky-300 text-xs font-semibold border border-sky-500/40 flex items-center gap-1.5 transition-all self-end sm:self-auto"
                >
                  <Layers className="w-3.5 h-3.5" />
                  <span>3D Sferada Ko‘rish</span>
                  <ArrowRight className="w-3 h-3" />
                </button>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
