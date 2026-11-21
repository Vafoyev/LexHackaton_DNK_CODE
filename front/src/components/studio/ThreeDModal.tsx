import React, { useState } from 'react';
import { X, Layers, Cpu, Scale, Sparkles, Box } from 'lucide-react';
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
  const [active3DTab, setActive3DTab] = useState<'SPHERE' | 'LEXUZ_GLTF' | 'SCALES'>('SPHERE');

  if (!isOpen) return null;

  const riskyCount = analysis.clauses.filter(
    (c) => c.risk_level === 'RED' || c.risk_level === 'YELLOW'
  ).length;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-2 sm:p-6 bg-slate-950/90 backdrop-blur-xl animate-in fade-in duration-200">
      <div 
        className="relative w-full max-w-6xl h-[90vh] rounded-3xl bg-slate-900 border border-slate-800 shadow-2xl flex flex-col overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex flex-col sm:flex-row items-center justify-between p-4 px-6 border-b border-slate-800 bg-slate-950/80 gap-3">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-sky-500/20 border border-sky-500/30 flex items-center justify-center text-sky-400">
              <Cpu className="w-5 h-5 animate-pulse" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-sm font-bold text-white tracking-tight">
                  LexGuard WebGL 3D Fazosi
                </h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                  Three.js + GLTF
                </span>
              </div>
              <p className="text-[11px] text-slate-400">
                Interaktiv 3D modellar, risk topologiyasi va Lex.uz rasmiy emblemasi
              </p>
            </div>
          </div>

          {/* 3D Tabs */}
          <div className="flex items-center p-1 bg-slate-950 rounded-2xl border border-slate-800">
            <button
              onClick={() => setActive3DTab('SPHERE')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                active3DTab === 'SPHERE'
                  ? 'bg-sky-500 text-white shadow-md shadow-sky-500/20'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <Cpu className="w-3.5 h-3.5" />
              <span>3D Sfera</span>
            </button>

            <button
              onClick={() => setActive3DTab('LEXUZ_GLTF')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                active3DTab === 'LEXUZ_GLTF'
                  ? 'bg-sky-500 text-white shadow-md shadow-sky-500/20'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <Box className="w-3.5 h-3.5 text-cyan-300" />
              <span>Lex.uz GLTF</span>
            </button>

            <button
              onClick={() => setActive3DTab('SCALES')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                active3DTab === 'SCALES'
                  ? 'bg-sky-500 text-white shadow-md shadow-sky-500/20'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <Scale className="w-3.5 h-3.5 text-amber-300" />
              <span>Muvozanat Tarozisi</span>
            </button>
          </div>

          <button
            onClick={onClose}
            className="p-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-all cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* 3D Body Content */}
        <div className="flex-1 w-full h-full relative overflow-hidden bg-slate-950">
          {active3DTab === 'SPHERE' && (
            <Contract3DVisualizer
              analysis={analysis}
              selectedClauseId={selectedClauseId}
              onSelectClause={(id) => {
                onSelectClause(id);
                onClose();
              }}
            />
          )}

          {active3DTab === 'LEXUZ_GLTF' && (
            <div className="h-full flex flex-col items-center justify-center p-6 text-center space-y-4">
              <div className="w-full max-w-xl h-80">
                <LexUz3DLogo size="hero" className="w-full h-full" autoRotate={true} interactive={true} />
              </div>
              <div className="max-w-md space-y-1">
                <h4 className="text-sm font-bold text-white flex items-center justify-center gap-2">
                  <span>Lex.uz 3D Metallik Vektor Emblemasi</span>
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-sky-500/20 text-sky-400 border border-sky-500/30">
                    GLTF 2.0 / GLB
                  </span>
                </h4>
                <p className="text-xs text-slate-400">
                  CorelDRAW vektoridan PBR Metallic-Roughness shaderi va Three.js ekstrudatsiyasi orqali generatsiya qilingan rasmiy 3D model. Sichqoncha orqali 360° aylantirishingiz mumkin.
                </p>
                <div className="pt-2 flex items-center justify-center gap-3 text-[11px] font-mono text-slate-500">
                  <span>Format: .GLTF / .GLB</span>
                  <span>·</span>
                  <span>Polygons: 13 Shapes</span>
                  <span>·</span>
                  <span>PBR Shader: ACESFilmic</span>
                </div>
              </div>
            </div>
          )}

          {active3DTab === 'SCALES' && (
            <div className="h-full flex flex-col items-center justify-center p-6 text-center space-y-4">
              <div className="w-full max-w-xl h-80">
                <LegalScales3D
                  className="w-full h-full"
                  tiltRatio={riskyCount > 0 ? -0.7 : 0}
                  isFixed={riskyCount === 0}
                />
              </div>
              <div className="max-w-md space-y-1">
                <h4 className="text-sm font-bold text-white flex items-center justify-center gap-2">
                  <span>Shartnoma Muvozanat Tarozisi (Scales of Justice)</span>
                </h4>
                <p className="text-xs text-slate-400">
                  {riskyCount > 0 
                    ? `Shartnomada ${riskyCount} ta asimmetrik xavf mavjud bo'lgani sababli, tarozi og'irligi bir tarafga og'moqda.`
                    : "Shartnomadagi barcha bandlar to'liq qonuniy va ikki tomon manfaatlari 50/50 muvozanatda!"}
                </p>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
