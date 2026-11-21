import React, { useState } from 'react';
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from '../ui/card';
import { Badge } from '../ui/badge';
import { Button } from '../ui/button';
import { 
  Building2, 
  User, 
  CheckCircle2, 
  ShieldCheck, 
  Key, 
  Lock, 
  Globe, 
  Sparkles,
  Award,
  Zap,
  ArrowRight
} from 'lucide-react';

interface ProfileViewProps {
  segment: 'b2c' | 'b2b';
  onSegmentChange: (segment: 'b2c' | 'b2b') => void;
  onOpenScan: () => void;
}

export const ProfileView: React.FC<ProfileViewProps> = ({
  segment,
  onSegmentChange,
  onOpenScan,
}) => {
  const isBusiness = segment === 'b2b';
  const [copiedKey, setCopiedKey] = useState(false);

  const handleCopyKey = () => {
    navigator.clipboard.writeText('lex_live_sec_991823abf87123');
    setCopiedKey(true);
    setTimeout(() => setCopiedKey(false), 2000);
  };

  return (
    <div className="max-w-4xl w-full mx-auto px-4 py-8 space-y-6">
      {/* Page Title */}
      <div>
        <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">
          Profil va Sozlamalar
        </h1>
        <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">
          ONE ID orqali tasdiqlangan huquqiy shaxs identifikatori va tizim parametrlari
        </p>
      </div>

      {/* ONE ID / Executive Identity Card */}
      <div className="relative overflow-hidden rounded-2xl border border-sky-500/30 bg-gradient-to-br from-slate-900 via-slate-850 to-sky-950 text-white p-6 shadow-xl">
        <div className="absolute right-0 top-0 w-80 h-80 bg-sky-500/10 rounded-full blur-3xl pointer-events-none" />

        <div className="relative z-10 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-6">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-sky-500 to-blue-600 flex items-center justify-center text-white font-bold text-2xl shadow-lg border border-white/20">
              {isBusiness ? 'DN' : 'AV'}
            </div>
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <h2 className="text-xl font-bold tracking-tight">
                  {isBusiness ? 'DNK CODE SOLUTIONS MChJ' : 'Aliyev Vali G\'aniyevich'}
                </h2>
                <Badge variant="outline" className="border-emerald-400/50 bg-emerald-500/20 text-emerald-300 text-[10px] gap-1">
                  <CheckCircle2 className="w-3 h-3" />
                  ONE ID Tasdiqlangan
                </Badge>
              </div>
              <p className="text-xs text-sky-200/80">
                {isBusiness ? 'STIR (INN): 308 192 481 · E-Imzo: Faol' : 'JShShIR: 32405910240012 · Fuqaro'}
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <div className="text-right sm:block hidden">
              <span className="text-[10px] uppercase tracking-wider text-sky-300 font-semibold block">Hozirgi Rejim</span>
              <span className="text-sm font-bold text-white">{isBusiness ? 'Yuridik Shaxs (B2B)' : 'Jismoniy Shaxs (B2C)'}</span>
            </div>
            <Button
              variant="secondary"
              size="sm"
              onClick={() => onSegmentChange(isBusiness ? 'b2c' : 'b2b')}
              className="bg-white/10 hover:bg-white/20 text-white border border-white/20 text-xs"
            >
              {isBusiness ? "B2C (Fuqaro) ga o'tish" : "B2B (Biznes) ga o'tish"}
            </Button>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Subscription & Tariffs */}
        <Card>
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="text-base flex items-center gap-2">
                <Award className="w-5 h-5 text-sky-600 dark:text-sky-400" />
                Obuna va Imkoniyatlar
              </CardTitle>
              <Badge variant="default" className="bg-sky-600 text-white text-[10px]">
                LexHackathon Pro
              </Badge>
            </div>
            <CardDescription className="text-xs">
              Cheklovlarsiz shartnoma auditi va Lex.uz sinxronizatsiyasi
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3 text-xs">
            <div className="flex items-center justify-between py-1.5 border-b border-slate-100 dark:border-slate-800">
              <span className="text-slate-500 dark:text-slate-400">Oylik Audit Limiti:</span>
              <span className="font-semibold text-slate-900 dark:text-white">Cheksiz (Unlimited)</span>
            </div>
            <div className="flex items-center justify-between py-1.5 border-b border-slate-100 dark:border-slate-800">
              <span className="text-slate-500 dark:text-slate-400">Lex.uz Sinxronlash:</span>
              <span className="font-semibold text-emerald-600">Avtomatik (Har 12 soatda)</span>
            </div>
            <div className="flex items-center justify-between py-1.5">
              <span className="text-slate-500 dark:text-slate-400">Maxfiylik Standarti:</span>
              <span className="font-semibold text-slate-900 dark:text-white">O‘RQ-547 va O‘RQ-1125</span>
            </div>
          </CardContent>
          <CardFooter className="pt-0">
            <Button onClick={onOpenScan} className="w-full gap-2 text-xs">
              <Zap className="w-4 h-4" />
              Yangi Shartnoma Tekshirish
            </Button>
          </CardFooter>
        </Card>

        {/* Security & Compliance Card */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2">
              <ShieldCheck className="w-5 h-5 text-emerald-600 dark:text-emerald-400" />
              Xavfsizlik va Anonimizatsiya
            </CardTitle>
            <CardDescription className="text-xs">
              Lokal PII sanitization — shaxsiy ma'lumotlar tashqariga chiqmaydi
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3 text-xs">
            <div className="p-3 rounded-lg bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-500/20 text-emerald-800 dark:text-emerald-300 space-y-1">
              <div className="font-semibold flex items-center gap-1.5">
                <Lock className="w-3.5 h-3.5" />
                O‘RQ-547 Standartiga 100% Muvofiq
              </div>
              <p className="text-[11px] leading-relaxed">
                Pasport seriya, telefon raqamlari, bank hisob varaqlari va summalar sun'iy intellektga yuborilishdan oldin brauzeringizda shifrlanadi.
              </p>
            </div>

            <div className="space-y-1 pt-1">
              <span className="text-slate-500 dark:text-slate-400 block">B2B API Token (Integratsiyalar uchun):</span>
              <div className="flex items-center gap-2">
                <code className="flex-1 px-2.5 py-1.5 rounded bg-slate-100 dark:bg-slate-800 font-mono text-[11px] text-slate-700 dark:text-slate-300 truncate">
                  lex_live_sec_991823abf87123...
                </code>
                <Button variant="outline" size="sm" onClick={handleCopyKey} className="text-xs shrink-0">
                  {copiedKey ? 'Nusxalandi' : 'Nusxa'}
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};
