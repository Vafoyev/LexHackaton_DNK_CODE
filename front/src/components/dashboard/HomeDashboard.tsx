import React, { useEffect, useRef, useState } from 'react';
import { AlertTriangle, ArrowRight, ChevronRight, ExternalLink, Loader2, RefreshCw, Upload } from 'lucide-react';
import { AnalysisResult, ProgressEvent } from '../../types/contract';
import { useAuth } from '../../context/AuthContext';
import { ApiService, ChatError, LawChangeItem, LawChangesReport, RecentAnalysis } from '../../services/api';
import { displayName } from '../../lib/utils';
import { Alert, AlertDescription } from '../ui/alert';
import { Badge } from '../ui/badge';
import { Button } from '../ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '../ui/card';
import { Progress } from '../ui/progress';
import { Skeleton } from '../ui/skeleton';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../ui/tabs';
import { Toggle } from '../ui/toggle';

interface HomeDashboardProps {
  currentAnalysis: AnalysisResult;
  onOpenContract: (contract: AnalysisResult) => void;
  onOpenScan: () => void;
  onAnalyzeDemo: () => void;
  onAnalyzeFile: (file: File) => void;
  isLoading: boolean;
  progress: ProgressEvent | null;
  onGoToDocuments: () => void;
  onGoToLaws: () => void;
}

interface RecentDocument {
  id: string;
  title: string;
  date: string;
  score: number;
  redCount: number;
  open: () => void;
}

const formatDate = (iso: string) => {
  const d = new Date(iso);
  return Number.isNaN(d.getTime())
    ? ''
    : d.toLocaleDateString('uz-UZ', { day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' });
};

/** Tahlil qoidalarida ishlatiladigan asosiy normalar (statik ro'yxat) */
const CORE_LAWS = [
  {
    id: 'fk-707',
    code: 'FK 707-modda',
    imperative: true,
    title: 'Haq evaziga xizmat ko‘rsatish shartnomasini bekor qilish',
    summary: 'Buyurtmachi shartnomani bekor qilishda Ijrochiga amalda qilingan xarajatlarni to‘lashi shart.',
    url: 'https://lex.uz/docs/111189#163821',
  },
  {
    id: 'fk-326',
    code: 'FK 326-modda',
    imperative: false,
    title: 'Neustoykani (penya va jarimani) sud orqali kamaytirish',
    summary: 'Nomutanosib yuqori neustoyka sud tomonidan kamaytirilishi mumkin.',
    url: 'https://lex.uz/docs/111189#161220',
  },
  {
    id: 'orq-547',
    code: 'O‘RQ-547, 15–20-moddalar',
    imperative: true,
    title: 'Shaxsiy ma\'lumotlar xavfsizligi',
    summary: 'Shaxsiy ma\'lumotlarni roziliksiz qayta ishlash yoki tarqatish man etiladi.',
    url: 'https://lex.uz/docs/4396419',
  },
  {
    id: 'fk-324',
    code: 'FK 324 va 333-moddalar',
    imperative: false,
    title: 'Zararni to‘lash majburiyati va javobgarlik chegarasi',
    summary: 'Tomonlar kelishuv bilan moddiy javobgarlikning yuqori chegarasini belgilashi mumkin.',
    url: 'https://lex.uz/docs/111189#161205',
  },
];

const MONTHS = ['yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun', 'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr'];

/** "2026-11-13" -> "13-noyabr 2026" */
const formatUzDate = (iso: string | null | undefined) => {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso || '');
  return m ? `${Number(m[3])}-${MONTHS[Number(m[2]) - 1]} ${m[1]}` : '';
};

const scoreTone = (score: number) =>
  score < 70
    ? { text: 'text-rose-600 dark:text-rose-400', bar: 'bg-rose-500' }
    : score < 90
    ? { text: 'text-amber-600 dark:text-amber-400', bar: 'bg-amber-500' }
    : { text: 'text-emerald-600 dark:text-emerald-400', bar: 'bg-emerald-500' };

const ChangeRow: React.FC<{ item: LawChangeItem }> = ({ item }) => (
  <li className="space-y-1 px-4 py-3.5">
    <div className="flex items-center justify-between gap-3">
      <p className="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-1 text-sm font-medium">
        <span>{item.code}</span>
        {item.used_in_analysis && <Badge variant="warning">Tahlilda ishlatiladi</Badge>}
      </p>
      <Button asChild variant="link" size="sm" className="h-auto shrink-0 gap-1 p-0 text-xs">
        <a href={item.url} target="_blank" rel="noopener noreferrer" aria-label={`${item.code}: Lex.uz da ochish`}>
          Lex.uz <ExternalLink className="h-3 w-3" aria-hidden="true" />
        </a>
      </Button>
    </div>
    <p className="text-sm text-foreground/90">{item.title}</p>
    <p className="text-xs text-muted-foreground">
      O‘zgargan: {formatUzDate(item.changed_on)}, {item.amended_by}-sonli {item.amended_by_kind.toLowerCase()}
      {item.changed_parts.length ? ` (${item.changed_parts.join(', ')})` : ''}
      {item.effective_from ? `. Kuchga kirish: ${formatUzDate(item.effective_from)}` : ''}
    </p>
  </li>
);

/** O'zgargan normalar: korpusdagi Lex.uz tahrir izohlaridan (jonli yangilanish emas) */
const ChangedLaws: React.FC = () => {
  const [onlyUsed, setOnlyUsed] = useState(false);
  const [report, setReport] = useState<LawChangesReport | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let cancelled = false;
    setReport(null);
    setError(null);
    ApiService.getLawChanges(5, onlyUsed)
      .then((r) => !cancelled && setReport(r))
      .catch((e) => !cancelled && setError(e instanceof ChatError ? e.message : "O'zgargan normalarni yuklab bo'lmadi."));
    return () => {
      cancelled = true;
    };
  }, [onlyUsed, attempt]);

  return (
    <div className="space-y-3">
      <div className="flex items-start justify-between gap-3 px-4 pt-3">
        <p className="text-xs text-muted-foreground" aria-live="polite">
          {report
            ? `Lex.uz bazasidagi so‘nggi o‘zgarish: ${formatUzDate(report.snapshot_latest)}. ${report.total_changed_articles} ta modda o‘zgartirilgan${
                report.affecting_analysis ? `, ${report.affecting_analysis} tasi tahlil qoidalarimizda ishlatiladi` : ''
              }.`
            : error
            ? ''
            : 'Yuklanmoqda…'}
        </p>
        <Toggle
          size="sm"
          variant="outline"
          pressed={onlyUsed}
          onPressedChange={setOnlyUsed}
          className="shrink-0 text-xs"
          aria-label="Faqat tahlilda ishlatiladigan normalar"
        >
          Tahlilda ishlatiladi
        </Toggle>
      </div>

      {error && (
        <div className="px-4 pb-4">
          <Alert role="alert">
            <AlertTriangle className="h-4 w-4" aria-hidden="true" />
            <AlertDescription className="flex flex-wrap items-center gap-3">
              <span className="flex-1">{error}</span>
              <Button type="button" size="sm" variant="outline" className="gap-1" onClick={() => setAttempt((n) => n + 1)}>
                <RefreshCw className="h-3.5 w-3.5" aria-hidden="true" /> Qayta urinish
              </Button>
            </AlertDescription>
          </Alert>
        </div>
      )}

      {!report && !error && (
        <ul className="divide-y" aria-busy="true" aria-label="O‘zgargan normalar yuklanmoqda">
          {[0, 1, 2].map((i) => (
            <li key={i} className="space-y-2 px-4 py-3.5">
              <Skeleton className="h-4 w-1/3" />
              <Skeleton className="h-4 w-4/5" />
              <Skeleton className="h-3 w-2/3" />
            </li>
          ))}
        </ul>
      )}

      {report && (
        <>
          <ul className="divide-y border-t" aria-label="So‘nggi o‘zgargan normalar">
            {report.items.length ? (
              report.items.map((i) => <ChangeRow key={i.id} item={i} />)
            ) : (
              <li className="px-4 py-6 text-center text-sm text-muted-foreground">Bunday normalar topilmadi.</li>
            )}
          </ul>
          <p className="px-4 pb-3 text-[11px] text-muted-foreground">{report.source_note}</p>
        </>
      )}
    </div>
  );
};

export const HomeDashboard: React.FC<HomeDashboardProps> = ({
  currentAnalysis,
  onOpenContract,
  onOpenScan,
  onAnalyzeDemo,
  onAnalyzeFile,
  isLoading,
  progress,
  onGoToDocuments,
  onGoToLaws,
}) => {
  const { user } = useAuth();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [dragOver, setDragOver] = useState(false);

  // Haqiqiy tahlillar tarixi (backend `/analyses`)
  const [recent, setRecent] = useState<RecentAnalysis[] | null>(null);
  const [recentError, setRecentError] = useState<string | null>(null);
  const [openError, setOpenError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setRecent(null);
    setRecentError(null);
    ApiService.listAnalyses()
      .then((list) => !cancelled && setRecent(list.filter((a) => a.status === 'COMPLETED')))
      .catch((e) => !cancelled && setRecentError(e instanceof Error ? e.message : "Hujjatlar ro'yxatini olib bo'lmadi."));
    return () => {
      cancelled = true;
    };
  }, [user?.id, currentAnalysis.id]);

  const documents: RecentDocument[] = (recent ?? []).map((a) => ({
    id: a.id,
    title: a.filename || 'Shartnoma',
    date: formatDate(a.created_at),
    score: Math.max(0, Math.min(100, 100 - (a.overall_risk_score ?? 0))),
    redCount: a.summary?.red_count ?? 0,
    open: () => {
      setOpenError(null);
      ApiService.loadAnalysis(a.id, a.contract_id)
        .then(onOpenContract)
        .catch((e) => setOpenError(e instanceof Error ? e.message : "Tahlilni ochib bo'lmadi."));
    },
  }));

  // Ko'rsatkichlar ro'yxatdagi hujjatlardan hisoblanadi (alohida o'ylab topilgan raqamlar yo'q)
  const totalRed = documents.reduce((sum, d) => sum + d.redCount, 0);
  const avgScore = documents.length ? Math.round(documents.reduce((sum, d) => sum + d.score, 0) / documents.length) : null;
  const firstName = displayName(user?.full_name);

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    const file = e.dataTransfer.files?.[0];
    if (file && !isLoading) onAnalyzeFile(file);
  };

  return (
    <div className="mx-auto max-w-6xl space-y-6 px-4 py-6 sm:px-6 lg:px-8">
      <header className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div className="min-w-0">
          <h1 className="text-2xl font-semibold tracking-tight">Xush kelibsiz{firstName ? `, ${firstName}` : ''}</h1>
          <p className="mt-1 text-sm text-muted-foreground">Shartnomani yuklang: xavflarni topib, tavsiya etilgan tahrirni ko‘rsatamiz.</p>
        </div>
        <div className="flex shrink-0 items-center gap-2">
          <Button variant="ghost" onClick={onAnalyzeDemo} disabled={isLoading}>
            Namunani sinash
          </Button>
          <Button onClick={() => fileInputRef.current?.click()} disabled={isLoading} className="gap-2">
            {isLoading ? <Loader2 className="h-4 w-4 animate-spin" aria-hidden="true" /> : <Upload className="h-4 w-4" aria-hidden="true" />}
            {isLoading ? progress?.message || 'Tahlil qilinmoqda…' : 'Shartnoma yuklash'}
          </Button>
          <input
            ref={fileInputRef}
            type="file"
            accept=".docx,.pdf,.txt"
            className="hidden"
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) onAnalyzeFile(file);
              e.target.value = '';
            }}
          />
        </div>
      </header>

      {/* Ko'rsatkichlar */}
      <Card>
        <dl className="grid grid-cols-3 divide-x">
          <div className="px-4 py-3 sm:px-5 sm:py-4">
            <dt className="text-xs text-muted-foreground">Tahlil qilingan</dt>
            <dd className="mt-0.5 text-xl font-semibold tabular-nums sm:text-2xl">{documents.length}</dd>
          </div>
          <div className="px-4 py-3 sm:px-5 sm:py-4">
            <dt className="text-xs text-muted-foreground">Qizil bandlar</dt>
            <dd className={`mt-0.5 text-xl font-semibold tabular-nums sm:text-2xl ${totalRed ? 'text-rose-600 dark:text-rose-400' : ''}`}>{totalRed}</dd>
          </div>
          <div className="px-4 py-3 sm:px-5 sm:py-4">
            <dt className="text-xs text-muted-foreground">O‘rtacha xavfsizlik bali</dt>
            <dd className={`mt-0.5 text-xl font-semibold tabular-nums sm:text-2xl ${avgScore === null ? 'text-muted-foreground' : scoreTone(avgScore).text}`}>
              {avgScore === null ? '—' : avgScore}
              {avgScore !== null && <span className="text-sm font-normal text-muted-foreground">/100</span>}
            </dd>
          </div>
        </dl>
      </Card>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
        {/* Hujjatlar */}
        <section
          className="lg:col-span-7"
          aria-labelledby="docs-title"
          onDragOver={(e) => {
            e.preventDefault();
            setDragOver(true);
          }}
          onDragLeave={() => setDragOver(false)}
          onDrop={handleDrop}
        >
          <div className="mb-2 flex items-center justify-between">
            <h2 id="docs-title" className="text-base font-semibold">
              Avvalgi analiz qilingan hujjatlar
            </h2>
            <Button variant="ghost" size="sm" onClick={onGoToDocuments} className="gap-1 text-xs text-muted-foreground">
              Barchasi <ArrowRight className="h-3.5 w-3.5" aria-hidden="true" />
            </Button>
          </div>

          <Card className={`overflow-hidden transition-shadow ${dragOver ? 'ring-2 ring-primary' : ''}`}>
            {recent === null && !recentError && (
              <div className="space-y-3 p-4" role="status" aria-label="Hujjatlar yuklanmoqda">
                <Skeleton className="h-10 w-full" />
                <Skeleton className="h-10 w-full" />
              </div>
            )}
            {recentError && (
              <Alert role="alert" className="m-3 w-auto">
                <AlertTriangle className="h-4 w-4" aria-hidden="true" />
                <AlertDescription>{recentError}</AlertDescription>
              </Alert>
            )}
            {openError && (
              <Alert variant="destructive" role="alert" className="m-3 w-auto">
                <AlertDescription>{openError}</AlertDescription>
              </Alert>
            )}
            {recent !== null && documents.length === 0 && (
              <div className="p-6 text-center">
                <p className="text-sm font-medium">Hali tahlil qilingan hujjat yo‘q</p>
                <p className="mt-1 text-xs text-muted-foreground">Birinchi shartnomangizni yuklang yoki namunani sinab ko‘ring.</p>
                <Button size="sm" className="mt-3 gap-1.5" onClick={onOpenScan}>
                  <Upload className="h-3.5 w-3.5" aria-hidden="true" /> Shartnoma yuklash
                </Button>
              </div>
            )}
            <ul className="divide-y">
              {documents.map((doc) => {
                const tone = scoreTone(doc.score);
                return (
                  <li key={doc.id}>
                    <Button
                      type="button"
                      variant="ghost"
                      onClick={doc.open}
                      className="group h-auto w-full justify-start gap-4 whitespace-normal rounded-none px-4 py-3.5 text-left font-normal"
                    >
                      <span className="min-w-0 flex-1">
                        <span className="line-clamp-2 block text-sm font-medium sm:truncate">{doc.title}</span>
                        <span className="mt-0.5 line-clamp-2 block text-xs text-muted-foreground sm:truncate">
                          {doc.date}
                        </span>
                        {doc.redCount > 0 && (
                          <span className="mt-0.5 block text-xs font-medium text-rose-600 dark:text-rose-400">{doc.redCount} ta qizil band</span>
                        )}
                      </span>
                      <span className="w-20 shrink-0 text-right">
                        <span className={`block text-base font-semibold tabular-nums ${tone.text}`}>
                          {doc.score}
                          <span className="text-xs font-normal text-muted-foreground">/100</span>
                        </span>
                        <Progress value={doc.score} className="mt-1.5 h-1 bg-muted" indicatorClassName={tone.bar} aria-label={`Xavfsizlik bali ${doc.score}/100`} />
                      </span>
                      <ChevronRight className="h-4 w-4 shrink-0 text-muted-foreground/60 group-hover:text-foreground" aria-hidden="true" />
                    </Button>
                  </li>
                );
              })}
            </ul>
          </Card>
          <p className="mt-2 hidden text-xs text-muted-foreground sm:block">Faylni shu yerga tashlab ham yuklash mumkin (.docx, .pdf, .txt).</p>
        </section>

        {/* Qonunlar */}
        <section className="lg:col-span-5" aria-labelledby="laws-title">
          <div className="mb-2 flex items-center justify-between">
            <h2 id="laws-title" className="text-base font-semibold">
              Yangi qonunlar & Lex.uz
            </h2>
            <Button variant="ghost" size="sm" onClick={onGoToLaws} className="gap-1 text-xs text-muted-foreground">
              Barchasi <ArrowRight className="h-3.5 w-3.5" aria-hidden="true" />
            </Button>
          </div>

          <Card>
            <Tabs defaultValue="changed">
              <CardHeader className="p-3 pb-0">
                <TabsList className="grid w-full grid-cols-2">
                  <TabsTrigger value="changed" className="text-xs">O‘zgargan normalar</TabsTrigger>
                  <TabsTrigger value="core" className="text-xs">Asosiy normalar</TabsTrigger>
                </TabsList>
                <CardTitle className="sr-only">Qonunchilikdagi o‘zgarishlar</CardTitle>
              </CardHeader>

              <TabsContent value="changed" className="mt-0">
                <ChangedLaws />
              </TabsContent>

              <TabsContent value="core" className="mt-0">
                <CardContent className="p-0 pt-3">
                  <ul className="divide-y border-t">
                    {CORE_LAWS.map((law) => (
                      <li key={law.id} className="px-4 py-3.5">
                        <div className="flex items-center justify-between gap-3">
                          <p className="flex min-w-0 items-center gap-2 text-sm font-medium">
                            <span className="truncate">{law.code}</span>
                            <span className="flex shrink-0 items-center gap-1 text-xs font-normal text-muted-foreground">
                              <span className={`h-1.5 w-1.5 rounded-full ${law.imperative ? 'bg-rose-500' : 'bg-slate-400'}`} aria-hidden="true" />
                              {law.imperative ? 'Imperativ' : 'Dispozitiv'}
                            </span>
                          </p>
                          <Button asChild variant="link" size="sm" className="h-auto shrink-0 gap-1 p-0 text-xs">
                            <a href={law.url} target="_blank" rel="noopener noreferrer" aria-label={`${law.code}: Lex.uz da ochish`}>
                              Lex.uz <ExternalLink className="h-3 w-3" aria-hidden="true" />
                            </a>
                          </Button>
                        </div>
                        <p className="mt-1 text-sm text-foreground/90">{law.title}</p>
                        <p className="mt-0.5 line-clamp-2 text-xs text-muted-foreground">{law.summary}</p>
                      </li>
                    ))}
                  </ul>
                </CardContent>
              </TabsContent>
            </Tabs>
          </Card>
        </section>
      </div>
    </div>
  );
};
