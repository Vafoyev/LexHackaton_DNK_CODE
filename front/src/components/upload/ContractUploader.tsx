import React, { useState, useRef } from 'react';
import { UploadCloud, FileText, CheckCircle2, AlertCircle, Sparkles, ArrowRight, ShieldCheck, Loader2 } from 'lucide-react';
import { calculateSHA256, formatBytes } from '../../utils/crypto';
import { ProgressEvent } from '../../types/contract';

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
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Asosiy Yuklash Maydoni */}
      <div
        onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
        onDragLeave={() => setDragOver(false)}
        onDrop={handleDrop}
        className={`relative overflow-hidden rounded-3xl border-2 border-dashed p-8 sm:p-12 text-center transition-all duration-300 ${
          dragOver 
            ? 'border-sky-400 bg-sky-950/30 scale-[1.01]' 
            : selectedFile 
            ? 'border-emerald-500/50 bg-slate-900/60' 
            : 'border-slate-800 hover:border-slate-700 bg-slate-900/40 backdrop-blur-md'
        }`}
      >
        <input
          type="file"
          ref={fileInputRef}
          onChange={(e) => e.target.files?.[0] && handleFileChange(e.target.files[0])}
          accept=".docx,.pdf,.txt"
          className="hidden"
        />

        {/* Holat: Yuklanmoqda (SSE Progress) */}
        {isLoading ? (
          <div className="py-8 space-y-6 max-w-lg mx-auto">
            <div className="relative w-20 h-20 mx-auto">
              <div className="absolute inset-0 rounded-full border-4 border-sky-500/20 animate-ping"></div>
              <div className="w-full h-full rounded-full border-4 border-t-sky-400 border-r-sky-500 border-b-emerald-400 border-l-transparent animate-spin"></div>
              <div className="absolute inset-0 flex items-center justify-center font-bold text-xs text-sky-400">
                {progress?.progress_pct ?? 40}%
              </div>
            </div>

            <div className="space-y-2">
              <h3 className="text-lg font-bold text-white tracking-wide">
                Shartnoma Huquqiy Tahlildan O'tmoqda...
              </h3>
              <p className="text-xs text-sky-400 font-mono">
                Bosqich: {progress?.stage || 'PII_REDACTION'}
              </p>
              <p className="text-xs text-slate-400">
                {progress?.message || "10 ta Go Deterministik qoida va Lex.uz FK moddalari bilan tekshirilmoqda..."}
              </p>
            </div>

            {/* Progress Bar */}
            <div className="w-full bg-slate-800 rounded-full h-2.5 overflow-hidden">
              <div 
                className="bg-gradient-to-r from-sky-500 via-brand-500 to-emerald-400 h-2.5 rounded-full transition-all duration-300"
                style={{ width: `${progress?.progress_pct ?? 30}%` }}
              />
            </div>

            <div className="flex items-center justify-center gap-2 text-[11px] text-slate-500">
              <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" />
              <span>O'RQ-547 bo'yicha shaxsiy ma'lumotlar lokal himoyalangan</span>
            </div>
          </div>
        ) : (
          <div className="space-y-6">
            <div className="w-16 h-16 mx-auto rounded-2xl bg-gradient-to-tr from-sky-600/30 to-brand-500/20 border border-sky-500/30 flex items-center justify-center shadow-lg shadow-sky-500/10">
              <UploadCloud className="w-8 h-8 text-sky-400 animate-bounce" />
            </div>

            <div className="space-y-2 max-w-md mx-auto">
              <h2 className="text-xl font-bold text-white">
                B2B Shartnomani Yuklang yoki Tashlang
              </h2>
              <p className="text-xs text-slate-400">
                DOCX, PDF yoki TXT formatdagi shartnomani bu yerga tortib keling yoki tanlang (maksimal 25MB)
              </p>
            </div>

            {/* Tanlangan fayl ko'rinishi */}
            {selectedFile && (
              <div className="max-w-md mx-auto p-4 rounded-2xl bg-slate-950/80 border border-slate-700/80 text-left space-y-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <FileText className="w-6 h-6 text-sky-400" />
                    <div>
                      <div className="text-xs font-bold text-white truncate max-w-[220px]">
                        {selectedFile.name}
                      </div>
                      <div className="text-[11px] text-slate-400">
                        {formatBytes(selectedFile.size)}
                      </div>
                    </div>
                  </div>
                  <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                </div>

                {sha256 && (
                  <div className="text-[10px] font-mono text-slate-500 truncate pt-1 border-t border-slate-800">
                    SHA256: <span className="text-slate-400">{sha256}</span>
                  </div>
                )}

                <button
                  onClick={startAnalysis}
                  className="w-full mt-3 py-2.5 px-4 rounded-xl bg-gradient-to-r from-sky-500 via-brand-600 to-emerald-500 hover:opacity-95 text-white font-bold text-xs shadow-lg shadow-sky-500/25 flex items-center justify-center gap-2 transition-all"
                >
                  <Sparkles className="w-4 h-4" />
                  <span>3D Huquqiy Tahlilni Boshlash</span>
                </button>
              </div>
            )}

            {!selectedFile && (
              <div className="flex flex-col sm:flex-row items-center justify-center gap-3">
                <button
                  type="button"
                  onClick={() => fileInputRef.current?.click()}
                  className="px-5 py-2.5 rounded-xl bg-sky-600 hover:bg-sky-500 text-white font-semibold text-xs shadow-md shadow-sky-600/30 transition-all flex items-center gap-2"
                >
                  <UploadCloud className="w-4 h-4" />
                  <span>Kompyuterdan Tanlash</span>
                </button>

                <span className="text-xs text-slate-500">yoki</span>

                <button
                  type="button"
                  onClick={startDemoAnalysis}
                  className="px-5 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-sky-300 font-semibold text-xs border border-slate-700 hover:border-sky-500/50 transition-all flex items-center gap-2"
                >
                  <Sparkles className="w-4 h-4 text-sky-400" />
                  <span>Namunaviy IT Xizmat Shartnomasini Sinash</span>
                </button>
              </div>
            )}

            {error && (
              <div className="p-3 bg-red-950/40 border border-red-900/60 rounded-xl text-xs text-red-300 flex items-center justify-center gap-2 max-w-md mx-auto">
                <AlertCircle className="w-4 h-4 text-red-400" />
                <span>{error}</span>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Namunaviy Shablonlar Bloki */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div 
          onClick={startDemoAnalysis}
          className="p-4 rounded-2xl bg-slate-900/50 hover:bg-slate-900/90 border border-slate-800 hover:border-sky-500/40 cursor-pointer transition-all group shadow-sm"
        >
          <div className="flex items-center justify-between mb-2">
            <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-sky-950 text-sky-400 border border-sky-800">
              B2B SERVICE
            </span>
            <ArrowRight className="w-3.5 h-3.5 text-slate-500 group-hover:text-sky-400 group-hover:translate-x-1 transition-all" />
          </div>
          <h4 className="text-xs font-bold text-white mb-1">
            IT Xizmat Ko'rsatish Shartnomasi
          </h4>
          <p className="text-[11px] text-slate-400 line-clamp-2">
            FK 707 (Bir tomonlama bekor qilish), Cheksiz javobgarlik va kunlik 1% penya xavflari bilan.
          </p>
        </div>

        <div 
          onClick={startDemoAnalysis}
          className="p-4 rounded-2xl bg-slate-900/50 hover:bg-slate-900/90 border border-slate-800 hover:border-sky-500/40 cursor-pointer transition-all group shadow-sm"
        >
          <div className="flex items-center justify-between mb-2">
            <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-amber-950 text-amber-400 border border-amber-800">
              COMMERCIAL LEASE
            </span>
            <ArrowRight className="w-3.5 h-3.5 text-slate-500 group-hover:text-amber-400 group-hover:translate-x-1 transition-all" />
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
          className="p-4 rounded-2xl bg-slate-900/50 hover:bg-slate-900/90 border border-slate-800 hover:border-sky-500/40 cursor-pointer transition-all group shadow-sm"
        >
          <div className="flex items-center justify-between mb-2">
            <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-950 text-emerald-400 border border-emerald-800">
              SUPPLY SALE
            </span>
            <ArrowRight className="w-3.5 h-3.5 text-slate-500 group-hover:text-emerald-400 group-hover:translate-x-1 transition-all" />
          </div>
          <h4 className="text-xs font-bold text-white mb-1">
            Uskunalar Yetkazib Berish Shartnomasi
          </h4>
          <p className="text-[11px] text-slate-400 line-clamp-2">
            Kafolat muddati, qabul qilish dalolatnomasi va to'lov kechikishi sanktsiyalari.
          </p>
        </div>
      </div>
    </div>
  );
};
