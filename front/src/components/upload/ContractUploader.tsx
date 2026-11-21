import React, { useState, useRef } from 'react';
import { 
  UploadCloud, 
  FileText, 
  CheckCircle2, 
  AlertCircle, 
  Sparkles, 
  ArrowRight, 
  ShieldCheck, 
  Loader2,
  User,
  Building,
  Home,
  Car,
  Briefcase
} from 'lucide-react';
import { calculateSHA256, formatBytes } from '../../utils/crypto';
import { ProgressEvent } from '../../types/contract';
import { useAuth } from '../../context/AuthContext';

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
  const { user, activeEntityType } = useAuth();
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
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Rejim Indikatori (Jismoniy shaxs / Yuridik shaxs) */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-3 p-3.5 rounded-2xl bg-slate-900/80 border border-slate-800">
        <div className="flex items-center gap-2.5">
          <div className={`p-2 rounded-xl ${
            isIndividual ? 'bg-sky-500/20 text-sky-400 border border-sky-500/30' : 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
          }`}>
            {isIndividual ? <User className="w-5 h-5" /> : <Building className="w-5 h-5" />}
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="text-xs font-bold text-white uppercase tracking-wider">
                {isIndividual ? 'JISMONIY SHAXS REJIMI' : 'YURIDIK SHAXS (B2B) REJIMI'}
              </span>
              <span className={`text-[10px] font-mono px-2 py-0.2 rounded-full font-bold ${
                isIndividual ? 'bg-sky-500/20 text-sky-300' : 'bg-emerald-500/20 text-emerald-300'
              }`}>
                {isIndividual ? 'FUQARO · JShShIR' : 'KOMPANIYA · STIR'}
              </span>
            </div>
            <p className="text-[11px] text-slate-400">
              {isIndividual 
                ? 'Fuqarolik shartnomalari (Ijara, Oldi-sotdi, Xizmat) bo‘yicha O‘zbekiston FK asosida tahlil' 
                : 'Korporativ tijoriy shartnomalar (Yetkazib berish, IT xizmat, Pudrat) bo‘yicha B2B audit'}
            </p>
          </div>
        </div>

        <span className="text-[11px] font-mono text-slate-400 bg-slate-950 px-3 py-1 rounded-xl border border-slate-800">
          O‘RQ-547 Anonimizatsiya: Faol
        </span>
      </div>

      {/* Lex.uz Rasmiy Qonunchilik Bazasiga Integratsiya Banneri */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-3 p-3.5 px-4 rounded-2xl bg-gradient-to-r from-sky-950/30 via-slate-900 to-slate-900 border border-sky-500/25 shadow-sm">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-xl bg-slate-950 border border-slate-800 flex items-center justify-center shrink-0">
            <img src="/lex_uz.svg" alt="Lex.uz Logo" className="h-5 w-auto object-contain brightness-110" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="text-xs font-bold text-white">Lex.uz Milliy Qonunchilik Bazasi Bilan 100% Integratsiya</span>
              <span className="text-[9px] font-mono font-bold px-1.5 py-0.2 rounded bg-sky-500/20 text-sky-300 border border-sky-500/30 uppercase">
                Rasmiy Manba
              </span>
            </div>
            <p className="text-[11px] text-slate-400">
              O‘zR Fuqarolik, Mehnat va Soliq kodekslarining amaldagi barcha moddalari bo‘yicha avtomatik tekshiruv.
            </p>
          </div>
        </div>

        <a
          href="https://lex.uz"
          target="_blank"
          rel="noopener noreferrer"
          className="shrink-0 text-[11px] font-bold text-sky-400 hover:text-sky-300 flex items-center gap-1 transition-colors px-3 py-1.5 rounded-xl bg-slate-950 border border-slate-800 hover:border-sky-500/40"
        >
          <span>lex.uz portali</span>
          <ArrowRight className="w-3.5 h-3.5" />
        </a>
      </div>

      {/* Asosiy Yuklash Maydoni */}
      <div
        onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
        onDragLeave={() => setDragOver(false)}
        onDrop={handleDrop}
        className={`relative overflow-hidden rounded-3xl border-2 border-dashed p-8 sm:p-12 text-center transition-all duration-300 ${
          dragOver 
            ? (isIndividual ? 'border-sky-400 bg-sky-950/30' : 'border-emerald-400 bg-emerald-950/30') + ' scale-[1.01]' 
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
              <div className={`absolute inset-0 rounded-full border-4 animate-ping ${isIndividual ? 'border-sky-500/20' : 'border-emerald-500/20'}`}></div>
              <div className={`w-full h-full rounded-full border-4 border-t-sky-400 border-r-emerald-400 border-b-sky-500 border-l-transparent animate-spin`}></div>
              <div className="absolute inset-0 flex items-center justify-center font-bold text-xs text-sky-400">
                {progress?.progress_pct ?? 45}%
              </div>
            </div>

            <div className="space-y-2">
              <h3 className="text-lg font-bold text-white tracking-wide">
                Shartnoma Huquqiy Tahlildan O'tmoqda...
              </h3>
              <p className="text-xs text-slate-400 font-mono">
                Bosqich: <span className="text-sky-300 font-semibold">{progress?.stage || 'O‘RQ-547 PII MASKALASH'}</span>
              </p>
            </div>

            <div className="w-full bg-slate-800 rounded-full h-2 overflow-hidden">
              <div 
                className={`h-2 rounded-full transition-all duration-300 ${isIndividual ? 'bg-gradient-to-r from-sky-500 to-blue-500' : 'bg-gradient-to-r from-emerald-500 to-teal-500'}`}
                style={{ width: `${progress?.progress_pct ?? 45}%` }}
              />
            </div>
          </div>
        ) : selectedFile ? (
          /* Holat: Fayl tanlangan */
          <div className="space-y-6 max-w-md mx-auto">
            <div className={`w-16 h-16 rounded-2xl mx-auto flex items-center justify-center ${isIndividual ? 'bg-sky-500/20 text-sky-400' : 'bg-emerald-500/20 text-emerald-400'}`}>
              <FileText className="w-8 h-8" />
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
                className="w-full sm:w-auto px-5 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold border border-slate-700 transition-all cursor-pointer"
              >
                Boshqa fayl tanlash
              </button>

              <button
                type="button"
                onClick={startAnalysis}
                className={`w-full sm:w-auto px-6 py-2.5 rounded-xl text-white text-xs font-bold shadow-lg flex items-center justify-center gap-2 transition-all cursor-pointer hover:scale-105 ${
                  isIndividual ? 'bg-sky-500 hover:bg-sky-400 shadow-sky-500/20' : 'bg-emerald-500 hover:bg-emerald-400 shadow-emerald-500/20'
                }`}
              >
                <span>Tahlilni Boshlash</span>
                <ArrowRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        ) : (
          /* Holat: Bo'sh yuklash maydoni */
          <div className="space-y-5">
            <div className={`w-16 h-16 rounded-3xl mx-auto flex items-center justify-center transition-transform hover:scale-110 shadow-lg ${
              isIndividual 
                ? 'bg-gradient-to-tr from-sky-500 to-blue-600 text-white shadow-sky-500/20' 
                : 'bg-gradient-to-tr from-emerald-500 to-teal-600 text-white shadow-emerald-500/20'
            }`}>
              <UploadCloud className="w-8 h-8" />
            </div>

            <div className="space-y-1.5">
              <h3 className="text-lg font-bold text-white">
                {isIndividual 
                  ? 'Shartnoma faylini bu yerga tashlang (Jismoniy shaxs)' 
                  : 'B2B Shartnoma faylini bu yerga tashlang (Yuridik shaxs)'}
              </h3>
              <p className="text-xs text-slate-400">
                Word (.docx), PDF (.pdf) yoki matn (.txt) formatida, 25MB gacha
              </p>
            </div>

            <div className="flex flex-col sm:flex-row items-center justify-center gap-3 pt-2">
              <button
                type="button"
                onClick={() => fileInputRef.current?.click()}
                className={`px-5 py-2.5 rounded-xl text-white font-bold text-xs shadow-md transition-all flex items-center gap-2 cursor-pointer hover:scale-105 ${
                  isIndividual ? 'bg-sky-600 hover:bg-sky-500' : 'bg-emerald-600 hover:bg-emerald-500'
                }`}
              >
                <UploadCloud className="w-4 h-4" />
                <span>Kompyuterdan Tanlash</span>
              </button>

              <span className="text-xs text-slate-500">yoki</span>

              <button
                type="button"
                onClick={startDemoAnalysis}
                className="px-5 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 font-semibold text-xs border border-slate-700 hover:border-sky-500/50 transition-all flex items-center gap-2 cursor-pointer"
              >
                <Sparkles className="w-4 h-4 text-sky-400" />
                <span>{isIndividual ? 'Namunaviy Ijara Shartnomasini Sinash' : 'Namunaviy B2B Shartnomani Sinash'}</span>
              </button>
            </div>

            {error && (
              <div className="p-3 bg-red-950/40 border border-red-900/60 rounded-xl text-xs text-red-300 flex items-center justify-center gap-2 max-w-md mx-auto">
                <AlertCircle className="w-4 h-4 text-red-400" />
                <span>{error}</span>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Namunaviy Shablonlar Bloki (Jismoniy yoki Yuridik shaxsga mos) */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {isIndividual ? (
          <>
            <div 
              onClick={startDemoAnalysis}
              className="p-4 rounded-2xl bg-slate-900/50 hover:bg-slate-900/90 border border-slate-800 hover:border-sky-500/40 cursor-pointer transition-all group shadow-sm"
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-sky-950 text-sky-400 border border-sky-800 flex items-center gap-1">
                  <Home className="w-3 h-3" /> UY-JOY IJARASI
                </span>
                <ArrowRight className="w-3.5 h-3.5 text-slate-500 group-hover:text-sky-400 group-hover:translate-x-1 transition-all" />
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
              className="p-4 rounded-2xl bg-slate-900/50 hover:bg-slate-900/90 border border-slate-800 hover:border-sky-500/40 cursor-pointer transition-all group shadow-sm"
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-amber-950 text-amber-400 border border-amber-800 flex items-center gap-1">
                  <Car className="w-3 h-3" /> OLDI-SOTDI
                </span>
                <ArrowRight className="w-3.5 h-3.5 text-slate-500 group-hover:text-amber-400 group-hover:translate-x-1 transition-all" />
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
              className="p-4 rounded-2xl bg-slate-900/50 hover:bg-slate-900/90 border border-slate-800 hover:border-sky-500/40 cursor-pointer transition-all group shadow-sm"
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-950 text-emerald-400 border border-emerald-800 flex items-center gap-1">
                  <Briefcase className="w-3 h-3" /> XIZMAT / MEHNAT
                </span>
                <ArrowRight className="w-3.5 h-3.5 text-slate-500 group-hover:text-emerald-400 group-hover:translate-x-1 transition-all" />
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
              className="p-4 rounded-2xl bg-slate-900/50 hover:bg-slate-900/90 border border-slate-800 hover:border-emerald-500/40 cursor-pointer transition-all group shadow-sm"
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-950 text-emerald-400 border border-emerald-800">
                  B2B SERVICE
                </span>
                <ArrowRight className="w-3.5 h-3.5 text-slate-500 group-hover:text-emerald-400 group-hover:translate-x-1 transition-all" />
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
              className="p-4 rounded-2xl bg-slate-900/50 hover:bg-slate-900/90 border border-slate-800 hover:border-emerald-500/40 cursor-pointer transition-all group shadow-sm"
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
              className="p-4 rounded-2xl bg-slate-900/50 hover:bg-slate-900/90 border border-slate-800 hover:border-emerald-500/40 cursor-pointer transition-all group shadow-sm"
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-sky-950 text-sky-400 border border-sky-800">
                  SUPPLY SALE
                </span>
                <ArrowRight className="w-3.5 h-3.5 text-slate-500 group-hover:text-sky-400 group-hover:translate-x-1 transition-all" />
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
