import React, { useRef, useState } from 'react';
import { Card } from '../ui/card';
import { Button } from '../ui/button';
import { Badge } from '../ui/badge';
import { 
  Upload, 
  FileText, 
  X, 
  ShieldCheck, 
  Sparkles, 
  Lock, 
  ArrowRight,
  FileCode,
  Home,
  ShoppingBag
} from 'lucide-react';
import { ProgressEvent } from '../../types/contract';

interface ScanUploadModalProps {
  isOpen: boolean;
  onClose: () => void;
  onAnalyze: (file: File | null, isDemo: boolean) => Promise<void>;
  isLoading: boolean;
  progress: ProgressEvent | null;
}

export const ScanUploadModal: React.FC<ScanUploadModalProps> = ({
  isOpen,
  onClose,
  onAnalyze,
  isLoading,
  progress,
}) => {
  const [dragActive, setDragActive] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  if (!isOpen) return null;

  const handleDrag = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === 'dragenter' || e.type === 'dragover') {
      setDragActive(true);
    } else if (e.type === 'dragleave') {
      setDragActive(false);
    }
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      setSelectedFile(e.dataTransfer.files[0]);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    e.preventDefault();
    if (e.target.files && e.target.files[0]) {
      setSelectedFile(e.target.files[0]);
    }
  };

  const handleStartAnalysis = async () => {
    if (selectedFile) {
      await onAnalyze(selectedFile, false);
      onClose();
    }
  };

  const handleSelectSample = async (sampleType: 'it' | 'ijara' | 'olish') => {
    await onAnalyze(null, true);
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in duration-200">
      <div 
        className="relative w-full max-w-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl shadow-2xl overflow-hidden p-6 space-y-6"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-800">
          <div>
            <h2 className="text-xl font-bold tracking-tight text-slate-900 dark:text-white flex items-center gap-2">
              <Upload className="w-5 h-5 text-sky-600 dark:text-sky-400" />
              Shartnomani Skanerlash va Tahlil Qilish
            </h2>
            <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
              Word (.docx), PDF (.pdf) yoki matn faylini yuklang
            </p>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Dropzone */}
        <div
          onDragEnter={handleDrag}
          onDragLeave={handleDrag}
          onDragOver={handleDrag}
          onDrop={handleDrop}
          onClick={() => inputRef.current?.click()}
          className={`cursor-pointer border-2 border-dashed rounded-xl p-8 text-center transition-all duration-200 ${
            dragActive
              ? 'border-sky-500 bg-sky-50/50 dark:bg-sky-950/20'
              : 'border-slate-200 dark:border-slate-800 hover:border-sky-400 bg-slate-50/50 dark:bg-slate-900/50'
          }`}
        >
          <input
            ref={inputRef}
            type="file"
            className="hidden"
            accept=".docx,.pdf,.txt"
            onChange={handleChange}
          />
          <div className="flex flex-col items-center justify-center space-y-3">
            <div className="p-3.5 rounded-full bg-sky-100 dark:bg-sky-950/60 text-sky-600 dark:text-sky-400">
              <Upload className="w-6 h-6" />
            </div>
            {selectedFile ? (
              <div className="space-y-1">
                <p className="text-sm font-semibold text-slate-900 dark:text-white">
                  {selectedFile.name}
                </p>
                <p className="text-xs text-slate-500">
                  {(selectedFile.size / 1024 / 1024).toFixed(2)} MB · Tanlandi
                </p>
              </div>
            ) : (
              <div className="space-y-1">
                <p className="text-sm font-medium text-slate-800 dark:text-slate-200">
                  Faylni shu yerga tortib tashlang yoki tanlang
                </p>
                <p className="text-xs text-slate-500 dark:text-slate-400">
                  DOCX, PDF yoki TXT (25MB gacha)
                </p>
              </div>
            )}
          </div>
        </div>

        {selectedFile && (
          <Button
            onClick={handleStartAnalysis}
            disabled={isLoading}
            className="w-full gap-2 shadow-md"
            size="lg"
          >
            <Sparkles className="w-4 h-4" />
            {isLoading ? 'Audit o\'tkazilmoqda...' : 'Auditni Boshlash (Lex.uz Sinxron)'}
          </Button>
        )}

        {/* Quick Sample Contracts */}
        <div className="space-y-2 pt-2">
          <span className="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider block">
            Yoki Namunaviy Shartnomani Sinab Ko'ring:
          </span>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
            <button
              onClick={() => handleSelectSample('it')}
              className="flex items-center gap-2 p-2.5 rounded-lg border border-slate-200 dark:border-slate-800 hover:border-sky-500 text-left transition-colors bg-white dark:bg-slate-850"
            >
              <FileCode className="w-4 h-4 text-sky-500 shrink-0" />
              <div className="truncate">
                <div className="text-xs font-semibold text-slate-800 dark:text-slate-200 truncate">IT Autsorsing</div>
                <div className="text-[10px] text-slate-500">B2B Shartnoma</div>
              </div>
            </button>
            <button
              onClick={() => handleSelectSample('ijara')}
              className="flex items-center gap-2 p-2.5 rounded-lg border border-slate-200 dark:border-slate-800 hover:border-sky-500 text-left transition-colors bg-white dark:bg-slate-850"
            >
              <Home className="w-4 h-4 text-emerald-500 shrink-0" />
              <div className="truncate">
                <div className="text-xs font-semibold text-slate-800 dark:text-slate-200 truncate">Uy-joy Ijarasi</div>
                <div className="text-[10px] text-slate-500">B2C Fuqarolik</div>
              </div>
            </button>
            <button
              onClick={() => handleSelectSample('olish')}
              className="flex items-center gap-2 p-2.5 rounded-lg border border-slate-200 dark:border-slate-800 hover:border-sky-500 text-left transition-colors bg-white dark:bg-slate-850"
            >
              <ShoppingBag className="w-4 h-4 text-amber-500 shrink-0" />
              <div className="truncate">
                <div className="text-xs font-semibold text-slate-800 dark:text-slate-200 truncate">Oldi-Sotdi</div>
                <div className="text-[10px] text-slate-500">Mulk va Avto</div>
              </div>
            </button>
          </div>
        </div>

        {/* Security Footer Notice */}
        <div className="flex items-center justify-between pt-2 border-t border-slate-100 dark:border-slate-800 text-[11px] text-slate-500 dark:text-slate-400">
          <span className="flex items-center gap-1.5">
            <Lock className="w-3.5 h-3.5 text-emerald-500" />
            O‘RQ-547 Lokal PII Sanitization faol
          </span>
          <span>Lex.uz bazasi bilan sinxron</span>
        </div>
      </div>
    </div>
  );
};
