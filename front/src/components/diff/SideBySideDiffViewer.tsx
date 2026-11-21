import React, { useState, useEffect, useRef } from 'react';
import { AnalysisResult, Finding, RiskLevel } from '../../types/contract';
import { 
  AlertTriangle, 
  ExternalLink, 
  Copy, 
  Check, 
  Search, 
  Scale, 
  ShieldAlert, 
  Filter, 
  Sparkles,
  ArrowRight,
  BookOpen
} from 'lucide-react';

interface SideBySideDiffViewerProps {
  analysis: AnalysisResult;
  focusedClauseId?: string | null;
}

export const SideBySideDiffViewer: React.FC<SideBySideDiffViewerProps> = ({
  analysis,
  focusedClauseId,
}) => {
  const [filter, setFilter] = useState<RiskLevel | 'ALL' | 'RISKS_ONLY'>('RISKS_ONLY');
  const [searchQuery, setSearchQuery] = useState('');
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [acceptedFindings, setAcceptedFindings] = useState<Record<string, boolean>>({});
  const clauseRefs = useRef<Record<string, HTMLDivElement | null>>({});

  // Fokuslangan band bo'lsa o'sha yerga avtomatik scroll qilish
  useEffect(() => {
    if (focusedClauseId && clauseRefs.current[focusedClauseId]) {
      clauseRefs.current[focusedClauseId]?.scrollIntoView({
        behavior: 'smooth',
        block: 'center',
      });
    }
  }, [focusedClauseId]);

  const handleCopyRedline = (findingId: string, text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedId(findingId);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const handleToggleAccept = (findingId: string) => {
    setAcceptedFindings(prev => ({
      ...prev,
      [findingId]: !prev[findingId],
    }));
  };

  // Clause va Findingsni birlashtirish
  const clausesWithFindings = analysis.clauses.map(clause => {
    const finding = analysis.findings.find(f => f.clause_number === clause.clause_number || f.clause_id === clause.id);
    return {
      ...clause,
      finding,
    };
  });

  // Filtrlash
  const filteredClauses = clausesWithFindings.filter(item => {
    if (filter === 'RISKS_ONLY') {
      if (item.risk_level === 'GREEN') return false;
    } else if (filter !== 'ALL') {
      if (item.risk_level !== filter) return false;
    }

    if (searchQuery.trim() !== '') {
      const q = searchQuery.toLowerCase();
      const matchText = item.original_text.toLowerCase().includes(q);
      const matchTitle = item.title.toLowerCase().includes(q);
      const matchFinding = item.finding?.issue_title.toLowerCase().includes(q) || item.finding?.suggested_redline.toLowerCase().includes(q);
      return matchText || matchTitle || matchFinding;
    }

    return true;
  });

  return (
    <div className="space-y-6">
      {/* Control Bar (Filtrlar va Qidiruv) */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4 p-4 bg-slate-900/90 backdrop-blur-md rounded-2xl border border-slate-800 shadow-xl">
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 sm:pb-0">
          <button
            onClick={() => setFilter('RISKS_ONLY')}
            className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all flex items-center gap-1.5 ${
              filter === 'RISKS_ONLY'
                ? 'bg-gradient-to-r from-red-600 to-amber-600 text-white shadow-md shadow-red-600/20'
                : 'text-slate-400 hover:text-white hover:bg-slate-800'
            }`}
          >
            <ShieldAlert className="w-3.5 h-3.5" />
            <span>Xavfli Bandlar ({analysis.summary.red_count + analysis.summary.yellow_count + analysis.summary.gray_count})</span>
          </button>

          <button
            onClick={() => setFilter('ALL')}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all ${
              filter === 'ALL'
                ? 'bg-sky-600 text-white shadow-md shadow-sky-600/20'
                : 'text-slate-400 hover:text-white hover:bg-slate-800'
            }`}
          >
            Barchasi ({analysis.clauses.length})
          </button>

          <button
            onClick={() => setFilter('RED')}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all flex items-center gap-1.5 ${
              filter === 'RED'
                ? 'bg-red-600 text-white shadow-md shadow-red-600/20'
                : 'text-slate-400 hover:text-white hover:bg-slate-800'
            }`}
          >
            <span className="w-2 h-2 rounded-full bg-red-400"></span>
            <span>Qizil ({analysis.summary.red_count})</span>
          </button>

          <button
            onClick={() => setFilter('YELLOW')}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all flex items-center gap-1.5 ${
              filter === 'YELLOW'
                ? 'bg-amber-600 text-white shadow-md shadow-amber-600/20'
                : 'text-slate-400 hover:text-white hover:bg-slate-800'
            }`}
          >
            <span className="w-2 h-2 rounded-full bg-amber-400"></span>
            <span>Sariq ({analysis.summary.yellow_count})</span>
          </button>

          <button
            onClick={() => setFilter('GREEN')}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all flex items-center gap-1.5 ${
              filter === 'GREEN'
                ? 'bg-emerald-600 text-white shadow-md shadow-emerald-600/20'
                : 'text-slate-400 hover:text-white hover:bg-slate-800'
            }`}
          >
            <span className="w-2 h-2 rounded-full bg-emerald-400"></span>
            <span>Yashil ({analysis.summary.green_count})</span>
          </button>
        </div>

        {/* Qidiruv */}
        <div className="relative min-w-[240px]">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Band matni yoki modda qidirish..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-4 py-1.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-sky-500 transition-all"
          />
        </div>
      </div>

      {/* Sarlavha Ustunlari (Side-by-side Headers) */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 text-xs font-bold uppercase tracking-wider text-slate-400 px-2">
        <div className="flex items-center gap-2 p-2 rounded-lg bg-slate-900/60 border border-slate-800">
          <BookOpen className="w-4 h-4 text-slate-400" />
          <span>Asl Shartnoma Matni (Original Text)</span>
        </div>
        <div className="flex items-center gap-2 p-2 rounded-lg bg-slate-900/60 border border-slate-800">
          <Sparkles className="w-4 h-4 text-sky-400" />
          <span>Tavsiya Qilingan Redline & Qonuniy Asos (Lex.uz)</span>
        </div>
      </div>

      {/* Ro'yxat (Cards) */}
      <div className="space-y-4">
        {filteredClauses.length === 0 ? (
          <div className="text-center py-12 bg-slate-900/40 rounded-2xl border border-slate-800 text-slate-400">
            <Scale className="w-10 h-10 mx-auto text-slate-500 mb-2 opacity-50" />
            <p className="text-sm font-medium">Ushbu filtr bo'yicha bandlar topilmadi</p>
          </div>
        ) : (
          filteredClauses.map((item) => {
            const hasFinding = !!item.finding;
            const isRed = item.risk_level === 'RED';
            const isYellow = item.risk_level === 'YELLOW';
            const isGreen = item.risk_level === 'GREEN';
            const isGray = item.risk_level === 'GRAY';
            const isAccepted = item.finding ? acceptedFindings[item.finding.id] : false;
            const isFocused = focusedClauseId === item.id;

            return (
              <div
                key={item.id}
                ref={(el) => (clauseRefs.current[item.id] = el)}
                className={`transition-all duration-300 rounded-2xl border p-4 sm:p-5 ${
                  isFocused
                    ? 'ring-2 ring-sky-500 bg-sky-950/20 border-sky-500/80 shadow-2xl shadow-sky-500/10'
                    : isRed
                    ? 'bg-slate-900/80 border-red-900/60 hover:border-red-600/60 shadow-lg shadow-red-950/20'
                    : isYellow
                    ? 'bg-slate-900/80 border-amber-900/60 hover:border-amber-600/60 shadow-lg shadow-amber-950/20'
                    : isGreen
                    ? 'bg-slate-900/40 border-slate-800/80 hover:border-slate-700'
                    : 'bg-slate-900/60 border-gray-800'
                }`}
              >
                {/* Band sarlavhasi va teglari */}
                <div className="flex flex-wrap items-center justify-between gap-2 pb-3 mb-3 border-b border-slate-800/80">
                  <div className="flex items-center gap-2.5">
                    <span className="font-mono text-sm font-bold text-white px-2 py-0.5 rounded-lg bg-slate-800 border border-slate-700">
                      {item.clause_number}
                    </span>
                    <h3 className="text-sm font-semibold text-slate-100">
                      {item.title}
                    </h3>
                  </div>

                  <div className="flex items-center gap-2">
                    {/* Risk Badge */}
                    <span
                      className={`text-[11px] font-bold px-2.5 py-1 rounded-full flex items-center gap-1.5 ${
                        isRed
                          ? 'bg-red-500/20 text-red-400 border border-red-500/30'
                          : isYellow
                          ? 'bg-amber-500/20 text-amber-400 border border-amber-500/30'
                          : isGreen
                          ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                          : 'bg-gray-500/20 text-gray-400 border border-gray-500/30'
                      }`}
                    >
                      <span className={`w-2 h-2 rounded-full ${isRed ? 'bg-red-500' : isYellow ? 'bg-amber-500' : isGreen ? 'bg-emerald-500' : 'bg-gray-500'}`} />
                      {isRed ? 'QIZIL (Huquqiy Xavf)' : isYellow ? 'SARIQ (Tijoriy Xavf)' : isGreen ? 'YASHIL (Muvozanatli)' : 'KULRANG (Ekspert Ko\'rigi)'}
                    </span>

                    {/* Verification Status */}
                    {item.finding && (
                      <span className="text-[10px] uppercase font-mono px-2 py-0.5 rounded bg-slate-800 text-sky-400 border border-slate-700">
                        {item.finding.verification_status}
                      </span>
                    )}
                  </div>
                </div>

                {/* Side-by-Side Content */}
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
                  {/* Chap Ustun: Asl Matn */}
                  <div className="space-y-3 bg-slate-950/70 p-4 rounded-xl border border-slate-800/80">
                    <div className="text-[11px] font-semibold text-slate-400 flex items-center justify-between">
                      <span>Asl Hujjatdagi Matn</span>
                      {isRed && <span className="text-red-400 font-bold text-[10px]">⚠️ Qonunga Ziddiyat Bor</span>}
                      {isYellow && <span className="text-amber-400 font-bold text-[10px]">⚠️ Asimmetrik Shart</span>}
                    </div>

                    <p className={`text-xs sm:text-sm leading-relaxed ${
                      isRed 
                        ? 'text-red-200 bg-red-950/20 p-2.5 rounded-lg border border-red-900/40' 
                        : isYellow 
                        ? 'text-amber-200 bg-amber-950/20 p-2.5 rounded-lg border border-amber-900/40' 
                        : 'text-slate-300'
                    }`}>
                      {item.finding?.original_quote || item.original_text}
                    </p>

                    {item.finding && (
                      <div className="pt-2 text-xs text-slate-400 border-t border-slate-800/60">
                        <span className="font-semibold text-slate-300">Aniqlangan muammo: </span>
                        <span>{item.finding.issue_explanation}</span>
                      </div>
                    )}
                  </div>

                  {/* O'ng Ustun: Qonuniy Tavsiya va Lex.uz Asosi */}
                  <div className="space-y-3">
                    {hasFinding && item.finding ? (
                      <div className="bg-slate-950/90 p-4 rounded-xl border border-sky-900/40 shadow-inner space-y-3">
                        <div className="flex items-center justify-between">
                          <span className="text-[11px] font-semibold text-sky-400 flex items-center gap-1.5">
                            <Sparkles className="w-3.5 h-3.5" />
                            <span>Tavsiya Qilingan Tahrir (Redline)</span>
                          </span>

                          <div className="flex items-center gap-1.5">
                            <button
                              onClick={() => handleCopyRedline(item.finding!.id, item.finding!.suggested_redline)}
                              className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-all text-[11px] flex items-center gap-1 border border-slate-700"
                              title="Tahrirni nusxalash"
                            >
                              {copiedId === item.finding.id ? (
                                <>
                                  <Check className="w-3.5 h-3.5 text-emerald-400" />
                                  <span className="text-emerald-400">Nusxalandi</span>
                                </>
                              ) : (
                                <>
                                  <Copy className="w-3.5 h-3.5" />
                                  <span>Nusxa olish</span>
                                </>
                              )}
                            </button>

                            <button
                              onClick={() => handleToggleAccept(item.finding!.id)}
                              className={`px-2.5 py-1.5 rounded-lg text-[11px] font-semibold transition-all flex items-center gap-1 border ${
                                isAccepted
                                  ? 'bg-emerald-600 text-white border-emerald-500 shadow-sm'
                                  : 'bg-slate-800 hover:bg-slate-700 text-slate-300 border-slate-700'
                              }`}
                            >
                              <Check className="w-3.5 h-3.5" />
                              <span>{isAccepted ? 'Qabul qilindi' : 'Qabul qilish'}</span>
                            </button>
                          </div>
                        </div>

                        {/* Redline Text Box */}
                        <div className="p-3 rounded-lg bg-emerald-950/20 border border-emerald-900/50 text-emerald-300 text-xs sm:text-sm font-medium leading-relaxed">
                          {item.finding.suggested_redline}
                        </div>

                        {/* Redline Sababi */}
                        <div className="text-[11px] text-slate-400">
                          <span className="font-semibold text-slate-300">Tuzatish maqsadi: </span>
                          <span>{item.finding.redline_reasoning}</span>
                        </div>

                        {/* Lex.uz Giperhavolasi va Qonuniy Asos */}
                        <div className="pt-2 border-t border-slate-800/80 flex flex-wrap items-center justify-between gap-2">
                          <div className="flex items-center gap-2">
                            <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-sky-950 text-sky-300 border border-sky-800">
                              {item.finding.legal_basis.norm_nature}
                            </span>
                            <span className="text-xs text-slate-300 font-medium">
                              {item.finding.legal_basis.article}
                            </span>
                          </div>

                          <a
                            href={item.finding.legal_basis.lex_uz_url}
                            target="_blank"
                            rel="noreferrer"
                            className="text-xs font-semibold text-sky-400 hover:text-sky-300 hover:underline flex items-center gap-1 transition-colors"
                          >
                            <span>Lex.uz da ko'rish</span>
                            <ExternalLink className="w-3.5 h-3.5" />
                          </a>
                        </div>
                      </div>
                    ) : (
                      <div className="h-full flex items-center justify-center p-6 bg-slate-950/40 rounded-xl border border-dashed border-slate-800 text-slate-400">
                        <div className="text-center space-y-1">
                          <Check className="w-5 h-5 text-emerald-400 mx-auto" />
                          <p className="text-xs font-medium text-slate-300">Band qonunchilikka muvofiq</p>
                          <p className="text-[11px] text-slate-500">Tahrir kiritish talab etilmaydi</p>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};
