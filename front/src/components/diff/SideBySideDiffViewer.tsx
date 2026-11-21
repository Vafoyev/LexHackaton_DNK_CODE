import React, { useState, useEffect, useRef } from 'react';
import { AnalysisResult, Finding, RiskLevel } from '../../types/contract';
import { Check, Copy, ExternalLink, Scale, Search, ShieldAlert, Sparkles, TriangleAlert } from 'lucide-react';
import { Badge } from '../ui/badge';
import { Button } from '../ui/button';
import { Card, CardContent, CardHeader } from '../ui/card';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '../ui/dialog';
import { Input } from '../ui/input';
import { Tabs, TabsList, TabsTrigger } from '../ui/tabs';
import { Tooltip, TooltipContent, TooltipTrigger } from '../ui/tooltip';

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

  const riskTone = (level: RiskLevel) =>
    level === 'RED'
      ? 'border-rose-200 bg-rose-50/60 dark:border-rose-900/60 dark:bg-card hover:border-rose-400'
      : level === 'YELLOW'
      ? 'border-amber-200 bg-amber-50/60 dark:border-amber-900/60 dark:bg-card hover:border-amber-400'
      : level === 'GREEN'
      ? 'border-emerald-200 bg-emerald-50/40 dark:border-border dark:bg-card/60'
      : '';

  const riskBadge = (level: RiskLevel) =>
    level === 'RED'
      ? { variant: 'danger' as const, label: 'Qizil: huquqiy xavf', dot: 'bg-rose-500' }
      : level === 'YELLOW'
      ? { variant: 'warning' as const, label: 'Sariq: tijoriy xavf', dot: 'bg-amber-500' }
      : level === 'GREEN'
      ? { variant: 'success' as const, label: 'Yashil: xavfsiz', dot: 'bg-emerald-500' }
      : { variant: 'neutral' as const, label: 'Kulrang', dot: 'bg-slate-500' };

  const FILTERS: { value: RiskLevel | 'ALL' | 'RISKS_ONLY'; label: string; dot?: string }[] = [
    { value: 'RISKS_ONLY', label: `Xavfli bandlar (${analysis.summary.red_count + analysis.summary.yellow_count + analysis.summary.gray_count})` },
    { value: 'ALL', label: `Barchasi (${analysis.clauses.length})` },
    { value: 'RED', label: `Qizil (${analysis.summary.red_count})`, dot: 'bg-red-500' },
    { value: 'YELLOW', label: `Sariq (${analysis.summary.yellow_count})`, dot: 'bg-amber-500' },
    { value: 'GREEN', label: `Yashil (${analysis.summary.green_count})`, dot: 'bg-emerald-500' },
  ];

  return (
    <div className="space-y-6">
      {/* Filtrlar va qidiruv */}
      <Card>
        <CardContent className="flex flex-col items-stretch justify-between gap-4 p-4 sm:flex-row sm:items-center">
          <Tabs value={filter} onValueChange={(v) => setFilter(v as RiskLevel | 'ALL' | 'RISKS_ONLY')} className="min-w-0">
            <TabsList className="h-auto max-w-full justify-start overflow-x-auto">
              {FILTERS.map((f) => (
                <TabsTrigger key={f.value} value={f.value} className="gap-1.5 whitespace-nowrap text-xs">
                  {f.value === 'RISKS_ONLY' && <ShieldAlert className="h-3.5 w-3.5" aria-hidden="true" />}
                  {f.dot && <span className={`h-2 w-2 rounded-full ${f.dot}`} aria-hidden="true" />}
                  {f.label}
                </TabsTrigger>
              ))}
            </TabsList>
          </Tabs>

          <div className="relative min-w-[240px]">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" aria-hidden="true" />
            <Input
              type="search"
              placeholder="Band matni yoki modda qidirish…"
              aria-label="Bandlarni qidirish"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9"
            />
          </div>
        </CardContent>
      </Card>

      {/* Bandlar */}
      <div className="space-y-4">
        {filteredClauses.length === 0 ? (
          <Card className="border-dashed">
            <CardContent className="py-12 text-center text-muted-foreground">
              <Scale className="mx-auto mb-2 h-10 w-10 opacity-50" aria-hidden="true" />
              <p className="text-sm font-medium">Ushbu filtr bo‘yicha bandlar topilmadi</p>
            </CardContent>
          </Card>
        ) : (
          filteredClauses.map((item) => {
            const hasFinding = !!item.finding;
            const isRed = item.risk_level === 'RED';
            const isYellow = item.risk_level === 'YELLOW';
            const isAccepted = item.finding ? acceptedFindings[item.finding.id] : false;
            const isFocused = focusedClauseId === item.id;
            const badge = riskBadge(item.risk_level);

            return (
              <Card
                key={item.id}
                ref={(el) => (clauseRefs.current[item.id] = el)}
                className={`transition-all duration-300 ${
                  isFocused ? 'border-primary ring-2 ring-primary/60' : riskTone(item.risk_level)
                }`}
              >
                <CardHeader className="flex flex-row flex-wrap items-center justify-between gap-2 space-y-0 border-b p-4 sm:px-5">
                  <div className="flex items-center gap-2.5">
                    <Badge variant="outline" className="font-mono text-xs sm:text-sm">
                      {item.clause_number}
                    </Badge>
                    <h3 className="text-sm font-semibold">{item.title}</h3>
                  </div>
                  <div className="flex items-center gap-2">
                    <Badge variant={badge.variant} className="gap-1.5">
                      <span className={`h-2 w-2 rounded-full ${badge.dot}`} aria-hidden="true" />
                      {badge.label}
                    </Badge>
                    {item.finding && (
                      <Badge variant="outline" className="font-mono text-[10px]">
                        {item.finding.verification_status}
                      </Badge>
                    )}
                  </div>
                </CardHeader>

                <CardContent className="grid grid-cols-1 items-start gap-5 p-4 sm:p-5 lg:grid-cols-2">
                  {/* Asl matn */}
                  <div className="space-y-3 rounded-xl border bg-background/70 p-4">
                    <div className="flex items-center justify-between text-[11px] font-semibold text-muted-foreground">
                      <span>Hujjatdagi asl tahrir</span>
                      {isRed && <span className="flex items-center gap-1 text-[10px] font-bold text-rose-600 dark:text-rose-400"><TriangleAlert className="h-3 w-3" aria-hidden="true" /> Qonunga ziddiyat</span>}
                      {isYellow && <span className="flex items-center gap-1 text-[10px] font-bold text-amber-600 dark:text-amber-400"><TriangleAlert className="h-3 w-3" aria-hidden="true" /> Asimmetrik shart</span>}
                    </div>

                    <p
                      className={`text-xs leading-relaxed sm:text-sm ${
                        isRed
                          ? 'rounded-lg border border-rose-200 bg-rose-50/70 p-2.5 font-medium text-rose-950 dark:border-red-900/40 dark:bg-red-950/20 dark:text-rose-200'
                          : isYellow
                          ? 'rounded-lg border border-amber-200 bg-amber-50/70 p-2.5 font-medium text-amber-950 dark:border-amber-900/40 dark:bg-amber-950/20 dark:text-amber-200'
                          : 'text-foreground/80'
                      }`}
                    >
                      “{item.finding?.original_quote || item.original_text}”
                    </p>

                    {item.finding && (
                      <div className="flex items-center justify-between gap-2 border-t pt-2 text-xs">
                        <span className="flex min-w-0 items-center gap-1.5 truncate text-[11px] font-semibold">
                          <TriangleAlert className="h-3.5 w-3.5 shrink-0 text-amber-500" aria-hidden="true" />
                          <span className="truncate">{item.finding.issue_title}</span>
                        </span>
                        <Button type="button" variant="outline" size="sm" className="shrink-0 gap-1.5" onClick={() => setSelectedFindingModal(item.finding!)}>
                          Huquqiy tahlil
                          <ExternalLink className="h-3 w-3" aria-hidden="true" />
                        </Button>
                      </div>
                    )}
                  </div>

                  {/* Tavsiya */}
                  <div className="space-y-3">
                    {hasFinding && item.finding ? (
                      <div className="space-y-3 rounded-xl border border-emerald-200 bg-background/80 p-4 dark:border-emerald-900/40">
                        <div className="flex items-center justify-between gap-2">
                          <span className="flex items-center gap-1.5 text-[11px] font-semibold text-emerald-700 dark:text-emerald-400">
                            <Sparkles className="h-3.5 w-3.5" aria-hidden="true" />
                            LexGuard tavsiya etgan tahrir
                          </span>
                          <div className="flex items-center gap-1.5">
                            <Tooltip>
                              <TooltipTrigger asChild>
                                <Button type="button" variant="outline" size="sm" className="gap-1" onClick={() => handleCopyRedline(item.finding!.id, item.finding!.suggested_redline)}>
                                  {copiedId === item.finding.id ? (
                                    <>
                                      <Check className="h-3.5 w-3.5 text-emerald-600 dark:text-emerald-400" aria-hidden="true" />
                                      <span className="text-emerald-600 dark:text-emerald-400">Nusxalandi</span>
                                    </>
                                  ) : (
                                    <>
                                      <Copy className="h-3.5 w-3.5" aria-hidden="true" />
                                      Nusxa
                                    </>
                                  )}
                                </Button>
                              </TooltipTrigger>
                              <TooltipContent>Tahrirni nusxalash</TooltipContent>
                            </Tooltip>

                            <Button
                              type="button"
                              size="sm"
                              variant={isAccepted ? 'default' : 'outline'}
                              aria-pressed={isAccepted}
                              className={`gap-1 ${isAccepted ? 'bg-emerald-600 text-white hover:bg-emerald-600/90 dark:bg-emerald-600' : ''}`}
                              onClick={() => handleToggleAccept(item.finding!.id)}
                            >
                              <Check className="h-3.5 w-3.5" aria-hidden="true" />
                              {isAccepted ? 'Qabul qilindi' : 'Qabul qilish'}
                            </Button>
                          </div>
                        </div>

                        <div className="rounded-lg border border-emerald-200 bg-emerald-50 p-3 text-xs font-medium leading-relaxed text-emerald-950 dark:border-emerald-900/50 dark:bg-emerald-950/20 dark:text-emerald-300 sm:text-sm">
                          “{item.finding.suggested_redline}”
                        </div>

                        <div className="flex flex-wrap items-center justify-between gap-2 border-t pt-2">
                          <div className="flex items-center gap-2">
                            <Badge variant="outline" className="text-[10px]">
                              {item.finding.legal_basis.norm_nature}
                            </Badge>
                            <span className="text-xs font-medium">{item.finding.legal_basis.article}</span>
                          </div>
                          <Button asChild variant="link" size="sm" className="h-auto gap-1 p-0 text-xs">
                            <a href={item.finding.legal_basis.lex_uz_url} target="_blank" rel="noreferrer">
                              <img src="/lex_uz.svg" alt="" aria-hidden="true" className="h-3.5 w-auto object-contain" />
                              Lex.uz da ko‘rish
                              <ExternalLink className="h-3.5 w-3.5" aria-hidden="true" />
                            </a>
                          </Button>
                        </div>
                      </div>
                    ) : (
                      <div className="flex h-full items-center justify-center rounded-xl border border-dashed bg-muted/40 p-6 text-muted-foreground">
                        <div className="space-y-1 text-center">
                          <Check className="mx-auto h-5 w-5 text-emerald-500" aria-hidden="true" />
                          <p className="text-xs font-medium text-foreground">Band qonunchilikka muvofiq</p>
                          <p className="text-[11px]">Qo‘shimcha tahrir kiritish talab etilmaydi</p>
                        </div>
                      </div>
                    )}
                  </div>
                </CardContent>
              </Card>
            );
          })
        )}
      </div>

      {/* Huquqiy tahlil */}
      <Dialog open={!!selectedFindingModal} onOpenChange={(open) => !open && setSelectedFindingModal(null)}>
        <DialogContent className="max-w-lg">
          {selectedFindingModal && (
            <>
              <DialogHeader>
                <div className="flex items-center gap-2 pr-6">
                  <Badge variant="danger" className="font-mono text-[10px]">
                    {selectedFindingModal.clause_number}-band
                  </Badge>
                  <DialogTitle className="text-sm">{selectedFindingModal.issue_title}</DialogTitle>
                </div>
                <DialogDescription className="sr-only">Aniqlangan muammo, huquqiy asos va tavsiya etilgan tuzatish maqsadi</DialogDescription>
              </DialogHeader>

              <div className="space-y-3 text-xs">
                <div className="rounded-xl border border-rose-200 bg-rose-50 p-3.5 dark:border-rose-900/40 dark:bg-rose-950/30">
                  <p className="mb-1 text-[11px] font-bold text-rose-800 dark:text-rose-300">Aniqlangan muammo va huquqiy xavf</p>
                  <p className="leading-relaxed text-rose-950 dark:text-rose-100">{selectedFindingModal.issue_explanation}</p>
                </div>

                <div className="space-y-2 rounded-xl border border-zinc-200 bg-zinc-50 p-3.5 dark:border-zinc-900/40 dark:bg-zinc-950/30">
                  <p className="text-[11px] font-bold text-zinc-800 dark:text-zinc-300">Tavsiya etilgan tuzatish maqsadi</p>
                  <p className="leading-relaxed text-foreground/80">{selectedFindingModal.redline_reasoning}</p>
                  <div className="flex items-center justify-between border-t border-zinc-200 pt-2 text-[11px] dark:border-zinc-900/30">
                    <span className="font-mono font-semibold text-zinc-800 dark:text-zinc-300">{selectedFindingModal.legal_basis.article}</span>
                    <Button asChild variant="link" size="sm" className="h-auto gap-1 p-0 text-[11px]">
                      <a href={selectedFindingModal.legal_basis.lex_uz_url} target="_blank" rel="noreferrer">
                        Lex.uz da ko‘rish <ExternalLink className="h-3 w-3" aria-hidden="true" />
                      </a>
                    </Button>
                  </div>
                </div>
              </div>

              <DialogFooter>
                <Button type="button" variant="secondary" onClick={() => setSelectedFindingModal(null)}>
                  Yopish
                </Button>
              </DialogFooter>
            </>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
};
