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
  BookOpen,
  AlertCircle,
  X
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
  const [selectedFindingModal, setSelectedFindingModal] = useState<Finding | null>(null);
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
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4 p-4 liquid-glass rounded-2xl border border-slate-200 dark:border-slate-800 shadow-xl">
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 sm:pb-0">
          <button
            onClick={() => setFilter('RISKS_ONLY')}
            className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all flex items-center gap-1.5 ${
              filter === 'RISKS_ONLY'
                ? 'bg-gradient-to-r from-red-600 to-amber-600 text-white shadow-md shadow-red-600/20'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800'
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
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800'
            }`}
          >
            Barchasi ({analysis.clauses.length})
          </button>

          <button
            onClick={() => setFilter('RED')}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all flex items-center gap-1.5 ${
              filter === 'RED'
                ? 'bg-red-600 text-white shadow-md shadow-red-600/20'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800'
            }`}
          >
            <span className="w-2 h-2 rounded-full bg-red-500"></span>
            <span>Qizil ({analysis.summary.red_count})</span>
          </button>

          <button
            onClick={() => setFilter('YELLOW')}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all flex items-center gap-1.5 ${
              filter === 'YELLOW'
                ? 'bg-amber-600 text-white shadow-md shadow-amber-600/20'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800'
            }`}
          >
            <span className="w-2 h-2 rounded-full bg-amber-500"></span>
            <span>Sariq ({analysis.summary.yellow_count})</span>
          </button>

          <button
            onClick={() => setFilter('GREEN')}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all flex items-center gap-1.5 ${
              filter === 'GREEN'
                ? 'bg-emerald-600 text-white shadow-md shadow-emerald-600/20'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800'
            }`}
          >
            <span className="w-2 h-2 rounded-full bg-emerald-500"></span>
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
            className="w-full pl-9 pr-4 py-1.5 bg-slate-100 dark:bg-slate-950/80 border border-slate-200 dark:border-slate-700/80 rounded-xl text-xs text-slate-900 dark:text-white placeholder-slate-500 focus:outline-none focus:border-sky-500 transition-all"
          />
        </div>
      </div>

      {/* Ro'yxat (Cards) */}
      <div className="space-y-4">
        {filteredClauses.length === 0 ? (
          <div className="text-center py-12 liquid-glass rounded-2xl border border-slate-200 dark:border-slate-800 text-slate-500 dark:text-slate-400">
            <Scale className="w-10 h-10 mx-auto text-slate-400 mb-2 opacity-50" />
            <p className="text-sm font-medium">Ushbu filtr bo'yicha bandlar topilmadi</p>
          </div>
        ) : (
          filteredClauses.map((item) => {
            const hasFinding = !!item.finding;
            const isRed = item.risk_level === 'RED';
            const isYellow = item.risk_level === 'YELLOW';
            const isGreen = item.risk_level === 'GREEN';
            const isAccepted = item.finding ? acceptedFindings[item.finding.id] : false;
            const isFocused = focusedClauseId === item.id;

            return (
              <div
                key={item.id}
                ref={(el) => (clauseRefs.current[item.id] = el)}
                className={`transition-all duration-300 rounded-2xl border p-4 sm:p-5 shadow-sm ${
                  isFocused
                    ? 'ring-2 ring-sky-500 bg-sky-50/50 dark:bg-sky-950/20 border-sky-400 dark:border-sky-500/80 shadow-md'
                    : isRed
                    ? 'bg-rose-50/60 dark:bg-slate-900/80 border-rose-200 dark:border-rose-900/60 hover:border-rose-400'
                    : isYellow
                    ? 'bg-amber-50/60 dark:bg-slate-900/80 border-amber-200 dark:border-amber-900/60 hover:border-amber-400'
                    : isGreen
                    ? 'bg-emerald-50/40 dark:bg-slate-900/40 border-emerald-200 dark:border-slate-800/80'
                    : 'bg-white/80 dark:bg-slate-900/60 border-slate-200 dark:border-gray-800'
                }`}
              >
                {/* Band sarlavhasi va teglari */}
                <div className="flex flex-wrap items-center justify-between gap-2 pb-3 mb-3 border-b border-slate-200 dark:border-slate-800/80">
                  <div className="flex items-center gap-2.5">
                    <span className="font-mono text-xs sm:text-sm font-bold text-slate-900 dark:text-white px-2 py-0.5 rounded-lg bg-slate-200 dark:bg-slate-800 border border-slate-300 dark:border-slate-700">
                      {item.clause_number}
                    </span>
                    <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100">
                      {item.title}
                    </h3>
                  </div>

                  <div className="flex items-center gap-2">
                    {/* Risk Badge */}
                    <span
                      className={`text-[11px] font-bold px-2.5 py-1 rounded-full flex items-center gap-1.5 ${
                        isRed
                          ? 'bg-rose-100 dark:bg-rose-500/20 text-rose-800 dark:text-rose-400 border border-rose-300 dark:border-rose-500/30'
                          : isYellow
                          ? 'bg-amber-100 dark:bg-amber-500/20 text-amber-800 dark:text-amber-400 border border-amber-300 dark:border-amber-500/30'
                          : isGreen
                          ? 'bg-emerald-100 dark:bg-emerald-500/20 text-emerald-800 dark:text-emerald-400 border border-emerald-300 dark:border-emerald-500/30'
                          : 'bg-slate-100 dark:bg-gray-500/20 text-slate-700 dark:text-gray-400 border border-slate-300 dark:border-gray-500/30'
                      }`}
                    >
                      <span className={`w-2 h-2 rounded-full ${isRed ? 'bg-rose-500' : isYellow ? 'bg-amber-500' : isGreen ? 'bg-emerald-500' : 'bg-gray-500'}`} />
                      {isRed ? 'QIZIL (Huquqiy Xavf)' : isYellow ? 'SARIQ (Tijoriy Xavf)' : isGreen ? 'YASHIL (Xavfsiz)' : 'KULRANG'}
                    </span>

                    {/* Verification Status */}
                    {item.finding && (
                      <span className="text-[10px] uppercase font-mono px-2 py-0.5 rounded bg-sky-50 dark:bg-slate-800 text-sky-700 dark:text-sky-400 border border-sky-200 dark:border-slate-700 font-semibold">
                        {item.finding.verification_status}
                      </span>
                    )}
                  </div>
                </div>

                {/* Side-by-Side Content */}
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-5 items-start">
                  {/* Chap Ustun: Asl Matn */}
                  <div className="space-y-3 bg-white/70 dark:bg-slate-950/70 p-4 rounded-xl border border-slate-200 dark:border-slate-800/80 shadow-sm">
                    <div className="text-[11px] font-semibold text-slate-500 dark:text-slate-400 flex items-center justify-between">
                      <span>Hujjatdagi asl tahrir</span>
                      {isRed && <span className="text-rose-600 dark:text-rose-400 font-bold text-[10px]">⚠️ Qonunga Ziddiyat</span>}
                      {isYellow && <span className="text-amber-600 dark:text-amber-400 font-bold text-[10px]">⚠️ Asimmetrik Shart</span>}
                    </div>

                    <p className={`text-xs sm:text-sm leading-relaxed ${
                      isRed 
                        ? 'text-rose-950 dark:text-rose-200 bg-rose-50/70 dark:bg-red-950/20 p-2.5 rounded-lg border border-rose-200 dark:border-red-900/40 font-medium' 
                        : isYellow 
                        ? 'text-amber-950 dark:text-amber-200 bg-amber-50/70 dark:bg-amber-950/20 p-2.5 rounded-lg border border-amber-200 dark:border-amber-900/40 font-medium' 
                        : 'text-slate-700 dark:text-slate-300'
                    }`}>
                      "{item.finding?.original_quote || item.original_text}"
                    </p>

                    {item.finding && (
                      <div className="pt-2 flex items-center justify-between border-t border-slate-200 dark:border-slate-800/60 text-xs gap-2">
                        <span className="font-semibold text-slate-700 dark:text-slate-300 truncate text-[11px]">
                          ⚠️ {item.finding.issue_title}
                        </span>
                        <button
                          type="button"
                          onClick={() => setSelectedFindingModal(item.finding!)}
                          className="px-2.5 py-1 rounded-lg bg-sky-50 hover:bg-sky-100 dark:bg-sky-950/40 dark:hover:bg-sky-900/40 text-sky-700 dark:text-sky-300 text-[11px] font-bold flex items-center gap-1.5 transition-colors cursor-pointer border border-sky-200 dark:border-sky-800/50 shrink-0 shadow-sm"
                          title="Batafsil yuridik asos va tahlilni ko'rish"
                        >
                          <span>ℹ️ Huquqiy Tahlil</span>
                          <ExternalLink className="w-3 h-3" />
                        </button>
                      </div>
                    )}
                  </div>

                  {/* O'ng Ustun: Qonuniy Tavsiya va Lex.uz Asosi */}
                  <div className="space-y-3">
                    {hasFinding && item.finding ? (
                      <div className="bg-white/80 dark:bg-slate-950/90 p-4 rounded-xl border border-emerald-200 dark:border-sky-900/40 shadow-sm space-y-3">
                        <div className="flex items-center justify-between">
                          <span className="text-[11px] font-semibold text-emerald-700 dark:text-sky-400 flex items-center gap-1.5">
                            <Sparkles className="w-3.5 h-3.5" />
                            <span>LexGuard Tavsiya Etgan Tahrir</span>
                          </span>

                          <div className="flex items-center gap-1.5">
                            <button
                              onClick={() => handleCopyRedline(item.finding!.id, item.finding!.suggested_redline)}
                              className="p-1.5 rounded-lg bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white transition-all text-[11px] flex items-center gap-1 border border-slate-200 dark:border-slate-700 cursor-pointer"
                              title="Tahrirni nusxalash"
                            >
                              {copiedId === item.finding.id ? (
                                <>
                                  <Check className="w-3.5 h-3.5 text-emerald-600 dark:text-emerald-400" />
                                  <span className="text-emerald-600 dark:text-emerald-400">Nusxalandi</span>
                                </>
                              ) : (
                                <>
                                  <Copy className="w-3.5 h-3.5" />
                                  <span>Nusxa</span>
                                </>
                              )}
                            </button>

                            <button
                              onClick={() => handleToggleAccept(item.finding!.id)}
                              className={`px-2.5 py-1.5 rounded-lg text-[11px] font-semibold transition-all flex items-center gap-1 border cursor-pointer ${
                                isAccepted
                                  ? 'bg-emerald-600 text-white border-emerald-500 shadow-sm'
                                  : 'bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 border-slate-200 dark:border-slate-700'
                              }`}
                            >
                              <Check className="w-3.5 h-3.5" />
                              <span>{isAccepted ? 'Qabul qilindi' : 'Qabul qilish'}</span>
                            </button>
                          </div>
                        </div>

                        {/* Redline Text Box */}
                        <div className="p-3 rounded-lg bg-emerald-50 dark:bg-emerald-950/20 border border-emerald-200 dark:border-emerald-900/50 text-emerald-950 dark:text-emerald-300 text-xs sm:text-sm font-medium leading-relaxed">
                          "{item.finding.suggested_redline}"
                        </div>

                        {/* Lex.uz Giperhavolasi va Qonuniy Asos */}
                        <div className="pt-2 border-t border-slate-200 dark:border-slate-800/80 flex flex-wrap items-center justify-between gap-2">
                          <div className="flex items-center gap-2">
                            <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-sky-100 dark:bg-sky-950 text-sky-800 dark:text-sky-300 border border-sky-300 dark:border-sky-800">
                              {item.finding.legal_basis.norm_nature}
                            </span>
                            <span className="text-xs text-slate-700 dark:text-slate-300 font-medium">
                              {item.finding.legal_basis.article}
                            </span>
                          </div>

                          <a
                            href={item.finding.legal_basis.lex_uz_url}
                            target="_blank"
                            rel="noreferrer"
                            className="text-xs font-semibold text-sky-600 dark:text-sky-400 hover:text-sky-500 hover:underline flex items-center gap-1 transition-colors"
                          >
                            <img src="/lex_uz.svg" alt="" aria-hidden="true" className="h-3.5 w-auto object-contain brightness-110" />
                            <span>Lex.uz da ko'rish</span>
                            <ExternalLink className="w-3.5 h-3.5" />
                          </a>
                        </div>
                      </div>
                    ) : (
                      <div className="h-full flex items-center justify-center p-6 bg-slate-100/60 dark:bg-slate-950/40 rounded-xl border border-dashed border-slate-200 dark:border-slate-800 text-slate-500 dark:text-slate-400">
                        <div className="text-center space-y-1">
                          <Check className="w-5 h-5 text-emerald-500 mx-auto" />
                          <p className="text-xs font-medium text-slate-700 dark:text-slate-300">Band qonunchilikka muvofiq</p>
                          <p className="text-[11px] text-slate-500">Qo‘shimcha tahrir kiritish talab etilmaydi</p>
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

      {/* Huquqiy Tahlil Modali (Juda ko'p yozuvlarni modalda qulay ko'rsatish) */}
      {selectedFindingModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-md animate-in fade-in">
          <div className="relative w-full max-w-lg liquid-glass-card rounded-3xl p-6 sm:p-7 border border-slate-200 dark:border-white/15 shadow-2xl space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-200 dark:border-white/10">
              <div className="flex items-center gap-2">
                <span className="px-2.5 py-0.5 rounded-full bg-rose-100 dark:bg-rose-500/20 text-rose-800 dark:text-rose-400 border border-rose-300 dark:border-rose-500/30 text-[10px] font-bold font-mono">
                  {selectedFindingModal.clause_number}-band
                </span>
                <h3 className="text-sm font-bold text-slate-900 dark:text-white">
                  {selectedFindingModal.issue_title}
                </h3>
              </div>
              <button
                onClick={() => setSelectedFindingModal(null)}
                className="p-1.5 rounded-full hover:bg-slate-200 dark:hover:bg-white/10 text-slate-500 hover:text-slate-900 dark:hover:text-white transition-colors cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="space-y-3 text-xs">
              <div className="p-3.5 rounded-xl bg-rose-50 dark:bg-rose-950/30 border border-rose-200 dark:border-rose-900/40">
                <p className="font-bold text-rose-800 dark:text-rose-300 text-[11px] mb-1">Aniqlangan muammo va huquqiy xavf:</p>
                <p className="text-rose-950 dark:text-rose-100 leading-relaxed font-normal">{selectedFindingModal.issue_explanation}</p>
              </div>

              <div className="p-3.5 rounded-xl bg-sky-50 dark:bg-sky-950/30 border border-sky-200 dark:border-sky-900/40 space-y-2">
                <p className="font-bold text-sky-800 dark:text-sky-300 text-[11px]">Tavsiya etilgan tuzatish maqsadi:</p>
                <p className="text-slate-700 dark:text-slate-300 leading-relaxed font-normal">{selectedFindingModal.redline_reasoning}</p>
                <div className="pt-2 border-t border-sky-200 dark:border-sky-900/30 flex items-center justify-between text-[11px]">
                  <span className="font-mono text-sky-800 dark:text-sky-300 font-semibold">{selectedFindingModal.legal_basis.article}</span>
                  <a
                    href={selectedFindingModal.legal_basis.lex_uz_url}
                    target="_blank"
                    rel="noreferrer"
                    className="text-sky-600 dark:text-sky-400 hover:underline flex items-center gap-1 font-semibold"
                  >
                    <span>Lex.uz da ko‘rish</span>
                    <ExternalLink className="w-3 h-3" />
                  </a>
                </div>
              </div>
            </div>

            <div className="pt-2 flex justify-end">
              <button
                onClick={() => setSelectedFindingModal(null)}
                className="px-4 py-2 rounded-xl bg-slate-200 hover:bg-slate-300 dark:bg-slate-800 dark:hover:bg-slate-700 text-xs font-semibold text-slate-800 dark:text-white transition-all cursor-pointer"
              >
                Yopish
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
