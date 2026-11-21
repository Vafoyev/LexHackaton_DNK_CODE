import React, { useState, useEffect, useRef } from 'react';
import { AnalysisResult } from '../../types/contract';
import { 
  Mic, 
  MicOff, 
  Volume2, 
  VolumeX, 
  Play, 
  Pause, 
  RotateCcw, 
  Sparkles, 
  MessageSquare,
  Bot,
  Zap,
  HelpCircle,
  ExternalLink,
  ChevronRight
} from 'lucide-react';
import { Badge } from '../ui/badge';
import { Button } from '../ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
import { Tabs, TabsList, TabsTrigger } from '../ui/tabs';

interface LiveVoiceAssistantProps {
  analysis: AnalysisResult;
  onNavigateToClause?: (clauseId: string) => void;
}

export const LiveVoiceAssistant: React.FC<LiveVoiceAssistantProps> = ({
  analysis,
  onNavigateToClause,
}) => {
  const { summary, document, clauses } = analysis;

  const [isPlayingBrief, setIsPlayingBrief] = useState(false);
  const [isListening, setIsListening] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [aiResponse, setAiResponse] = useState<string | null>(null);
  const [referencedClauseId, setReferencedClauseId] = useState<string | null>(null);
  const [speechRate, setSpeechRate] = useState(1.0);
  const [activeTab, setActiveTab] = useState<'brief' | 'qa'>('brief');

  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const animationRef = useRef<number | null>(null);
  const recognitionRef = useRef<any>(null);

  // 1. Shartnomaning Ovozli Tahlil Matni (Uzbek tili)
  const generateDebriefText = () => {
    const redCount = summary.red_count;
    const yellowCount = summary.yellow_count;
    const score = 100 - summary.risk_score;

    return `Assalomu alaykum! LexGuard AI tizimi shartnoma auditini yakunladi. 
Hujjat: ${document.filename}. 
Umumiy huquqiy xavfsizlik indeksi yuz balldan ${score} ballni tashkil etmoqda. 
Diqqat! Shartnomada ${redCount} ta qonunga to'g'ridan-to'g'ri zid modda va ${yellowCount} ta tijoriy asimmetriya aniqlandi.
Birinchi jiddiy xavf: 7.3-bandda shartnomani ogohlantirmasdan va xarajatlarni qoplamasdan bir tomonlama bekor qilish kiritilgan. Bu Fuqarolik Kodeksining 707-moddasiga ziddir.
Ikkinchi xavf: 9.1-bandda har bir kun uchun bir foiz asossiz yuqori penya belgilangan.
Uchinchi xavf: 8.2-bandda ijrochiga cheksiz moddiy javobgarlik yuklangan.
Tavsiyamiz: Ushbu bandlarni imzolashdan oldin biz tayyorlagan redline takliflar asosida o'zgartiring va kelishmovchiliklar bayonnomasini taqdim eting.`;
  };

  // 2. Web Speech API orqali Ovoz chiqarish (Text-to-Speech)
  const speakText = (text: string, onEnd?: () => void) => {
    if (!('speechSynthesis' in window)) {
      alert("Brauzeringizda ovozli sintez qo'llab-quvvatlanmaydi.");
      return;
    }

    window.speechSynthesis.cancel(); // oldingisini to'xtatish
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = speechRate;
    utterance.pitch = 1.0;

    // O'zbek tili yoki mos ovozni tanlash
    const voices = window.speechSynthesis.getVoices();
    const uzVoice = voices.find(v => v.lang.startsWith('uz')) || 
                    voices.find(v => v.lang.startsWith('tr')) || 
                    voices.find(v => v.lang.startsWith('ru')) || 
                    voices[0];
    if (uzVoice) {
      utterance.voice = uzVoice;
    }

    utterance.onend = () => {
      setIsPlayingBrief(false);
      if (onEnd) onEnd();
    };

    utterance.onerror = () => {
      setIsPlayingBrief(false);
    };

    window.speechSynthesis.speak(utterance);
    setIsPlayingBrief(true);
  };

  const stopSpeaking = () => {
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel();
    }
    setIsPlayingBrief(false);
  };

  // 3. Audio To'lqin Visualizatsiyasi (Sinusoidal Canvas Animation)
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let step = 0;

    const renderWave = () => {
      step += 0.06;
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      const isActive = isPlayingBrief || isListening;
      const waveCount = 4;
      const baseAmp = isActive ? 18 : 3;

      for (let i = 0; i < waveCount; i++) {
        ctx.beginPath();
        ctx.lineWidth = i === 0 ? 2.5 : 1.5;
        
        // Ranglar: faol bo'lsa jonli neon havorang/zumrad, tinch bo'lsa xira
        if (isActive) {
          ctx.strokeStyle = i % 2 === 0 
            ? `rgba(56, 189, 248, ${0.85 - i * 0.18})` 
            : `rgba(16, 185, 129, ${0.85 - i * 0.18})`;
        } else {
          ctx.strokeStyle = `rgba(100, 116, 139, 0.25)`;
        }

        const freq = 0.02 + i * 0.008;
        const phase = step + i * 1.5;

        for (let x = 0; x < canvas.width; x++) {
          const y = canvas.height / 2 + Math.sin(x * freq + phase) * (baseAmp + Math.sin(step * 0.5) * 6);
          if (x === 0) {
            ctx.moveTo(x, y);
          } else {
            ctx.lineTo(x, y);
          }
        }
        ctx.stroke();
      }

      animationRef.current = requestAnimationFrame(renderWave);
    };

    renderWave();

    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
      }
    };
  }, [isPlayingBrief, isListening]);

  // 4. Speech Recognition (Mikrofon bilan jonli savol berish)
  const toggleListening = () => {
    const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;

    if (!SpeechRecognition) {
      alert("Brauzeringiz ovozli buyruqlarni qabul qilishni qo'llab-quvvatlamaydi (Google Chrome yoki Edge tavsiya etiladi).");
      return;
    }

    if (isListening) {
      if (recognitionRef.current) {
        recognitionRef.current.stop();
      }
      setIsListening(false);
      return;
    }

    stopSpeaking();
    const recognition = new SpeechRecognition();
    recognition.lang = 'uz-UZ';
    recognition.continuous = false;
    recognition.interimResults = false;

    recognition.onstart = () => {
      setIsListening(true);
      setTranscript('');
      setAiResponse(null);
      setReferencedClauseId(null);
    };

    recognition.onresult = (event: any) => {
      const text = event.results[0][0].transcript;
      setTranscript(text);
      handleVoiceQuery(text);
    };

    recognition.onerror = (event: any) => {
      console.warn("Speech recognition xatosi:", event.error);
      setIsListening(false);
    };

    recognition.onend = () => {
      setIsListening(false);
    };

    recognitionRef.current = recognition;
    recognition.start();
  };

  // Savolga intellektual javob generatsiyasi
  const handleVoiceQuery = (query: string) => {
    const qLower = query.toLowerCase();
    let reply = "";
    let targetClauseId: string | null = null;

    if (qLower.includes("penya") || qLower.includes("jarima")) {
      reply = "Shartnomaning 9.1-bandida kunlik 1% penya ko'rsatilgan. Bu yiliga 365% degani! Fuqarolik Kodeksining 326-moddasiga muvofiq, sud bu penyani asossiz yuqori deb topib kamaytirishi mumkin. Tavsiya: penyani kunlik 0.1% ga va jami shartnoma summasining 10% limitiga tushirish kerak.";
      targetClauseId = "c-09";
    } else if (qLower.includes("bekor") || qLower.includes("707") || qLower.includes("to'xtatish")) {
      reply = "7.3-bandda buyurtmachi shartnomani ogohlantirmasdan va xarajatlarni qoplamasdan bekor qilishi belgilangan. Fuqarolik Kodeksining 707-moddasi bu qoidani imperativ ravishda taqiqlaydi. Buyurtmachi 15 kun oldin ogohlantirishi va amaldagi xarajatlarni to'liq to'lashi shart!";
      targetClauseId = "c-07";
    } else if (qLower.includes("javobgarlik") || qLower.includes("zarar") || qLower.includes("cheksiz")) {
      reply = "8.2-bandda ijrochiga cheksiz moddiy javobgarlik va boy berilgan foydani to'lash yuklangan. FK 324-moddasiga ko'ra, axborot xizmatlarida javobgarlik shartnoma qiymatidan oshmasligi kerak.";
      targetClauseId = "c-08";
    } else if (qLower.includes("imzolash") || qLower.includes("mumkinmi") || qLower.includes("xavfsizmi")) {
      reply = `Hozirgi holatida bu shartnomani imzolash tavsiya etilmaydi! Unda ${summary.red_count} ta qonunga zid va ${summary.yellow_count} ta og'ir asimmetrik shart bor. Avval redline takliflarimizni buyurtmachiga jo'nating.`;
    } else if (qLower.includes("fors") || qLower.includes("major")) {
      reply = "14.1-bandda fors-major bandi juda umumiy yozilgan. Savdo-sanoat palatasi sertifikati va 3 kunlik xabarnoma mexanizmi kiritilishi shart.";
      targetClauseId = "c-14";
    } else {
      reply = `Sizning savolingiz: "${query}". Shartnomaning 10 ta deterministik qoidasi bo'yicha umumiy xavfsizlik 100 dan ${100 - summary.risk_score} ballni tashkil etadi. Redline tahririmiz bilan shartnomani muvozanatga keltirishingiz mumkin.`;
    }

    setAiResponse(reply);
    setReferencedClauseId(targetClauseId);
    speakText(reply);
  };

  return (
    <Card className="overflow-hidden">
      <CardHeader className="flex flex-row flex-wrap items-center justify-between gap-3 space-y-0 pb-3">
        <div className="flex items-center gap-2.5">
          <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-primary/10 text-primary">
            <Bot className="h-5 w-5" aria-hidden="true" />
          </span>
          <div>
            <div className="flex items-center gap-2">
              <CardTitle className="text-sm">Ovozli yordamchi</CardTitle>
              <Badge variant="outline" className="gap-1 text-[10px]">
                <span className="h-1.5 w-1.5 rounded-full bg-emerald-500" aria-hidden="true" />
                Jonli
              </Badge>
            </div>
            <CardDescription className="text-[11px]" aria-live="polite">
              {isPlayingBrief
                ? 'AI tahlilni ovozda tushuntirmoqda…'
                : isListening
                ? 'Sizni tinglamoqda… savolingizni ayting'
                : 'Audio brifing yoki ovozli savol-javob'}
            </CardDescription>
          </div>
        </div>

        <Tabs value={activeTab} onValueChange={(v) => setActiveTab(v as 'brief' | 'qa')}>
          <TabsList>
            <TabsTrigger value="brief" className="text-xs">Audio brifing</TabsTrigger>
            <TabsTrigger value="qa" className="gap-1 text-xs">
              <Mic className="h-3 w-3" aria-hidden="true" /> Ovozli savol
            </TabsTrigger>
          </TabsList>
        </Tabs>
      </CardHeader>

      <CardContent className="space-y-4">
        {/* Jonli audio to'lqin */}
        <div className="relative flex h-16 w-full items-center justify-center overflow-hidden rounded-2xl border bg-slate-950">
          <canvas ref={canvasRef} width={600} height={64} className="h-full w-full object-cover" aria-hidden="true" />
          <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
            {isListening && (
              <span className="flex animate-pulse items-center gap-1.5 rounded-full border border-rose-500/40 bg-rose-500/20 px-3 py-1 text-xs font-bold text-rose-400">
                <span className="h-2 w-2 rounded-full bg-rose-500" aria-hidden="true" />
                Tinglamoqda…
              </span>
            )}
          </div>
        </div>

        {activeTab === 'brief' ? (
          <div className="flex flex-col items-center justify-between gap-3 rounded-2xl border bg-muted/40 p-3 sm:flex-row">
            <div className="flex items-center gap-2">
              {!isPlayingBrief ? (
                <Button type="button" onClick={() => speakText(generateDebriefText())} className="gap-2 text-xs font-bold">
                  <Play className="h-4 w-4 fill-current" aria-hidden="true" />
                  Brifingni eshitish
                </Button>
              ) : (
                <Button type="button" variant="destructive" onClick={stopSpeaking} className="gap-2 text-xs font-bold">
                  <Pause className="h-4 w-4 fill-current" aria-hidden="true" />
                  To‘xtatish
                </Button>
              )}
              <Button
                type="button"
                variant="outline"
                size="icon"
                aria-label="Qayta tinglash"
                title="Qayta tinglash"
                onClick={() => {
                  stopSpeaking();
                  speakText(generateDebriefText());
                }}
              >
                <RotateCcw className="h-3.5 w-3.5" />
              </Button>
            </div>

            <div className="flex items-center gap-1 text-[11px] text-muted-foreground">
              <span>Tezlik:</span>
              {[1.0, 1.25, 1.5].map((rate) => (
                <Button
                  key={rate}
                  type="button"
                  size="sm"
                  variant={speechRate === rate ? 'default' : 'outline'}
                  aria-pressed={speechRate === rate}
                  className="h-6 px-2 text-[11px]"
                  onClick={() => {
                    setSpeechRate(rate);
                    if (isPlayingBrief) {
                      stopSpeaking();
                      speakText(generateDebriefText());
                    }
                  }}
                >
                  {rate}x
                </Button>
              ))}
            </div>
          </div>
        ) : (
          <div className="space-y-3">
            <Button
              type="button"
              variant={isListening ? 'destructive' : 'secondary'}
              onClick={toggleListening}
              aria-pressed={isListening}
              className="w-full gap-2 text-xs font-bold"
            >
              {isListening ? <MicOff className="h-4 w-4" aria-hidden="true" /> : <Mic className="h-4 w-4" aria-hidden="true" />}
              {isListening ? 'Tinglashni to‘xtatish' : 'Mikrofonni yoqish va savol berish'}
            </Button>

            <div className="flex flex-wrap items-center gap-1.5">
              <span className="text-[10px] text-muted-foreground">Tezkor savollar:</span>
              {['Penya qancha va qonuniymi?', 'FK 707 bekor qilish nima?', 'Cheksiz javobgarlik bormi?', 'Shartnomani imzolash xavfsizmi?', "Fors-major bandi to'g'rimi?"].map((q) => (
                <Button
                  key={q}
                  type="button"
                  variant="outline"
                  size="sm"
                  className="h-7 px-2.5 text-[11px] font-normal"
                  onClick={() => {
                    setTranscript(q);
                    handleVoiceQuery(q);
                  }}
                >
                  {q}
                </Button>
              ))}
            </div>

            {(transcript || aiResponse) && (
              <div className="space-y-2.5 rounded-2xl border bg-muted/40 p-4 text-xs">
                {transcript && (
                  <div className="flex items-start gap-2">
                    <span className="shrink-0 font-bold text-primary">Siz:</span>
                    <p className="italic">“{transcript}”</p>
                  </div>
                )}
                {aiResponse && (
                  <div className="space-y-2 border-t pt-2.5">
                    <div className="flex items-start gap-2">
                      <span className="shrink-0 font-bold text-emerald-600 dark:text-emerald-400">LexGuard:</span>
                      <p className="leading-relaxed">{aiResponse}</p>
                    </div>
                    {referencedClauseId && onNavigateToClause && (
                      <div className="flex justify-end">
                        <Button type="button" variant="link" size="sm" className="h-auto gap-1 p-0 text-[11px]" onClick={() => onNavigateToClause(referencedClauseId)}>
                          Tegishli bandni Diff-da ko‘rish <ChevronRight className="h-3.5 w-3.5" aria-hidden="true" />
                        </Button>
                      </div>
                    )}
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
};
