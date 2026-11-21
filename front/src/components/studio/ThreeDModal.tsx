import React, { useState } from 'react';
import { Box, Cpu, Scale, Sparkles } from 'lucide-react';
import { AnalysisResult } from '../../types/contract';
import { Contract3DVisualizer } from '../visualizer/Contract3DVisualizer';
import { LexUz3DLogo } from '../3d/LexUz3DLogo';
import { LegalScales3D } from '../3d/LegalScales3D';
import { Badge } from '../ui/badge';
import { Dialog, DialogContent, DialogDescription, DialogTitle } from '../ui/dialog';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../ui/tabs';

interface ThreeDModalProps {
  isOpen: boolean;
  onClose: () => void;
  analysis: AnalysisResult;
  selectedClauseId?: string | null;
  onSelectClause: (clauseId: string) => void;
}

type View3D = 'SPHERE' | 'LEXUZ_GLTF' | 'SCALES';

export const ThreeDModal: React.FC<ThreeDModalProps> = ({ isOpen, onClose, analysis, selectedClauseId, onSelectClause }) => {
  const [view, setView] = useState<View3D>('LEXUZ_GLTF');

  const riskyCount = analysis.clauses.filter((c) => c.risk_level === 'RED' || c.risk_level === 'YELLOW').length;

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="flex h-[88vh] w-[calc(100%-1.5rem)] max-w-6xl flex-col gap-0 overflow-hidden rounded-2xl p-0 sm:max-w-6xl">
        <Tabs value={view} onValueChange={(v) => setView(v as View3D)} className="flex min-h-0 flex-1 flex-col">
          {/* Sarlavha */}
          <div className="flex flex-col items-center justify-between gap-3 border-b p-4 pr-14 sm:flex-row sm:px-6">
            <div className="flex items-center gap-3">
              <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary">
                <Box className="h-5 w-5" aria-hidden="true" />
              </span>
              <div>
                <div className="flex items-center gap-2">
                  <DialogTitle className="text-base">LexGuard WebGL 3D fazosi</DialogTitle>
                  <Badge variant="success">Three.js PBR + GLTF</Badge>
                </div>
                <DialogDescription className="text-xs">Lex.uz 3D emblemasi va interaktiv muvozanat tarozisi</DialogDescription>
              </div>
            </div>

            <TabsList className="rounded-full">
              <TabsTrigger value="LEXUZ_GLTF" className="gap-1.5 rounded-full text-xs">
                <Box className="h-3.5 w-3.5" aria-hidden="true" /> Lex.uz 3D
              </TabsTrigger>
              <TabsTrigger value="SCALES" className="gap-1.5 rounded-full text-xs">
                <Scale className="h-3.5 w-3.5" aria-hidden="true" /> Muvozanat tarozisi
              </TabsTrigger>
              <TabsTrigger value="SPHERE" className="gap-1.5 rounded-full text-xs">
                <Cpu className="h-3.5 w-3.5" aria-hidden="true" /> Risk sferasi
              </TabsTrigger>
            </TabsList>
          </div>

          {/* 3D maydon (faol tabdagina yuklanadi: WebGL kontekstlari tejaladi) */}
          <div className="relative min-h-0 flex-1 overflow-hidden bg-slate-950">
            {view === 'LEXUZ_GLTF' && (
              <TabsContent value="LEXUZ_GLTF" className="relative m-0 flex h-full w-full flex-col items-center justify-center p-4">
                <LexUz3DLogo size="hero" className="h-full w-full" autoRotate={true} interactive={true} />
                <div className="absolute bottom-6 left-1/2 flex -translate-x-1/2 items-center gap-2 rounded-full border border-white/15 bg-black/50 px-5 py-2 text-xs text-slate-200 backdrop-blur">
                  <Sparkles className="h-4 w-4 text-zinc-300" aria-hidden="true" />
                  Kursor bilan 360° aylantiring va yaqinlashtiring
                </div>
              </TabsContent>
            )}
            {view === 'SCALES' && (
              <TabsContent value="SCALES" className="relative m-0 h-full w-full">
                <LegalScales3D className="h-full w-full" tiltRatio={riskyCount > 0 ? -0.55 : 0} />
              </TabsContent>
            )}
            {view === 'SPHERE' && (
              <TabsContent value="SPHERE" className="relative m-0 h-full w-full">
                <Contract3DVisualizer analysis={analysis} selectedClauseId={selectedClauseId} onSelectClause={onSelectClause} />
              </TabsContent>
            )}
          </div>
        </Tabs>
      </DialogContent>
    </Dialog>
  );
};
