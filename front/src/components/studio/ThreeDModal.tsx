import React from 'react';
import { X, Layers, Cpu, Eye } from 'lucide-react';
import { AnalysisResult } from '../../types/contract';
import { Contract3DVisualizer } from '../visualizer/Contract3DVisualizer';

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
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-2 sm:p-6 bg-slate-950/90 backdrop-blur-xl animate-in fade-in duration-200">
      <div 
        className="relative w-full max-w-6xl h-[90vh] rounded-3xl bg-slate-900 border border-slate-800 shadow-2xl flex flex-col overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between p-4 px-6 border-b border-slate-800 bg-slate-950/60">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-sky-500/20 border border-sky-500/30 flex items-center justify-center text-sky-400">
              <Cpu className="w-5 h-5 animate-pulse" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-sm font-bold text-white tracking-tight">
                  3D Shartnoma Risk Fazosi (Knowledge Graph)
                </h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                  WebGL 3D
                </span>
              </div>
              <p className="text-[11px] text-slate-400">
                Sferadagi tugunlarni bosib, xavflar klasterini 3D fazoda ko‘ring
              </p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-all cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* 3D Visualizer Canvas */}
        <div className="flex-1 w-full h-full relative overflow-hidden">
          <Contract3DVisualizer
            analysis={analysis}
            selectedClauseId={selectedClauseId}
            onSelectClause={(id) => {
              onSelectClause(id);
              onClose(); // bosganda studiodagi o'sha bandga olib o'tadi
            }}
          />
        </div>
      </div>
    </div>
  );
};
