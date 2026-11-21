import React, { useState, useRef } from 'react';
import { AlertCircle, ArrowRight, Upload, Sparkles, FileText, CheckCircle2 } from 'lucide-react';
import { calculateSHA256, formatBytes } from '../../utils/crypto';
import { ProgressEvent } from '../../types/contract';
import { useAuth } from '../../context/AuthContext';
import { LexUz3DLogo } from '../3d/LexUz3DLogo';

interface ContractUploaderProps {
  onAnalyze: (file: File | null, isDemo: boolean) => void;
  isLoading: boolean;
  progress: ProgressEvent | null;
}

export const ContractUploader: React.FC<ContractUploaderProps> = ({
  onAnalyze,
  isLoading,
  progress,
}) => {
  const { user, activeEntityType, switchEntityType } = useAuth();
  const isIndividual = (user?.entity_type || activeEntityType) === 'INDIVIDUAL';

  const [dragOver, setDragOver] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [sha256, setSha256] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

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
    <div className="max-w-4xl mx-auto space-y-7">
      {/* ============================================================
          1. DUAL-ROLE SEGMENTED LIQUID GLASS CAPSULE
          ============================================================ */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-3 p-2.5 sm:p-3 rounded-full liquid-glass-pill">
        {/* Role toggle buttons */}
        <div className="flex items-center p-1 rounded-full bg-black/40 border border-white/10 w-full sm:w-auto">
          <button
            onClick={() => switchEntityType('INDIVIDUAL')}
            className={`flex-1 sm:flex-none flex items-center justify-center gap-2 px-4 py-1.5 rounded-full text-xs font-bold transition-all cursor-pointer ${
              isIndividual
                ? 'bg-gradient-to-r from-zinc-500 to-zinc-600 text-white shadow-lg shadow-zinc-500/30'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            <span className="w-2 h-2 rounded-full bg-zinc-400 animate-pulse" />
            <span>Jismoniy Shaxs (B2C)</span>
          </button>

          <button
            onClick={() => switchEntityType('LEGAL_ENTITY')}
            className={`flex-1 sm:flex-none flex items-center justify-center gap-2 px-4 py-1.5 rounded-full text-xs font-bold transition-all cursor-pointer ${
              !isIndividual
                ? 'bg-gradient-to-r from-emerald-500 to-zinc-600 text-white shadow-lg shadow-emerald-500/30'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
            <span>Yuridik Shaxs (B2B)</span>
          </button>
        </div>

        {/* Security / Norms Tag */}
        <div className="flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/[0.04] border border-white/10 text-[11px] font-mono text-slate-300">
          <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" />
          <span>O‘RQ-547 Anonimizatsiya: <strong className="text-emerald-400 font-semibold">Faol</strong></span>
        </div>
      </div>

      {/* ============================================================
          2. 3D LEX.UZ LIQUID GLASS HERO CHAMBER
          ============================================================ */}
      <div className={`relative overflow-hidden rounded-3xl p-6 sm:p-8 transition-all duration-500 liquid-hover-glow ${
        isIndividual ? 'liquid-glass-sapphire' : 'liquid-glass-emerald'
      }`}>
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-center">
          {/* Matn qismi */}
          <div className="lg:col-span-7 space-y-3.5">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/40 dark:bg-white/10 border border-slate-300 dark:border-white/20 text-slate-800 dark:text-white text-[10px] font-mono font-bold tracking-wider">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-ping" />
              <span>O‘ZBEKISTON RESPUBLIKASI LEX.UZ BAZASI BILAN SINXRON</span>
            </div>

            <h1 className="text-2xl sm:text-3xl font-black text-slate-900 dark:text-white tracking-tight leading-tight">
              Shartnomangizni <span className={`bg-clip-text text-transparent ${
                isIndividual 
                  ? 'bg-gradient-to-r from-zinc-600 via-zinc-600 to-zinc-600 dark:from-zinc-400 dark:via-zinc-300 dark:to-zinc-400' 
                  : 'bg-gradient-to-r from-emerald-600 via-zinc-600 to-green-600 dark:from-emerald-300 dark:via-zinc-200 dark:to-green-400'
              }`}>
                Imzolashdan Oldin
              </span> Huquqiy Auditdan O‘tkazing
            </h1>

            <p className="text-xs sm:text-sm text-slate-700 dark:text-slate-300 leading-relaxed font-normal">
              {isIndividual 
                ? 'Fuqarolik shartnomalari (Ijara, Oldi-sotdi, Avto, Mehnat) dagi yashirin xavflar, asimmetriyalar va noqonuniy jarimalarni Lex.uz moddalari bo‘yicha tahlil qiling.'
                : 'B2B korporativ bitimlari (Yetkazib berish, IT xizmat, Tijoriy ijara) bo‘yicha O‘zbekiston qonunchiligiga to‘liq muvofiqlik auditi va 2 xil DOCX eksport.'}
            </p>

            <div className="flex flex-wrap items-center gap-3 pt-2 text-[11px] font-mono text-slate-700 dark:text-slate-300">
              <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-slate-100 dark:bg-white/5 border border-slate-200 dark:border-white/10">
                <span className="w-2 h-2 rounded-full bg-rose-500" />
                <span>Qizil: Qonun xavfi</span>
              </div>
              <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-slate-100 dark:bg-white/5 border border-slate-200 dark:border-white/10">
                <span className="w-2 h-2 rounded-full bg-amber-500" />
                <span>Sariq: Tijoriy risk</span>
              </div>
              <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-slate-100 dark:bg-white/5 border border-slate-200 dark:border-white/10">
                <span className="w-2 h-2 rounded-full bg-emerald-500" />
                <span>Yashil: Topilma yo‘q</span>
              </div>
            </div>
          </div>

          {/* 3D Lex.uz Dizayn Elementi */}
          <div className="lg:col-span-5 flex flex-col items-center justify-center relative">
            <div className="w-full h-56 sm:h-64 rounded-2xl relative overflow-hidden flex items-center justify-center">
              {/* Soft radial glow behind 3D emblem */}
              <div className={`absolute inset-0 rounded-full blur-2xl opacity-30 pointer-events-none ${
                isIndividual ? 'bg-zinc-500' : 'bg-emerald-500'
              }`} />
              <LexUz3DLogo size="md" className="w-full h-full relative z-10" autoRotate={true} interactive={false} />
            </div>
          </div>
        </div>
      </div>

      {/* ============================================================
          3. LIQUID GLASS FILE UPLOAD DROPZONE
          ============================================================ */}
      <div
        onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
        onDragLeave={() => setDragOver(false)}
        onDrop={handleDrop}
        className={`relative overflow-hidden rounded-3xl p-8 sm:p-12 text-center transition-all duration-300 liquid-glass-card ${
          dragOver 
            ? isIndividual 
              ? 'border-zinc-400 bg-zinc-950/40 scale-[1.01]' 
              : 'border-emerald-400 bg-emerald-950/40 scale-[1.01]'
            : selectedFile 
            ? 'border-emerald-500/50 bg-slate-900/50' 
            : 'border-white/10 hover:border-white/20'
        }`}
      >
        <input
          type="file"
          ref={fileInputRef}
          onChange={(e) => e.target.files?.[0] && handleFileChange(e.target.files[0])}
          accept=".docx,.pdf,.txt"
          className="hidden"
        />

        {/* Holat 1: Yuklanmoqda (SSE Progress) */}
        {isLoading ? (
          <div className="py-8 space-y-6 max-w-lg mx-auto">
            <div className="relative w-24 h-24 mx-auto">
              <div className={`absolute inset-0 rounded-full border-4 animate-ping ${isIndividual ? 'border-zinc-500/20' : 'border-emerald-500/20'}`} />
              <div className="w-full h-full rounded-full border-4 border-t-sky-400 border-r-emerald-400 border-b-sky-500 border-l-transparent animate-spin" />
              <div className="absolute inset-0 flex items-center justify-center font-black text-sm text-white">
                {progress?.progress_pct ?? 45}%
              </div>
            </div>

            <div className="space-y-2">
              <h3 className="text-lg font-bold text-white tracking-wide">
                Shartnoma Huquqiy Tahlildan O'tmoqda...
              </h3>
              <p className="text-xs text-slate-300 font-mono">
                Bosqich: <span className="text-zinc-300 font-semibold">{progress?.stage || 'O‘RQ-547 PII MASKALASH'}</span>
              </p>
            </div>

            {/* Liquid Glass Progress Track */}
            <div className="w-full bg-black/40 rounded-full h-2.5 overflow-hidden p-0.5 border border-white/10">
              <div 
                className={`h-full rounded-full transition-all duration-300 ${
                  isIndividual 
                    ? 'bg-gradient-to-r from-zinc-500 to-zinc-500 shadow-sm shadow-zinc-500' 
                    : 'bg-gradient-to-r from-emerald-500 to-zinc-500 shadow-sm shadow-emerald-500'
                }`}
                style={{ width: `${progress?.progress_pct ?? 45}%` }}
              />
            </div>
          </div>
        ) : selectedFile ? (
          /* Holat 2: Fayl tanlangan */
          <div className="space-y-6 max-w-md mx-auto">
            <div className={`w-16 h-16 rounded-2xl mx-auto flex items-center justify-center p-3 liquid-glass-pill ${
              isIndividual ? 'border-zinc-500/40 shadow-zinc-500/20' : 'border-emerald-500/40 shadow-emerald-500/20'
            }`}>
              <FileText className={`w-8 h-8 ${isIndividual ? 'text-zinc-400' : 'text-emerald-400'}`} />
            </div>

            <div>
              <h3 className="text-base font-bold text-white break-words">
                {selectedFile.name}
              </h3>
              <p className="text-xs text-slate-400 mt-1 font-mono">
                Hajmi: {formatBytes(selectedFile.size)} · SHA256: {sha256?.substring(0, 16)}...
              </p>
            </div>

            <div className="flex flex-col sm:flex-row items-center justify-center gap-3">
              <button
                type="button"
                onClick={() => setSelectedFile(null)}
                className="w-full sm:w-auto px-5 py-2.5 rounded-full liquid-glass-subtle hover:bg-white/10 text-slate-300 text-xs font-semibold transition-all cursor-pointer"
              >
                Boshqa fayl tanlash
              </button>

              <button
                type="button"
                onClick={startAnalysis}
                className={`w-full sm:w-auto px-7 py-2.5 rounded-full text-white text-xs font-bold shadow-xl flex items-center justify-center gap-2 transition-all cursor-pointer hover:scale-105 ${
                  isIndividual 
                    ? 'bg-gradient-to-r from-zinc-500 to-zinc-600 shadow-zinc-500/30' 
                    : 'bg-gradient-to-r from-emerald-500 to-zinc-600 shadow-emerald-500/30'
                }`}
              >
                <span>Tahlilni Boshlash</span>
                <ArrowRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        ) : (
          /* Holat 3: Bo'sh yuklash maydoni */
          <div className="space-y-5">
            <div className="w-16 h-16 rounded-2xl mx-auto flex items-center justify-center p-3 liquid-glass-pill border-white/20 shadow-xl group-hover:scale-110 transition-transform">
              <Upload className={`w-7 h-7 ${isIndividual ? 'text-zinc-400' : 'text-emerald-400'}`} />
            </div>

            <div className="space-y-1.5">
              <h3 className="text-lg sm:text-xl font-bold text-white tracking-tight">
                {isIndividual 
                  ? 'Fuqarolik shartnomasi faylini bu yerga tashlang' 
                  : 'B2B korporativ shartnoma faylini bu yerga tashlang'}
              </h3>
              <p className="text-xs text-slate-400">
                Word (.docx), PDF (.pdf) yoki matn (.txt) formatida, 25MB gacha
              </p>
            </div>

            <div className="flex flex-col sm:flex-row items-center justify-center gap-3 pt-2">
              <button
                type="button"
                onClick={() => fileInputRef.current?.click()}
                className={`px-6 py-2.5 rounded-full text-white font-bold text-xs shadow-xl transition-all cursor-pointer hover:scale-105 ${
                  isIndividual 
                    ? 'bg-gradient-to-r from-zinc-500 to-zinc-600 shadow-zinc-500/30' 
                    : 'bg-gradient-to-r from-emerald-500 to-zinc-600 shadow-emerald-500/30'
                }`}
              >
                Kompyuterdan Tanlash
              </button>

              <span className="text-xs text-slate-500 font-medium">yoki</span>

              <button
                type="button"
                onClick={startDemoAnalysis}
                className="px-6 py-2.5 rounded-full liquid-glass-subtle hover:bg-white/10 text-slate-200 font-semibold text-xs border border-white/10 hover:border-white/20 transition-all cursor-pointer"
              >
                {isIndividual ? 'Namunaviy Ijara Shartnomasini Sinash' : 'Namunaviy B2B IT Shartnomani Sinash'}
              </button>
            </div>

            {error && (
              <div className="p-3 bg-red-950/50 border border-red-500/30 rounded-2xl text-xs text-red-300 flex items-center justify-center gap-2 max-w-md mx-auto">
                <AlertCircle className="w-4 h-4 text-red-400 shrink-0" />
                <span>{error}</span>
              </div>
            )}
          </div>
        )}
      </div>

      {/* ============================================================
          4. LIQUID GLASS DEMO CONTRACT PILLS
          ============================================================ */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {isIndividual ? (
          <>
            <div 
              onClick={startDemoAnalysis}
              className="p-4 rounded-2xl liquid-glass-card liquid-hover-glow cursor-pointer transition-all group border-white/10"
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-zinc-500/15 text-zinc-400 border border-zinc-500/30 font-bold">
                  UY-JOY IJARASI
                </span>
                <span className="text-slate-500 group-hover:text-zinc-400 group-hover:translate-x-1 transition-all text-xs font-bold">→</span>
              </div>
              <h4 className="text-xs font-bold text-white mb-1">
                Kvartira / Bino Ijara Shartnomasi
              </h4>
              <p className="text-[11px] text-slate-400 line-clamp-2">
                Garov depozitini qaytarish, muddatidan oldin chiqarib yuborish va kommunal to‘lov asimmetriyalari.
              </p>
            </div>

            <div 
              onClick={startDemoAnalysis}
              className="p-4 rounded-2xl liquid-glass-card liquid-hover-glow cursor-pointer transition-all group border-white/10"
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-amber-500/15 text-amber-400 border border-amber-500/30 font-bold">
                  OLDI-SOTDI
                </span>
                <span className="text-slate-500 group-hover:text-amber-400 group-hover:translate-x-1 transition-all text-xs font-bold">→</span>
              </div>
              <h4 className="text-xs font-bold text-white mb-1">
                Avtomobil / Mulk Oldi-Sotdi Bitimi
              </h4>
              <p className="text-[11px] text-slate-400 line-clamp-2">
                To‘lov grafigi, nuqsonlar uchun javobgarlik va notarial tasdiqlash majburiyatlari.
              </p>
            </div>

            <div 
              onClick={startDemoAnalysis}
              className="p-4 rounded-2xl liquid-glass-card liquid-hover-glow cursor-pointer transition-all group border-white/10"
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 font-bold">
                  XIZMAT / MEHNAT
                </span>
                <span className="text-slate-500 group-hover:text-emerald-400 group-hover:translate-x-1 transition-all text-xs font-bold">→</span>
              </div>
              <h4 className="text-xs font-bold text-white mb-1">
                Fuqarolik-Huquqiy Xizmat Shartnomasi
              </h4>
              <p className="text-[11px] text-slate-400 line-clamp-2">
                Mehnat qonunchiligi (MK) va FK o‘rtasidagi farqlar, noqonuniy jarimalar va to‘lov kafolatlari.
              </p>
            </div>
          </>
        ) : (
          <>
            <div 
              onClick={startDemoAnalysis}
              className="p-4 rounded-2xl liquid-glass-card liquid-hover-glow cursor-pointer transition-all group border-white/10"
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 font-bold">
                  B2B SERVICE
                </span>
                <span className="text-slate-500 group-hover:text-emerald-400 group-hover:translate-x-1 transition-all text-xs font-bold">→</span>
              </div>
              <h4 className="text-xs font-bold text-white mb-1">
                IT Xizmat Ko'rsatish Shartnomasi
              </h4>
              <p className="text-[11px] text-slate-400 line-clamp-2">
                FK 707 (Bir tomonlama bekor qilish), Cheksiz javobgarlik va kunlik 0.5% penya asimmetriyasi.
              </p>
            </div>

            <div 
              onClick={startDemoAnalysis}
              className="p-4 rounded-2xl liquid-glass-card liquid-hover-glow cursor-pointer transition-all group border-white/10"
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-amber-500/15 text-amber-400 border border-amber-500/30 font-bold">
                  COMMERCIAL LEASE
                </span>
                <span className="text-slate-500 group-hover:text-amber-400 group-hover:translate-x-1 transition-all text-xs font-bold">→</span>
              </div>
              <h4 className="text-xs font-bold text-white mb-1">
                Tijoriy Bino Ijarasi Shartnomasi
              </h4>
              <p className="text-[11px] text-slate-400 line-clamp-2">
                Bir tomonlama ijara haqini oshirish va garov depozitini qaytarmaslik asimmetriyalari.
              </p>
            </div>

            <div 
              onClick={startDemoAnalysis}
              className="p-4 rounded-2xl liquid-glass-card liquid-hover-glow cursor-pointer transition-all group border-white/10"
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-zinc-500/15 text-zinc-400 border border-zinc-500/30 font-bold">
                  SUPPLY SALE
                </span>
                <span className="text-slate-500 group-hover:text-zinc-400 group-hover:translate-x-1 transition-all text-xs font-bold">→</span>
              </div>
              <h4 className="text-xs font-bold text-white mb-1">
                Uskunalar Yetkazib Berish Shartnomasi
              </h4>
              <p className="text-[11px] text-slate-400 line-clamp-2">
                Kafolat muddati, qabul qilish dalolatnomasi va to'lov kechikishi sanktsiyalari.
              </p>
            </div>
          </>
        )}
      </div>
    </div>
  );
};
