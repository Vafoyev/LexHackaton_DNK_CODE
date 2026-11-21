import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  AlertTriangle,
  Bot,
  ExternalLink,
  Mic,
  Send,
  Sparkles,
  Square,
  Trash2,
  Volume2,
  VolumeX,
} from 'lucide-react';
import { ApiService, ChatError, ChatFinding, ChatReply, ChatSource } from '../../services/api';
import { useSpeechRecognition, useSpeechSynthesis } from '../../hooks/useSpeech';
import { Alert, AlertDescription } from '../ui/alert';
import { Badge } from '../ui/badge';
import { Button } from '../ui/button';
import { Card, CardContent, CardFooter, CardHeader, CardTitle, CardDescription } from '../ui/card';
import { ScrollArea } from '../ui/scroll-area';
import { Textarea } from '../ui/textarea';
import { Toggle } from '../ui/toggle';
import { Tooltip, TooltipContent, TooltipTrigger } from '../ui/tooltip';

interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  text: string;
  reply?: ChatReply;
  error?: { kind: string; retryText?: string };
  viaVoice?: boolean;
}

interface AIChatViewProps {
  /** Sessiya tugagan yoki demo rejimda — kirish oynasini ochish uchun */
  onRequireAuth?: () => void;
}

const STORAGE_KEY = 'lexguard_chat_v1';
const MAX_STORED = 40;
const MAX_CHARS = 2000;

const WELCOME_SUGGESTIONS = [
  '707-modda nima deydi?',
  "Penya qancha bo'lishi mumkin?",
  'Shartnomani bir tomonlama bekor qilish mumkinmi?',
  "Shaxsiy ma'lumotlarni chet elga uzatish mumkinmi?",
];

const WELCOME_TEXT =
  "Assalomu alaykum! Men LexGuard AI yordamchisiman. O'zbekiston qonunchiligi (Lex.uz) bo'yicha savollarga javob beraman va shartnoma bandlarini tahlil qilaman.\n\n" +
  "• Modda haqida so'rang: «707-modda nima deydi?»\n" +
  '• Shartnoma bandini yozing — xavf va tavsiya etilgan tahrirni ko\'rsataman.\n' +
  '• Mikrofon tugmasi orqali ovozli so\'rashingiz ham mumkin.';

const newId = () => `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;

function loadMessages(): ChatMessage[] {
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as ChatMessage[]) : [];
  } catch {
    return [];
  }
}

function saveMessages(messages: ChatMessage[]) {
  try {
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify(messages.slice(-MAX_STORED)));
  } catch {
    /* xotira to'lgan yoki taqiqlangan — suhbat shunchaki saqlanmaydi */
  }
}

const isSafeUrl = (url: string) => /^https:\/\//i.test(url);

/** Javob matnini paragraflarga bo'ladi (bo'sh qatorlar katta bo'shliq qoldirmasligi uchun). Matn React orqali, HTML sifatida emas, chiqariladi. */
const Paragraphs: React.FC<{ text: string }> = ({ text }) => (
  <>
    {text.split(/\n{2,}/).map((para, i) => (
      <p key={i} className="whitespace-pre-line mt-2 first:mt-0">
        {para}
      </p>
    ))}
  </>
)

const SourceChips: React.FC<{ sources: ChatSource[] }> = ({ sources }) => {
  const items = sources.filter((s) => s.url && isSafeUrl(s.url)).slice(0, 5);
  if (!items.length) return null;
  return (
    <div className="mt-3 flex flex-wrap gap-1.5" aria-label="Manbalar">
      {items.map((s) => (
        <Button key={s.id || s.code} asChild variant="outline" size="sm" className="h-6 gap-1 px-2 text-[11px] font-medium text-primary">
          <a href={s.url} target="_blank" rel="noopener noreferrer" title={s.title}>
            {s.code}
            <ExternalLink className="h-3 w-3" aria-hidden="true" />
          </a>
        </Button>
      ))}
    </div>
  );
};

const FindingCard: React.FC<{ finding: ChatFinding }> = ({ finding }) => {
  const isRed = finding.risk_level === 'RED';
  return (
    <Card
      className={`mt-3 text-sm shadow-none ${
        isRed ? 'border-red-200 bg-red-50/60 dark:border-red-900/60 dark:bg-red-950/20' : 'border-amber-200 bg-amber-50/60 dark:border-amber-900/60 dark:bg-amber-950/20'
      }`}
    >
      <CardContent className="p-3">
        <div className="flex flex-wrap items-center gap-2">
          <Badge variant={isRed ? 'destructive' : 'warning'}>{isRed ? 'Jiddiy xavf' : 'Tijoriy xavf'}</Badge>
          <span className="font-semibold">{finding.issue_title}</span>
        </div>
        <p className="mt-2 rounded-lg bg-red-100/70 px-2.5 py-1.5 text-red-900 dark:bg-red-950/40 dark:text-red-200">
          <span className="block text-[10px] font-bold uppercase tracking-wide opacity-70">Asl matn</span>
          {finding.problematic_quote}
        </p>
        <p className="mt-2 rounded-lg bg-emerald-100/70 px-2.5 py-1.5 text-emerald-900 dark:bg-emerald-950/40 dark:text-emerald-200">
          <span className="block text-[10px] font-bold uppercase tracking-wide opacity-70">Tavsiya etilgan tahrir</span>
          {finding.suggested_redline}
        </p>
        <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-[11px] text-muted-foreground">
          <span>{finding.cited_article}</span>
          {finding.balance_label && <span>· {finding.balance_label}</span>}
          {finding.lex_uz_url && isSafeUrl(finding.lex_uz_url) && (
            <Button asChild variant="link" size="sm" className="h-auto gap-1 p-0 text-[11px]">
              <a href={finding.lex_uz_url} target="_blank" rel="noopener noreferrer">
                Lex.uz <ExternalLink className="h-3 w-3" aria-hidden="true" />
              </a>
            </Button>
          )}
        </div>
      </CardContent>
    </Card>
  );
};

const TypingDots: React.FC = () => (
  <div className="flex items-center gap-1 px-1 py-1" role="status" aria-label="AI javob yozmoqda">
    {[0, 150, 300].map((delay) => (
      <span key={delay} className="h-2 w-2 animate-bounce rounded-full bg-primary/70" style={{ animationDelay: `${delay}ms` }} />
    ))}
  </div>
);

const VoiceBars: React.FC = () => (
  <span className="inline-flex h-4 items-end gap-0.5" aria-hidden="true">
    {[0, 120, 240, 120, 0].map((delay, i) => (
      <span key={i} className="w-0.5 animate-pulse rounded-full bg-red-500" style={{ height: `${8 + ((i % 3) + 1) * 3}px`, animationDelay: `${delay}ms` }} />
    ))}
  </span>
);

const BotAvatar: React.FC<{ warn?: boolean }> = ({ warn }) => (
  <span className={`mt-1 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg ${warn ? 'bg-amber-500 text-white' : 'bg-slate-900 text-zinc-400'}`}>
    {warn ? <AlertTriangle className="h-4 w-4" aria-hidden="true" /> : <Bot className="h-4 w-4" aria-hidden="true" />}
  </span>
);

export const AIChatView: React.FC<AIChatViewProps> = ({ onRequireAuth }) => {
  const [messages, setMessages] = useState<ChatMessage[]>(loadMessages);
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);
  const [autoSpeak, setAutoSpeak] = useState<boolean>(() => {
    try {
      return localStorage.getItem('lexguard_chat_autospeak') === '1';
    } catch {
      return false;
    }
  });

  const stt = useSpeechRecognition('uz-UZ');
  const tts = useSpeechSynthesis();
  const bottomRef = useRef<HTMLDivElement | null>(null);
  const textareaRef = useRef<HTMLTextAreaElement | null>(null);
  const mountedRef = useRef(true);
  const sendingRef = useRef(false);

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
    };
  }, []);

  useEffect(() => {
    saveMessages(messages);
    bottomRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' });
  }, [messages, sending]);

  // Textarea balandligini matnga moslash (1-5 qator)
  useEffect(() => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = 'auto';
    el.style.height = `${Math.min(el.scrollHeight, 140)}px`;
  }, [input, stt.interim]);

  const lastSuggestions =
    [...messages].reverse().find((m) => m.role === 'assistant' && m.reply?.suggestions?.length)?.reply?.suggestions ||
    WELCOME_SUGGESTIONS;

  const send = useCallback(
    async (rawText: string, viaVoice = false) => {
      const text = rawText.trim();
      if (!text || sendingRef.current) return;
      if (text.length > MAX_CHARS) {
        setMessages((m) => [
          ...m,
          { id: newId(), role: 'assistant', text: `Xabar juda uzun (${MAX_CHARS} belgigacha).`, error: { kind: 'TOO_LONG' } },
        ]);
        return;
      }
      tts.cancel();
      sendingRef.current = true;
      setSending(true);
      setInput('');
      setMessages((m) => [...m, { id: newId(), role: 'user', text, viaVoice }]);

      try {
        const reply = await ApiService.chat(text);
        if (!mountedRef.current) return;
        setMessages((m) => [...m, { id: newId(), role: 'assistant', text: reply.answer, reply }]);
        if (viaVoice || autoSpeak) tts.speak(reply.speech || reply.answer);
      } catch (e) {
        if (!mountedRef.current) return;
        const err = e instanceof ChatError ? e : new ChatError('UNAVAILABLE', "Kutilmagan xatolik. Qayta urinib ko'ring.");
        setMessages((m) => [
          ...m,
          { id: newId(), role: 'assistant', text: err.message, error: { kind: err.kind, retryText: text } },
        ]);
      } finally {
        sendingRef.current = false;
        if (mountedRef.current) setSending(false);
      }
    },
    [autoSpeak, tts]
  );

  const toggleMic = () => {
    if (stt.listening) {
      stt.stop();
      return;
    }
    tts.cancel();
    stt.start((text) => {
      setInput(text);
      void send(text, true);
    });
  };

  const toggleAutoSpeak = () => {
    const next = !autoSpeak;
    setAutoSpeak(next);
    if (!next) tts.cancel();
    try {
      localStorage.setItem('lexguard_chat_autospeak', next ? '1' : '0');
    } catch {
      /* e'tiborsiz */
    }
  };

  const clearChat = () => {
    tts.cancel();
    setMessages([]);
    try {
      sessionStorage.removeItem(STORAGE_KEY);
    } catch {
      /* e'tiborsiz */
    }
  };

  const onKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) {
      e.preventDefault();
      void send(input);
    }
  };

  const displayInput = stt.listening && stt.interim ? stt.interim : input;
  const canSend = !!input.trim() && !sending && !stt.listening;

  return (
    <section
      className="relative z-10 mx-auto flex w-full max-w-4xl flex-1 flex-col px-3 pb-3 pt-3 sm:px-6"
      style={{ height: 'calc(100dvh - 5rem)' }}
      aria-label="AI yordamchi"
    >
      <Card className="flex min-h-0 flex-1 flex-col overflow-hidden shadow-lg backdrop-blur-xl">
        <CardHeader className="flex flex-row items-center justify-between gap-3 space-y-0 border-b px-4 py-3">
          <div className="flex min-w-0 items-center gap-3">
            <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-zinc-500 to-zinc-500 text-white shadow-sm">
              <Sparkles className="h-5 w-5" aria-hidden="true" />
            </span>
            <div className="min-w-0">
              <CardTitle className="truncate text-base leading-tight">AI yordamchi</CardTitle>
              <CardDescription className="truncate text-[11px]">Lex.uz bazasiga asoslangan · chat va ovozli rejim</CardDescription>
            </div>
          </div>
          <div className="flex shrink-0 items-center gap-1.5">
            {tts.supported && (
              <Tooltip>
                <TooltipTrigger asChild>
                  <Toggle
                    variant="outline"
                    size="sm"
                    pressed={autoSpeak}
                    onPressedChange={toggleAutoSpeak}
                    className="h-8 w-8 p-0"
                    aria-label="Javoblarni ovoz chiqarib o‘qish"
                  >
                    {autoSpeak ? <Volume2 className="h-4 w-4" /> : <VolumeX className="h-4 w-4" />}
                  </Toggle>
                </TooltipTrigger>
                <TooltipContent>{autoSpeak ? 'Javoblar o‘qiladi' : 'Javoblarni ovoz chiqarib o‘qish'}</TooltipContent>
              </Tooltip>
            )}
            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="outline" size="icon" onClick={clearChat} disabled={!messages.length} className="h-8 w-8" aria-label="Suhbatni tozalash">
                  <Trash2 className="h-4 w-4" />
                </Button>
              </TooltipTrigger>
              <TooltipContent>Suhbatni tozalash</TooltipContent>
            </Tooltip>
          </div>
        </CardHeader>

        <ScrollArea className="min-h-0 flex-1">
          <div className="px-3 py-4 sm:px-5" role="log" aria-live="polite" aria-relevant="additions">
            <div className="mx-auto flex max-w-3xl flex-col gap-4">
              {!messages.length && (
                <div className="flex gap-3">
                  <BotAvatar />
                  <div className="max-w-[85%] rounded-2xl rounded-tl-sm bg-muted px-4 py-3 text-sm leading-relaxed">
                    <Paragraphs text={WELCOME_TEXT} />
                  </div>
                </div>
              )}

              {messages.map((m) =>
                m.role === 'user' ? (
                  <div key={m.id} className="flex justify-end">
                    <div className="max-w-[85%] whitespace-pre-wrap break-words rounded-2xl rounded-tr-sm bg-primary px-4 py-2.5 text-sm leading-relaxed text-primary-foreground shadow-sm">
                      {m.viaVoice && <Mic className="mr-1.5 inline h-3.5 w-3.5 opacity-80" aria-label="Ovozli xabar" />}
                      {m.text}
                    </div>
                  </div>
                ) : (
                  <div key={m.id} className="flex gap-3">
                    <BotAvatar warn={!!m.error} />
                    <div className="min-w-0 max-w-[88%]">
                      <div
                        className={`break-words rounded-2xl rounded-tl-sm px-4 py-3 text-sm leading-relaxed ${
                          m.error
                            ? 'border border-amber-200 bg-amber-50 text-amber-900 dark:border-amber-900/60 dark:bg-amber-950/30 dark:text-amber-100'
                            : 'bg-muted'
                        }`}
                      >
                        <Paragraphs text={m.text} />
                      </div>

                      {m.reply?.findings?.map((f, i) => <FindingCard key={i} finding={f} />)}
                      {m.reply && <SourceChips sources={m.reply.sources} />}

                      {m.error?.kind === 'AUTH' && onRequireAuth && (
                        <Button size="sm" className="mt-2" onClick={onRequireAuth}>
                          Kirish
                        </Button>
                      )}
                      {m.error?.retryText && m.error.kind !== 'AUTH' && (
                        <Button size="sm" variant="outline" className="mt-2" disabled={sending} onClick={() => void send(m.error!.retryText!)}>
                          Qayta urinish
                        </Button>
                      )}

                      {m.reply && (
                        <div className="mt-2 flex items-center gap-2">
                          {tts.supported && (
                            <Button
                              type="button"
                              variant="ghost"
                              size="sm"
                              className="h-7 gap-1 px-1.5 text-[11px] text-muted-foreground"
                              onClick={() => (tts.speaking ? tts.cancel() : tts.speak(m.reply!.speech || m.reply!.answer))}
                              aria-label={tts.speaking ? "O'qishni to'xtatish" : "Javobni ovoz chiqarib o'qish"}
                            >
                              {tts.speaking ? <Square className="h-3 w-3" /> : <Volume2 className="h-3.5 w-3.5" />}
                              {tts.speaking ? "To'xtatish" : 'Eshitish'}
                            </Button>
                          )}
                          <span className="text-[10px] text-muted-foreground">{m.reply.disclaimer}</span>
                        </div>
                      )}
                    </div>
                  </div>
                )
              )}

              {sending && (
                <div className="flex gap-3">
                  <BotAvatar />
                  <div className="rounded-2xl rounded-tl-sm bg-muted px-3 py-2">
                    <TypingDots />
                  </div>
                </div>
              )}
              <div ref={bottomRef} />
            </div>
          </div>
        </ScrollArea>

        {/* Tezkor savollar */}
        {!sending && (
          <div className="flex gap-2 overflow-x-auto px-3 pb-2 sm:px-5 [scrollbar-width:none]">
            {lastSuggestions.slice(0, 4).map((s) => (
              <Button key={s} type="button" variant="outline" size="sm" onClick={() => void send(s)} className="h-8 shrink-0 rounded-full text-xs font-medium text-muted-foreground hover:text-foreground">
                {s}
              </Button>
            ))}
          </div>
        )}

        {/* Kiritish */}
        <CardFooter className="flex-col items-stretch gap-2 border-t p-3 sm:px-5">
          {(stt.listening || stt.error) && (
            <Alert variant={stt.error ? 'default' : 'destructive'} role="status" className="py-2">
              <AlertDescription className="flex items-center gap-2 text-xs">
                {stt.error ? (
                  <>
                    <AlertTriangle className="h-3.5 w-3.5 shrink-0" aria-hidden="true" />
                    <span className="flex-1">{stt.error}</span>
                    <Button type="button" variant="link" size="sm" className="h-auto p-0 text-xs" onClick={stt.clearError}>
                      Yopish
                    </Button>
                  </>
                ) : (
                  <>
                    <VoiceBars />
                    <span>Tinglayapman… gapiring</span>
                  </>
                )}
              </AlertDescription>
            </Alert>
          )}

          <div className="flex items-end gap-2">
            <Textarea
              ref={textareaRef}
              value={displayInput}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={onKeyDown}
              rows={1}
              maxLength={MAX_CHARS}
              readOnly={stt.listening}
              placeholder="Savol yoki shartnoma bandi…"
              aria-label="Xabar"
              className="min-h-[40px] flex-1 resize-none rounded-xl"
            />
            <Button
              type="button"
              variant={stt.listening ? 'destructive' : 'outline'}
              size="icon"
              onClick={toggleMic}
              disabled={!stt.supported || sending}
              className="h-10 w-10 shrink-0 rounded-xl"
              aria-pressed={stt.listening}
              aria-label={stt.listening ? "Tinglashni to'xtatish" : 'Ovozli savol berish'}
              title={
                stt.supported
                  ? stt.listening
                    ? "Tinglashni to'xtatish"
                    : 'Ovozli savol berish'
                  : "Brauzeringiz ovozli kiritishni qo'llab-quvvatlamaydi (Chrome/Edge tavsiya etiladi)"
              }
            >
              {stt.listening ? <Square className="h-4 w-4" /> : <Mic className="h-4 w-4" />}
            </Button>
            <Button type="button" onClick={() => void send(input)} disabled={!canSend} className="h-10 w-10 shrink-0 rounded-xl" size="icon" aria-label="Yuborish" title="Yuborish (Enter)">
              <Send className="h-4 w-4" />
            </Button>
          </div>
          {input.length > MAX_CHARS - 200 && (
            <p className="text-right text-[10px] text-muted-foreground">
              {input.length}/{MAX_CHARS}
            </p>
          )}
        </CardFooter>
      </Card>
    </section>
  );
};
