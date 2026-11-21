import React, { useRef, useState } from 'react';
import { FileCode, Home, Lock, ShoppingBag, Sparkles, Upload } from 'lucide-react';
import { ProgressEvent } from '../../types/contract';
import { SampleContract } from '../../data/sampleContracts';
import { Alert, AlertDescription } from '../ui/alert';
import { Button } from '../ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '../ui/dialog';
import { Progress } from '../ui/progress';
import { Separator } from '../ui/separator';

interface ScanUploadModalProps {
  isOpen: boolean;
  onClose: () => void;
  onAnalyze: (file: File | null, isDemo: boolean, sampleId?: SampleContract['id']) => Promise<boolean | void>;
  isLoading: boolean;
  progress: ProgressEvent | null;
  error?: string | null;
}

const SAMPLES = [
  { id: 'it' as const, title: 'IT autsorsing', subtitle: 'B2B shartnoma', icon: FileCode, tone: 'text-zinc-500' },
  { id: 'ijara' as const, title: 'Uy-joy ijarasi', subtitle: 'B2C fuqarolik', icon: Home, tone: 'text-emerald-500' },
  { id: 'olish' as const, title: 'Oldi-sotdi', subtitle: 'Mulk va avto', icon: ShoppingBag, tone: 'text-amber-500' },
] as const;

export const ScanUploadModal: React.FC<ScanUploadModalProps> = ({ isOpen, onClose, onAnalyze, isLoading, progress, error }) => {
  const [dragActive, setDragActive] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleDrag = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === 'dragenter' || e.type === 'dragover') setDragActive(true);
    else if (e.type === 'dragleave') setDragActive(false);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    const file = e.dataTransfer.files?.[0];
    if (file) setSelectedFile(file);
  };

  const handleStartAnalysis = async () => {
    if (!selectedFile) return;
    const ok = await onAnalyze(selectedFile, false);
    if (ok !== false) onClose();
  };

  const handleSelectSample = async (sampleId: SampleContract['id']) => {
    const ok = await onAnalyze(null, true, sampleId);
    if (ok !== false) onClose();
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2 text-xl">
            <Upload className="h-5 w-5 text-primary" aria-hidden="true" />
            Shartnomani skanerlash va tahlil qilish
          </DialogTitle>
          <DialogDescription>Word (.docx), PDF (.pdf) yoki matn faylini yuklang</DialogDescription>
        </DialogHeader>

        <label
          htmlFor="scan-file"
          onDragEnter={handleDrag}
          onDragLeave={handleDrag}
          onDragOver={handleDrag}
          onDrop={handleDrop}
          className={`flex cursor-pointer flex-col items-center justify-center gap-3 rounded-xl border-2 border-dashed p-8 text-center transition-colors focus-within:ring-2 focus-within:ring-ring ${
            dragActive ? 'border-primary bg-primary/5' : 'border-border bg-muted/40 hover:border-primary/60'
          }`}
        >
          <input
            id="scan-file"
            ref={inputRef}
            type="file"
            className="sr-only"
            accept=".docx,.pdf,.txt"
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) setSelectedFile(file);
            }}
          />
          <span className="rounded-full bg-primary/10 p-3.5 text-primary">
            <Upload className="h-6 w-6" aria-hidden="true" />
          </span>
          {selectedFile ? (
            <span className="space-y-1">
              <span className="block text-sm font-semibold">{selectedFile.name}</span>
              <span className="block text-xs text-muted-foreground">{(selectedFile.size / 1024 / 1024).toFixed(2)} MB, tanlandi</span>
            </span>
          ) : (
            <span className="space-y-1">
              <span className="block text-sm font-medium">Faylni shu yerga tortib tashlang yoki tanlang</span>
              <span className="block text-xs text-muted-foreground">DOCX, PDF yoki TXT (25 MB gacha)</span>
            </span>
          )}
        </label>

        {isLoading && (
          <div className="space-y-1.5" role="status">
            <Progress value={progress?.progress_pct ?? 5} />
            <p className="text-xs text-muted-foreground">{progress?.message || 'Audit o‘tkazilmoqda…'}</p>
          </div>
        )}

        {error && (
          <Alert variant="destructive" role="alert">
            <AlertDescription>{error}</AlertDescription>
          </Alert>
        )}

        {selectedFile && (
          <Button onClick={handleStartAnalysis} disabled={isLoading} size="lg" className="w-full gap-2">
            <Sparkles className="h-4 w-4" aria-hidden="true" />
            {isLoading ? 'Audit o‘tkazilmoqda…' : 'Auditni boshlash'}
          </Button>
        )}

        <div className="space-y-2">
          <p className="text-xs font-medium text-muted-foreground">Yoki namunaviy shartnomani sinab ko‘ring</p>
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
            {SAMPLES.map(({ id, title, subtitle, icon: Icon, tone }) => (
              <Button
                key={id}
                type="button"
                variant="outline"
                onClick={() => handleSelectSample(id)}
                disabled={isLoading}
                className="h-auto justify-start gap-2 px-3 py-2.5 text-left"
              >
                <Icon className={`h-4 w-4 shrink-0 ${tone}`} aria-hidden="true" />
                <span className="min-w-0">
                  <span className="block truncate text-xs font-semibold">{title}</span>
                  <span className="block truncate text-[10px] font-normal text-muted-foreground">{subtitle}</span>
                </span>
              </Button>
            ))}
          </div>
        </div>

        <Separator />
        <DialogFooter className="flex-row items-center justify-between gap-2 text-[11px] text-muted-foreground sm:justify-between">
          <span className="flex items-center gap-1.5">
            <Lock className="h-3.5 w-3.5 text-emerald-500" aria-hidden="true" />
            O‘RQ-547: shaxsga doir ma’lumotlar lokal maskalanadi
          </span>
          <span>Lex.uz bazasi bilan ishlaydi</span>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};
