import React, { useState } from 'react';
import { AnalysisResult, RiskLevel } from '../../types/contract';
import { 
  ShieldCheck, 
  AlertOctagon, 
  Coins, 
  Activity, 
  Layers, 
  ArrowRight,
  TrendingDown,
  Calculator,
  Scale
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

  // Moliyaviy Simulyator holati
  const [contractAmount, setContractAmount] = useState<number>(100000000); // 100 mln so'm
  const [delayDays, setDelayDays] = useState<number>(15); // 15 kun kechikish

  // Amaldagi noqonuniy shart (kuniga 1% penya, cap yo'q)
  const currentRiskPenalty = Math.round(contractAmount * 0.01 * delayDays);
  // LexGuard tavsiya qilgan qonuniy redline (kuniga 0.1% penya, max 10%)
  const legalRedlinePenalty = Math.round(Math.min(contractAmount * 0.001 * delayDays, contractAmount * 0.10));
  // Tejalgan mablag'
  const savedAmount = Math.max(0, currentRiskPenalty - legalRedlinePenalty);

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

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('uz-UZ').format(amount) + " so'm";
  };

  return (
    <div className="rounded-3xl bg-slate-900/90 border border-slate-800 p-6 shadow-2xl relative overflow-hidden backdrop-blur-xl space-y-6">
      {/* Orqa fon nur effekti */}
      <div 
        className="absolute -top-24 -right-24 w-72 h-72 rounded-full opacity-20 blur-3xl pointer-events-none"
        style={{ backgroundColor: status.stroke }}
      />

      {/* 1. Asosiy Gauge va Metrikalar */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-center">
        {/* KATTA VISUAL GAUGE (0-100 Radiali) */}
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

        {/* GLANCEABLE METRIKALAR & 4-RANGLI HISOB */}
        <div className="lg:col-span-8 space-y-4">
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

          {/* DNA SHARTNOMA ISSIQLIK XARITASI (HEATMAP STRIP) */}
          <div className="p-4 rounded-2xl bg-slate-950/50 border border-slate-800/80 space-y-2.5">
            <div className="flex items-center justify-between text-xs">
              <span className="font-semibold text-slate-300 flex items-center gap-1.5">
                <Activity className="w-3.5 h-3.5 text-zinc-400" />
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

            <div className="flex items-center justify-between text-[10px] text-slate-500 px-1">
              <span>1.1 (Muqaddima)</span>
              <span className="text-zinc-400 font-semibold">{summary.balance_label}</span>
              <span>{clauses[clauses.length - 1]?.clause_number || '18.1'} (Yakuniy)</span>
            </div>
          </div>
        </div>
      </div>

      {/* 2. INTERAKTIV MOLIYAVIY XATAR KALKULYATORI (FINANCIAL EXPOSURE SIMULATOR) */}
      <div className="p-5 rounded-2xl bg-gradient-to-r from-slate-950 via-slate-900 to-slate-950 border border-amber-900/40 space-y-4">
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-2 border-b border-slate-800/80 pb-3">
          <div className="flex items-center gap-2">
            <div className="p-1.5 rounded-lg bg-amber-500/20 text-amber-400 border border-amber-500/30">
              <Calculator className="w-4 h-4" />
            </div>
            <div>
              <h4 className="text-xs font-bold text-white uppercase tracking-wider flex items-center gap-2">
                <span>Interaktiv Moliyaviy Xatar Simulyatori</span>
                <span className="text-[10px] px-2 py-0.5 rounded bg-amber-500/20 text-amber-300 font-mono">FK 326 / FK 707</span>
              </h4>
              <p className="text-[11px] text-slate-400">
                Shartnomadagi kunlik 1% penya va asossiz bekor qilishning moliyaviy oqibati
              </p>
            </div>
          </div>

          <div className="text-right">
            <span className="text-[10px] uppercase font-bold text-slate-400">Tejaladigan Mablag':</span>
            <div className="text-base font-black text-emerald-400 flex items-center gap-1">
              <TrendingDown className="w-4 h-4" />
              <span>{formatCurrency(savedAmount)}</span>
            </div>
          </div>
        </div>

        {/* Slayderlar va Hisob-kitob */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 items-center">
          {/* Shartnoma summasi tanlash */}
          <div className="space-y-1.5">
            <div className="flex justify-between text-xs font-medium">
              <span className="text-slate-400">Shartnoma Umumiy Qiymati:</span>
              <span className="text-white font-mono font-bold">{formatCurrency(contractAmount)}</span>
            </div>
            <input 
              type="range"
              min={10000000}
              max={500000000}
              step={5000000}
              value={contractAmount}
              onChange={(e) => setContractAmount(Number(e.target.value))}
              className="w-full accent-zinc-500 bg-slate-800 h-1.5 rounded-lg cursor-pointer"
            />
            <div className="flex justify-between text-[10px] text-slate-500">
              <span>10 mln</span>
              <span>100 mln</span>
              <span>500 mln so'm</span>
            </div>
          </div>

          {/* Kechikish kunlari */}
          <div className="space-y-1.5">
            <div className="flex justify-between text-xs font-medium">
              <span className="text-slate-400">Faraziy Kechikish:</span>
              <span className="text-amber-400 font-mono font-bold">{delayDays} kun</span>
            </div>
            <input 
              type="range"
              min={1}
              max={60}
              step={1}
              value={delayDays}
              onChange={(e) => setDelayDays(Number(e.target.value))}
              className="w-full accent-amber-500 bg-slate-800 h-1.5 rounded-lg cursor-pointer"
            />
            <div className="flex justify-between text-[10px] text-slate-500">
              <span>1 kun</span>
              <span>15 kun</span>
              <span>60 kun</span>
            </div>
          </div>

          {/* Natija taqqoslash */}
          <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 text-xs space-y-1.5">
            <div className="flex justify-between text-slate-400">
              <span>Hozirgi shartda (1%/kun):</span>
              <span className="text-rose-400 font-mono font-bold">{formatCurrency(currentRiskPenalty)}</span>
            </div>
            <div className="flex justify-between text-slate-400">
              <span>Redline taklifi bilan:</span>
              <span className="text-emerald-400 font-mono font-bold">{formatCurrency(legalRedlinePenalty)}</span>
            </div>
            <div className="pt-1 border-t border-slate-800 flex justify-between text-[11px] font-bold text-zinc-400">
              <span>Yuridik Xavf Qisqarishi:</span>
              <span>-{Math.round((savedAmount / Math.max(currentRiskPenalty, 1)) * 100)}%</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
