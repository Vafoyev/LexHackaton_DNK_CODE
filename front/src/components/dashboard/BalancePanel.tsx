import React, { useEffect, useMemo, useState } from 'react';
import { AlertTriangle, Check, Copy, ExternalLink, Loader2, Scale } from 'lucide-react';
import { AnalysisResult } from '../../types/contract';
import { ApiService, BalanceReport, BalanceTopic, ChatError } from '../../services/api';
import { Alert, AlertDescription } from '../ui/alert';
import { Badge } from '../ui/badge';
import { Button } from '../ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '../ui/collapsible';
import { Skeleton } from '../ui/skeleton';

interface BalancePanelProps {
  analysis: AnalysisResult;
}

const VERDICT_VARIANT: Record<BalanceReport['verdict'], 'success' | 'warning' | 'danger'> = {
  BALANCED: 'success',
  BALANCED_HEAVY: 'warning',
  ONE_SIDED_PROVIDER: 'danger',
  ONE_SIDED_RECIPIENT: 'danger',
};

const isSafeUrl = (url: string) => /^https:\/\//i.test(url);

/** Ikki tomon yuk ulushi: chap — majburiyatni bajaruvchi, o'ng — natijani oluvchi. Markazdagi chiziq "teng" nuqtasi. */
const BalanceBar: React.FC<{ report: BalanceReport }> = ({ report }) => {
  const { provider, recipient } = report.sides;
  const noSignal = provider.burden + recipient.burden === 0;
  const label = noSignal
    ? 'Tomonlar o‘rtasida yuk farqi topilmadi'
    : `${provider.name} ${provider.share}%, ${recipient.name} ${recipient.share}%`;
  return (
    <div>
      <div className="mb-1.5 flex items-end justify-between text-xs">
        <div>
          <p className="font-semibold">{provider.name}</p>
          <p className="text-muted-foreground">
            {provider.share}% <span className="text-slate-500">({provider.burden} ball)</span>
          </p>
        </div>
        <div className="text-right">
          <p className="font-semibold">{recipient.name}</p>
          <p className="text-muted-foreground">
            {recipient.share}% <span className="text-slate-500">({recipient.burden} ball)</span>
          </p>
        </div>
      </div>
      <div className="relative h-2.5 overflow-hidden rounded-full bg-muted" role="img" aria-label={`Yuk taqsimoti: ${label}`}>
        {!noSignal && (
          <>
            <div className="absolute inset-y-0 left-0 bg-foreground" style={{ width: `${provider.share}%` }} />
            <div className="absolute inset-y-0 right-0 bg-foreground/35" style={{ width: `${recipient.share}%` }} />
          </>
        )}
        <div className="absolute inset-y-0 left-1/2 w-px bg-foreground/50" aria-hidden="true" />
      </div>
      <p className="mt-1.5 text-[11px] text-muted-foreground">Ustunning uzunligi shu tomonga tushayotgan yuk ulushini ko‘rsatadi; markaz — teng nuqta.</p>
    </div>
  );
};

const CopyButton: React.FC<{ text: string }> = ({ text }) => {
  const [copied, setCopied] = useState(false);
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1800);
    } catch {
      /* clipboard taqiqlangan: foydalanuvchi matnni qo'lda belgilab oladi */
    }
  };
  return (
    <Button type="button" variant="outline" size="sm" onClick={copy} className="h-7 gap-1 text-[11px]">
      {copied ? <Check className="h-3 w-3 text-emerald-500" aria-hidden="true" /> : <Copy className="h-3 w-3" aria-hidden="true" />}
      {copied ? 'Nusxalandi' : 'Nusxalash'}
    </Button>
  );
};

const TopicRow: React.FC<{ topic: BalanceTopic }> = ({ topic }) => {
  const ok = topic.status === 'BALANCED';
  return (
    <li className="py-3">
      <div className="flex items-start gap-3">
        <span
          className={`mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full ${
            ok ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-400' : 'bg-amber-100 text-amber-700 dark:bg-amber-500/15 dark:text-amber-400'
          }`}
          aria-hidden="true"
        >
          {ok ? <Check className="h-3 w-3" /> : <AlertTriangle className="h-3 w-3" />}
        </span>
        <div className="min-w-0 flex-1">
          <p className="text-sm font-medium">
            {topic.label}
            <span className="ml-2 text-xs font-normal text-muted-foreground">
              {topic.clause_numbers.length ? `${topic.clause_numbers.join(', ')}-band` : ''}
            </span>
          </p>
          <p className="mt-0.5 text-xs text-muted-foreground">
            {ok ? 'Ikkala tomon uchun teng.' : `${topic.detail}${topic.burdened_name ? ` Yuk: ${topic.burdened_name} tomonida.` : ''}`}
          </p>
          {!ok && topic.fix && (
            <Collapsible className="mt-2">
              <CollapsibleTrigger asChild>
                <Button type="button" variant="link" size="sm" className="h-auto p-0 text-xs">
                  Ikki tomonga teng tahrir
                </Button>
              </CollapsibleTrigger>
              <CollapsibleContent>
                <div className="mt-2 rounded-lg border border-emerald-200 bg-emerald-50 p-3 dark:border-emerald-500/20 dark:bg-emerald-500/5">
                  <p className="text-xs leading-relaxed text-emerald-900 dark:text-emerald-100">{topic.fix}</p>
                  <div className="mt-2">
                    <CopyButton text={topic.fix} />
                  </div>
                </div>
              </CollapsibleContent>
            </Collapsible>
          )}
        </div>
      </div>
    </li>
  );
};

export const BalancePanel: React.FC<BalancePanelProps> = ({ analysis }) => {
  const clauses = useMemo(
    () =>
      analysis.clauses
        .filter((c) => (c.original_text || '').trim())
        .map((c) => ({ clause_number: c.clause_number, text: c.original_text })),
    [analysis.clauses]
  );
  const docType = analysis.document?.document_type || '';

  const [report, setReport] = useState<BalanceReport | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let cancelled = false;
    setReport(null);
    setError(null);
    if (!clauses.length) return;
    ApiService.getBalance(clauses, docType)
      .then((r) => !cancelled && setReport(r))
      .catch((e) => !cancelled && setError(e instanceof ChatError ? e.message : "Balans tahlili bajarilmadi."));
    return () => {
      cancelled = true;
    };
  }, [clauses, docType, attempt]);

  const loading = !report && !error && clauses.length > 0;
  const issues = report ? report.topics.filter((t) => t.status !== 'BALANCED') : [];

  return (
    <Card aria-labelledby="balance-title" aria-busy={loading}>
      <CardHeader className="flex flex-row flex-wrap items-start justify-between gap-3 space-y-0">
        <div>
          <CardTitle id="balance-title" className="flex items-center gap-2 text-base">
            <Scale className="h-4 w-4 text-amber-500" aria-hidden="true" />
            Tomonlar balansi
          </CardTitle>
          <CardDescription className="mt-1 text-xs">Shartnoma ikki tomondan biriga ortiqcha og‘ir tushmayaptimi?</CardDescription>
        </div>
        {report && <Badge variant={VERDICT_VARIANT[report.verdict]}>{report.verdict_label}</Badge>}
      </CardHeader>

      <CardContent className="space-y-5">
        {loading && (
          <div className="space-y-3" role="status" aria-label="Balans hisoblanmoqda">
            <Skeleton className="h-4 w-3/4" />
            <Skeleton className="h-2.5 w-full rounded-full" />
            <Skeleton className="h-16 w-full" />
          </div>
        )}

        {error && (
          <Alert role="alert">
            <AlertTriangle className="h-4 w-4" aria-hidden="true" />
            <AlertDescription className="flex flex-wrap items-center gap-3">
              <span className="flex-1">{error}</span>
              <Button type="button" size="sm" variant="outline" onClick={() => setAttempt((n) => n + 1)}>
                Qayta urinish
              </Button>
            </AlertDescription>
          </Alert>
        )}

        {report && (
          <>
            <p className="text-sm leading-relaxed">{report.summary}</p>

            <BalanceBar report={report} />

            <div className="flex flex-wrap items-center gap-x-5 gap-y-1 text-xs text-muted-foreground">
              <span>
                Simmetriya: <strong className="text-foreground">{report.score}/100</strong>
              </span>
              <span>{issues.length ? `${issues.length} ta tengsiz mavzu` : 'Tengsiz mavzu yo‘q'}</span>
              {report.confidence === 'LOW' && <span className="text-amber-700 dark:text-amber-400">Ishonch past: tahlil uchun ma’lumot kam</span>}
            </div>

            {report.topics.length > 0 && (
              <ul className="divide-y rounded-xl border bg-muted/30 px-4" aria-label="Mavzular bo‘yicha balans">
                {[...issues, ...report.topics.filter((t) => t.status === 'BALANCED')].map((t) => (
                  <TopicRow key={t.topic} topic={t} />
                ))}
              </ul>
            )}

            <div className="flex flex-wrap items-center gap-2 text-[11px] text-muted-foreground">
              <span>Asos:</span>
              {report.basis.map((b) =>
                isSafeUrl(b.url) ? (
                  <Button key={b.id} asChild variant="outline" size="sm" className="h-6 gap-1 px-1.5 text-[11px] font-normal">
                    <a href={b.url} target="_blank" rel="noopener noreferrer" title={b.title}>
                      {b.code} <ExternalLink className="h-3 w-3" aria-hidden="true" />
                    </a>
                  </Button>
                ) : null
              )}
            </div>

            <Collapsible>
              <CollapsibleTrigger asChild>
                <Button type="button" variant="link" size="sm" className="h-auto p-0 text-[11px] text-muted-foreground">
                  Bu baho qanday hisoblanadi va cheklovlari
                </Button>
              </CollapsibleTrigger>
              <CollapsibleContent>
                <ul className="mt-2 list-disc space-y-1 pl-4 text-[11px] text-muted-foreground">
                  <li>Evristik baho: bekor qilish, penya, javobgarlik, narx/shartni o‘zgartirish va maxfiylik mavzulari tomonlar bo‘yicha taqqoslanadi.</li>
                  {report.limitations.map((l) => (
                    <li key={l}>{l}</li>
                  ))}
                </ul>
              </CollapsibleContent>
            </Collapsible>
          </>
        )}
      </CardContent>
    </Card>
  );
};
