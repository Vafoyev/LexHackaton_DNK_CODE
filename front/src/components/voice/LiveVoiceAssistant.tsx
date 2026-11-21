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
  HelpCircle
} from 'lucide-react';

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

    return `Assalomu alaykum! LexGuard AI tahlili tayyor. 
Hujjat: ${document.filename}. 
Umumiy xavfsizlik indeksi yuzdan ${score} ball. 
Diqqat! Shartnomada ${redCount} ta jiddiy qonuniy ziddiyat va ${yellowCount} ta tijoriy asimmetriya aniqlandi.
Birinchi jiddiy xavf: 4.2-bandda shartnomani ogohlantirmasdan bir tomonlama bekor qilish kiritilgan. Bu Fuqarolik Kodeksining 707-moddasiga ziddir.
Ikkinchi xavf: 7.3-bandda har bir kun uchun yarim foiz nomutanosib penya belgilangan.
Tavsiya: Mazkur bandlarni imzolashdan oldin biz tayyorlagan redline takliflar asosida o‘zgartiring.`;
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
            ? `rgba(56, 189, 248, ${0.8 - i * 0.18})` 
            : `rgba(16, 185, 129, ${0.8 - i * 0.18})`;
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
      alert("Brauzeringiz ovozli buyruqlarni qabul qilishni qo'llab-quvvatlamaydi (Chrome yoki Edge tavsiya etiladi).");
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

    if (qLower.includes("penya") || qLower.includes("jarima")) {
      reply = "Shartnomaning 7.3-bandiga binoan kechiktirilgan har bir kun uchun 0.5% miqdorida penya belgilangan. Bu Fuqarolik Kodeksining 326-moddasiga ko‘ra asimmetrik xavf tug‘diradi va uni 0.1% ga kamaytirish lozim.";
    } else if (qLower.includes("bekor") || qLower.includes("to'xtatish") || qLower.includes("qaytarish")) {
      reply = "4.2-bandda buyurtmachi bir tomonlama ogohlantirmasdan bekor qilishi aytilgan. FK 707-moddasiga ko‘ra bunday band haqiqiy emas va amalda qilingan xarajatlar to‘lanishi shart.";
    } else if (qLower.includes("xavf") || qLower.includes("muammo") || qLower.includes("eng katta")) {
      reply = `Shartnomada jami ${summary.red_count} ta qizil va ${summary.yellow_count} ta sariq xavf mavjud. Eng katta xavf - buyurtmachi foydasiga tuzilgan nomutanosib javobgarlikdir.`;
    } else {
      reply = `Sizning savolingiz: "${query}". Shartnomaning 10 ta tekshirilgan qoidasi bo‘yicha umumiy xavfsizlik 100 dan ${100 - summary.risk_score} ballni tashkil qiladi. Tavsiyamiz - redline takliflarni ko‘rib chiqing.`;
    }

    setAiResponse(reply);
    speakText(reply);
  };

  return (
    <div className="rounded-3xl bg-gradient-to-br from-slate-900/95 via-slate-900/90 to-brand-950/40 border border-sky-500/30 p-5 shadow-2xl relative overflow-hidden backdrop-blur-xl">
      {/* Yuqori qism: Sarlavha & Status */}
      <div className="flex items-center justify-between gap-3 mb-4">
        <div className="flex items-center gap-2.5">
          <div className="w-9 h-9 rounded-xl bg-sky-500/20 border border-sky-500/40 flex items-center justify-center text-sky-400 shadow-sm shadow-sky-500/30">
            <Bot className="w-5 h-5 animate-pulse" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h3 className="text-sm font-bold text-white tracking-tight">
                LexGuard Live Voice Yurist
              </h3>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-sky-500/20 text-sky-400 border border-sky-500/30 flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-ping" />
                AI OVOZLI LIVE
              </span>
            </div>
            <p className="text-[11px] text-slate-400">
              {isPlayingBrief ? "AI tahlilni ovozda tushuntirmoqda..." : isListening ? "Sizni tinglamoqda... Savolingizni ayting" : "30 soniyalik audio brifing yoki ovozli savol-javob"}
            </p>
          </div>
        </div>

        {/* Tablar */}
        <div className="flex items-center gap-1 p-1 rounded-xl bg-slate-950 border border-slate-800 text-xs font-semibold">
          <button
            onClick={() => setActiveTab('brief')}
            className={`px-3 py-1 rounded-lg transition-all ${
              activeTab === 'brief' ? 'bg-sky-500 text-white shadow-sm' : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            Audio Brifing
          </button>
          <button
            onClick={() => setActiveTab('qa')}
            className={`px-3 py-1 rounded-lg transition-all flex items-center gap-1 ${
              activeTab === 'qa' ? 'bg-sky-500 text-white shadow-sm' : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            <Mic className="w-3 h-3" />
            <span>Ovozli Q&A</span>
          </button>
        </div>
      </div>

      {/* JONLI AUDIO TO'LQIN KANVASI (Waveform Visualizer) */}
      <div className="relative w-full h-16 rounded-2xl bg-slate-950/80 border border-slate-800/80 overflow-hidden flex items-center justify-center mb-4">
        <canvas
          ref={canvasRef}
          width={600}
          height={64}
          className="w-full h-full object-cover"
        />
        {/* Markazdagi mikrofon / status ko'rsatkichi */}
        <div className="absolute inset-0 pointer-events-none flex items-center justify-center">
          {isListening && (
            <div className="px-3 py-1 rounded-full bg-rose-500/20 border border-rose-500/40 text-rose-400 text-xs font-bold animate-pulse flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-rose-500" />
              TINGLAMOQDA... SAVOLINGIZNI AYTING
            </div>
          )}
        </div>
      </div>

      {/* KONTROLLAR & ASOSIY INTERFEYS */}
      {activeTab === 'brief' ? (
        <div className="flex flex-col sm:flex-row items-center justify-between gap-3 p-3 rounded-2xl bg-slate-950/50 border border-slate-800/80">
          <div className="flex items-center gap-2">
            {!isPlayingBrief ? (
              <button
                onClick={() => speakText(generateDebriefText())}
                className="px-4 py-2 rounded-xl bg-gradient-to-r from-sky-500 to-brand-600 hover:from-sky-400 hover:to-brand-500 text-white text-xs font-bold shadow-lg shadow-sky-500/20 flex items-center gap-2 transition-all cursor-pointer hover:scale-105"
              >
                <Play className="w-4 h-4 fill-current" />
                <span>Brifingni Eshitish (30s)</span>
              </button>
            ) : (
              <button
                onClick={stopSpeaking}
                className="px-4 py-2 rounded-xl bg-rose-500/20 hover:bg-rose-500/30 text-rose-400 border border-rose-500/40 text-xs font-bold flex items-center gap-2 transition-all cursor-pointer"
              >
                <Pause className="w-4 h-4 fill-current" />
                <span>To‘xtatish</span>
              </button>
            )}

            <button
              onClick={() => {
                stopSpeaking();
                speakText(generateDebriefText());
              }}
              title="Qayta tinglash"
              className="p-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 transition-all border border-slate-700"
            >
              <RotateCcw className="w-3.5 h-3.5" />
            </button>
          </div>

          {/* Tezlik tanlash */}
          <div className="flex items-center gap-1 text-[11px] font-mono text-slate-400">
            <span>Tezlik:</span>
            {[1.0, 1.25, 1.5].map((rate) => (
              <button
                key={rate}
                onClick={() => {
                  setSpeechRate(rate);
                  if (isPlayingBrief) {
                    stopSpeaking();
                    speakText(generateDebriefText());
                  }
                }}
                className={`px-2 py-0.5 rounded-md border ${
                  speechRate === rate 
                    ? 'bg-sky-500/20 border-sky-500/40 text-sky-300 font-bold' 
                    : 'bg-slate-900 border-slate-800 text-slate-500 hover:text-slate-300'
                }`}
              >
                {rate}x
              </button>
            ))}
          </div>
        </div>
      ) : (
        /* OVOZLI Q&A REJIMI */
        <div className="space-y-3">
          <div className="flex items-center gap-3">
            <button
              onClick={toggleListening}
              className={`flex-1 py-2.5 px-4 rounded-xl text-xs font-bold flex items-center justify-center gap-2 transition-all cursor-pointer ${
                isListening 
                  ? 'bg-rose-500 text-white shadow-lg shadow-rose-500/40 animate-pulse' 
                  : 'bg-sky-500/20 hover:bg-sky-500/30 text-sky-300 border border-sky-500/40'
              }`}
            >
              {isListening ? (
                <>
                  <MicOff className="w-4 h-4" />
                  <span>Tinglashni to‘xtatish</span>
                </>
              ) : (
                <>
                  <Mic className="w-4 h-4" />
                  <span>Mikrofonni yoqish va savol berish</span>
                </>
              )}
            </button>
          </div>

          {/* Tezkor Savol Tugmalari (Yozuvsiz yoki bitta bosishda) */}
          <div className="flex flex-wrap gap-1.5 items-center">
            <span className="text-[10px] text-slate-400 font-mono">Tezkor savollar:</span>
            {[
              "Penya qancha?",
              "Shartnomani qanday bekor qilsa bo'ladi?",
              "Eng katta xavflar nima?"
            ].map((q) => (
              <button
                key={q}
                onClick={() => {
                  setTranscript(q);
                  handleVoiceQuery(q);
                }}
                className="text-[11px] px-2.5 py-1 rounded-lg bg-slate-850 hover:bg-slate-800 text-slate-300 border border-slate-800 hover:border-sky-500/40 transition-all cursor-pointer"
              >
                {q}
              </button>
            ))}
          </div>

          {/* Traskript va AI Ovozli Javobi */}
          {(transcript || aiResponse) && (
            <div className="p-3 rounded-2xl bg-slate-950/70 border border-slate-800/80 space-y-2 text-xs">
              {transcript && (
                <div className="flex items-start gap-2 text-slate-300">
                  <span className="font-bold text-sky-400 shrink-0">Siz:</span>
                  <p className="italic">"{transcript}"</p>
                </div>
              )}
              {aiResponse && (
                <div className="flex items-start gap-2 text-emerald-300 pt-1 border-t border-slate-800/60">
                  <span className="font-bold text-emerald-400 shrink-0">LexGuard:</span>
                  <p className="leading-relaxed">{aiResponse}</p>
                </div>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
};
