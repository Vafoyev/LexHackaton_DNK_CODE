import React, { useState } from 'react';
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '../ui/card';
import { Badge } from '../ui/badge';
import { Button } from '../ui/button';
import { Input } from '../ui/input';
import { 
  FileText, 
  Search, 
  Download, 
  ExternalLink, 
  ShieldAlert, 
  ShieldCheck, 
  AlertTriangle,
  Calendar,
  Sparkles,
  Plus
} from 'lucide-react';
import { AnalysisResult } from '../../types/contract';

interface DocumentsViewProps {
  currentAnalysis: AnalysisResult;
  onOpenContract: (contract: AnalysisResult) => void;
  onOpenScan: () => void;
}

interface ContractRecord {
  id: string;
  title: string;
  counterparty: string;
  date: string;
  score: number;
  criticalCount: number;
  mediumCount: number;
  lowCount: number;
  category: 'IT' | 'Ijara' | 'Oldi-sotdi' | 'Mehnat';
  status: 'QIZIL' | 'SARIQ' | 'YASHIL';
  data: AnalysisResult;
}

export const DocumentsView: React.FC<DocumentsViewProps> = ({
  currentAnalysis,
  onOpenContract,
  onOpenScan,
}) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [activeFilter, setActiveFilter] = useState<'all' | 'QIZIL' | 'SARIQ' | 'YASHIL'>('all');

  const documents: ContractRecord[] = [
    {
      id: 'doc-001',
      title: 'IT Autsorsing va Dasturiy Ta\'minot Shartnomasi',
      counterparty: 'Digital Innovators MChJ',
      date: '2026-11-21',
      score: 100 - (currentAnalysis.summary?.risk_score ?? 32),
      criticalCount: 2,
      mediumCount: 4,
      lowCount: 11,
      category: 'IT',
      status: 'QIZIL',
      data: currentAnalysis,
    },
    {
      id: 'doc-002',
      title: 'Tijoriy Bino va Ofis Joylashuvi Ijara Shartnomasi',
      counterparty: 'Poytaxt Property Invest MChJ',
      date: '2026-11-19',
      score: 84,
      criticalCount: 0,
      mediumCount: 2,
      lowCount: 14,
      category: 'Ijara',
      status: 'SARIQ',
      data: currentAnalysis,
    },
    {
      id: 'doc-003',
      title: 'Mulk va Texnika Vositalari Oldi-Sotdi Bitimi',
      counterparty: 'Asia Agro Logistics XK',
      date: '2026-11-15',
      score: 95,
      criticalCount: 0,
      mediumCount: 0,
      lowCount: 18,
      category: 'Oldi-sotdi',
      status: 'YASHIL',
      data: currentAnalysis,
    },
    {
      id: 'doc-004',
      title: 'Yetakchi Dasturchi bilan Mehnat Shartnomasi',
      counterparty: 'DNK Code Solutions MChJ',
      date: '2026-11-10',
      score: 72,
      criticalCount: 1,
      mediumCount: 3,
      lowCount: 12,
      category: 'Mehnat',
      status: 'QIZIL',
      data: currentAnalysis,
    },
  ];

  const filteredDocs = documents.filter((doc) => {
    const matchesSearch =
      doc.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      doc.counterparty.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesFilter = activeFilter === 'all' || doc.status === activeFilter;
    return matchesSearch && matchesFilter;
  });

  return (
    <div className="max-w-6xl w-full mx-auto px-4 py-8 space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">
            Hujjatlar
          </h1>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">
            LexGuard AI va Lex.uz orqali audit qilingan barcha shartnomalar arxivi
          </p>
        </div>
        <Button onClick={onOpenScan} className="gap-2 shadow-sm">
          <Plus className="w-4 h-4" />
          Yangi Shartnoma Skanerlash
        </Button>
      </div>

      {/* Search & Filters */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
          <Input
            placeholder="Hujjat nomi yoki kontragent bo'yicha qidirish..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-9"
          />
        </div>
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 sm:pb-0">
          <Button
            variant={activeFilter === 'all' ? 'default' : 'outline'}
            size="sm"
            onClick={() => setActiveFilter('all')}
          >
            Barchasi ({documents.length})
          </Button>
          <Button
            variant={activeFilter === 'QIZIL' ? 'destructive' : 'outline'}
            size="sm"
            onClick={() => setActiveFilter('QIZIL')}
            className={activeFilter !== 'QIZIL' ? 'text-red-600 dark:text-red-400' : ''}
          >
            Qizil xavf
          </Button>
          <Button
            variant={activeFilter === 'SARIQ' ? 'secondary' : 'outline'}
            size="sm"
            onClick={() => setActiveFilter('SARIQ')}
            className={activeFilter !== 'SARIQ' ? 'text-amber-600 dark:text-amber-400' : ''}
          >
            Tijoriy risk
          </Button>
          <Button
            variant={activeFilter === 'YASHIL' ? 'secondary' : 'outline'}
            size="sm"
            onClick={() => setActiveFilter('YASHIL')}
            className={activeFilter !== 'YASHIL' ? 'text-emerald-600 dark:text-emerald-400' : ''}
          >
            Xavfsiz
          </Button>
        </div>
      </div>

      {/* Document Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {filteredDocs.map((doc) => (
          <Card key={doc.id} className="hover:border-sky-500/50 transition-all duration-200">
            <CardHeader className="pb-3">
              <div className="flex items-start justify-between gap-3">
                <div className="flex items-center gap-2">
                  <div className="p-2 rounded-lg bg-sky-50 dark:bg-sky-950/60 text-sky-600 dark:text-sky-400">
                    <FileText className="w-5 h-5" />
                  </div>
                  <div>
                    <span className="text-xs font-medium text-slate-500 dark:text-slate-400">
                      {doc.category}
                    </span>
                    <CardTitle className="text-base line-clamp-1">
                      {doc.title}
                    </CardTitle>
                  </div>
                </div>
                {doc.status === 'QIZIL' && (
                  <Badge variant="risk-red" className="shrink-0 gap-1">
                    <ShieldAlert className="w-3 h-3" />
                    Qonun Ziddiyati
                  </Badge>
                )}
                {doc.status === 'SARIQ' && (
                  <Badge variant="risk-yellow" className="shrink-0 gap-1">
                    <AlertTriangle className="w-3 h-3" />
                    Tijoriy Xavf
                  </Badge>
                )}
                {doc.status === 'YASHIL' && (
                  <Badge variant="risk-green" className="shrink-0 gap-1">
                    <ShieldCheck className="w-3 h-3" />
                    Muvozanatli
                  </Badge>
                )}
              </div>
              <CardDescription className="flex items-center justify-between text-xs pt-2">
                <span>Kontragent: <strong>{doc.counterparty}</strong></span>
                <span className="flex items-center gap-1">
                  <Calendar className="w-3.5 h-3.5" />
                  {doc.date}
                </span>
              </CardDescription>
            </CardHeader>

            <CardContent className="space-y-4 pt-0">
              <div className="flex items-center justify-between p-2.5 rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-100 dark:border-slate-800 text-xs">
                <div>
                  <span className="text-slate-500 dark:text-slate-400">Huquqiy Salomatlik:</span>
                  <span className="ml-1.5 font-bold text-slate-900 dark:text-white">{doc.score}/100</span>
                </div>
                <div className="flex items-center gap-2 text-xs">
                  {doc.criticalCount > 0 && (
                    <span className="text-red-600 font-semibold">{doc.criticalCount} qizil</span>
                  )}
                  {doc.mediumCount > 0 && (
                    <span className="text-amber-600 font-semibold">{doc.mediumCount} sariq</span>
                  )}
                  <span className="text-emerald-600 font-semibold">{doc.lowCount} xavfsiz</span>
                </div>
              </div>

              <div className="flex items-center justify-end gap-2 pt-1">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => onOpenContract(doc.data)}
                  className="gap-1.5 text-xs"
                >
                  <ExternalLink className="w-3.5 h-3.5" />
                  Ochish (Studiyada)
                </Button>
              </div>
            </CardContent>
          </Card>
        ))}

        {filteredDocs.length === 0 && (
          <div className="col-span-full text-center py-12 border border-dashed rounded-xl border-slate-300 dark:border-slate-800">
            <p className="text-slate-500 dark:text-slate-400 text-sm">
              Hech qanday shartnoma topilmadi
            </p>
          </div>
        )}
      </div>
    </div>
  );
};
