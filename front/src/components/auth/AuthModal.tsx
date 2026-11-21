import React, { useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { 
  X, 
  ShieldCheck, 
  Lock, 
  Mail, 
  Building, 
  User, 
  ArrowRight, 
  Zap, 
  CheckCircle2, 
  AlertCircle 
} from 'lucide-react';

interface AuthModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const AuthModal: React.FC<AuthModalProps> = ({ isOpen, onClose }) => {
  const { login, demoLogin, register, isLoading } = useAuth();

  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [orgName, setOrgName] = useState('');
  const [agreeConsent, setAgreeConsent] = useState(true);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleQuickFill = (type: 'lawyer' | 'client') => {
    if (type === 'lawyer') {
      setEmail('lawyer@lexguard.uz');
      setPassword('Password123!');
    } else {
      setEmail('client@lexguard.uz');
      setPassword('Password123!');
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);

    if (mode === 'login') {
      if (!email || !password) {
        setErrorMsg('Email va parolni kiriting');
        return;
      }
      try {
        await login(email, password);
        onClose();
      } catch (err: any) {
        setErrorMsg(err.message || 'Kirishda xatolik yuz berdi');
      }
    } else {
      if (!fullName || !email || !password || !orgName) {
        setErrorMsg('Barcha maydonlarni to‘ldiring');
        return;
      }
      if (!agreeConsent) {
        setErrorMsg('O‘RQ-547 bo‘yicha shaxsiy ma’lumotlarni qayta ishlashga rozilik shart');
        return;
      }
      try {
        await register({ email, password, full_name: fullName, org_name: orgName });
        onClose();
      } catch (err: any) {
        setErrorMsg(err.message || 'Ro‘yxatdan o‘tishda xatolik');
      }
    }
  };

  const handleInstantDemo = async (role: 'lawyer' | 'client') => {
    await demoLogin(role);
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-md animate-in fade-in duration-200">
      <div 
        className="relative w-full max-w-md rounded-3xl bg-slate-900 border border-slate-800 shadow-2xl p-6 sm:p-8 overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Yopish tugmasi */}
        <button
          onClick={onClose}
          className="absolute top-5 right-5 p-2 rounded-xl bg-slate-800/60 hover:bg-slate-700 text-slate-400 hover:text-white transition-all cursor-pointer"
        >
          <X className="w-4 h-4" />
        </button>

        {/* Logo & Sarlavha */}
        <div className="flex items-center gap-3 mb-6">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-sky-500 to-emerald-400 p-[2px] shadow-lg shadow-sky-500/20">
            <div className="w-full h-full bg-slate-900 rounded-[10px] flex items-center justify-center">
              <ShieldCheck className="w-6 h-6 text-sky-400" />
            </div>
          </div>
          <div>
            <h3 className="text-lg font-bold text-white tracking-tight">
              {mode === 'login' ? 'LexGuard AI Tizimiga Kirish' : 'B2B Tashkilotni Ro‘yxatdan O‘tkazish'}
            </h3>
            <p className="text-xs text-slate-400 font-mono">
              Lex.uz Integratsiyalashgan Yuridik Kabinet
            </p>
          </div>
        </div>

        {/* 1-Bosishda OneID / Tezkor Demo Qatlam */}
        <div className="mb-5 space-y-2">
          <button
            onClick={() => handleInstantDemo('lawyer')}
            className="w-full py-2.5 px-4 rounded-xl bg-gradient-to-r from-sky-600 to-brand-600 hover:from-sky-500 hover:to-brand-500 text-white text-xs font-bold shadow-lg shadow-sky-600/30 flex items-center justify-between transition-all cursor-pointer hover:scale-[1.01]"
          >
            <div className="flex items-center gap-2">
              <Zap className="w-4 h-4 fill-current text-amber-300" />
              <span>1-bosishda Demo Yurist sifatida kirish</span>
            </div>
            <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-black/20 text-sky-200">
              Alisher Qodirov
            </span>
          </button>

          <div className="flex items-center gap-2">
            <button
              onClick={() => handleInstantDemo('client')}
              className="flex-1 py-2 px-3 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-200 text-xs font-semibold flex items-center justify-center gap-1.5 transition-all cursor-pointer"
            >
              <span>🏢 Tadbirkor (Klient) Demo</span>
            </button>

            <button
              onClick={() => handleInstantDemo('lawyer')}
              className="flex-1 py-2 px-3 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-emerald-400 text-xs font-semibold flex items-center justify-center gap-1.5 transition-all cursor-pointer"
            >
              <span>🇺🇿 OneID Sandbox</span>
            </button>
          </div>
        </div>

        <div className="relative my-4">
          <div className="absolute inset-0 flex items-center">
            <div className="w-full border-t border-slate-800"></div>
          </div>
          <div className="relative flex justify-center text-[10px] uppercase font-mono tracking-widest">
            <span className="bg-slate-900 px-3 text-slate-500">yoki email orqali</span>
          </div>
        </div>

        {/* Xatolik xabari */}
        {errorMsg && (
          <div className="mb-4 p-3 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-400 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 shrink-0" />
            <span>{errorMsg}</span>
          </div>
        )}

        {/* Forma */}
        <form onSubmit={handleSubmit} className="space-y-3.5">
          {mode === 'register' && (
            <>
              <div>
                <label className="block text-[11px] font-medium text-slate-400 mb-1">F.I.Sh.</label>
                <div className="relative">
                  <User className="w-4 h-4 text-slate-500 absolute left-3 top-3" />
                  <input
                    type="text"
                    value={fullName}
                    onChange={(e) => setFullName(e.target.value)}
                    placeholder="Masalan: Aziz Rahimov"
                    className="w-full pl-9 pr-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white focus:outline-none focus:border-sky-500 transition-colors"
                  />
                </div>
              </div>

              <div>
                <label className="block text-[11px] font-medium text-slate-400 mb-1">Tashkilot nomi (yoki YaTT)</label>
                <div className="relative">
                  <Building className="w-4 h-4 text-slate-500 absolute left-3 top-3" />
                  <input
                    type="text"
                    value={orgName}
                    onChange={(e) => setOrgName(e.target.value)}
                    placeholder="Masalan: Digital Solutions MCHJ"
                    className="w-full pl-9 pr-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white focus:outline-none focus:border-sky-500 transition-colors"
                  />
                </div>
              </div>
            </>
          )}

          <div>
            <div className="flex items-center justify-between mb-1">
              <label className="text-[11px] font-medium text-slate-400">Elektron pochta</label>
              {mode === 'login' && (
                <div className="flex gap-1.5 text-[10px] text-sky-400">
                  <button type="button" onClick={() => handleQuickFill('lawyer')} className="hover:underline">Yurist</button>
                  <span>·</span>
                  <button type="button" onClick={() => handleQuickFill('client')} className="hover:underline">Klient</button>
                </div>
              )}
            </div>
            <div className="relative">
              <Mail className="w-4 h-4 text-slate-500 absolute left-3 top-3" />
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="nomi@kompaniya.uz"
                className="w-full pl-9 pr-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white focus:outline-none focus:border-sky-500 transition-colors"
              />
            </div>
          </div>

          <div>
            <label className="block text-[11px] font-medium text-slate-400 mb-1">Maxfiy parol</label>
            <div className="relative">
              <Lock className="w-4 h-4 text-slate-500 absolute left-3 top-3" />
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full pl-9 pr-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white focus:outline-none focus:border-sky-500 transition-colors"
              />
            </div>
          </div>

          {mode === 'register' && (
            <label className="flex items-start gap-2 pt-1 text-[11px] text-slate-400 cursor-pointer">
              <input
                type="checkbox"
                checked={agreeConsent}
                onChange={(e) => setAgreeConsent(e.target.checked)}
                className="mt-0.5 rounded border-slate-800 bg-slate-950 text-sky-500"
              />
              <span>
                O‘zbekiston Respublikasi O‘RQ-547 qonuniga binoan shaxsiy ma’lumotlarni anonim qayta ishlashga roziman.
              </span>
            </label>
          )}

          <button
            type="submit"
            disabled={isLoading}
            className="w-full py-2.5 rounded-xl bg-slate-100 hover:bg-white text-slate-900 text-xs font-bold flex items-center justify-center gap-1.5 transition-all shadow-md cursor-pointer mt-2"
          >
            {isLoading ? (
              <span>Tekshirilmoqda...</span>
            ) : mode === 'login' ? (
              <>
                <span>Kirish</span>
                <ArrowRight className="w-3.5 h-3.5" />
              </>
            ) : (
              <>
                <span>Ro‘yxatdan O‘tish</span>
                <CheckCircle2 className="w-3.5 h-3.5" />
              </>
            )}
          </button>
        </form>

        {/* Tab almashtirish */}
        <div className="mt-5 text-center text-xs text-slate-400">
          {mode === 'login' ? (
            <span>
              Hisobingiz yo‘qmi?{' '}
              <button 
                onClick={() => { setMode('register'); setErrorMsg(null); }}
                className="text-sky-400 font-bold hover:underline"
              >
                Yangi hisob yaratish
              </button>
            </span>
          ) : (
            <span>
              Akkauntingiz bormi?{' '}
              <button 
                onClick={() => { setMode('login'); setErrorMsg(null); }}
                className="text-sky-400 font-bold hover:underline"
              >
                Kirish sahifasi
              </button>
            </span>
          )}
        </div>
      </div>
    </div>
  );
};
