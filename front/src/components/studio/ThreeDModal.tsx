import React, { useState } from 'react';
import { X, Cpu, Box, Sparkles, Scale } from 'lucide-react';
import { AnalysisResult } from '../../types/contract';
import { Contract3DVisualizer } from '../visualizer/Contract3DVisualizer';
import { LexUz3DLogo } from '../3d/LexUz3DLogo';
import { LegalScales3D } from '../3d/LegalScales3D';

interface ThreeDModalProps {
  isOpen: boolean;
  onClose: () => void;
  analysis: AnalysisResult;
  selectedClauseId?: string | null;
  onSelectClause: (clauseId: string) => void;
}

export const ThreeDModal: React.FC<ThreeDModalProps> = ({
  isOpen,
  onClose,
  analysis,
  selectedClauseId,
  onSelectClause,
}) => {
  const [active3DTab, setActive3DTab] = useState<'SPHERE' | 'LEXUZ_GLTF' | 'SCALES'>('LEXUZ_GLTF');

  React.useEffect(() => {
    if (!isOpen) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  const riskyCount = analysis.clauses.filter(
    (c) => c.risk_level === 'RED' || c.risk_level === 'YELLOW'
  ).length;

  return (
    <div 
      className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6 bg-black/75 backdrop-blur-2xl animate-in fade-in duration-200"
      onClick={onClose}
    >
      <div 
        className="relative w-full max-w-6xl h-[88vh] rounded-3xl liquid-glass-card flex flex-col overflow-hidden border border-white/15 shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header (Liquid Glass) */}
        <div className="flex flex-col sm:flex-row items-center justify-between p-4 px-6 border-b border-white/10 bg-white/[0.03] backdrop-blur-xl gap-3">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl liquid-glass-pill flex items-center justify-center text-sky-400 border border-sky-500/30">
              <Box className="w-5 h-5 animate-pulse text-cyan-300" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-base font-bold text-white tracking-tight">
                  LexGuard WebGL 3D Fazosi
                </h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 font-bold">
                  Three.js PBR + GLTF
                </span>
              </div>
              <p className="text-[11px] text-slate-300">
                Rasmiy Lex.uz 3D metallik emblemasi va interaktiv muvozanat tarozisi
              </p>
            </div>
          </div>

          {/* 3D Tabs (Segmented Glass Pill) */}
          <div className="flex items-center p-1 bg-black/40 rounded-full border border-white/10">
            <button
              onClick={() => setActive3DTab('LEXUZ_GLTF')}
              className={`flex items-center gap-1.5 px-4 py-1.5 rounded-full text-xs font-bold transition-all cursor-pointer ${
                active3DTab === 'LEXUZ_GLTF'
                  ? 'bg-gradient-to-r from-sky-500 to-blue-600 text-white shadow-md shadow-sky-500/30'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <Box className="w-3.5 h-3.5 text-cyan-300" />
              <span>Lex.uz 3D GLTF</span>
            </button>

            <button
              onClick={() => setActive3DTab('SCALES')}
              className={`flex items-center gap-1.5 px-4 py-1.5 rounded-full text-xs font-bold transition-all cursor-pointer ${
                active3DTab === 'SCALES'
                  ? 'bg-gradient-to-r from-sky-500 to-blue-600 text-white shadow-md shadow-sky-500/30'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <Scale className="w-3.5 h-3.5 text-amber-300" />
              <span>Muvozanat Tarozisi</span>
            </button>

            <button
              onClick={() => setActive3DTab('SPHERE')}
              className={`flex items-center gap-1.5 px-4 py-1.5 rounded-full text-xs font-bold transition-all cursor-pointer ${
                active3DTab === 'SPHERE'
                  ? 'bg-gradient-to-r from-sky-500 to-blue-600 text-white shadow-md shadow-sky-500/30'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <Cpu className="w-3.5 h-3.5" />
              <span>Risk Sferasi</span>
            </button>

            <button
              onClick={onClose}
              className="ml-2 w-8 h-8 rounded-full flex items-center justify-center text-slate-400 hover:text-white hover:bg-white/10 transition-colors cursor-pointer"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* 3D Canvas Body */}
        <div className="relative flex-1 w-full h-full overflow-hidden bg-slate-950/70">
          {active3DTab === 'LEXUZ_GLTF' && (
            <div className="w-full h-full flex flex-col items-center justify-center relative p-4">
              <LexUz3DLogo size="hero" className="w-full h-full" autoRotate={true} interactive={true} />
              <div className="absolute bottom-6 left-1/2 -translate-x-1/2 liquid-glass-pill px-5 py-2 rounded-full text-xs text-slate-200 border border-white/15 flex items-center gap-2 shadow-xl">
                <Sparkles className="w-4 h-4 text-cyan-300 animate-pulse" />
                <span>Kursor bilan 360° aylantiring va yaqinlashtiring</span>
              </div>
            </div>
          )}

          {active3DTab === 'SCALES' && (
            <div className="w-full h-full relative">
              <LegalScales3D
                className="w-full h-full"
                tiltRatio={riskyCount > 0 ? -0.55 : 0}
              />
            </div>
          )}

          {active3DTab === 'SPHERE' && (
            <div className="w-full h-full relative">
              <Contract3DVisualizer
                analysis={analysis}
                selectedClauseId={selectedClauseId}
                onSelectClause={onSelectClause}
              />
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
