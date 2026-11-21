import React, { useRef, useState } from 'react';
import { 
  ShieldAlert, 
  CheckCircle2, 
  FileText, 
  Scale, 
  ArrowRight, 
  Sparkles, 
  AlertTriangle, 
  Lock, 
  Download, 
  Zap,
  ExternalLink,
  ChevronRight,
  Upload,
  AlertCircle
} from 'lucide-react';
import { ProgressEvent } from '../../types/contract';
import { useAuth } from '../../context/AuthContext';
import { calculateSHA256, formatBytes } from '../../utils/crypto';
import { Alert, AlertDescription } from '../ui/alert';
import { Badge } from '../ui/badge';
import { Button } from '../ui/button';
import { Card } from '../ui/card';
import { Progress } from '../ui/progress';

interface LandingViewProps {
  onAnalyze: (file: File | null, isDemo: boolean) => void;
  isLoading: boolean;
  progress: ProgressEvent | null;
  onOpenAuth: () => void;
  segment?: 'b2c' | 'b2b';
  onSegmentChange?: (segment: 'b2c' | 'b2b') => void;
}

export const LandingView: React.FC<LandingViewProps> = ({
  onAnalyze,
  isLoading,
  progress,
  onOpenAuth,
}) => {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [dragOver, setDragOver] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [sha256, setSha256] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleFileChange = async (file: File) => {
    setError(null);
    const validExtensions = ['.docx', '.pdf', '.txt'];
    const hasValidExt = validExtensions.some(ext => file.name.toLowerCase().endsWith(ext));

    if (!hasValidExt) {
      setError("Faqat DOCX, PDF va TXT formatidagi shartnomalar qo'llab-quvvatlanadi.");
      return;
    }

    if (file.size > 25 * 1024 * 1024) {
      setError("Fayl hajmi 25MB limitidan oshmasligi kerak.");
      return;
    }

    setSelectedFile(file);
    try {
      const hash = await calculateSHA256(file);
      setSha256(hash);
    } catch {
      setSha256("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
    }
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      handleFileChange(e.dataTransfer.files[0]);
    }
  };

  const startAnalysis = () => {
    if (!selectedFile) return;
    onAnalyze(selectedFile, false);
  };

  const startDemoAnalysis = () => {
    onAnalyze(null, true);
  };

  return (
    <div className="w-full space-y-20 pb-16 font-sans">
      
      {/* ============================================================
          1. HERO SECTION (3D va Three.js'siz, Aniq va Mazmunli)
          ============================================================ */}
      <section className="relative pt-6 sm:pt-12 pb-8 max-w-5xl mx-auto px-4 sm:px-6 text-center space-y-6">
        
        {/* Rasmiy Milliy Davlat Portali nishoni */}
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-slate-100 dark:bg-slate-800/80 border border-slate-200 dark:border-slate-700/80 text-xs font-medium text-slate-700 dark:text-slate-300">
          <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
          <span className="font-semibold text-slate-900 dark:text-white">O‘zbekiston Respublikasi Lex.uz</span>
          <span className="text-slate-400">·</span>
          <span>Rasmiy milliy qonunchilik bazasi bilan 100% sinxron</span>
        </div>

        {/* Bosh Sarlavha */}
        <h1 className="text-3xl sm:text-5xl lg:text-6xl font-extrabold tracking-tight text-slate-900 dark:text-white leading-[1.15]">
          Shartnomangizni Imzolashdan Oldin{' '}
          <span className="text-muted-foreground">
            Qonuniy Himoya Qiling
          </span>
        </h1>

        {/* Mazmunli Izoh */}
        <p className="max-w-3xl mx-auto text-sm sm:text-base lg:text-lg text-slate-600 dark:text-slate-300 leading-relaxed font-normal">
          <strong>LexGuard AI</strong> — O‘zR Fuqarolik Kodeksi va 2,058 ta qonun normalari asosida 
          shartnomalardagi yashirin jarimalar, asimmetrik majburiyatlar va 
          noqonuniy bandlarni soniyalar ichida aniqlab, 1-bosishda rasmiy <strong>Redline tahrir</strong> beruvchi huquqiy sun'iy intellekt tizimi.
        </p>

        {/* Boshqaruv Tugmalari (CTA) */}
        <div className="flex flex-wrap items-center justify-center gap-3 pt-4">
          <Button size="lg" onClick={startDemoAnalysis} className="gap-2 px-6 font-semibold">
            <Sparkles className="h-4 w-4" aria-hidden="true" />
            Namunaviy IT shartnomani sinash
            <ArrowRight className="h-4 w-4" aria-hidden="true" />
          </Button>

          <Button size="lg" variant="secondary" onClick={onOpenAuth} className="gap-2 px-6 font-semibold">
            <Lock className="h-4 w-4 text-muted-foreground" aria-hidden="true" />
            OneID / E-IMZO bilan kirish
          </Button>
        </div>

        {/* Ishonch va Xavfsizlik ko'rsatkichlari */}
        <div className="flex flex-wrap items-center justify-center gap-6 pt-6 text-xs text-slate-500 dark:text-slate-400 font-medium">
          <div className="flex items-center gap-1.5">
            <CheckCircle2 className="w-4 h-4 text-emerald-500" />
            <span>O‘RQ-547 Shaxsiy ma'lumotlar lokal shifrlanadi</span>
          </div>
          <div className="flex items-center gap-1.5">
            <CheckCircle2 className="w-4 h-4 text-emerald-500" />
            <span>10 ta Deterministik Go qoidalar dvigateli</span>
          </div>
          <div className="flex items-center gap-1.5">
            <CheckCircle2 className="w-4 h-4 text-emerald-500" />
            <span>2 xil DOCX & PDF Protokol eksporti</span>
          </div>
        </div>
      </section>

      {/* ============================================================
          2. LOYIHA NIMA UCHUN KERAK? (MUAMMO VA XAVFLAR)
          ============================================================ */}
      <section id="muammolar" className="max-w-6xl mx-auto px-4 sm:px-6">
        <div className="text-center max-w-2xl mx-auto mb-10 space-y-2">
          <span className="text-xs font-bold tracking-wider uppercase text-rose-500 font-mono">
            E'tiborsizlik Bahosi Juda Qimmat
          </span>
          <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight">
            Shartnomalarda Qanday Xavflar Yashiringan?
          </h2>
          <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400">
            O‘zbekiston sud amaliyotida biznes va fuqarolar aynan quyidagi 3 ta tuzoq tufayli millionlab so‘m zarar ko‘rmoqda:
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {/* 1-xavf */}
          <div className="p-6 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-sm space-y-3">
            <div className="w-10 h-10 rounded-xl bg-rose-500/10 border border-rose-500/20 flex items-center justify-center text-rose-600 dark:text-rose-400">
              <ShieldAlert className="w-5 h-5" />
            </div>
            <h3 className="text-base font-bold text-slate-900 dark:text-white">
              Bir Tomonlama Bekor Qilish (FK 707)
            </h3>
            <p className="text-xs sm:text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
              Buyurtmachi istalgan vaqtda shartnomani xarajatlarni qoplamasdan bekor qilishi ko'rsatiladi. Bu ijrochini qilingan xarajatlar va ish haqsiz qoldiradi.
            </p>
            <div className="pt-2 text-[11px] font-mono text-rose-600 dark:text-rose-400 font-bold flex items-center gap-1">
              <span>⚠️ Qonunga to‘g‘ridan-to‘g‘ri zid</span>
            </div>
          </div>

          {/* 2-xavf */}
          <div className="p-6 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-sm space-y-3">
            <div className="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-600 dark:text-amber-400">
              <AlertTriangle className="w-5 h-5" />
            </div>
            <h3 className="text-base font-bold text-slate-900 dark:text-white">
              Nomutanosib Kunlik 1% Penya (FK 326)
            </h3>
            <p className="text-xs sm:text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
              Bozor normasida kuniga 0.1% penya qo'llanilishi kerak bo'lgan joyda, 1% (oyiga 30%!) penya kiritiladi va asossiz moliyaviy asimmetriya yaratiladi.
            </p>
            <div className="pt-2 text-[11px] font-mono text-amber-600 dark:text-amber-400 font-bold flex items-center gap-1">
              <span>⚠️ Asimmetrik moliyaviy bosim</span>
            </div>
          </div>

          {/* 3-xavf */}
          <div className="p-6 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-sm space-y-3">
            <div className="w-10 h-10 rounded-xl bg-zinc-500/10 border border-zinc-500/20 flex items-center justify-center text-zinc-600 dark:text-zinc-400">
              <Scale className="w-5 h-5" />
            </div>
            <h3 className="text-base font-bold text-slate-900 dark:text-white">
              Cheksiz Moddiy Javobgarlik (FK 324)
            </h3>
            <p className="text-xs sm:text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
              Javobgarlik chegarasi (Cap of Liability) belgilanmaydi. Kichik xato uchun butun korxona hisob raqamlari va aktivlari xavf ostida qoladi.
            </p>
            <div className="pt-2 text-[11px] font-mono text-zinc-600 dark:text-zinc-400 font-bold flex items-center gap-1">
              <span>⚠️ Korxona aktivlariga to‘g‘ridan-to‘g‘ri tahdid</span>
            </div>
          </div>
        </div>
      </section>

      {/* ============================================================
          3. LEXGUARD AI QANDAY YENGILLIKLAR BERADI? (AFZALLIKLAR)
          ============================================================ */}
      <section id="afzalliklar" className="max-w-6xl mx-auto px-4 sm:px-6">
        <div className="text-center max-w-2xl mx-auto mb-10 space-y-2">
          <span className="text-xs font-bold tracking-wider uppercase text-emerald-600 font-mono">
            Raqamli Huquqiy Advokat
          </span>
          <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight">
            LexGuard AI Beradigan 4 Ta Katta Yengillik
          </h2>
          <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400">
            Katta yuridik firmalar haftalab qiladigan tahlilni siz 3 soniyada olasiz:
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {/* 1-afzallik */}
          <div className="p-5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-200 dark:border-slate-800 space-y-2.5">
            <div className="w-9 h-9 rounded-lg bg-zinc-500/15 border border-zinc-500/30 flex items-center justify-center text-zinc-600 dark:text-zinc-400">
              <Zap className="w-4 h-4" />
            </div>
            <h4 className="text-sm font-bold text-slate-900 dark:text-white">Avtonom Audit</h4>
            <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
              Word (.docx) va PDF shartnomani tashlang — AI har bir bandni alohida tahlil qilib xavflarni ajratadi.
            </p>
          </div>

          {/* 2-afzallik */}
          <div className="p-5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-200 dark:border-slate-800 space-y-2.5">
            <div className="w-9 h-9 rounded-lg bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-600 dark:text-emerald-400">
              <Sparkles className="w-4 h-4" />
            </div>
            <h4 className="text-sm font-bold text-slate-900 dark:text-white">1-Click Redline Tahrir</h4>
            <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
              Qonunga zid bandlarni o'chirish shart emas — tizim FK normalariga 100% mos to'g'ri tahrirni tayyorlab beradi.
            </p>
          </div>

          {/* 3-afzallik */}
          <div className="p-5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-200 dark:border-slate-800 space-y-2.5">
            <div className="w-9 h-9 rounded-lg bg-zinc-500/15 border border-zinc-500/30 flex items-center justify-center text-zinc-600 dark:text-zinc-400">
              <ExternalLink className="w-4 h-4" />
            </div>
            <h4 className="text-sm font-bold text-slate-900 dark:text-white">Lex.uz Havolalari</h4>
            <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
              Hech qanday gallyutsinatsiya yo'q — har bir tavsiya O‘zR rasmiy Lex.uz moddasiga to'g'ridan-to'g'ri bog'lanadi.
            </p>
          </div>

          {/* 4-afzallik */}
          <div className="p-5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-200 dark:border-slate-800 space-y-2.5">
            <div className="w-9 h-9 rounded-lg bg-zinc-500/15 border border-zinc-500/30 flex items-center justify-center text-zinc-600 dark:text-zinc-400">
              <Download className="w-4 h-4" />
            </div>
            <h4 className="text-sm font-bold text-slate-900 dark:text-white">DOCX & PDF Eksport</h4>
            <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
              Hamkoringizga yuborish uchun <strong>Protokol raznoglasiy</strong> jadvali va rasmiy huquqiy xulosani yuklab oling.
            </p>
          </div>
        </div>
      </section>

      {/* ============================================================
          4. INTERAKTIV SHARTNOMA AUDITI MAYDONI (UPLOAD DROPZONE)
          ============================================================ */}
      <section id="sinash" className="max-w-4xl mx-auto px-4 sm:px-6">
        <div className="text-center mb-8 space-y-3">
          <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-700 dark:text-emerald-400 text-xs font-semibold">
            <ShieldAlert className="w-3.5 h-3.5" />
            <span>O‘RQ-547 Standarti: Shaxsiy ma'lumotlar avtomatik anonimlashtiriladi</span>
          </div>

          <h3 className="text-xl sm:text-2xl font-bold text-slate-900 dark:text-white">
            Shartnomani Tekshirish Uchun Yuklang
          </h3>
          <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400">
            Word (.docx), PDF (.pdf) yoki matn (.txt) formatida, 25MB gacha
          </p>
        </div>

        {/* Upload Card */}
        <Card
          onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
          onDragLeave={() => setDragOver(false)}
          onDrop={handleDrop}
          className={`rounded-3xl border-2 border-dashed p-8 text-center shadow-none transition-all sm:p-12 ${
            dragOver
              ? 'border-primary bg-primary/5'
              : selectedFile
              ? 'border-emerald-500 bg-emerald-50/20 dark:bg-emerald-950/20'
              : 'hover:border-primary/50'
          }`}
        >
          <input
            type="file"
            ref={fileInputRef}
            onChange={(e) => e.target.files?.[0] && handleFileChange(e.target.files[0])}
            accept=".docx,.pdf,.txt"
            className="hidden"
          />

          {isLoading ? (
            /* Loading SSE State */
            <div className="py-6 space-y-6 max-w-md mx-auto">
              <div className="w-16 h-16 rounded-full border-4 border-t-sky-500 border-r-emerald-500 border-b-sky-500 border-l-transparent animate-spin mx-auto" />
              <div className="space-y-1.5">
                <h4 className="text-base font-bold text-slate-900 dark:text-white">
                  Shartnoma Huquqiy Tahlildan O'tmoqda...
                </h4>
                <p className="text-xs text-zinc-600 dark:text-zinc-400 font-mono font-semibold">
                  Bosqich: {progress?.stage || 'O‘RQ-547 PII MASKALASH'} ({progress?.progress_pct ?? 45}%)
                </p>
              </div>
              <Progress value={progress?.progress_pct ?? 45} aria-label="Tahlil jarayoni" />
            </div>
          ) : selectedFile ? (
            /* File Selected State */
            <div className="space-y-4 max-w-md mx-auto">
              <div className="w-14 h-14 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center mx-auto text-emerald-600 dark:text-emerald-400">
                <FileText className="w-7 h-7" />
              </div>
              <div>
                <h4 className="text-sm font-bold text-slate-900 dark:text-white break-words">{selectedFile.name}</h4>
                <p className="text-xs text-slate-500 font-mono mt-0.5">
                  Hajmi: {formatBytes(selectedFile.size)} · SHA256: {sha256?.substring(0, 16)}...
                </p>
              </div>
              <div className="flex items-center justify-center gap-3 pt-2">
                <Button type="button" onClick={startAnalysis}>
                  Tahlilni boshlash
                </Button>
                <Button type="button" variant="secondary" onClick={() => setSelectedFile(null)}>
                  Bekor qilish
                </Button>
              </div>
            </div>
          ) : (
            /* Empty Dropzone State */
            <div className="space-y-4 max-w-md mx-auto">
              <div className="w-14 h-14 rounded-2xl bg-slate-100 dark:bg-slate-800 flex items-center justify-center mx-auto text-slate-500">
                <Upload className="w-6 h-6" />
              </div>
              <div>
                <h4 className="text-sm font-bold text-slate-900 dark:text-white">
                  Shartnoma faylini bu yerga tashlang
                </h4>
                <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">
                  yoki kompyuterdan tanlang (Word, PDF, TXT)
                </p>
              </div>
              <div className="flex flex-col sm:flex-row items-center justify-center gap-2 pt-2">
                <Button type="button" onClick={() => fileInputRef.current?.click()} className="w-full sm:w-auto">
                  Kompyuterdan tanlash
                </Button>
                <span className="text-xs text-muted-foreground">yoki</span>
                <Button type="button" variant="outline" onClick={startDemoAnalysis} className="w-full sm:w-auto">
                  Namunaviy B2B IT shartnomani sinash
                </Button>
              </div>
            </div>
          )}

          {error && (
            <Alert variant="destructive" role="alert" className="mx-auto mt-4 max-w-md text-left">
              <AlertCircle className="h-4 w-4" aria-hidden="true" />
              <AlertDescription>{error}</AlertDescription>
            </Alert>
          )}
        </Card>

        {/* Namuna shartnomalar */}
        <div className="grid grid-cols-1 gap-4 pt-6 md:grid-cols-3">
          {[
            { tag: 'B2B SERVICE', variant: 'success' as const, title: "IT xizmat ko'rsatish shartnomasi", text: 'FK 707 (bir tomonlama bekor qilish), cheksiz javobgarlik va kunlik 0,5% penya asimmetriyasi.' },
            { tag: 'COMMERCIAL LEASE', variant: 'warning' as const, title: 'Tijoriy bino ijarasi shartnomasi', text: 'Bir tomonlama ijara haqini oshirish va garov depozitini qaytarmaslik asimmetriyalari.' },
            { tag: 'SUPPLY SALE', variant: 'outline' as const, title: 'Uskunalar yetkazib berish', text: "Kafolat muddati, qabul qilish dalolatnomasi va to'lov kechikishi sanktsiyalari." },
          ].map((c) => (
            <Button
              key={c.tag}
              type="button"
              variant="outline"
              onClick={startDemoAnalysis}
              className="group h-auto flex-col items-stretch gap-1.5 whitespace-normal p-4 text-left font-normal"
            >
              <span className="flex items-center justify-between">
                <Badge variant={c.variant} className="font-mono text-[10px]">
                  {c.tag}
                </Badge>
                <ChevronRight className="h-4 w-4 text-muted-foreground transition-transform group-hover:translate-x-1" aria-hidden="true" />
              </span>
              <span className="text-xs font-bold">{c.title}</span>
              <span className="line-clamp-2 text-[11px] text-muted-foreground">{c.text}</span>
            </Button>
          ))}
        </div>
      </section>

    </div>
  );
};
