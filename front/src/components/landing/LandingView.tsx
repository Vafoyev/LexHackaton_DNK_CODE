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
  Building2,
  User,
  ExternalLink,
  ChevronRight,
  Upload,
  AlertCircle
} from 'lucide-react';
import { ProgressEvent } from '../../types/contract';
import { useAuth } from '../../context/AuthContext';
import { calculateSHA256, formatBytes } from '../../utils/crypto';

interface LandingViewProps {
  onAnalyze: (file: File | null, isDemo: boolean) => void;
  isLoading: boolean;
  progress: ProgressEvent | null;
  onOpenAuth: () => void;
  segment: 'b2c' | 'b2b';
  onSegmentChange: (segment: 'b2c' | 'b2b') => void;
}

export const LandingView: React.FC<LandingViewProps> = ({
  onAnalyze,
  isLoading,
  progress,
  onOpenAuth,
  segment,
  onSegmentChange,
}) => {
  const isB2B = segment === 'b2b';
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
          <span className={isB2B ? "text-emerald-600 dark:text-emerald-400" : "text-sky-600 dark:text-sky-400"}>
            Qonuniy Himoya Qiling
          </span>
        </h1>

        {/* Mazmunli Izoh */}
        <p className="max-w-3xl mx-auto text-sm sm:text-base lg:text-lg text-slate-600 dark:text-slate-300 leading-relaxed font-normal">
          <strong>LexGuard AI</strong> — O‘zR Fuqarolik Kodeksi va 2,058 ta qonun normalari asosida 
          tadbirkorlar va fuqarolar shartnomalaridagi yashirin jarimalar, asimmetrik majburiyatlar va 
          noqonuniy bandlarni soniyalar ichida aniqlab, 1-bosishda rasmiy <strong>Redline tahrir</strong> beruvchi huquqiy sun'iy intellekt tizimi.
        </p>

        {/* Boshqaruv Tugmalari (CTA) */}
        <div className="flex flex-wrap items-center justify-center gap-3 pt-4">
          <button
            onClick={startDemoAnalysis}
            className={`px-6 py-3 rounded-xl font-bold text-sm text-white shadow-lg transition-all cursor-pointer flex items-center gap-2 hover:scale-[1.02] ${
              isB2B 
                ? 'bg-emerald-600 hover:bg-emerald-500 shadow-emerald-600/25' 
                : 'bg-sky-600 hover:bg-sky-500 shadow-sky-600/25'
            }`}
          >
            <Sparkles className="w-4 h-4" />
            <span>Namunaviy IT Shartnomani Sinash</span>
            <ArrowRight className="w-4 h-4 ml-1" />
          </button>

          <button
            onClick={onOpenAuth}
            className="px-6 py-3 rounded-xl font-semibold text-sm text-slate-800 dark:text-white bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 border border-slate-200 dark:border-slate-700 transition-all cursor-pointer flex items-center gap-2"
          >
            <Lock className="w-4 h-4 text-slate-500" />
            <span>OneID / E-IMZO bilan Kirish</span>
          </button>
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
            <div className="w-10 h-10 rounded-xl bg-purple-500/10 border border-purple-500/20 flex items-center justify-center text-purple-600 dark:text-purple-400">
              <Scale className="w-5 h-5" />
            </div>
            <h3 className="text-base font-bold text-slate-900 dark:text-white">
              Cheksiz Moddiy Javobgarlik (FK 324)
            </h3>
            <p className="text-xs sm:text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
              Javobgarlik chegarasi (Cap of Liability) belgilanmaydi. Kichik xato uchun butun korxona hisob raqamlari va aktivlari xavf ostida qoladi.
            </p>
            <div className="pt-2 text-[11px] font-mono text-purple-600 dark:text-purple-400 font-bold flex items-center gap-1">
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
            <div className="w-9 h-9 rounded-lg bg-sky-500/15 border border-sky-500/30 flex items-center justify-center text-sky-600 dark:text-sky-400">
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
            <div className="w-9 h-9 rounded-lg bg-blue-500/15 border border-blue-500/30 flex items-center justify-center text-blue-600 dark:text-blue-400">
              <ExternalLink className="w-4 h-4" />
            </div>
            <h4 className="text-sm font-bold text-slate-900 dark:text-white">Lex.uz Havolalari</h4>
            <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
              Hech qanday gallyutsinatsiya yo'q — har bir tavsiya O‘zR rasmiy Lex.uz moddasiga to'g'ridan-to'g'ri bog'lanadi.
            </p>
          </div>

          {/* 4-afzallik */}
          <div className="p-5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-200 dark:border-slate-800 space-y-2.5">
            <div className="w-9 h-9 rounded-lg bg-teal-500/15 border border-teal-500/30 flex items-center justify-center text-teal-600 dark:text-teal-400">
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
        <div className="text-center mb-8 space-y-2">
          <div className="inline-flex items-center gap-2 p-1 rounded-xl bg-slate-100 dark:bg-slate-800/80 border border-slate-200 dark:border-slate-700/60">
            <button
              onClick={() => onSegmentChange('b2c')}
              className={`px-4 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                !isB2B 
                  ? 'bg-white dark:bg-slate-900 text-sky-600 shadow-sm' 
                  : 'text-slate-500 hover:text-slate-900 dark:hover:text-white'
              }`}
            >
              Fuqaro Shartnomalari (B2C)
            </button>
            <button
              onClick={() => onSegmentChange('b2b')}
              className={`px-4 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                isB2B 
                  ? 'bg-white dark:bg-slate-900 text-emerald-600 shadow-sm' 
                  : 'text-slate-500 hover:text-slate-900 dark:hover:text-white'
              }`}
            >
              Biznes Bitimlari (B2B)
            </button>
          </div>

          <h3 className="text-xl sm:text-2xl font-bold text-slate-900 dark:text-white">
            {isB2B ? "B2B Korporativ Shartnomani Yuklang" : "Fuqarolik Shartnomasini Yuklang"}
          </h3>
          <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400">
            Word (.docx), PDF (.pdf) yoki matn (.txt) formatida, 25MB gacha
          </p>
        </div>

        {/* Upload Card */}
        <div
          onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
          onDragLeave={() => setDragOver(false)}
          onDrop={handleDrop}
          className={`rounded-3xl border-2 border-dashed p-8 sm:p-12 text-center transition-all bg-white dark:bg-slate-900 ${
            dragOver 
              ? 'border-sky-500 bg-sky-50 dark:bg-sky-950/20' 
              : selectedFile 
              ? 'border-emerald-500 bg-emerald-50/20 dark:bg-emerald-950/20' 
              : 'border-slate-200 dark:border-slate-800 hover:border-slate-300 dark:hover:border-slate-700'
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
                <p className="text-xs text-sky-600 dark:text-sky-400 font-mono font-semibold">
                  Bosqich: {progress?.stage || 'O‘RQ-547 PII MASKALASH'} ({progress?.progress_pct ?? 45}%)
                </p>
              </div>
              <div className="w-full bg-slate-100 dark:bg-slate-800 rounded-full h-2 overflow-hidden">
                <div 
                  className="h-full bg-gradient-to-r from-sky-500 to-emerald-500 transition-all duration-300"
                  style={{ width: `${progress?.progress_pct ?? 45}%` }}
                />
              </div>
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
                <button
                  type="button"
                  onClick={startAnalysis}
                  className="px-6 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow-md transition-all cursor-pointer"
                >
                  Tahlilni Boshlash
                </button>
                <button
                  type="button"
                  onClick={() => setSelectedFile(null)}
                  className="px-4 py-2.5 rounded-xl bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 font-semibold text-xs transition-all cursor-pointer"
                >
                  Bekor qilish
                </button>
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
                <button
                  type="button"
                  onClick={() => fileInputRef.current?.click()}
                  className="w-full sm:w-auto px-5 py-2.5 rounded-xl bg-slate-900 dark:bg-white text-white dark:text-slate-900 font-bold text-xs transition-all cursor-pointer shadow-sm"
                >
                  Kompyuterdan Tanlash
                </button>
                <span className="text-xs text-slate-400 font-mono">yoki</span>
                <button
                  type="button"
                  onClick={startDemoAnalysis}
                  className="w-full sm:w-auto px-5 py-2.5 rounded-xl bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 font-semibold text-xs border border-slate-200 dark:border-slate-700 transition-all cursor-pointer"
                >
                  Namunaviy B2B IT Shartnomani Sinash
                </button>
              </div>
            </div>
          )}

          {error && (
            <div className="mt-4 p-3 bg-red-50 dark:bg-red-950/40 border border-red-200 dark:border-red-900/50 rounded-xl text-xs text-red-600 dark:text-red-400 flex items-center justify-center gap-2 max-w-md mx-auto">
              <AlertCircle className="w-4 h-4 shrink-0" />
              <span>{error}</span>
            </div>
          )}
        </div>

        {/* Namuna Shartnomalar Kartochkalari */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 pt-6">
          <div 
            onClick={startDemoAnalysis}
            className="p-4 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 hover:border-slate-300 dark:hover:border-slate-700 cursor-pointer transition-all group"
          >
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-[10px] font-mono px-2 py-0.5 rounded-md bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 font-bold">
                B2B SERVICE
              </span>
              <ChevronRight className="w-4 h-4 text-slate-400 group-hover:translate-x-1 transition-transform" />
            </div>
            <h4 className="text-xs font-bold text-slate-900 dark:text-white">IT Xizmat Ko'rsatish Shartnomasi</h4>
            <p className="text-[11px] text-slate-500 line-clamp-2 mt-1">
              FK 707 (Bir tomonlama bekor qilish), Cheksiz javobgarlik va kunlik 0.5% penya asimmetriyasi.
            </p>
          </div>

          <div 
            onClick={startDemoAnalysis}
            className="p-4 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 hover:border-slate-300 dark:hover:border-slate-700 cursor-pointer transition-all group"
          >
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-[10px] font-mono px-2 py-0.5 rounded-md bg-amber-500/10 text-amber-600 dark:text-amber-400 font-bold">
                COMMERCIAL LEASE
              </span>
              <ChevronRight className="w-4 h-4 text-slate-400 group-hover:translate-x-1 transition-transform" />
            </div>
            <h4 className="text-xs font-bold text-slate-900 dark:text-white">Tijoriy Bino Ijarasi Shartnomasi</h4>
            <p className="text-[11px] text-slate-500 line-clamp-2 mt-1">
              Bir tomonlama ijara haqini oshirish va garov depozitini qaytarmaslik asimmetriyalari.
            </p>
          </div>

          <div 
            onClick={startDemoAnalysis}
            className="p-4 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 hover:border-slate-300 dark:hover:border-slate-700 cursor-pointer transition-all group"
          >
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-[10px] font-mono px-2 py-0.5 rounded-md bg-sky-500/10 text-sky-600 dark:text-sky-400 font-bold">
                SUPPLY SALE
              </span>
              <ChevronRight className="w-4 h-4 text-slate-400 group-hover:translate-x-1 transition-transform" />
            </div>
            <h4 className="text-xs font-bold text-slate-900 dark:text-white">Uskunalar Yetkazib Berish</h4>
            <p className="text-[11px] text-slate-500 line-clamp-2 mt-1">
              Kafolat muddati, qabul qilish dalolatnomasi va to'lov kechikishi sanktsiyalari.
            </p>
          </div>
        </div>
      </section>

    </div>
  );
};
